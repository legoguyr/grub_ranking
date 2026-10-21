-- Social provenance is separate from each account's cooking graph and ranking evidence.
begin;
create table staygrubby.shared_cooks (
 id uuid primary key,
 owner_id uuid not null references staygrubby.accounts(id) on delete cascade,
 source_attempt_id uuid not null,
 metadata jsonb not null,
 created_at timestamptz not null default now(),
 unique(owner_id,source_attempt_id)
);
create table staygrubby.shared_participants (
 event_id uuid not null references staygrubby.shared_cooks(id) on delete cascade,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 state text not null default 'pending' check(state in('pending','joining','joined','declined','removed')),
 updated_at timestamptz not null default now(),
 primary key(event_id,account_id)
);
create index shared_participants_recipient on staygrubby.shared_participants(account_id,event_id);
create table staygrubby.cooking_origins (
 id uuid primary key default gen_random_uuid(),
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 kind text not null check(kind in('together','recreated')),
 event_id uuid references staygrubby.shared_cooks(id) on delete set null,
 post_id uuid references staygrubby.social_posts(id) on delete set null,
 creator_id uuid references staygrubby.accounts(id) on delete set null,
 item_id uuid not null default gen_random_uuid(),
 attempt_id uuid,
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 unique(account_id,item_id)
);
create unique index cooking_origin_event on staygrubby.cooking_origins(account_id,event_id) where event_id is not null;
create unique index cooking_origin_post on staygrubby.cooking_origins(account_id,post_id) where post_id is not null;
create index cooking_origins_creator on staygrubby.cooking_origins(creator_id);
create index cooking_origins_event on staygrubby.cooking_origins(event_id);
create index cooking_origins_post on staygrubby.cooking_origins(post_id);
create table staygrubby.social_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references staygrubby.accounts(id) on delete cascade,
 actor_id uuid not null references staygrubby.accounts(id) on delete cascade,
 kind text not null check(kind in('request','accepted','invited','joined','recreated','like','comment')),
 target_id uuid not null,
 dedupe_key text not null unique,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 check(recipient_id<>actor_id)
);
create index social_notifications_page on staygrubby.social_notifications(recipient_id,created_at desc,id desc);
create index social_notifications_actor on staygrubby.social_notifications(actor_id);
alter table staygrubby.shared_cooks enable row level security;
alter table staygrubby.shared_participants enable row level security;
alter table staygrubby.cooking_origins enable row level security;
alter table staygrubby.social_notifications enable row level security;
revoke all on staygrubby.shared_cooks,staygrubby.shared_participants,staygrubby.cooking_origins,staygrubby.social_notifications from public,anon,authenticated;

