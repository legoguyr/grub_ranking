import pg from 'pg';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// Refuse a remote database. This harness creates/drops ONLY its own uniquely named
// database inside a disposable PostgreSQL cluster on a temporary Unix socket.
const socket=process.env.PG_TEST_SOCKET;
assert(socket?.startsWith('/private/tmp/staygrubby-'), 'Set PG_TEST_SOCKET to an isolated temporary Unix socket');
const port=Number(process.env.PG_TEST_PORT || 55439);
const database='staygrubby_test_'+randomUUID().replaceAll('-','');
const base={host:socket,port,user:process.env.USER,application_name:'staygrubby-concurrency-fixture'};
const admin=new pg.Client({...base,database:'postgres'});
let db,holder;const clients=[];let checks=0;
const check=(condition,message)=>{assert.ok(condition,message);checks++};
try {
 await admin.connect();
 for(const role of ['authenticated','anon','authenticator']) {
  if(!(await admin.query('select 1 from pg_roles where rolname=$1',[role])).rowCount) await admin.query(`create role ${role} nologin`);
 }
 await admin.query(`create database ${database}`);
 db=new pg.Client({...base,database});await db.connect();
 await db.query(`create schema auth;
 create table auth.users(id uuid primary key,is_anonymous boolean default false,deleted_at timestamptz);
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id),not_after timestamptz);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;`);
 const directory=new URL('../../supabase/migrations/',import.meta.url);
 for(const file of (await readdir(directory)).filter(n=>n.endsWith('.sql')).sort()) await db.query(await readFile(new URL(file,directory),'utf8'));
 const uid=randomUUID(),sid=randomUUID(),secondUser=randomUUID(),secondSession=randomUUID();
 await db.query('insert into auth.users(id) values($1),($2)',[uid,secondUser]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[sid,uid,secondSession,secondUser]);
 async function actor(client,user,session) {
  await client.query('set role authenticated');
  await client.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[user,JSON.stringify({session_id:session})]);
 }
 holder=new pg.Client({...base,database});await holder.connect();await holder.query('begin');await actor(holder,uid,sid);
 const first=(await holder.query('select api.provision_account() as account')).rows[0].account;
 check(first.account_id!==uid,'Independent permanent account UUID');
 const requests=Array.from({length:20},async()=>{
  const client=new pg.Client({...base,database});clients.push(client);await client.connect();await actor(client,uid,sid);
  return (await client.query('select api.provision_account() as account')).rows[0].account;
 });
 let waiting=0;
 for(let i=0;i<250;i++) {
  waiting=Number((await db.query("select count(*) n from pg_stat_activity where datname=$1 and wait_event='advisory'",[database])).rows[0].n);
  if(waiting===20)break;
  await new Promise(r=>setTimeout(r,20));
 }
 check(waiting===20,'All 20 overlapping connections wait on the uncommitted provisioning lock');
 await holder.query('commit');
 const results=await Promise.all(requests);
 check(results.every(r=>r.account_id===first.account_id),'Concurrent committed calls return one account');
 const counts=(await db.query(`select (select count(*) from staygrubby.accounts) accounts,(select count(*) from staygrubby.auth_account_links) links,(select count(*) from staygrubby.profiles) profiles,(select count(*) from staygrubby.rankings) rankings,(select count(*) from staygrubby.account_libraries) libraries`)).rows[0];
 check(counts.accounts==='1' && counts.links==='1' && counts.profiles==='1','No duplicate or orphan accounts/profiles/links');
 check(counts.rankings==='0' && counts.libraries==='0','Concurrency does not initialize a library');
 const retry=(await clients[0].query('select api.provision_account() as account')).rows[0].account;
 check(retry.account_id===first.account_id,'Lost-response retry uses same account');
 await holder.query('begin');await actor(holder,secondUser,secondSession);
 await holder.query('select api.provision_account()');await holder.query('rollback');
 check((await db.query('select count(*) n from staygrubby.accounts')).rows[0].n==='1','Rolled-back provisioning leaves no orphan account');
 await actor(holder,secondUser,secondSession);
 const second=(await holder.query('select api.provision_account() as account')).rows[0].account;
 check(second.account_id!==first.account_id && second.account_id!==secondUser,'Different authenticated identity has its own permanent account');
 check((await db.query('select count(*) n from staygrubby.accounts')).rows[0].n==='2','Retry after rollback creates exactly one account');
 // A session revoked while a valid caller is waiting must not create an account.
 const waitingUser=randomUUID(),waitingSession=randomUUID();
 await db.query('insert into auth.users(id) values($1)',[waitingUser]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[waitingSession,waitingUser]);
 await holder.query('begin');
 await holder.query("select pg_advisory_xact_lock(hashtextextended('staygrubby:provision:' || $1,0))",[waitingUser]);
 const delayed=new pg.Client({...base,database});clients.push(delayed);await delayed.connect();await actor(delayed,waitingUser,waitingSession);
 const outcome=delayed.query('select api.provision_account()').then(()=>({ok:true}),e=>({ok:false,code:e.code}));
 let revokedWait=0;
 for(let i=0;i<250;i++) {
  revokedWait=Number((await db.query("select count(*) n from pg_stat_activity where datname=$1 and wait_event='advisory'",[database])).rows[0].n);
  if(revokedWait===1)break;
  await new Promise(r=>setTimeout(r,20));
 }
 check(revokedWait===1,'Revocation test truly overlaps an authenticated waiting request');
 await db.query('delete from auth.sessions where id=$1',[waitingSession]);
 await holder.query('commit');
 const revoked=await outcome;
 check(!revoked.ok && revoked.code==='42501','Session revoked during lock wait is rejected');
 check((await db.query('select count(*) n from staygrubby.auth_account_links where auth_user_id=$1',[waitingUser])).rows[0].n==='0','Revoked waiter creates no protected link');
 check((await db.query('select count(*) n from staygrubby.accounts')).rows[0].n==='2','Revoked waiter leaves no orphan account');
 console.log(`PASS ${checks} native PostgreSQL concurrency/transaction assertions; 20 blocked concurrent callers plus holder, no hosted users.`);
} finally {
 if(holder){try{await holder.query('rollback')}catch{}await holder.end()}
 await Promise.all(clients.map(c=>c.end().catch(()=>{})));
 if(db)await db.end();
 await admin.query(`drop database if exists ${database} with (force)`);
 await admin.end();
}
