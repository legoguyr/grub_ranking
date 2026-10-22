-- An intentionally authored social description, never derived from private cook notes.
begin;
alter table staygrubby.social_posts add column post_description text
 check(post_description is null or (length(post_description)<=2000
 and regexp_replace(post_description,E'[\n\r\t]','','g') !~ '[[:cntrl:]]'));

alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_description;
revoke all on function staygrubby.social_post_card_before_description(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_description(viewer,post); p staygrubby.social_posts%rowtype; source jsonb;
begin
 if card is null then return null; end if;
 select * into p from staygrubby.social_posts where id=post;
 -- Only the previously consented snapshot allowlist; no live private record lookup.
 if p.safe_metadata->'source'->>'type' in ('cookbook','restaurant','onlineRecipe','socialMedia') then
  source:=jsonb_strip_nulls(jsonb_build_object('type',p.safe_metadata->'source'->'type',
   'name',p.safe_metadata->'source'->'name','author',p.safe_metadata->'source'->'author',
   'recipe',p.safe_metadata->'source'->'recipe','page',p.safe_metadata->'source'->'page'));
 end if;
 return card||jsonb_build_object('postDescription',p.post_description,'metadata',jsonb_strip_nulls(jsonb_build_object(
  'course',p.safe_metadata->'course','cuisine',p.safe_metadata->'cuisine','source',source)));
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.social_content(text,jsonb) rename to social_content_before_description;
revoke all on function staygrubby.social_content_before_description(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); description text; existed boolean; result jsonb; pid uuid;
begin
 if action not in ('prepare','editDescription') then return staygrubby.social_content_before_description(action,payload); end if;
 if octet_length(payload::text)>20480 or (payload ? 'postDescription' and jsonb_typeof(payload->'postDescription') not in ('string','null'))
 then raise exception 'Invalid post description' using errcode='22023'; end if;
 description:=nullif(btrim(payload->>'postDescription',E' \t\n\r'),'');
 if length(description)>2000 or regexp_replace(description,E'[\n\r\t]','','g') ~ '[[:cntrl:]]'
 then raise exception 'Invalid post description' using errcode='22023'; end if;
 if action='editDescription' then
  pid:=(payload->>'postID')::uuid;
  if pid is null or not payload ? 'postDescription' then raise exception 'Description required' using errcode='22023'; end if;
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  perform staygrubby.social_actor();
  update staygrubby.social_posts set post_description=description
   where id=pid and author_id=owner and deleted_at is null and published and moderation_state='active';
  if not found then raise exception 'Post unavailable' using errcode='42501'; end if;
 else
  -- Serialize new preparations for a cook; retries must not edit an existing snapshot.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post-source:'||owner::text||':'||coalesce(payload->>'attemptID',''),0));
  select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=(payload->>'attemptID')::uuid and deleted_at is null) into existed;
  result:=staygrubby.social_content_before_description(action,payload-'postDescription');
  pid:=(result->'posts'->0->>'id')::uuid;
  if not existed then
   update staygrubby.social_posts set post_description=description where id=pid and author_id=owner and deleted_at is null;
  end if;
 end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create or replace function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;

alter function staygrubby.social_feed(text,jsonb) rename to social_feed_before_profile;
revoke all on function staygrubby.social_feed_before_profile(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare viewer uuid:=staygrubby.social_actor(); profile uuid:=coalesce((payload->>'peerID')::uuid,viewer); result jsonb;
begin
 if action<>'profile' then return staygrubby.social_feed_before_profile(action,payload); end if;
 if octet_length(payload::text)>1024 or ((payload->>'beforeTime' is null)<>(payload->>'beforeID' is null))
 then raise exception 'Invalid cursor' using errcode='22023'; end if;
 select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
  select staygrubby.social_post_card(viewer,p.id) card,p.created_at,p.id from staygrubby.social_posts p
  where p.author_id=profile and p.published and p.deleted_at is null and p.moderation_state='active'
   and staygrubby.social_can_view(viewer,p.id)
   and (payload->>'beforeTime' is null or (p.created_at,p.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
  order by p.created_at desc,p.id desc limit 25) rows;
 return jsonb_build_object('posts',result);
end $$;
revoke all on function staygrubby.social_feed(text,jsonb) from public,anon;
grant execute on function staygrubby.social_feed(text,jsonb) to authenticated;
create or replace function api.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_feed(action,payload) $$;
notify pgrst,'reload schema';
commit;