create function staygrubby.shared_friends(a uuid,b uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select a<>b and not staygrubby.social_blocked(a,b)
 and exists(select 1 from staygrubby.friendships where low_id=least(a,b) and high_id=greatest(a,b) and state='friends')
 and (select count(*)=2 from staygrubby.profiles p join staygrubby.accounts x on x.id=p.account_id
 where p.account_id in(a,b) and p.username is not null and p.deleted_at is null and p.social_state='active' and x.status='active')
$$;
revoke all on function staygrubby.shared_friends(uuid,uuid) from public,anon,authenticated;

-- Explicitly shared snapshot only: omit annotations, free text notes, allergens, scores and media.
create function staygrubby.shared_cook_metadata(owner uuid,attempt uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_strip_nulls(jsonb_build_object('title',left(d.name,200),'course',a.course_code,'cuisine',d.cuisine,
 'source',case when s.type_code='cookbook' then jsonb_build_object('type','cookbook','name',s.cookbook_title,'author',s.cookbook_authors,'recipe',s.cookbook_recipe_name,'page',s.cookbook_page)
 when s.type_code='restaurant' then jsonb_build_object('type','restaurant','name',s.restaurant_name,'recipe',s.restaurant_dish_name)
 when s.type_code='onlineRecipe' then jsonb_build_object('type','onlineRecipe','name',s.online_website,'recipe',s.online_recipe_name)
 when s.type_code='socialMedia' then jsonb_build_object('type','socialMedia','name',s.social_creator,'recipe',s.social_dish_name)
 end))
 from staygrubby.cooking_attempts a join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
 join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
 left join staygrubby.dish_sources s on s.account_id=d.account_id and s.id=d.source_id and s.deleted_at is null
 where a.account_id=owner and a.id=attempt and a.deleted_at is null
$$;
revoke all on function staygrubby.shared_cook_metadata(uuid,uuid) from public,anon,authenticated;
alter table staygrubby.social_posts add column safe_metadata jsonb not null default '{}'::jsonb;
create function staygrubby.capture_shared_metadata() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 new.safe_metadata:=coalesce(staygrubby.shared_cook_metadata(new.author_id,new.source_attempt_id),'{}'::jsonb);
 return new;
end $$;
revoke all on function staygrubby.capture_shared_metadata() from public,anon,authenticated;
create trigger capture_shared_metadata before insert on staygrubby.social_posts for each row execute function staygrubby.capture_shared_metadata();

create function staygrubby.shared_access(viewer uuid,event uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.shared_cooks e
 join staygrubby.profiles p on p.account_id=e.owner_id and p.social_state='active' and p.deleted_at is null
 join staygrubby.accounts x on x.id=e.owner_id and x.status='active'
 join staygrubby.cooking_attempts a on a.account_id=e.owner_id and a.id=e.source_attempt_id and a.deleted_at is null
 where e.id=event and (e.owner_id=viewer or (staygrubby.shared_friends(viewer,e.owner_id)
 and exists(select 1 from staygrubby.shared_participants s where s.event_id=e.id and s.account_id=viewer and s.state in('pending','joining','joined')))))
$$;
revoke all on function staygrubby.shared_access(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_notice(recipient uuid,actor uuid,kind text,target uuid,dedupe text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if recipient is null or actor is null or recipient=actor then return; end if;
 insert into staygrubby.social_notifications(recipient_id,actor_id,kind,target_id,dedupe_key)
 values(recipient,actor,kind,target,dedupe) on conflict(dedupe_key) do nothing;
end $$;
revoke all on function staygrubby.social_notice(uuid,uuid,text,uuid,text) from public,anon,authenticated;

create function staygrubby.shared_event_card(viewer uuid,event uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',e.id,'owner',staygrubby.social_person(viewer,e.owner_id),'metadata',e.metadata,'isOwner',e.owner_id=viewer,
 'participants',coalesce((select jsonb_agg(jsonb_build_object('person',staygrubby.social_person(viewer,s.account_id),'state',s.state) order by s.account_id)
 from staygrubby.shared_participants s where s.event_id=e.id and (s.account_id=viewer or (e.owner_id=viewer and staygrubby.shared_friends(viewer,s.account_id)))),'[]'::jsonb))
 from staygrubby.shared_cooks e where e.id=event and staygrubby.shared_access(viewer,e.id)
$$;
revoke all on function staygrubby.shared_event_card(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); eid uuid:=(payload->>'eventID')::uuid; pid uuid:=(payload->>'postID')::uuid;
 oid uuid:=(payload->>'originID')::uuid; peer uuid; source uuid; meta jsonb; ev staygrubby.shared_cooks%rowtype;
 origin staygrubby.cooking_origins%rowtype; participant staygrubby.shared_participants%rowtype; result jsonb;
begin
 if octet_length(payload::text)>8192 then raise exception 'Invalid cooking request' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:shared:'||owner::text,0));
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='create' then
  source:=(payload->>'attemptID')::uuid;
  if eid is null or coalesce((payload->>'confirmed')::boolean,false) is not true
   or jsonb_typeof(payload->'participantIDs') is distinct from 'array'
   or jsonb_array_length(payload->'participantIDs') not between 1 and 8 then raise exception 'Choose up to eight friends' using errcode='22023'; end if;
  meta:=staygrubby.shared_cook_metadata(owner,source);
  if meta is null or not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and social_state='active') then raise exception 'Cook unavailable' using errcode='42501'; end if;
  select * into ev from staygrubby.shared_cooks where owner_id=owner and source_attempt_id=source;
  if ev.id is not null then return staygrubby.shared_event_card(owner,ev.id); end if;
  for peer in select distinct value::uuid from jsonb_array_elements_text(payload->'participantIDs') loop
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:pair:'||least(owner,peer)::text||':'||greatest(owner,peer)::text,0));
   if not staygrubby.shared_friends(owner,peer) then raise exception 'Choose current friends only' using errcode='42501'; end if;
  end loop;
  insert into staygrubby.shared_cooks(id,owner_id,source_attempt_id,metadata) values(eid,owner,source,meta);
  for peer in select distinct value::uuid from jsonb_array_elements_text(payload->'participantIDs') loop
   insert into staygrubby.shared_participants(event_id,account_id) values(eid,peer);
   perform staygrubby.social_notice(peer,owner,'invited',eid,'invite:'||eid::text||':'||peer::text);
  end loop;
  return staygrubby.shared_event_card(owner,eid);
 elsif action in('event','decline','remove','claim') and eid is not null then
  select * into ev from staygrubby.shared_cooks where id=eid for update;
  if not staygrubby.shared_access(owner,eid) then raise exception 'Shared cook unavailable' using errcode='42501'; end if;
  if action='event' then return staygrubby.shared_event_card(owner,eid); end if;
  if action='remove' then
   if ev.owner_id<>owner then raise exception 'Owner required' using errcode='42501'; end if;
   update staygrubby.shared_participants set state='removed',updated_at=now() where event_id=eid and account_id=(payload->>'peerID')::uuid and state in('pending','joining');
   return staygrubby.shared_event_card(owner,eid);
  end if;
  select * into participant from staygrubby.shared_participants where event_id=eid and account_id=owner for update;
  if participant.account_id is null or participant.state not in('pending','joining','joined') then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  if action='decline' then
   if participant.state='joined' then raise exception 'Already joined' using errcode='40001'; end if;
   update staygrubby.shared_participants set state='declined',updated_at=now() where event_id=eid and account_id=owner;
   return jsonb_build_object('declined',true);
  end if;
  insert into staygrubby.cooking_origins(account_id,kind,event_id,creator_id) values(owner,'together',eid,ev.owner_id) on conflict(account_id,event_id) where event_id is not null do nothing;
  select * into origin from staygrubby.cooking_origins where account_id=owner and event_id=eid;
  update staygrubby.shared_participants set state=case when state='pending' then 'joining' else state end,updated_at=now() where event_id=eid and account_id=owner;
  meta:=ev.metadata;
 elsif action='recreate' then
  if not staygrubby.social_can_view(owner,pid) or not exists(select 1 from staygrubby.social_posts where id=pid and author_id<>owner) then raise exception 'Post unavailable' using errcode='42501'; end if;
  select author_id,safe_metadata||jsonb_build_object('title',title) into peer,meta from staygrubby.social_posts where id=pid;
  insert into staygrubby.cooking_origins(account_id,kind,post_id,creator_id) values(owner,'recreated',pid,peer) on conflict(account_id,post_id) where post_id is not null do nothing;
  select * into origin from staygrubby.cooking_origins where account_id=owner and post_id=pid;
 elsif action='complete' then
  select * into origin from staygrubby.cooking_origins where id=oid and account_id=owner for update;
  if origin.id is null then raise exception 'Origin unavailable' using errcode='42501'; end if;
  select id into source from staygrubby.cooking_attempts where account_id=owner and ranked_item_id=origin.item_id and deleted_at is null;
  if source is null then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
  if origin.completed_at is null then
   update staygrubby.cooking_origins set attempt_id=source,completed_at=now() where id=oid returning * into origin;
   if origin.kind='together' then
    update staygrubby.shared_participants set state='joined',updated_at=now() where event_id=origin.event_id and account_id=owner and state='joining';
    if found and staygrubby.shared_access(owner,origin.event_id) then perform staygrubby.social_notice(origin.creator_id,owner,'joined',origin.event_id,'joined:'||oid::text); end if;
   elsif staygrubby.social_can_view(owner,origin.post_id) then
    perform staygrubby.social_notice(origin.creator_id,owner,'recreated',origin.post_id,'recreated:'||oid::text);
   end if;
  end if;
 elsif action='own' then
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'kind',o.kind,'itemID',o.item_id,'completed',o.completed_at is not null,
   'creator',case when staygrubby.shared_friends(owner,o.creator_id) then staygrubby.social_person(owner,o.creator_id) end,
   'eventID',case when staygrubby.shared_access(owner,o.event_id) then o.event_id end)),'[]'::jsonb)
   into result from staygrubby.cooking_origins o where o.account_id=owner and o.item_id=(payload->>'targetID')::uuid;
  return jsonb_build_object('origins',result,'events',coalesce((select jsonb_agg(staygrubby.shared_event_card(owner,e.id)) from staygrubby.shared_cooks e
   join staygrubby.cooking_attempts a on a.account_id=owner and a.id=e.source_attempt_id where e.owner_id=owner and a.ranked_item_id=(payload->>'targetID')::uuid and staygrubby.shared_access(owner,e.id)),'[]'::jsonb));
 else raise exception 'Unknown cooking action' using errcode='22023'; end if;
 return jsonb_build_object('id',origin.id,'itemID',origin.item_id,'kind',origin.kind,'completed',origin.completed_at is not null,'metadata',coalesce(meta,'{}'::jsonb));
