begin;
alter table staygrubby.social_comments add column deleted_at timestamptz;
create index social_comments_visible on staygrubby.social_comments(post_id,created_at desc,id desc) where deleted_at is null and moderation_state='active';
-- Participation is visible only while the participant still has access to this post.
create function staygrubby.social_participant(viewer uuid,participant uuid,post uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select staygrubby.social_can_view(participant,post) and not staygrubby.social_blocked(viewer,participant)
 and exists(select 1 from staygrubby.profiles where account_id=participant and username is not null)
$$;
revoke all on function staygrubby.social_participant(uuid,uuid,uuid) from public,anon,authenticated;

-- Preserve the existing safe card shape and add aggregate engagement in the same request.
create or replace function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'author',jsonb_build_object('id',a.account_id,'displayName',a.display_name,'username',a.username,
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

create function staygrubby.social_interactions(action text,payload jsonb default '{}'::jsonb) returns jsonb
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
    'author',jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,'relationship',case when exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,p.account_id) and f.high_id=greatest(viewer,p.account_id) and f.state='friends') then 'friends' else 'none' end),
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
revoke all on function staygrubby.social_interactions(text,jsonb) from public,anon;
grant execute on function staygrubby.social_interactions(text,jsonb) to authenticated;
create function api.social_interactions(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_interactions(action,payload) $$;
revoke all on function api.social_interactions(text,jsonb) from public,anon;
grant execute on function api.social_interactions(text,jsonb) to authenticated;
create or replace function staygrubby.social_report(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid := staygrubby.social_actor(); kind text := payload->>'targetType'; target uuid := (payload->>'targetID')::uuid;
 author uuid; post uuid; comment uuid; note text; why text := payload->>'reason';
begin
 if action<>'report' or target is null or octet_length(payload::text)>4096 or why is null
  or why not in ('harassment','hate','spam','inappropriate','impersonation','other')
 then raise exception 'Invalid report' using errcode='22023'; end if;
 if kind='profile' then
  if staygrubby.social_person(owner,target) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  author:=target;
 elsif kind='post' then
  if not staygrubby.social_can_view(owner,target) then raise exception 'Post unavailable' using errcode='42501'; end if;
  select author_id,id into author,post from staygrubby.social_posts where id=target;
 elsif kind='comment' then
  select c.author_id,c.post_id,c.id into author,post,comment from staygrubby.social_comments c
  where c.id=target and c.deleted_at is null and c.moderation_state='active' and staygrubby.social_participant(owner,c.author_id,c.post_id) and staygrubby.social_can_view(owner,c.post_id)
   and not staygrubby.social_blocked(owner,c.author_id);
  if author is null then raise exception 'Comment unavailable' using errcode='42501'; end if;
 else raise exception 'Invalid report target' using errcode='22023'; end if;
 if author=owner then raise exception 'Cannot report yourself' using errcode='22023'; end if;
 if exists(select 1 from staygrubby.social_reports where reporter_id=owner and target_type=kind and target_id=target)
 then return jsonb_build_object('reported',true); end if;
 if (select count(*) from staygrubby.social_reports where reporter_id=owner and created_at>now()-interval '1 day')>=50
 then raise exception 'Report limit reached' using errcode='54000'; end if;
 note:=nullif(btrim(regexp_replace(coalesce(payload->>'context',''),'[[:space:]]+',' ','g')),'');
 if length(note)>500 then raise exception 'Report context too long' using errcode='22023'; end if;
 insert into staygrubby.social_reports(reporter_id,target_type,target_id,target_account_id,target_post_id,target_comment_id,reason,context)
 values(owner,kind,target,author,post,comment,why,note)
 on conflict(reporter_id,target_type,target_id) do nothing;
 return jsonb_build_object('reported',true);
end $$;
notify pgrst,'reload schema';
commit;
