-- Optional social identity, separate from the private cooking/sync graph.
begin;
alter table staygrubby.profiles add column discoverable boolean not null default false;
create table staygrubby.username_reservations (
 username text primary key,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 expires_at timestamptz not null
);
alter table staygrubby.username_reservations enable row level security;
revoke all on staygrubby.username_reservations from public,anon,authenticated;

create function staygrubby.social_actor() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); owner uuid;
begin
 select l.account_id into owner from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id where l.auth_user_id=actor and a.status='active';
 if owner is null then raise exception 'Social account unavailable' using errcode='42501'; end if;
 return owner;
end $$;
revoke all on function staygrubby.social_actor() from public,anon,authenticated;

create function staygrubby.social_identity(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid := staygrubby.social_actor(); label text; handle text; previous text; visible boolean; result jsonb;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid profile' using errcode='22023'; end if;
 if action='save' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:social-profile:'||owner::text,0));
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
  label := btrim(regexp_replace(coalesce(payload->>'displayName',''),'[[:space:]]+',' ','g'));
  handle := lower(btrim(coalesce(payload->>'username','')));
  if left(handle,1)='@' then handle:=substring(handle from 2); end if;
  visible := coalesce((payload->>'discoverable')::boolean,false);
  if length(label) not between 1 and 50 or label ~ '[[:cntrl:]]'
   or length(handle) not between 3 and 24 or handle !~ '^[a-z0-9]+([_][a-z0-9]+)*$'
  then raise exception 'Use a name up to 50 characters and a 3-24 character username with letters, numbers and single underscores' using errcode='22023'; end if;
  if replace(handle,'_','')=any(array['staygrubby','staygrubbyapp','admin','administrator','support','privacy','help','moderator','system','official','staygrubbysupport'])
  then raise exception 'Username unavailable' using errcode='23505'; end if;
  -- A handle lock serializes claims, including reservations and returning owners.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:username:'||handle,0));
  if exists(select 1 from staygrubby.username_reservations r where r.username=handle and r.account_id<>owner and r.expires_at>now())
  then raise exception 'Username unavailable' using errcode='23505'; end if;
  select username into previous from staygrubby.profiles where account_id=owner for update;
  update staygrubby.profiles set display_name=label,username=handle,discoverable=visible where account_id=owner;
  if previous is not null and previous<>handle then
   insert into staygrubby.username_reservations(username,account_id,expires_at) values(previous,owner,now()+interval '30 days')
   on conflict(username) do update set account_id=excluded.account_id,expires_at=excluded.expires_at;
  end if;
 elsif action<>'get' then raise exception 'Unknown identity action' using errcode='22023'; end if;
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'discoverable',p.discoverable) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;
revoke all on function staygrubby.social_identity(text,jsonb) from public,anon;
grant execute on function staygrubby.social_identity(text,jsonb) to authenticated;
create function api.social_identity(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_identity(action,payload) $$;
revoke all on function api.social_identity(text,jsonb) from public,anon;
grant execute on function api.social_identity(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
