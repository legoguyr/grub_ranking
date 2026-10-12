import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import assert from 'node:assert/strict';

// A disposable PostgreSQL engine. These stubs emulate only the JWT-to-auth.uid SQL
// boundary, not real authentication, token validation, PostgREST or Storage.
const db = new PGlite();
let checks = 0;
const check = (value, message) => { assert.ok(value, message); checks++; };
const a='10000000-0000-0000-0000-000000000001', b='10000000-0000-0000-0000-000000000002';
const ua='20000000-0000-0000-0000-000000000001', ub='20000000-0000-0000-0000-000000000002';
const ranking='30000000-0000-0000-0000-000000000001';
const item1='40000000-0000-0000-0000-000000000001', item2='40000000-0000-0000-0000-000000000002';
await db.exec(`create role authenticated; create role anon; create schema auth;
 create table auth.users(id uuid primary key,is_anonymous boolean default false,deleted_at timestamptz);
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,not_after timestamptz);
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;`);
const migrationDirectory = new URL('../../supabase/migrations/', import.meta.url);
const migrations = (await readdir(migrationDirectory)).filter(name => name.endsWith('.sql')).sort();
check(migrations.length === 4, 'Setup has foundation, hardening, provisioning and session-guard migrations');
const initial = (await Promise.all(migrations.map(name => readFile(new URL(name, migrationDirectory), 'utf8')))).join('');
check(initial === await readFile(new URL('../schema.sql', import.meta.url), 'utf8'), 'Reference and complete migration chain agree');
for (const name of migrations) await db.exec(await readFile(new URL(name, migrationDirectory), 'utf8'));
await db.exec(`insert into auth.users(id) values('${ua}'),('${ub}');
 insert into staygrubby.accounts(id) values('${a}'),('${b}');
 insert into staygrubby.auth_account_links(auth_user_id,account_id) values('${ua}','${a}'),('${ub}','${b}');
 insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values
 ('${a}','${ranking}','A cooking',123.1234567,'global'),('${b}','${ranking}','B cooking',123.1234567,'global');
 insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values
 ('${a}','${item1}','${ranking}','One',1,0.12345678901234567,1),
 ('${a}','${item2}','${ranking}','Two',2,-0.12345678901234567,1);`);
async function rejects(sql, message, code) {
 try { await db.exec(sql); assert.fail(message); }
 catch (error) { if (error.code) { if(code) assert.equal(error.code,code); checks++; } else throw error; }
}
async function actor(user) {
 await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${user}',false)`);
}
await actor(ua);
check((await db.query('select id from staygrubby.accounts')).rows[0].id===a,'Auth identity maps to separate permanent account');
check((await db.query('select name from staygrubby.rankings')).rows.length===1,'A sees only one owned ranking');
check((await db.query('select name from staygrubby.rankings')).rows[0].name==='A cooking','A cannot see B');
await rejects(`insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values('${b}',gen_random_uuid(),'Forged',0,'historical')`,'Client cannot write another owner','42501');
await rejects(`update staygrubby.ranked_items set strength=9`,'Client cannot forge ranking caches or server versions','42501');
await rejects(`select * from staygrubby.auth_account_links`,'Private auth mapping is not a profile','42501');
await rejects(`update staygrubby.rankings set account_id='${b}'`,'Client cannot reassign ownership','42501');
await rejects(`insert into staygrubby.auth_account_links(auth_user_id,account_id) values(gen_random_uuid(),'${a}')`,'Client cannot forge identity links','42501');
await rejects(`truncate staygrubby.rankings cascade`,'TRUNCATE cannot bypass RLS','42501');
await rejects(`delete from staygrubby.rankings`,'Client cannot bypass atomic deletion','42501');
await actor(ub);
check((await db.query('select name from staygrubby.rankings')).rows[0].name==='B cooking','B sees only B');
check((await db.query('select * from staygrubby.ranked_items')).rows.length===0,'B sees no A item data');
await actor('');
check((await db.query('select * from staygrubby.rankings')).rows.length===0,'Expired/missing identity sees no private rows');
await db.exec('reset role; set role anon');
await rejects('select * from staygrubby.rankings','Anonymous API role denied','42501');
await rejects('select staygrubby.current_account_id()','Anonymous private helper denied','42501');
await db.exec('reset role');
await rejects(`insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values('${a}',gen_random_uuid(),'Duplicate',0,'global')`,'One active global ranking','23505');
await rejects(`insert into staygrubby.comparisons(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref) values('${b}',gen_random_uuid(),'${ranking}','${item1}','${item2}','${item1}',false,123)`,'Cross-account evidence rejected','23503');
await rejects(`insert into staygrubby.comparisons(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref) values('${a}',gen_random_uuid(),'${ranking}','${item1}','${item1}','${item1}',false,123)`,'Self-comparison rejected','23514');
await rejects(`insert into staygrubby.comparisons(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref) values('${a}',gen_random_uuid(),'${ranking}','${item1}','${item2}','${item1}',true,123)`,'Tie cannot have a winner','23514');
await db.exec(`insert into staygrubby.comparisons(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref) values
 ('${a}',gen_random_uuid(),'${ranking}','${item1}','${item2}','${item1}',false,123.1234567),
 ('${a}',gen_random_uuid(),'${ranking}','${item1}','${item2}',null,true,124.1234567);`);
