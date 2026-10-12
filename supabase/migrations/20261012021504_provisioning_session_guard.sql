-- Check the live Auth session AFTER serialization, including when a caller
-- waited behind another transaction while its session was revoked.
begin;
create or replace function staygrubby.provision_account() returns jsonb
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
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:provision:' || actor::text,0));
 if session_id is null or not exists (
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=session_id and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;

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
notify pgrst, 'reload schema';
commit;
