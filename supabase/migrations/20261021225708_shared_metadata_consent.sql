-- Existing clients/posts never acquire new metadata disclosure implicitly.
begin;
drop trigger capture_shared_metadata on staygrubby.social_posts;
drop function staygrubby.capture_shared_metadata();
alter function staygrubby.social_content(text,jsonb) rename to social_content_before_shared_metadata;
revoke all on function staygrubby.social_content_before_shared_metadata(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); existed boolean; result jsonb; pid uuid;
begin
 if action='prepare' then
  select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=(payload->>'attemptID')::uuid and deleted_at is null) into existed;
 end if;
 result:=staygrubby.social_content_before_shared_metadata(action,payload);
 if action='prepare' and not existed and coalesce((payload->>'includeAttribution')::boolean,false) then
  pid:=(result->'posts'->0->>'id')::uuid;
  update staygrubby.social_posts set safe_metadata=coalesce(staygrubby.shared_cook_metadata(owner,source_attempt_id),'{}'::jsonb)
   where id=pid and author_id=owner and deleted_at is null;
 end if;
 return result;
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create or replace function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;

-- Explicit cancellation is safe even when an invitation reply was lost.
alter function staygrubby.social_cooking(text,jsonb) rename to social_cooking_before_cancel;
revoke all on function staygrubby.social_cooking_before_cancel(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); eid uuid:=(payload->>'eventID')::uuid;
begin
 if action<>'cancel' then return staygrubby.social_cooking_before_cancel(action,payload); end if;
 if eid is null or octet_length(payload::text)>4096 then raise exception 'Invalid cancellation' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:shared:'||owner::text,0));
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 if exists(select 1 from staygrubby.shared_cooks where id=eid and owner_id<>owner) then raise exception 'Owner required' using errcode='42501'; end if;
 update staygrubby.shared_participants p set state='removed',updated_at=now() from staygrubby.shared_cooks e
 where e.id=eid and e.owner_id=owner and p.event_id=e.id and p.state in('pending','joining');
 return jsonb_build_object('cancelled',true);
end $$;
revoke all on function staygrubby.social_cooking(text,jsonb) from public,anon;
grant execute on function staygrubby.social_cooking(text,jsonb) to authenticated;
create or replace function api.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_cooking(action,payload) $$;

-- The original creator may see their own identity in Recreated provenance.
create or replace function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_shared(viewer,post); p staygrubby.social_posts%rowtype;
 origin staygrubby.cooking_origins%rowtype; people jsonb; creator jsonb;
begin
 if card is null then return null; end if;
 select * into p from staygrubby.social_posts where id=post;
 select * into origin from staygrubby.cooking_origins where account_id=p.author_id and attempt_id=p.source_attempt_id and completed_at is not null;
 if origin.kind='recreated' and (viewer=origin.creator_id or staygrubby.shared_friends(viewer,origin.creator_id)) and staygrubby.social_can_view(viewer,origin.post_id) then
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
notify pgrst,'reload schema';
commit;