check((await db.query('select * from staygrubby.comparisons')).rows.length===2,'Repeated pair and tie remain separate observations');
await rejects(`update staygrubby.ranked_items set strength='NaN'::double precision`,'Non-finite cache rejected','23514');
await rejects(`update staygrubby.ranked_items set id=gen_random_uuid()`,'Stable UUID cannot be replaced','P0001');
await rejects(`update staygrubby.comparisons set timestamp_ref=999`,'Evidence is immutable','P0001');
await rejects(`update staygrubby.ranked_items set account_id='${b}'`,'Owner cannot be reassigned even by a generic update','P0001');
const old=(await db.query('select row_version from staygrubby.ranked_items limit 1')).rows[0].row_version;
await db.exec(`update staygrubby.ranked_items set name='Renamed',row_version=999`);
check(Number((await db.query('select row_version from staygrubby.ranked_items limit 1')).rows[0].row_version)===Number(old)+1,'Version assigned by server trigger');
await db.exec(`insert into staygrubby.tags(account_id,tag_key,kind_code,value,label) values
 ('${a}','contains:milk','contains','milk','Milk'),('${a}','allergy:milkFree','allergy','milkFree','Milk-Free')`);
check((await db.query('select * from staygrubby.tags')).rows.length===2,'Contains and legacy Free remain distinct');
await rejects(`insert into staygrubby.tags(account_id,tag_key,kind_code,value,label) values('${a}','contains:milkFree','allergy','milkFree','Bad')`,'Tag key semantics cannot be inverted','23514');
await db.exec(`insert into staygrubby.profiles(account_id,username) values('${a}','Chef');`);
await rejects(`insert into staygrubby.profiles(account_id,username) values('${b}','chef')`,'Username uniqueness is case-insensitive; no recycling function','23505');
await db.exec(`update staygrubby.rankings set deleted_at=now() where account_id='${a}'; update staygrubby.accounts set status='deleting' where id='${a}'`);
await actor(ua);
check((await db.query('select * from staygrubby.rankings')).rows.length===0,'Deleting account loses private access without relying on stale JWT claims');
await db.exec('reset role');
const exposed=(await db.query(`select count(*)::int n from pg_tables where schemaname='staygrubby' and not rowsecurity`)).rows[0].n;
check(exposed===0,'Every application table has RLS');
check((await db.query(`select count(*)::int n from pg_tables where schemaname='staygrubby'`)).rows[0].n===15,'Only private foundation tables exist');
const permissions = (await db.query(`select c.relname,
 has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') as anon_access,
 has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') as client_write,
 has_table_privilege('authenticated',c.oid,'SELECT') as client_read
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='staygrubby' and c.relkind='r'`)).rows;
check(permissions.every(p => !p.anon_access && !p.client_write), 'No client write/bypass privileges on any table');
check(permissions.every(p => p.client_read === (p.relname !== 'auth_account_links')), 'Only intended owner-readable tables have SELECT grants');
check(!(await db.query(`select has_function_privilege('anon','staygrubby.current_account_id()','EXECUTE') as access`)).rows[0].access, 'No anonymous helper execution');
check(!(await db.query(`select has_function_privilege('authenticated','staygrubby.stamp_record()','EXECUTE') as access`)).rows[0].access, 'Trigger helper is not a client RPC');
await db.exec(`delete from auth.users where id='${ua}'`);
check((await db.query(`select * from staygrubby.accounts where id='${a}'`)).rows.length===1, 'Deleting provider identity does not delete permanent account');
check((await db.query(`select * from staygrubby.auth_account_links where auth_user_id='${ua}'`)).rows.length===0, 'Deleted Auth identity link cascades');
await db.exec(`delete from staygrubby.accounts where id='${a}'`);
check((await db.query(`select * from staygrubby.rankings where account_id='${a}'`)).rows.length===0, 'Explicit account erasure cascades cooking data');
// Provisioning uses simulated verified claims/sessions only in this disposable DB.
const newcomer='20000000-0000-0000-0000-000000000003';
const sid='60000000-0000-0000-0000-000000000003';
const anonymous='20000000-0000-0000-0000-000000000004';
const anonymousSession='60000000-0000-0000-0000-000000000004';
await db.exec(`insert into auth.users(id) values('${newcomer}');
 insert into auth.sessions(id,user_id) values('${sid}','${newcomer}');
 insert into auth.users(id,is_anonymous) values('${anonymous}',true);
 insert into auth.sessions(id,user_id) values('${anonymousSession}','${anonymous}');`);
