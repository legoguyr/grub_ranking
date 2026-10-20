-- Durable, self-only account deletion coordination. Privileged erasure remains
-- server-only; clients can neither choose an owner nor invoke finalization.
begin;

grant usage on schema api to service_role;

create table staygrubby.account_deletion_jobs (
 auth_user_id uuid primary key references auth.users(id) on delete cascade,
 account_id uuid not null unique,
 state text not null default 'requested'
  check (state in ('requested','apple_revoked','storage_cleared','account_erased')),
 object_keys jsonb not null default '[]'::jsonb check (jsonb_typeof(object_keys)='array'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table staygrubby.account_deletion_jobs enable row level security;
revoke all on staygrubby.account_deletion_jobs from public, anon, authenticated;

create function staygrubby.account_deletion_actor() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := auth.uid(); sid uuid;
begin
 if actor is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
 begin sid := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then
  raise exception 'Authenticated session required' using errcode='42501';
 end;
 if sid is null or not exists(
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=sid and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;
 return actor;
end $$;
revoke all on function staygrubby.account_deletion_actor() from public,anon;
grant execute on function staygrubby.account_deletion_actor() to authenticated;

create function staygrubby.account_deletion_state() returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); job staygrubby.account_deletion_jobs%rowtype;
begin
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=actor;
 if found then
  return jsonb_build_object('pending',true,'account_id',job.account_id,'state',job.state);
 end if;
 return jsonb_build_object('pending',false);
end $$;
revoke all on function staygrubby.account_deletion_state() from public,anon;
grant execute on function staygrubby.account_deletion_state() to authenticated;

create function api.account_deletion_state() returns jsonb
language sql volatile security invoker set search_path='' as $$
 select staygrubby.account_deletion_state()
$$;
revoke all on function api.account_deletion_state() from public,anon;
grant execute on function api.account_deletion_state() to authenticated;

create function staygrubby.begin_account_deletion() returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); owner uuid; job staygrubby.account_deletion_jobs%rowtype; keys jsonb;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || actor::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=actor for update;
 if found then
  return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
 end if;
 select l.account_id into owner from staygrubby.auth_account_links l where l.auth_user_id=actor;
 if owner is null then raise exception 'Account unavailable' using errcode='42501'; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 select coalesce(jsonb_agg(value order by value),'[]'::jsonb) into keys from (
  select display_key value from staygrubby.media_backups where account_id=owner and not cleaned
  union select thumbnail_key from staygrubby.media_backups where account_id=owner and not cleaned
 ) paths;
 insert into staygrubby.account_deletion_jobs(auth_user_id,account_id,object_keys)
 values(actor,owner,keys) returning * into job;
 update staygrubby.accounts set status='deleting' where id=owner;
 return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
end $$;
revoke all on function staygrubby.begin_account_deletion() from public,anon;
grant execute on function staygrubby.begin_account_deletion() to authenticated;

create function api.begin_account_deletion() returns jsonb
language sql volatile security invoker set search_path='' as $$
 select staygrubby.begin_account_deletion()
$$;
revoke all on function api.begin_account_deletion() from public,anon;
grant execute on function api.begin_account_deletion() to authenticated;

create function staygrubby.advance_account_deletion(target_auth_user uuid,target_state text) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype; current_step integer; next_step integer;
begin
 if target_state not in ('apple_revoked','storage_cleared') then raise exception 'Invalid deletion stage' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 current_step := case job.state when 'requested' then 0 when 'apple_revoked' then 1 when 'storage_cleared' then 2 else 3 end;
 next_step := case target_state when 'apple_revoked' then 1 else 2 end;
 if next_step > current_step then
  if next_step <> current_step + 1 then raise exception 'Deletion stage out of order' using errcode='55000'; end if;
  update staygrubby.account_deletion_jobs set state=target_state,updated_at=clock_timestamp()
   where auth_user_id=target_auth_user returning * into job;
 end if;
 return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
end $$;
revoke all on function staygrubby.advance_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function staygrubby.advance_account_deletion(uuid,text) to service_role;

create function api.advance_account_deletion(target_auth_user uuid,target_state text) returns jsonb
language sql volatile security definer set search_path='' as $$
 select staygrubby.advance_account_deletion(target_auth_user,target_state)
$$;
revoke all on function api.advance_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function api.advance_account_deletion(uuid,text) to service_role;

create function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;
 if exists(select 1 from storage.objects where bucket_id='cooking-photos'
           and (name=job.account_id::text or name like job.account_id::text || '/%'))
 then raise exception 'Storage cleanup incomplete' using errcode='55000'; end if;
 delete from staygrubby.accounts where id=job.account_id and status='deleting';
 if found or not exists(select 1 from staygrubby.accounts where id=job.account_id) then
  update staygrubby.account_deletion_jobs set state='account_erased',updated_at=clock_timestamp()
   where auth_user_id=target_auth_user returning * into job;
 else raise exception 'Account deletion refused' using errcode='55000';
 end if;
 return jsonb_build_object('accountID',job.account_id,'state',job.state);
end $$;
revoke all on function staygrubby.erase_account_data(uuid) from public,anon,authenticated;
grant execute on function staygrubby.erase_account_data(uuid) to service_role;

create function api.erase_account_data(target_auth_user uuid) returns jsonb
language sql volatile security definer set search_path='' as $$
 select staygrubby.erase_account_data(target_auth_user)
$$;
revoke all on function api.erase_account_data(uuid) from public,anon,authenticated;
grant execute on function api.erase_account_data(uuid) to service_role;

notify pgrst,'reload schema';
commit;
