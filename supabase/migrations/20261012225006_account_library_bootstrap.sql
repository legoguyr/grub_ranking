-- Account-only bootstrap/snapshot. No caller IDs, imports, media bytes or demo data.
begin;
create function staygrubby.open_account_library() returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
 receipt jsonb; owner uuid; ranking uuid; graph jsonb;
begin
 -- Same authenticated identity/live-session check and per-user lock as provisioning.
 receipt := staygrubby.provision_account(); owner := (receipt->>'account_id')::uuid;
 if not exists(select 1 from staygrubby.account_libraries l where l.account_id=owner) then
  if exists(select 1 from staygrubby.rankings r where r.account_id=owner)
   or exists(select 1 from staygrubby.dishes r where r.account_id=owner)
   or exists(select 1 from staygrubby.cooking_attempts r where r.account_id=owner)
   or exists(select 1 from staygrubby.ranked_items r where r.account_id=owner)
   or exists(select 1 from staygrubby.comparisons r where r.account_id=owner)
   or exists(select 1 from staygrubby.dish_sources r where r.account_id=owner)
   or exists(select 1 from staygrubby.tags r where r.account_id=owner)
   or exists(select 1 from staygrubby.media r where r.account_id=owner)
   or exists(select 1 from staygrubby.attempt_tags r where r.account_id=owner)
  then raise exception 'Account library is incomplete; initialization refused' using errcode='55000'; end if;
  ranking := gen_random_uuid();
  insert into staygrubby.rankings(account_id,id,name,created_at_ref,role)
   values(owner,ranking,'My Cooking',extract(epoch from (now()-timestamptz '2001-01-01 00:00:00+00')),'global');
  insert into staygrubby.account_libraries(account_id,library_key,global_ranking_id,bridge_version)
   values(owner,'local',ranking,1);
  update staygrubby.accounts set sync_revision=sync_revision+1 where id=owner;
 end if;
 if not exists(select 1 from staygrubby.account_libraries l join staygrubby.rankings r
    on r.account_id=l.account_id and r.id=l.global_ranking_id
    where l.account_id=owner and l.deleted_at is null and r.deleted_at is null and r.role='global')
 then raise exception 'Account library unavailable' using errcode='55000'; end if;
 receipt := staygrubby.provision_account();
 select jsonb_build_object('formatVersion',1,'accountID',owner,'deletions',coalesce((select jsonb_agg(jsonb_build_object('entity',d.entity,'key',d.key)) from (select 'ranking'::text entity,id::text key from staygrubby.rankings where account_id=owner and deleted_at is not null union all select 'dish'::text entity,id::text key from staygrubby.dishes where account_id=owner and deleted_at is not null union all select 'attempt'::text entity,id::text key from staygrubby.cooking_attempts where account_id=owner and deleted_at is not null union all select 'rankedItem'::text entity,id::text key from staygrubby.ranked_items where account_id=owner and deleted_at is not null union all select 'comparison'::text entity,id::text key from staygrubby.comparisons where account_id=owner and deleted_at is not null union all select 'source'::text entity,id::text key from staygrubby.dish_sources where account_id=owner and deleted_at is not null union all select 'tag'::text entity,tag_key::text key from staygrubby.tags where account_id=owner and deleted_at is not null union all select 'media'::text entity,id::text key from staygrubby.media where account_id=owner and deleted_at is not null) d),'[]'::jsonb),
 'libraries',coalesce((select jsonb_agg(jsonb_build_object('key',r.library_key,'globalRankingID',r.global_ranking_id,'bridgeVersion',r.bridge_version)) from staygrubby.account_libraries r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'rankings',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'createdAt',r.created_at_ref)) from staygrubby.rankings r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'dishes',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'defaultCategoryCode',r.default_course_code,'createdAt',r.created_at_ref,'sourceID',r.source_id)) from staygrubby.dishes r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'attempts',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'rankedItemID',r.ranked_item_id,'cookedAt',r.cooked_at_ref,'versionTitle',r.version_title,'notes',r.notes,'categoryCode',r.course_code,'sequenceNumber',r.sequence_number,'createdAt',r.created_at_ref,'updatedAt',r.updated_at_ref,'isLegacyImport',r.is_legacy_import,'dishID',r.dish_id,'tagKeys',coalesce((select jsonb_agg(t.tag_key order by t.tag_key) from staygrubby.attempt_tags t where t.account_id=owner and t.attempt_id=r.id and t.deleted_at is null),'[]'::jsonb))) from staygrubby.cooking_attempts r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'items',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'createdAt',r.created_at_ref,'strength',r.strength,'uncertainty',r.uncertainty,'sessionDiagnosticsData',replace(encode(r.session_diagnostics,'base64'),E'\n',''),'rankingID',r.ranking_id)) from staygrubby.ranked_items r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'comparisons',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'firstItemID',r.first_item_id,'secondItemID',r.second_item_id,'preferredItemID',r.preferred_item_id,'isTie',r.is_tie,'timestamp',r.timestamp_ref,'rankingID',r.ranking_id)) from staygrubby.comparisons r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'tags',coalesce((select jsonb_agg(jsonb_build_object('key',r.tag_key,'kindCode',r.kind_code,'value',r.value,'label',r.label)) from staygrubby.tags r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'media',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'kindCode',r.kind_code,'displayFilename',r.display_filename,'thumbnailFilename',r.thumbnail_filename,'pixelWidth',r.pixel_width,'pixelHeight',r.pixel_height,'sortOrder',r.sort_order,'createdAt',r.created_at_ref,'attemptID',r.attempt_id)) from staygrubby.media r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'sources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'typeCode',r.type_code,'createdAt',r.created_at_ref,'updatedAt',r.updated_at_ref,'dishID',r.dish_id,'cookbookTitle',r.cookbook_title,'cookbookAuthors',r.cookbook_authors,'cookbookRecipeName',r.cookbook_recipe_name,'cookbookPage',r.cookbook_page,'restaurantName',r.restaurant_name,'restaurantDishName',r.restaurant_dish_name,'restaurantLocation',r.restaurant_location,'onlineRecipeName',r.online_recipe_name,'onlineWebsite',r.online_website,'onlineURL',r.online_url,'socialCreator',r.social_creator,'socialPlatform',r.social_platform,'socialURL',r.social_url,'socialDishName',r.social_dish_name,'friendName',r.friend_name,'friendNote',r.friend_note,'otherName',r.other_name,'otherDetails',r.other_details)) from staygrubby.dish_sources r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
 'legacyItemDates',(select l.legacy_item_dates from staygrubby.account_libraries l where l.account_id=owner)) into graph;
 return jsonb_build_object('account',receipt,'graph',graph);
end $$;
revoke all on function staygrubby.open_account_library() from public,anon;
grant execute on function staygrubby.open_account_library() to authenticated;
create function api.open_account_library() returns jsonb
language sql volatile security invoker set search_path = '' as $$ select staygrubby.open_account_library() $$;
revoke all on function api.open_account_library() from public,anon;
grant execute on function api.open_account_library() to authenticated;
notify pgrst,'reload schema';
commit;
