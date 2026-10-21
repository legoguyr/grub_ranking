-- Purpose-specific, authenticated social identity media. No private cooking changes.
begin;
alter table staygrubby.profiles add column avatar_path text, add column avatar_draft_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',false,2097152,array['image/jpeg']);

create function staygrubby.social_avatar_visible(viewer uuid,target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.profiles v where v.account_id=viewer and v.deleted_at is null and v.social_state='active') and exists(select 1 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id
 where p.account_id=target and a.status='active' and p.deleted_at is null and p.social_state='active'
 and not staygrubby.social_blocked(viewer,target)
 and (viewer=target or (p.username is not null and (
  staygrubby.social_person(viewer,target) is not null
  or exists(select 1 from staygrubby.social_posts s where s.author_id=target and staygrubby.social_can_view(viewer,s.id))
  or exists(select 1 from staygrubby.social_comments c where c.author_id=target and c.deleted_at is null and c.moderation_state='active'
    and staygrubby.social_can_view(viewer,c.post_id) and staygrubby.social_participant(viewer,target,c.post_id))
 ))))
$$;
revoke all on function staygrubby.social_avatar_visible(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_avatar(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); profile staygrubby.profiles%rowtype; path text; result jsonb;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid avatar request' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:avatar:'||owner::text,0));
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 select * into profile from staygrubby.profiles where account_id=owner and deleted_at is null for update;
 if profile.account_id is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 if action='prepare' then
  if profile.username is null or profile.social_state<>'active' then raise exception 'Social identity required' using errcode='42501'; end if;
  path:=owner::text||'/'||(payload->>'assetID')::uuid::text||'.jpg';
  if path=profile.avatar_path then return jsonb_build_object('path',path,'published',true); end if;
  if path is null then raise exception 'New asset required' using errcode='22023'; end if;
  update staygrubby.profiles set avatar_draft_path=path where account_id=owner;
  return jsonb_build_object('path',path);
 elsif action='publish' then
  path:=payload->>'avatarPath';
  if path=profile.avatar_path then return jsonb_build_object('avatarPath',path); end if;
  if path is null or path is distinct from profile.avatar_draft_path or profile.social_state<>'active'
   then raise exception 'Avatar draft unavailable' using errcode='42501'; end if;
  if not exists(select 1 from storage.objects where bucket_id='profile-photos' and name=path
    and metadata->>'mimetype'='image/jpeg' and (metadata->>'size')::bigint between 1 and 2097152)
   then raise exception 'Upload required' using errcode='55000'; end if;
  update staygrubby.profiles set avatar_path=path,avatar_draft_path=null where account_id=owner;
 elsif action='remove' then
  if (payload->>'avatarPath') is distinct from profile.avatar_path then raise exception 'Profile changed; refresh' using errcode='40001'; end if;
  update staygrubby.profiles set avatar_path=null,avatar_draft_path=null where account_id=owner;
 elsif action='cleanup' then
  select coalesce(jsonb_agg(name),'[]'::jsonb) into result from (
   select name from storage.objects where bucket_id='profile-photos' and name like owner::text||'/%'
    and name is distinct from profile.avatar_path and name is distinct from profile.avatar_draft_path order by name limit 25) objects;
  return jsonb_build_object('paths',result);
 else raise exception 'Unknown avatar action' using errcode='22023'; end if;
 return jsonb_build_object('avatarPath',(select avatar_path from staygrubby.profiles where account_id=owner));
