import { storageStubSQL } from './storage-stub.mjs';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { readFile,readdir } from 'node:fs/promises';
import { randomUUID,createHash } from 'node:crypto';
import assert from 'node:assert/strict';

const native=process.argv.includes('--native');
let admin,db,database,checks=0;
const check=(condition,message)=>{assert.ok(condition,message);checks++};
const fixture=JSON.parse(await readFile(new URL('fixtures/swift-cooking-operations.json',import.meta.url),'utf8'));
const owner=fixture.initial.accountID,user=randomUUID(),session=randomUUID(),otherUser=randomUUID(),otherSession=randomUUID();
const sqlString=value=>"'"+String(value).replaceAll("'","''")+"'";
function canonical(value,key='') {
 if(value===null)return undefined;
 if(Array.isArray(value))return value.map(v=>canonical(v,key)).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().filter(k=>value[k]!==null).map(k=>[k,canonical(value[k],k)]));
 if(typeof value==='string' && (key==='id'||key.endsWith('ID')||key==='key') && /^[a-f0-9-]{36}$/i.test(value))return value.toUpperCase();
 return value;
}
async function actor(uid,sid) {
 await db.exec('reset role; set role authenticated');
 await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[uid,JSON.stringify({sub:uid,session_id:sid})]);
}
async function apply(envelope){return (await db.query('select api.apply_cooking_operation($1::jsonb) result',[JSON.stringify(envelope)])).rows[0].result}
async function snapshot(){return (await db.query('select api.open_account_library() result')).rows[0].result}
async function rejected(envelope,code,label){try{await apply(envelope);assert.fail(label)}catch(e){assert.equal(e.code,code,label);checks++}}
function operation(upserts,deletions=[],revision=0,storeID=randomUUID(),predecessorID) {
 const payload=Buffer.from(JSON.stringify({upserts,deletions}));
 return {operationID:randomUUID(),storeID,accountID:owner,kind:'fixtureMutation',payload:payload.toString('base64'),payloadHash:createHash('sha256').update(payload).digest('hex'),expectedRevision:revision,...(predecessorID?{predecessorID}:{})};
}
function record(entity,value,key=value.id??value.key) {return {reference:{entity,key},data:Buffer.from(JSON.stringify(value)).toString('base64')}}
try {
 if(native){
  assert(process.env.PG_TEST_SOCKET?.startsWith('/private/tmp/staygrubby-'),'Native harness refuses non-disposable/non-Unix connections');
  const base={host:process.env.PG_TEST_SOCKET,port:Number(process.env.PG_TEST_PORT||55439),user:process.env.USER};
  admin=new pg.Client({...base,database:'postgres'});await admin.connect();
  for(const role of ['authenticated','anon','authenticator'])if(!(await admin.query('select 1 from pg_roles where rolname=$1',[role])).rowCount)await admin.query(`create role ${role} nologin`);
  database='staygrubby_structured_'+randomUUID().replaceAll('-','');await admin.query(`create database ${database}`);
  const client=new pg.Client({...base,database});await client.connect();
  db={query:(...args)=>client.query(...args),exec:sql=>client.query(sql),close:()=>client.end()};
 }else{
  db=new PGlite();await db.exec('create role authenticated;create role anon;create role authenticator');
 }
 await db.exec(`create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean default false,deleted_at timestamptz);
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id),not_after timestamptz);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;`);
 await db.exec(storageStubSQL);
 const directory=new URL('../../supabase/migrations/',import.meta.url);
 for(const file of (await readdir(directory)).filter(f=>f.endsWith('.sql')).sort())await db.exec(await readFile(new URL(file,directory),'utf8'));
 await db.query('insert into auth.users(id) values($1),($2)',[user,otherUser]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[session,user,otherSession,otherUser]);
 await db.query('insert into staygrubby.accounts(id,sync_revision) values($1,1)',[owner]);
 await db.query('insert into staygrubby.auth_account_links(auth_user_id,account_id) values($1,$2)',[user,owner]);
 await db.query('insert into staygrubby.profiles(account_id) values($1)',[owner]);
 const ranking=fixture.initial.rankings[0];
 await db.query("insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values($1,$2,$3,$4,'global')",[owner,ranking.id,ranking.name,ranking.createdAt]);
 await db.query("insert into staygrubby.account_libraries(account_id,library_key,global_ranking_id,bridge_version) values($1,'local',$2,1)",[owner,ranking.id]);
 await db.exec('set extra_float_digits=0');
 await actor(user,session);
 check(JSON.stringify(canonical((await snapshot()).graph))===JSON.stringify(canonical(fixture.initial)),'Initial Swift/server graph parity');
 let latest=1;
 for(const [index,envelope] of fixture.operations.entries()){
  const receipt=await apply(envelope);latest++;
  check(receipt.operationID.toUpperCase()===envelope.operationID.toUpperCase()&&receipt.revision===latest,'Receipt UUID/revision');
  check(receipt.storeID.toUpperCase()===envelope.storeID.toUpperCase()&&receipt.accountID.toUpperCase()===owner.toUpperCase()&&receipt.payloadHash===envelope.payloadHash,'Receipt owner/store/hash');
  check(JSON.stringify(await apply(envelope))===JSON.stringify(receipt),'Ambiguous response retry identical durable receipt');
  const restored=await snapshot();
  assert.deepEqual(canonical(restored.graph),canonical(fixture.steps[index]),'Exact Swift encoded graph at step '+index);checks++;
  check(restored.account.sync_revision===latest,'Duplicate request does not advance revision');
 }
 check((await db.query('select count(*)::int n from staygrubby.sync_operations where account_id=$1',[owner])).rows[0].n===fixture.operations.length,'No duplicate operation rows');
 const accepted=canonical((await snapshot()).graph);
 await rejected({...fixture.operations[0],storeID:randomUUID()},'23505','Operation UUID cannot change installation');
 await rejected({...fixture.operations[0],expectedRevision:2},'23505','Operation UUID cannot change expectation');
 await rejected({...fixture.operations[0],kind:'other'},'23505','Operation UUID cannot change kind');
 await rejected({...fixture.operations[0],predecessorID:randomUUID()},'23505','Operation UUID cannot change predecessor');
 await rejected({...fixture.operations[0],payloadHash:'0'.repeat(64)},'22023','Server recomputes exact SHA256');
 const dish=fixture.expected.dishes[0];
 await rejected(operation([record('dish',{...dish,name:'Stale write'})],[],1),'40001','Stale independent-device revision rejected');
 check(JSON.stringify(canonical((await snapshot()).graph))===JSON.stringify(accepted),'Conflict leaves accepted state intact');
 await rejected(operation([record('dish',{...dish,name:'Forged chain'})],[],1,randomUUID(),fixture.operations.at(-1).operationID),'22023','Predecessor from different store denied');
 // Source storage fields/types round-trip without converting legacy nullable metadata.
 for(const typeCode of ['original','cookbook','restaurant','onlineRecipe','socialMedia','friendFamily','other']){
  const source={...fixture.expected.sources[0],typeCode,onlineURL:'https://example.com/a?x=1&y=2',socialURL:'https://example.com/social',friendNote:'Nullable legacy field'};
  await apply(operation([record('source',source)],[],latest));latest++;
  const restored=(await snapshot()).graph.sources.find(s=>s.id.toUpperCase()===source.id.toUpperCase());
  check(restored.typeCode===typeCode&&restored.onlineURL===source.onlineURL&&restored.socialURL===source.socialURL&&restored.friendNote===source.friendNote,'Full Source fields '+typeCode);
 }
 const afterSources=canonical((await snapshot()).graph);
 await rejected(operation([record('dish',{...dish,sourceID:randomUUID()})],[],latest),'55000','Dangling active Source rejected atomically');
 await rejected(operation([record('media',{...fixture.expected.media[0],displayFilename:'../outside.jpg'})],[],latest),'23514','Unsafe restored media path rejected');
 const observation=(await snapshot()).graph.comparisons[0];
 if(observation)await rejected(operation([record('comparison',{...observation,isTie:!observation.isTie,preferredItemID:observation.isTie?observation.firstItemID:null})],[],latest),'P0001','Accepted evidence cannot be edited');
 check(JSON.stringify(canonical((await snapshot()).graph))===JSON.stringify(afterSources),'Rejected graph transactions leave complete state intact');
 const deleted=fixture.expected.deletions.find(r=>r.entity==='attempt');
 const oldAttempt=fixture.steps[0].attempts.find(a=>a.id.toUpperCase()===deleted?.key.toUpperCase())??fixture.steps[1].attempts.find(a=>a.id.toUpperCase()===deleted?.key.toUpperCase());
 await rejected(operation([record('attempt',oldAttempt)],[],latest),'55000','Deleted attempt identity cannot resurrect');
 await rejected(operation([], [{entity:'library',key:'local'}],latest),'22023','Global library cannot be wiped');
 const duplicateRecord=record('dish',dish);
 await rejected(operation([duplicateRecord,duplicateRecord],[],latest),'22023','Duplicate references rejected');
 // Device B accepts a current revision; Device A can fetch it, never blindly overwrite it.
 const edit=operation([record('dish',{...dish,name:'Device B accepted edit'})],[],latest);
 await apply(edit);latest++;
 check((await snapshot()).graph.dishes[0].name==='Device B accepted edit','Second installation edit restores');
 await actor(otherUser,otherSession);
 const other=await snapshot();
 check(other.graph.dishes.length===0&&other.account.account_id.toUpperCase()!==owner.toUpperCase(),'Other account restores only own empty graph');
 await rejected(edit,'42501','Another account cannot apply or fetch durable receipt');
 check((await db.query('select count(*)::int n from staygrubby.dishes')).rows[0].n===0,'RLS hides Account A from B');
 await db.exec('reset role;set role anon');
 await rejected(edit,'42501','Anonymous apply denied');
 try{await snapshot();assert.fail('Anonymous snapshot denied')}catch(e){check(e.code==='42501','Anonymous restore denied')}
 await db.exec('reset role');
 await db.query('delete from auth.sessions where id=$1',[session]);await actor(user,session);
 await rejected(edit,'42501','Revoked session cannot replay prior accepted receipt');
 console.log(`PASS ${checks} ${native?'native PostgreSQL':'PGlite'} structured sync assertions; actual Swift wire data, isolated identities only.`);
}finally{
 if(db)await db.close();
 if(admin){await admin.query(`drop database if exists ${database} with (force)`);await admin.end()}
}