end $$;
revoke all on function staygrubby.social_cooking(text,jsonb) from public,anon;
grant execute on function staygrubby.social_cooking(text,jsonb) to authenticated;
create function api.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_cooking(action,payload) $$;
revoke all on function api.social_cooking(text,jsonb) from public,anon;
grant execute on function api.social_cooking(text,jsonb) to authenticated;

-- No notification creation endpoint: canonical transitions alone produce notifications.
create function staygrubby.social_activity_notice() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 if tg_table_name='friendships' then
  if new.state='pending' and (tg_op='INSERT' or old.state is distinct from new.state) then
   perform staygrubby.social_notice(case when new.requester_id=new.low_id then new.high_id else new.low_id end,new.requester_id,'request',new.requester_id,'request:'||new.low_id::text||new.high_id::text||new.updated_at::text);
  elsif new.state='friends' and old.state is distinct from new.state then
   perform staygrubby.social_notice(new.requester_id,case when new.requester_id=new.low_id then new.high_id else new.low_id end,'accepted',case when new.requester_id=new.low_id then new.high_id else new.low_id end,'accepted:'||new.low_id::text||new.high_id::text||new.updated_at::text);
  end if;
 elsif tg_table_name='social_likes' then
  select author_id into recipient from staygrubby.social_posts where id=new.post_id;
  perform staygrubby.social_notice(recipient,new.account_id,'like',new.post_id,'like:'||new.post_id::text||new.account_id::text);
 elsif tg_table_name='social_comments' and new.deleted_at is null then
  select author_id into recipient from staygrubby.social_posts where id=new.post_id;
  perform staygrubby.social_notice(recipient,new.author_id,'comment',new.id,'comment:'||new.id::text);
 end if;
 return new;
