begin;
create table staygrubby.friendships (
 low_id uuid not null references staygrubby.accounts(id) on delete cascade,
 high_id uuid not null references staygrubby.accounts(id) on delete cascade,
 requester_id uuid not null references staygrubby.accounts(id) on delete cascade,
 state text not null check(state in ('pending','friends','declined','cancelled','removed')),
 updated_at timestamptz not null default now(),
 primary key(low_id,high_id), check(low_id<high_id),check(requester_id in (low_id,high_id))
);
create table staygrubby.social_blocks (
 blocker_id uuid not null references staygrubby.accounts(id) on delete cascade,
 blocked_id uuid not null references staygrubby.accounts(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id),check(blocker_id<>blocked_id)
);
alter table staygrubby.friendships enable row level security;
alter table staygrubby.social_blocks enable row level security;
revoke all on staygrubby.friendships,staygrubby.social_blocks from public,anon,authenticated;
create index friendships_recipient on staygrubby.friendships(high_id,state);
create index social_blocks_target on staygrubby.social_blocks(blocked_id);

create function staygrubby.social_blocked(a uuid,b uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.social_blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a))
$$;
revoke all on function staygrubby.social_blocked(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_person(viewer uuid,target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,
 'relationship',case when f.state='friends' then 'friends' when f.state='pending' and f.requester_id=viewer then 'outgoing' when f.state='pending' then 'incoming' else 'none' end)
 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id
 left join staygrubby.friendships f on f.low_id=least(viewer,target) and f.high_id=greatest(viewer,target)
 where p.account_id=target and p.username is not null and p.deleted_at is null and a.status='active'
 and not staygrubby.social_blocked(viewer,target)
 and (p.discoverable or viewer=target or f.state in ('friends','pending'))
$$;
revoke all on function staygrubby.social_person(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_people(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid := staygrubby.social_actor(); peer uuid; lo uuid; hi uuid; relation staygrubby.friendships%rowtype; query text; people jsonb;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid social request' using errcode='22023'; end if;
 if not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and deleted_at is null)
 then raise exception 'Set up a social identity first' using errcode='22023'; end if;
 if action in ('search','friends','incoming','outgoing') then
  query:=lower(btrim(coalesce(payload->>'query',''))); if left(query,1)='@' then query:=substring(query from 2); end if;
  if action='search' and (length(query)<2 or length(query)>50) then return jsonb_build_object('people','[]'::jsonb); end if;
  select coalesce(jsonb_agg(card order by card->>'username'),'[]'::jsonb) into people from (
   select staygrubby.social_person(owner,p.account_id) card from staygrubby.profiles p
   left join staygrubby.friendships f on f.low_id=least(owner,p.account_id) and f.high_id=greatest(owner,p.account_id)
   where p.account_id<>owner and p.username is not null and p.deleted_at is null
    and p.username>coalesce(payload->>'afterUsername','')
    and ((action='search' and p.discoverable and position(query in p.username)>0)
     or(action='friends' and f.state='friends')
     or(action='incoming' and f.state='pending' and f.requester_id<>owner)
     or(action='outgoing' and f.state='pending' and f.requester_id=owner))
   order by p.username limit 50
  ) r where card is not null;
  return jsonb_build_object('people',people,'nextCursor',case when jsonb_array_length(people)=50 then people->49->>'username' end);
 elsif action='blocked' then
  select coalesce(jsonb_agg(jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,'relationship','blocked') order by p.username),'[]'::jsonb)
  into people from staygrubby.social_blocks b join staygrubby.profiles p on p.account_id=b.blocked_id
  join staygrubby.accounts a on a.id=p.account_id where b.blocker_id=owner and a.status='active' and p.deleted_at is null;
  return jsonb_build_object('people',people);
 end if;
 peer:=(payload->>'peerID')::uuid;
 if peer is null or peer=owner then raise exception 'Invalid person' using errcode='22023'; end if;
 lo:=least(owner,peer);hi:=greatest(owner,peer);
 if action='profile' then
  people:=staygrubby.social_person(owner,peer);
  if people is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  return jsonb_build_object('people',jsonb_build_array(people));
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:pair:'||lo::text||':'||hi::text,0));
 perform staygrubby.social_actor(); -- Recheck live Auth after waiting on the pair lock.
 -- Account deletion locks the account row; recheck active state after pair serialization.
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 select * into relation from staygrubby.friendships where low_id=lo and high_id=hi for update;
 if action='unblock' then
  delete from staygrubby.social_blocks where blocker_id=owner and blocked_id=peer;
  return jsonb_build_object('people','[]'::jsonb);
 elsif action='block' then
  if not exists(select 1 from staygrubby.social_blocks where blocker_id=owner and blocked_id=peer)
   and staygrubby.social_person(owner,peer) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  insert into staygrubby.social_blocks(blocker_id,blocked_id) values(owner,peer) on conflict do nothing;
  update staygrubby.friendships set state='removed',updated_at=now() where low_id=lo and high_id=hi;
  return jsonb_build_object('people','[]'::jsonb);
 end if;
 if staygrubby.social_blocked(owner,peer) then raise exception 'Person unavailable' using errcode='42501'; end if;
 if action='request' then
  if staygrubby.social_person(owner,peer) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  if relation.state='pending' and relation.requester_id<>owner then
   update staygrubby.friendships set state='friends',updated_at=now() where low_id=lo and high_id=hi;
  elsif relation.state in ('friends','pending') then null; -- Idempotent same-direction request.
  else
   if relation.state='declined' and relation.requester_id=owner and relation.updated_at>now()-interval '24 hours'
   then raise exception 'Wait before requesting again' using errcode='40001'; end if;
   if not exists(select 1 from staygrubby.profiles where account_id=peer and discoverable and deleted_at is null)
   then raise exception 'Person unavailable' using errcode='42501'; end if;
   insert into staygrubby.friendships(low_id,high_id,requester_id,state) values(lo,hi,owner,'pending')
   on conflict(low_id,high_id) do update set requester_id=excluded.requester_id,state='pending',updated_at=now();
  end if;
 elsif action in ('accept','decline') then
  if relation.state is distinct from 'pending' or relation.requester_id=owner
  then raise exception 'Request changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state=case action when 'accept' then 'friends' else 'declined' end,updated_at=now() where low_id=lo and high_id=hi;
 elsif action='cancel' then
  if relation.state is distinct from 'pending' or relation.requester_id<>owner then raise exception 'Request changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state='cancelled',updated_at=now() where low_id=lo and high_id=hi;
 elsif action='remove' then
  if relation.state is distinct from 'friends' then raise exception 'Friendship changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state='removed',updated_at=now() where low_id=lo and high_id=hi;
 else raise exception 'Unknown social action' using errcode='22023'; end if;
 people:=staygrubby.social_person(owner,peer);
 return jsonb_build_object('people',case when people is null then '[]'::jsonb else jsonb_build_array(people) end);
end $$;
revoke all on function staygrubby.social_people(text,jsonb) from public,anon;
grant execute on function staygrubby.social_people(text,jsonb) to authenticated;
create function api.social_people(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_people(action,payload) $$;
revoke all on function api.social_people(text,jsonb) from public,anon;
grant execute on function api.social_people(text,jsonb) to authenticated;
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
notify pgrst,'reload schema';
commit;
