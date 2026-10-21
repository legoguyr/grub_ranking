-- Account-level future-entry default. Legacy users remain private. Never publishes history.
begin;
alter table staygrubby.profiles add column auto_share_new_cooks boolean not null default false;
create or replace function staygrubby.social_identity(action text,payload jsonb default '{}'::jsonb) returns jsonb
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
  perform staygrubby.social_actor(); -- Recheck live Auth after the handle lock.
  select username into previous from staygrubby.profiles where account_id=owner for update;
  update staygrubby.profiles set display_name=label,username=handle,discoverable=visible,auto_share_new_cooks=coalesce((payload->>'automaticallyShareNewDishes')::boolean,auto_share_new_cooks) where account_id=owner;
  if previous is not null and previous<>handle then
   insert into staygrubby.username_reservations(username,account_id,expires_at) values(previous,owner,now()+interval '30 days')
   on conflict(username) do update set account_id=excluded.account_id,expires_at=excluded.expires_at;
  end if;
 elsif action='sharing' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:social-profile:'||owner::text,0));
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
  if payload->>'automaticallyShareNewDishes' is null then raise exception 'Choose a default' using errcode='22023'; end if;
  if not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and deleted_at is null)
   then raise exception 'Social identity required' using errcode='42501'; end if;
  update staygrubby.profiles set auto_share_new_cooks=(payload->>'automaticallyShareNewDishes')::boolean where account_id=owner;
 elsif action<>'get' then raise exception 'Unknown identity action' using errcode='22023'; end if;
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'avatarPath',p.avatar_path,'discoverable',p.discoverable,'automaticallyShareNewDishes',p.auto_share_new_cooks) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