end $$;
revoke all on function staygrubby.social_activity_notice() from public,anon,authenticated;
create trigger social_friend_notice after insert or update on staygrubby.friendships for each row execute function staygrubby.social_activity_notice();
create trigger social_like_notice after insert on staygrubby.social_likes for each row execute function staygrubby.social_activity_notice();
create trigger social_comment_notice after insert on staygrubby.social_comments for each row execute function staygrubby.social_activity_notice();

create function staygrubby.social_notice_visible(viewer uuid,notice uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.social_notifications n where n.id=notice and n.recipient_id=viewer and not staygrubby.social_blocked(viewer,n.actor_id)
 and exists(select 1 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id where p.account_id=n.actor_id and p.social_state='active' and p.deleted_at is null and a.status='active')
 and case n.kind
 when 'request' then exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,n.actor_id) and f.high_id=greatest(viewer,n.actor_id) and f.state='pending' and f.requester_id=n.actor_id)
 when 'accepted' then staygrubby.shared_friends(viewer,n.actor_id)
 when 'invited' then staygrubby.shared_access(viewer,n.target_id)
 when 'joined' then staygrubby.shared_access(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
 when 'like' then staygrubby.social_can_view(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
  and exists(select 1 from staygrubby.social_likes l where l.post_id=n.target_id and l.account_id=n.actor_id)
 when 'recreated' then staygrubby.social_can_view(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
 when 'comment' then exists(select 1 from staygrubby.social_comments c where c.id=n.target_id and c.deleted_at is null and c.moderation_state='active' and staygrubby.social_can_view(viewer,c.post_id) and staygrubby.social_participant(viewer,c.author_id,c.post_id))
 else false end)
$$;
revoke all on function staygrubby.social_notice_visible(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_notifications_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); result jsonb; unread integer;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid notifications request' using errcode='22023'; end if;
 if action='read' then
  if not staygrubby.social_notice_visible(owner,(payload->>'targetID')::uuid) then raise exception 'Notification unavailable' using errcode='42501'; end if;
  update staygrubby.social_notifications set read_at=coalesce(read_at,now()) where id=(payload->>'targetID')::uuid and recipient_id=owner;
 elsif action='readAll' then
  update staygrubby.social_notifications n set read_at=now() where recipient_id=owner and read_at is null and staygrubby.social_notice_visible(owner,n.id);
 elsif action='delete' then
  -- Keep the dedupe tombstone: a delayed source retry must not recreate a dismissed notice.
  update staygrubby.social_notifications set read_at=coalesce(read_at,now()) where id=(payload->>'targetID')::uuid and recipient_id=owner;
 elsif action<>'page' then raise exception 'Unknown notification action' using errcode='22023'; end if;
 select count(*) into unread from staygrubby.social_notifications n where recipient_id=owner and read_at is null and staygrubby.social_notice_visible(owner,n.id);
 select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
  select n.created_at,n.id,jsonb_build_object('id',n.id,'kind',n.kind,'actor',staygrubby.social_person(owner,n.actor_id),'targetID',n.target_id,
   'postID',case when n.kind in('like','recreated') then n.target_id when n.kind='comment' then (select post_id from staygrubby.social_comments where id=n.target_id) end,
   'createdAt',extract(epoch from n.created_at),'read',n.read_at is not null) card
  from staygrubby.social_notifications n where recipient_id=owner and staygrubby.social_notice_visible(owner,n.id)
  and (payload->>'beforeTime' is null or(n.created_at,n.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
  order by n.created_at desc,n.id desc limit 25) page;
 return jsonb_build_object('notifications',result,'unread',unread);
end $$;
revoke all on function staygrubby.social_notifications_api(text,jsonb) from public,anon;
grant execute on function staygrubby.social_notifications_api(text,jsonb) to authenticated;
create function api.social_notifications(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_notifications_api(action,payload) $$;
revoke all on function api.social_notifications(text,jsonb) from public,anon;
grant execute on function api.social_notifications(text,jsonb) to authenticated;

-- Retire pending invitations on relationship loss; completed private cooks are never touched.
create function staygrubby.retire_shared_relationship() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.state='removed' then
  update staygrubby.shared_participants p set state='removed',updated_at=now() from staygrubby.shared_cooks e
  where p.event_id=e.id and least(p.account_id,e.owner_id)=new.low_id and greatest(p.account_id,e.owner_id)=new.high_id and p.state in('pending','joining');
 end if;
 return new;
end $$;
revoke all on function staygrubby.retire_shared_relationship() from public,anon,authenticated;
create trigger retire_shared_relationship after update of state on staygrubby.friendships for each row execute function staygrubby.retire_shared_relationship();

-- Decorate only the controlled social representation, never the private graph.
alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_shared;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_shared(viewer,post); p staygrubby.social_posts%rowtype;
 origin staygrubby.cooking_origins%rowtype; people jsonb; creator jsonb;
begin
 if card is null then return null; end if;
 select * into p from staygrubby.social_posts where id=post;
 select * into origin from staygrubby.cooking_origins where account_id=p.author_id and attempt_id=p.source_attempt_id and completed_at is not null;
 if origin.kind='recreated' and staygrubby.shared_friends(viewer,origin.creator_id) and staygrubby.social_can_view(viewer,origin.post_id) then
  creator:=staygrubby.social_person(viewer,origin.creator_id);
  card:=card||jsonb_build_object('provenance',jsonb_build_object('kind','recreated','creator',creator));
 end if;
 select coalesce(jsonb_agg(staygrubby.social_person(viewer,s.account_id) order by s.account_id),'[]'::jsonb) into people
 from staygrubby.shared_cooks e join staygrubby.shared_participants s on s.event_id=e.id
 where e.owner_id=p.author_id and e.source_attempt_id=p.source_attempt_id and s.state='joined'
 and staygrubby.shared_friends(p.author_id,s.account_id) and (s.account_id=viewer or staygrubby.shared_friends(viewer,s.account_id));
 if origin.kind='together' and staygrubby.shared_friends(p.author_id,origin.creator_id) and (viewer=origin.creator_id or staygrubby.shared_friends(viewer,origin.creator_id)) then
  people:=people||jsonb_build_array(staygrubby.social_person(viewer,origin.creator_id));
 end if;
 if jsonb_array_length(people)>0 then card:=card||jsonb_build_object('provenance',jsonb_build_object('kind','together','people',people)); end if;
 return card;
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
