import { storageStubSQL } from './storage-stub.mjs';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { readFile,readdir } from 'node:fs/promises';
import { randomUUID,createHash } from 'node:crypto';
import assert from 'node:assert/strict';

const native=process.argv.includes('--native');let admin,db,database,checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++};
const fixture=JSON.parse(await readFile(new URL('fixtures/swift-cooking-operations.json',import.meta.url),'utf8'));
const owner=fixture.initial.accountID.toLowerCase(),user=randomUUID(),session=randomUUID(),other=randomUUID(),otherSession=randomUUID();
const media=fixture.steps.find(s=>s.media.length)?.media[0];assert(media);
const manifest={accountID:owner,mediaID:media.id.toLowerCase(),displayHash:'a'.repeat(64),thumbnailHash:'b'.repeat(64),displayBytes:100,thumbnailBytes:50};
const path=owner+'/'+manifest.mediaID+'/display-'+manifest.displayHash+'.jpg';
const thumb=owner+'/'+manifest.mediaID+'/thumbnail-'+manifest.thumbnailHash+'.jpg';
async function actor(uid=user,sid=session,operation='object.get_authenticated'){
 await db.exec('reset role;set role authenticated');
 await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false),set_config('storage.operation',$3,false)",[uid,JSON.stringify({session_id:sid}),operation]);
}
async function rpc(action,value=manifest){return (await db.query('select api.media_backup($1,$2::jsonb) result',[action,JSON.stringify(value)])).rows[0].result}
async function rejects(action,code,label){try{await action();assert.fail(label)}catch(e){if(e.code){assert.equal(e.code,code,label);checks++}else throw e}}
try{
 if(native){
  assert(process.env.PG_TEST_SOCKET?.startsWith('/private/tmp/staygrubby-'));
  const base={host:process.env.PG_TEST_SOCKET,port:Number(process.env.PG_TEST_PORT||55439),user:process.env.USER};
  admin=new pg.Client({...base,database:'postgres'});await admin.connect();
  for(const role of ['authenticated','anon','authenticator'])if(!(await admin.query('select 1 from pg_roles where rolname=$1',[role])).rowCount)await admin.query(`create role ${role} nologin`);
  database='staygrubby_photos_'+randomUUID().replaceAll('-','');await admin.query(`create database ${database}`);
  const client=new pg.Client({...base,database});await client.connect();db={query:(...args)=>client.query(...args),exec:sql=>client.query(sql),close:()=>client.end()};
 }else{db=new PGlite();await db.exec('create role authenticated;create role anon;create role authenticator;create role service_role')}
 await db.exec(`create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean default false,deleted_at timestamptz);
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id),not_after timestamptz);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;`);
 await db.exec(storageStubSQL);
 const directory=new URL('../../supabase/migrations/',import.meta.url);
 for(const file of (await readdir(directory)).filter(f=>f.endsWith('.sql')).sort())await db.exec(await readFile(new URL(file,directory),'utf8'));
 await db.query('insert into auth.users(id) values($1),($2)',[user,other]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[session,user,otherSession,other]);
 await db.query('insert into staygrubby.accounts(id,sync_revision) values($1,1)',[owner]);
 await db.query('insert into staygrubby.auth_account_links(auth_user_id,account_id) values($1,$2)',[user,owner]);
 const ranking=fixture.initial.rankings[0];await db.query("insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values($1,$2,$3,$4,'global')",[owner,ranking.id,ranking.name,ranking.createdAt]);
 await db.query("insert into staygrubby.account_libraries(account_id,library_key,global_ranking_id,bridge_version) values($1,'local',$2,1)",[owner,ranking.id]);
 check((await db.query("select public,file_size_limit,allowed_mime_types from storage.buckets where id='cooking-photos'")).rows[0].public===false,'Private bucket');
 await actor();for(const operation of fixture.operations.slice(0,4))await db.query('select api.apply_cooking_operation($1::jsonb)',[JSON.stringify(operation)]);
 check((await rpc('list',null)).backups.length===0,'No automatic byte claims from structured metadata');
 const registered=await rpc('register');check(registered.accountID===owner&&registered.backups[0].displayKey===path,'Owner derived / deterministic exact paths');
 check(registered.backups[0].state==='pending','Bytes must be verified before ready');
 check(JSON.stringify(await rpc('register'))===JSON.stringify(registered),'Ambiguous registration retry idempotent');
 await rejects(()=>rpc('register',{...manifest,displayHash:'c'.repeat(64)}),'23505','Manifest immutable');
 await rejects(()=>rpc('register',{...manifest,accountID:randomUUID()}),'42501','Forged manifest account rejected');
 await rejects(()=>rpc('complete'),'55000','Missing object pair cannot complete');
 await actor(user,session,'object.upload');
 const insert=(name,size)=>db.query("insert into storage.objects(bucket_id,name,metadata) values('cooking-photos',$1,$2::jsonb)",[name,JSON.stringify({size,mimetype:'image/jpeg'})]);
 await insert(path,100);checks++;await insert(thumb,50);checks++;
 await rejects(()=>insert(owner+'/unregistered.jpg',100),'42501','Unregistered object denied');
 await actor();check((await db.query('select * from storage.objects')).rows.length===2,'A reads owned active objects');
 await rpc('complete');check((await rpc('list',null)).backups[0].state==='ready','Both catalog sizes required');
 check((await rpc('complete')).backups[0].state==='ready','Complete retry idempotent');
 await actor(user,session,'object.upload');check((await db.query('update storage.objects set metadata=metadata where name=$1',[path])).rowCount===1,'Own upload retry can upsert');
 await actor(user,session,'object.sign');check((await db.query('select * from storage.objects')).rows.length===0,'No signed/public URL access path');
 await actor(other,otherSession);check((await db.query('select * from storage.objects')).rows.length===0,'B cannot download/enumerate A');
 await rejects(()=>rpc('register'),'42501','Unprovisioned B cannot register for A');
 await db.query('select api.provision_account()');
 check((await rpc('list',null)).backups.length===0,'Provisioned B cannot enumerate A manifests');
 await rejects(()=>rpc('register'),'42501','Provisioned B cannot register forged A owner');
 await actor(other,otherSession,'object.upload');await rejects(()=>insert(path+'forged',100),'42501','B forged A path upload denied');
 check((await db.query('update storage.objects set metadata=metadata where name=$1',[path])).rowCount===0,'B overwrite denied');
 await actor(other,otherSession,'object.delete_many');check((await db.query('delete from storage.objects where name=$1',[path])).rowCount===0,'B delete denied');
 await db.exec('reset role;set role anon');check((await db.query('select * from storage.objects')).rows.length===0,'Anonymous read/list denied');
 await rejects(()=>insert(path+'anon',100),'42501','Anonymous upload denied');
 await rejects(()=>rpc('list',null),'42501','Anonymous manifest RPC denied');
 await actor(user,session,'object.delete_many');check((await db.query('delete from storage.objects where name=$1',[path])).rowCount===0,'Active backup cannot be purged through cleanup');
 await rejects(()=>rpc('cleaned'),'40001','Cannot mark active bytes cleaned');
 if(native){
  await actor(user,session,'object.upload');await db.exec('begin');
  check((await db.query('select staygrubby.cooking_object_allowed($1,$2,$3) ok',['cooking-photos',path,'write'])).rows[0].ok,'Upload authorization holds shared account lock');
  const delayed=new pg.Client({host:process.env.PG_TEST_SOCKET,port:Number(process.env.PG_TEST_PORT||55439),user:process.env.USER,database,application_name:'staygrubby-photo-tombstone-fixture'});
  try{
   await delayed.connect();await delayed.query('set role authenticated');
   await delayed.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[user,JSON.stringify({session_id:session})]);
   const payload=Buffer.from(JSON.stringify({upserts:[],deletions:[{entity:'media',key:manifest.mediaID}]}));
   const envelope={operationID:randomUUID(),storeID:randomUUID(),accountID:owner,kind:'deleteMediaFixture',expectedRevision:5,payload:payload.toString('base64'),payloadHash:createHash('sha256').update(payload).digest('hex')};
   const outcome=delayed.query('select api.apply_cooking_operation($1::jsonb) result',[JSON.stringify(envelope)]).then(r=>r.rows[0].result,e=>({error:e}));
   let waiting=false;
   for(let i=0;i<100;i++){
    waiting=Number((await admin.query("select count(*) n from pg_stat_activity where datname=$1 and application_name='staygrubby-photo-tombstone-fixture' and wait_event_type='Lock'",[database])).rows[0].n)===1;
    if(waiting)break;await new Promise(r=>setTimeout(r,10));
   }
   check(waiting,'Structured retirement truly waits behind in-flight object authorization');
   await db.exec('commit');const result=await outcome;assert(!result.error);check(result.revision===6,'Retirement accepts after upload transaction ends');
   await actor(user,session,'object.upload');
   check(!(await db.query('select staygrubby.cooking_object_allowed($1,$2,$3) ok',['cooking-photos',path,'write'])).rows[0].ok,'Later upload transaction cannot pass tombstone');
  }finally{await db.exec('rollback');await delayed.end()}
 }else{
  await db.exec('reset role');await db.query('update staygrubby.media set deleted_at=now() where account_id=$1 and id=$2',[owner,manifest.mediaID]);
 }
 await actor();check((await rpc('list',null)).backups[0].state==='deleted','Retired path retained for cleanup');
 check((await db.query('select * from storage.objects')).rows.length===0,'Tombstone immediately blocks download before cleanup');
 await actor(user,session,'object.list');check((await db.query('select * from storage.objects')).rows.length===0,'Tombstone blocks enumeration');
 await actor(user,session,'object.upload');check((await db.query('update storage.objects set metadata=metadata where name=$1',[path])).rowCount===0,'Late upload retry cannot revive retired object');
 await rejects(()=>rpc('register'),'40001','Tombstoned manifest cannot revive');
 await actor(user,session,'object.delete_many');check((await db.query('select * from storage.objects')).rows.length===2,'Cleanup-specific SELECT only');
 await rejects(()=>rpc('cleaned'),'55000','Cleanup cannot acknowledge remaining objects');
 check((await db.query('delete from storage.objects where bucket_id=$1',['cooking-photos'])).rowCount===2,'A deletes own retired pair via emulated Storage transaction');
 check((await db.query('delete from storage.objects')).rowCount===0,'Duplicate cleanup idempotent');
 check((await rpc('cleaned')).backups.length===0,'Cleanup acknowledgement hides completed work');
 check((await rpc('cleaned')).backups.length===0,'Cleanup acknowledgement retry idempotent');
 await db.exec('reset role');await db.query('delete from auth.sessions where id=$1',[session]);await actor();
 await rejects(()=>rpc('list',null),'42501','Revoked session cannot restore manifests');
 check((await db.query('select staygrubby.cooking_object_allowed($1,$2,$3) ok',['cooking-photos',path,'read'])).rows[0].ok===false,'Revoked Storage access denied');
 check((await db.query('select count(*)::int n from staygrubby.media_backups')).rows[0].n===0,'Manifest RLS checks live session');
 console.log(`PASS ${checks} ${native?'native PostgreSQL':'PGlite'} photo manifest/Storage policy assertions; SQL catalog fixtures only.`);
}finally{await db?.close();if(admin){await admin.query(`drop database if exists ${database} with(force)`);await admin.end()}}