end $$;
revoke all on function staygrubby.social_avatar(text,jsonb) from public,anon;
grant execute on function staygrubby.social_avatar(text,jsonb) to authenticated;
create function api.social_avatar(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_avatar(action,payload) $$;
revoke all on function api.social_avatar(text,jsonb) from public,anon;
grant execute on function api.social_avatar(text,jsonb) to authenticated;

create function staygrubby.profile_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; target uuid; profile staygrubby.profiles%rowtype; operation text;
begin
 if bucket is distinct from 'profile-photos' or mode not in('read','write','delete') then return false; end if;
 owner:=staygrubby.media_owner(); if owner is null then return false; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.media_owner() is distinct from owner then return false; end if;
 if path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.]jpg$' then return false; end if;
 begin target:=split_part(path,'/',1)::uuid; exception when invalid_text_representation then return false; end;
 select * into profile from staygrubby.profiles where account_id=target and deleted_at is null;
 if profile.account_id is null then return false; end if;
 if mode='delete' or (mode='read' and storage.allow_any_operation(array['object.delete','object.delete_many'])) then
  return owner=target and path is distinct from profile.avatar_path and path is distinct from profile.avatar_draft_path
   and storage.allow_any_operation(array['object.delete','object.delete_many']);
 end if;
 if mode='write' then return owner=target and profile.avatar_draft_path=path and profile.social_state='active'
  and storage.allow_any_operation(array['object.upload','object.upload_update']); end if;
 -- No arbitrary bucket enumeration, including authenticated listing.
 return storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.upload','object.upload_update'])
  and ((owner=target and profile.avatar_draft_path=path) or (profile.avatar_path=path and staygrubby.social_avatar_visible(owner,target)));
end $$;
revoke all on function staygrubby.profile_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.profile_object_allowed(text,text,text) to authenticated;
create policy profile_photo_read on storage.objects for select to authenticated using(staygrubby.profile_object_allowed(bucket_id,name,'read'));
create policy profile_photo_create on storage.objects for insert to authenticated with check(staygrubby.profile_object_allowed(bucket_id,name,'write'));
create policy profile_photo_replace on storage.objects for update to authenticated using(staygrubby.profile_object_allowed(bucket_id,name,'write')) with check(staygrubby.profile_object_allowed(bucket_id,name,'write'));
create policy profile_photo_remove on storage.objects for delete to authenticated using(staygrubby.profile_object_allowed(bucket_id,name,'delete'));

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
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'avatarPath',p.avatar_path,'discoverable',p.discoverable) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;

create or replace function staygrubby.social_person(viewer uuid,target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,'avatarPath',p.avatar_path,
 'relationship',case when f.state='friends' then 'friends' when f.state='pending' and f.requester_id=viewer then 'outgoing' when f.state='pending' then 'incoming' else 'none' end)
 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id
 left join staygrubby.friendships f on f.low_id=least(viewer,target) and f.high_id=greatest(viewer,target)
 where p.account_id=target and p.username is not null and p.deleted_at is null and p.social_state='active' and a.status='active'
 and not staygrubby.social_blocked(viewer,target)
 and (p.discoverable or viewer=target or f.state in ('friends','pending'))
$$;

create or replace function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'author',jsonb_build_object('id',a.account_id,'displayName',a.display_name,'username',a.username,'avatarPath',a.avatar_path,
  'relationship',case when p.author_id=viewer then 'none' when exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,p.author_id) and f.high_id=greatest(viewer,p.author_id) and f.state='friends') then 'friends' else 'none' end),
  'title',p.title,'versionTitle',p.version_title,'scoreText',p.score_text,'achievement',p.achievement,
  'createdAt',extract(epoch from p.created_at),'photoPath',case when p.photo_ready or p.author_id=viewer then p.photo_path end,
  'published',p.published,'isAuthor',p.author_id=viewer,'moderationState',p.moderation_state,
  'likeCount',(select count(*) from staygrubby.social_likes l where l.post_id=p.id and staygrubby.social_participant(viewer,l.account_id,p.id)),
  'liked',exists(select 1 from staygrubby.social_likes l where l.post_id=p.id and l.account_id=viewer),
  'commentCount',(select count(*) from staygrubby.social_comments c where c.post_id=p.id and c.deleted_at is null and c.moderation_state='active' and staygrubby.social_participant(viewer,c.author_id,p.id)))
 from staygrubby.social_posts p join staygrubby.profiles a on a.account_id=p.author_id
 where p.id=post and p.deleted_at is null and (p.author_id=viewer or staygrubby.social_can_view(viewer,p.id))
$$;

