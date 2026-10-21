begin;
alter table staygrubby.social_posts add column photo_path text;
alter table staygrubby.social_posts add column photo_ready boolean not null default false;
alter table staygrubby.social_posts add constraint social_photo_path check(photo_path is null or photo_path=author_id::text||'/'||id::text||'.jpg');
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('social-photos','social-photos',false,2097152,array['image/jpeg']);

create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'author',jsonb_build_object('id',a.account_id,'displayName',a.display_name,'username',a.username,
  'relationship',case when p.author_id=viewer then 'none' when exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,p.author_id) and f.high_id=greatest(viewer,p.author_id) and f.state='friends') then 'friends' else 'none' end),
  'title',p.title,'versionTitle',p.version_title,'scoreText',p.score_text,'achievement',p.achievement,
  'createdAt',extract(epoch from p.created_at),'photoPath',case when p.photo_ready or p.author_id=viewer then p.photo_path end,
  'published',p.published,'isAuthor',p.author_id=viewer,'moderationState',p.moderation_state)
 from staygrubby.social_posts p join staygrubby.profiles a on a.account_id=p.author_id
 where p.id=post and p.deleted_at is null and (p.author_id=viewer or staygrubby.social_can_view(viewer,p.id))
$$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid := staygrubby.social_actor(); pid uuid := (payload->>'postID')::uuid;
 source uuid; row staygrubby.social_posts%rowtype; cook record; count_entries integer; score text; needs_photo boolean; result jsonb;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid post' using errcode='22023'; end if;
 if action='own' then
  select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
   select staygrubby.social_post_card(owner,p.id) card,p.created_at,p.id from staygrubby.social_posts p
   where p.author_id=owner and p.deleted_at is null and (payload->>'beforeTime' is null
    or(p.created_at,p.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
   order by p.created_at desc,p.id desc limit 25) rows;
  return jsonb_build_object('posts',result);
 elsif action='cleanup' then
  update staygrubby.social_posts set deleted_at=now() where author_id=owner and not published and deleted_at is null and created_at<now()-interval '1 day';
  select coalesce(jsonb_agg(jsonb_build_object('postID',id,'path',photo_path)),'[]'::jsonb) into result from staygrubby.social_posts where author_id=owner and deleted_at is not null and photo_path is not null;
  return jsonb_build_object('paths',result);
 end if;
 if pid is null then raise exception 'Post identity required' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post:'||pid::text,0));
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 perform staygrubby.social_actor();
 select * into row from staygrubby.social_posts where id=pid for update;
 if action='prepare' then
  if coalesce((payload->>'confirmed')::boolean,false) is not true then raise exception 'Explicit sharing required' using errcode='22023'; end if;
  if not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and social_state='active')
  then raise exception 'Social identity required' using errcode='22023'; end if;
  if (payload->>'expectedRevision')::bigint is distinct from (select sync_revision from staygrubby.accounts where id=owner)
  then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
  source:=(payload->>'attemptID')::uuid;
  select a.id,d.name,a.version_title,a.sequence_number,i.strength into cook from staygrubby.cooking_attempts a
   join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
   join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
   join staygrubby.account_libraries l on l.account_id=a.account_id and l.global_ranking_id=i.ranking_id and l.deleted_at is null
   join staygrubby.rankings r on r.account_id=l.account_id and r.id=l.global_ranking_id and r.deleted_at is null
   where a.id=source and a.account_id=owner and a.deleted_at is null;
  if cook.id is null then raise exception 'Cook unavailable' using errcode='42501'; end if;
  if row.id is not null then
   if row.author_id<>owner or row.source_attempt_id<>source or row.deleted_at is not null then raise exception 'Post identity unavailable' using errcode='42501'; end if;
   return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,row.id)));
  end if;
  -- One active snapshot per cook. Retrying/re-sharing never silently creates copies.
  select * into row from staygrubby.social_posts where author_id=owner and source_attempt_id=source and deleted_at is null;
  if row.id is not null then return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,row.id))); end if;
  select count(distinct a.ranked_item_id) into count_entries from staygrubby.cooking_attempts a
   join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
   join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
   join staygrubby.account_libraries l on l.account_id=a.account_id and l.global_ranking_id=i.ranking_id and l.deleted_at is null
   where a.account_id=owner and a.deleted_at is null;
  -- Presentation-only mirror of PreferenceEstimate.score. Never writes ranking caches/evidence.
  if count_entries>=10 then
   score:=round((1+9/(1+exp(-greatest(-100.0,least(100.0,cook.strength/2)))))::numeric,1)::text;
  end if;
  needs_photo:=coalesce((payload->>'includePhoto')::boolean,false);
  insert into staygrubby.social_posts(id,author_id,source_attempt_id,title,version_title,score_text,published,photo_path)
   values(pid,owner,source,left(cook.name,200),left(coalesce(nullif(cook.version_title,''),case when cook.sequence_number>1 then 'Version '||cook.sequence_number end),200),score,not needs_photo,
    case when needs_photo then owner::text||'/'||pid::text||'.jpg' end);
 elsif action='publish' then
  if row.id is null or row.author_id<>owner or row.deleted_at is not null then raise exception 'Post unavailable' using errcode='42501'; end if;
  if row.photo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='social-photos' and o.name=row.photo_path
   and coalesce(o.metadata->>'mimetype','')='image/jpeg' and coalesce((o.metadata->>'size')::bigint,0) between 1 and 2097152)
  then raise exception 'Photo upload incomplete' using errcode='55000'; end if;
  update staygrubby.social_posts set published=true,photo_ready=photo_path is not null,
   created_at=case when published then created_at else clock_timestamp() end where id=pid;
 elsif action='cleaned' then
  if row.id is null or row.author_id<>owner or row.deleted_at is null then raise exception 'Cleanup unavailable' using errcode='42501'; end if;
  if exists(select 1 from storage.objects where bucket_id='social-photos' and name=row.photo_path) then raise exception 'Photo cleanup incomplete' using errcode='55000'; end if;
  update staygrubby.social_posts set photo_path=null,photo_ready=false where id=pid;
  return jsonb_build_object('posts','[]'::jsonb);
 elsif action='delete' then
  if row.id is null then return jsonb_build_object('posts','[]'::jsonb); end if;
  if row.author_id<>owner then raise exception 'Post unavailable' using errcode='42501'; end if;
  update staygrubby.social_posts set deleted_at=coalesce(deleted_at,now()) where id=pid;
  return jsonb_build_object('posts','[]'::jsonb);
 else raise exception 'Unknown post action' using errcode='22023'; end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;
