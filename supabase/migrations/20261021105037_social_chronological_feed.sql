begin;
create index social_feed_order on staygrubby.social_posts(created_at desc,id desc) where published and deleted_at is null and moderation_state='active';
create function staygrubby.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare viewer uuid:=staygrubby.social_actor(); result jsonb;
begin
 if octet_length(payload::text)>1024 or ((payload->>'beforeTime' is null)<>(payload->>'beforeID' is null)) then raise exception 'Invalid cursor' using errcode='22023'; end if;
 if action='post' then
  if not staygrubby.social_can_view(viewer,(payload->>'postID')::uuid) then raise exception 'Post unavailable' using errcode='42501'; end if;
  return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(viewer,(payload->>'postID')::uuid)));
 end if;
 if action<>'page' then raise exception 'Unknown feed action' using errcode='22023'; end if;
 select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
  select staygrubby.social_post_card(viewer,p.id) card,p.created_at,p.id from staygrubby.social_posts p
  where p.published and p.deleted_at is null and p.moderation_state='active' and staygrubby.social_can_view(viewer,p.id)
   and (payload->>'beforeTime' is null or(p.created_at,p.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
  order by p.created_at desc,p.id desc limit 25) rows;
 return jsonb_build_object('posts',result);
end $$;
revoke all on function staygrubby.social_feed(text,jsonb) from public,anon;
grant execute on function staygrubby.social_feed(text,jsonb) to authenticated;
create function api.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_feed(action,payload) $$;
revoke all on function api.social_feed(text,jsonb) from public,anon;
grant execute on function api.social_feed(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
