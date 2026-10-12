-- Explicit self-provisioning only. No library initialization, guest import or Auth trigger.
begin;
create schema api;
revoke all on schema api from public, anon;
grant usage on schema api to authenticated;

create function staygrubby.provision_account() returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
 actor uuid := auth.uid();
 session_id uuid;
 account uuid;
 account_status text;
 revision bigint;
begin
 if actor is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
 begin
  session_id := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then
  raise exception 'Authenticated session required' using errcode='42501';
 end;
 if session_id is null or not exists (
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=session_id and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;

 -- Serialize first creation and every retry for this verified identity. Hash collisions
 -- merely serialize unrelated callers; no client-supplied lock or owner is accepted.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:provision:' || actor::text,0));
 select l.account_id into account from staygrubby.auth_account_links l where l.auth_user_id=actor;
 if account is null then
  insert into staygrubby.accounts default values returning id into account;
  insert into staygrubby.auth_account_links(auth_user_id,account_id) values(actor,account);
  insert into staygrubby.profiles(account_id) values(account);
 end if;
 select a.status,a.sync_revision into account_status,revision from staygrubby.accounts a where a.id=account;
 if account_status is distinct from 'active' then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 return pg_catalog.jsonb_build_object('format_version',1,'auth_user_id',actor,
  'account_id',account,'sync_revision',revision,'library_state',
  case when exists(select 1 from staygrubby.account_libraries l where l.account_id=account)
   then 'initialized' else 'uninitialized' end);
end $$;
revoke all on function staygrubby.provision_account() from public, anon;
grant execute on function staygrubby.provision_account() to authenticated;

-- Only this wrapper is intended for the Data API. Trusted writes remain private.
create function api.provision_account() returns jsonb
language sql volatile security invoker set search_path = '' as $$
 select staygrubby.provision_account()
$$;
revoke all on function api.provision_account() from public, anon;
grant execute on function api.provision_account() to authenticated;
-- No new table grants, write policies, ownership parameters, or signup trigger.
-- Retain the existing hosted schemas and add only api. This supported explicit
-- PostgREST override is maintained here, not by the Dashboard exposed-schema UI.
do $$ begin
 if exists(select 1 from pg_catalog.pg_roles where rolname='authenticator') then
  execute 'alter role authenticator set pgrst.db_schemas = ''public,graphql_public,api''';
 end if;
end $$;
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
commit;
