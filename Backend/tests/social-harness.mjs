import { PGlite } from '@electric-sql/pglite';
import { storageStubSQL } from './storage-stub.mjs';
import { readFile,readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
export async function fixture() {
 const db=new PGlite();let checks=0;
 await db.exec(`create role authenticated;create role anon;create role service_role;create schema auth;
 create table auth.users(id uuid primary key,is_anonymous boolean default false,deleted_at timestamptz);
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,not_after timestamptz);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;`);
 await db.exec(storageStubSQL);
 const dir=new URL('../../supabase/migrations/',import.meta.url);
 for(const f of (await readdir(dir)).filter(f=>f.endsWith('.sql')).sort())await db.exec(await readFile(new URL(f,dir),'utf8'));
 const users=[];
 for(let n=0;n<4;n++){
  const user=randomUUID(),session=randomUUID();
  await db.query('insert into auth.users(id) values($1)',[user]);
  await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[session,user]);
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[user,JSON.stringify({sub:user,session_id:session})]);
  const receipt=(await db.query('select api.provision_account() value')).rows[0].value;
  users.push({user,session,id:receipt.account_id});await db.exec('reset role');
 }
 async function actor(n){await db.exec('reset role;set role authenticated');const u=users[n];await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[u.user,JSON.stringify({sub:u.user,session_id:u.session})]);}
 async function rpc(name,action,payload={}){return (await db.query(`select api.${name}($1,$2::jsonb) value`,[action,JSON.stringify(payload)])).rows[0].value;}
 function check(value,message){assert.ok(value,message);checks++;}
 async function rejects(fn,code='42501'){try{await fn();assert.fail('Expected rejection')}catch(e){assert.equal(e.code,code);checks++;}}
 return {db,users,actor,rpc,check,rejects,finish:async()=>{console.log(`PASS ${checks} social assertions (${new URL(import.meta.url).pathname});`);await db.close();}};
}