create or replace function staygrubby.social_interactions(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare viewer uuid:=staygrubby.social_actor(); pid uuid:=(payload->>'postID')::uuid;
 cid uuid:=(payload->>'commentID')::uuid; author uuid; body_text text; existing staygrubby.social_comments%rowtype; result jsonb;
begin
 if pid is null or octet_length(payload::text)>8192 or ((payload->>'beforeTime' is null)<>(payload->>'beforeID' is null)) then raise exception 'Invalid interaction' using errcode='22023'; end if;
 select author_id into author from staygrubby.social_posts where id=pid;
 if author is null then raise exception 'Post unavailable' using errcode='42501'; end if;
 -- Serialize relationship transitions and source/account deletion against writes.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:pair:'||least(viewer,author)::text||':'||greatest(viewer,author)::text,0));
 perform 1 from staygrubby.accounts where id in(viewer,author) order by id for share;
 perform staygrubby.social_actor();
 perform 1 from staygrubby.social_posts where id=pid for update;
 if not staygrubby.social_can_view(viewer,pid) then raise exception 'Post unavailable' using errcode='42501'; end if;
 if action='comments' then
  select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
   select c.created_at,c.id,jsonb_build_object('id',c.id,'body',c.body,'createdAt',extract(epoch from c.created_at),
    'author',jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,'avatarPath',p.avatar_path,'relationship',case when exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,p.account_id) and f.high_id=greatest(viewer,p.account_id) and f.state='friends') then 'friends' else 'none' end),
    'canDelete',c.author_id=viewer or author=viewer,'isAuthor',c.author_id=viewer) card
   from staygrubby.social_comments c join staygrubby.profiles p on p.account_id=c.author_id
   where c.post_id=pid and c.deleted_at is null and c.moderation_state='active' and staygrubby.social_participant(viewer,c.author_id,pid)
    and (payload->>'beforeTime' is null or(c.created_at,c.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
   order by c.created_at desc,c.id desc limit 25) rows;
  return jsonb_build_object('comments',result);
 end if;
 if not exists(select 1 from staygrubby.profiles where account_id=viewer and username is not null) then raise exception 'Social identity required' using errcode='22023'; end if;
 if action='comment' then perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:social-comments:'||viewer::text,0)); end if;
 if action='like' then
  insert into staygrubby.social_likes(post_id,account_id) values(pid,viewer) on conflict do nothing;
 elsif action='unlike' then delete from staygrubby.social_likes where post_id=pid and account_id=viewer;
 elsif action='comment' then
  body_text:=btrim(regexp_replace(coalesce(payload->>'body',''),'[[:space:]]+',' ','g'));
  if cid is null or length(body_text) not between 1 and 1000 or body_text ~ '[[:cntrl:]]' then raise exception 'Invalid comment' using errcode='22023'; end if;
  select * into existing from staygrubby.social_comments where id=cid;
  if existing.id is not null then
   if existing.deleted_at is not null or existing.author_id<>viewer or existing.post_id<>pid or existing.body<>body_text then raise exception 'Comment identity unavailable' using errcode='42501'; end if;
  else
   if (select count(*) from staygrubby.social_comments where author_id=viewer and created_at>now()-interval '1 hour')>=60 then raise exception 'Comment limit reached' using errcode='54000'; end if;
   insert into staygrubby.social_comments(id,post_id,author_id,body) values(cid,pid,viewer,body_text);
  end if;
 elsif action='deleteComment' then
  if cid is null then raise exception 'Comment identity required' using errcode='22023'; end if;
  select * into existing from staygrubby.social_comments where id=cid;
  if existing.id is not null then
   if existing.post_id<>pid or(viewer<>existing.author_id and viewer<>author) then raise exception 'Comment unavailable' using errcode='42501'; end if;
   update staygrubby.social_comments set deleted_at=coalesce(deleted_at,now()),body='[Deleted]',moderation_state='hidden' where id=cid;
   delete from staygrubby.social_reports where target_comment_id=cid;
  end if;
 else raise exception 'Unknown interaction' using errcode='22023'; end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(viewer,pid)));
end $$;

create or replace function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;
 if exists(select 1 from storage.objects where bucket_id in ('cooking-photos','social-photos','profile-photos')
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
notify pgrst,'reload schema';
commit;