await db.exec('set role anon');
await rejects('select api.provision_account()', 'Anonymous API role cannot provision', '42501');
await db.exec('reset role');
await actor('');
await rejects('select api.provision_account()', 'No authenticated identity cannot provision', '42501');
await actor(newcomer);
await rejects('select api.provision_account()', 'Missing live session cannot provision', '42501');
await db.exec(`select set_config('request.jwt.claims','{"session_id":"${sid}"}',false)`);
const first=(await db.query('select api.provision_account() as result')).rows[0].result;
check(first.auth_user_id===newcomer && first.account_id!==newcomer, 'Permanent account independent from authenticated identity');
check(first.format_version===1 && first.sync_revision===0 && first.library_state==='uninitialized', 'New account explicitly has no library');
const repeated=await Promise.all(Array.from({length:20},()=>db.query('select api.provision_account() as result')));
check(repeated.every(r=>r.rows[0].result.account_id===first.account_id), 'Queued/retried provisioning returns the same account');
await rejects(`select api.provision_account('${ub}'::uuid)`, 'No caller-supplied identity overload exists', '42883');
await rejects(`update staygrubby.auth_account_links set account_id='${b}'`, 'Provisioned client still cannot reassign links', '42501');
await db.exec('reset role');
check((await db.query(`select count(*)::int n from staygrubby.auth_account_links where auth_user_id='${newcomer}'`)).rows[0].n===1,'Exactly one protected link');
check((await db.query(`select count(*)::int n from staygrubby.profiles where account_id='${first.account_id}'`)).rows[0].n===1,'Exactly one minimal profile');
check((await db.query(`select count(*)::int n from staygrubby.accounts where id='${first.account_id}'`)).rows[0].n===1,'Exactly one permanent account');
check((await db.query(`select count(*)::int n from staygrubby.account_libraries where account_id='${first.account_id}'`)).rows[0].n===0,'No premature library');
check((await db.query(`select count(*)::int n from staygrubby.rankings where account_id='${first.account_id}'`)).rows[0].n===0,'No premature ranking');
await db.exec(`update auth.sessions set not_after=now()-interval '1 second' where id='${sid}'`);
await actor(newcomer); await db.exec(`select set_config('request.jwt.claims','{"session_id":"${sid}"}',false)`);
await rejects('select api.provision_account()','Expired server session rejected','42501');
await db.exec('reset role'); await db.exec(`update auth.sessions set not_after=null where id='${sid}'; update staygrubby.accounts set status='deleting' where id='${first.account_id}'`);
await actor(newcomer); await db.exec(`select set_config('request.jwt.claims','{"session_id":"${sid}"}',false)`);
await rejects('select api.provision_account()','Deleting account cannot be reprovisioned','42501');
await actor(anonymous); await db.exec(`select set_config('request.jwt.claims','{"session_id":"${anonymousSession}"}',false)`);
await rejects('select api.provision_account()','Supabase anonymous Auth user rejected','42501');
await actor(ub); await db.exec(`select set_config('request.jwt.claims','{"session_id":"${sid}"}',false)`);
await rejects('select api.provision_account()','Session belonging to a different user rejected','42501');
await db.exec('reset role');
check((await db.query(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api'`)).rows[0].n===1,'Only one exposed API function');
check(!(await db.query(`select has_function_privilege('anon','api.provision_account()','EXECUTE') as access`)).rows[0].access,'Anonymous function execution denied');
console.log(`PASS ${checks} PostgreSQL schema/RLS assertions; simulated JWT mapping, no hosted project.`);
await db.close();