revoke all on function api.social_content(text,jsonb) from public,anon;
grant execute on function api.social_content(text,jsonb) to authenticated;

create function staygrubby.social_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; row staygrubby.social_posts%rowtype;
begin
 if bucket is distinct from 'social-photos' or mode is null or mode not in ('read','write','delete') then return false; end if;
 owner:=staygrubby.media_owner(); if owner is null then return false; end if;
 perform 1 from staygrubby.accounts where id=owner for share;
 if staygrubby.media_owner() is distinct from owner then return false; end if;
 select * into row from staygrubby.social_posts where photo_path=path;
 if row.id is null then return false; end if;
 if mode='delete' then return row.author_id=owner and (row.deleted_at is not null or not row.published)
  and storage.allow_any_operation(array['object.delete','object.delete_many']); end if;
 if mode='write' then return row.author_id=owner and row.deleted_at is null and not row.published
  and storage.allow_any_operation(array['object.upload','object.upload_update'])
  and exists(select 1 from staygrubby.profiles where account_id=owner and social_state='active'); end if;
 if storage.allow_any_operation(array['object.delete','object.delete_many']) then return row.author_id=owner and(row.deleted_at is not null or not row.published); end if;
 return storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.list','object.list_v2','object.upload','object.upload_update'])
  and ((row.author_id=owner and row.deleted_at is null) or(row.photo_ready and staygrubby.social_can_view(owner,row.id)));
end $$;
revoke all on function staygrubby.social_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.social_object_allowed(text,text,text) to authenticated;
create policy social_photo_read on storage.objects for select to authenticated using(staygrubby.social_object_allowed(bucket_id,name,'read'));
create policy social_photo_create on storage.objects for insert to authenticated with check(staygrubby.social_object_allowed(bucket_id,name,'write'));
create policy social_photo_replace on storage.objects for update to authenticated using(staygrubby.social_object_allowed(bucket_id,name,'write')) with check(staygrubby.social_object_allowed(bucket_id,name,'write'));
create policy social_photo_remove on storage.objects for delete to authenticated using(staygrubby.social_object_allowed(bucket_id,name,'delete'));

create function staygrubby.retire_social_cook() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.deleted_at is not null then update staygrubby.social_posts set deleted_at=coalesce(deleted_at,now()) where author_id=new.account_id and source_attempt_id=new.id; end if;
 return new;
end $$;
revoke all on function staygrubby.retire_social_cook() from public,anon,authenticated;
create trigger retire_social_cook after update of deleted_at on staygrubby.cooking_attempts for each row execute function staygrubby.retire_social_cook();
create function staygrubby.clear_retired_social_interactions() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.deleted_at is not null then
  delete from staygrubby.social_comments where post_id=new.id;
  delete from staygrubby.social_likes where post_id=new.id;
  delete from staygrubby.social_reports where target_post_id=new.id;
 end if;
 return new;
end $$;
revoke all on function staygrubby.clear_retired_social_interactions() from public,anon,authenticated;
create trigger clear_retired_social_interactions after update of deleted_at on staygrubby.social_posts for each row execute function staygrubby.clear_retired_social_interactions();

create or replace function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;
 if exists(select 1 from storage.objects where bucket_id in ('cooking-photos','social-photos')
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
