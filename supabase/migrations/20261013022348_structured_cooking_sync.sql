-- Atomic structured changes only. No images, imports, caller-controlled ownership or direct-write grants.
begin;
create function staygrubby.apply_cooking_operation(envelope jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
 owner uuid; revision bigint; operation uuid; installation uuid; predecessor uuid; expected bigint;
 payload_bytes bytea; changes jsonb; row jsonb; data jsonb; entity text; identity text; target text;
 existing staygrubby.sync_operations%rowtype; prior staygrubby.sync_operations%rowtype; result jsonb; known boolean;
begin
 owner := (staygrubby.provision_account()->>'account_id')::uuid;
 select sync_revision into revision from staygrubby.accounts where id=owner for update;
 perform staygrubby.provision_account(); -- Recheck live session after the account lock wait.
 if (envelope->>'accountID')::uuid is distinct from owner then
  raise exception 'Account mismatch' using errcode='42501'; end if;
 if not exists(select 1 from staygrubby.account_libraries where account_id=owner and deleted_at is null)
 then raise exception 'Restore required' using errcode='55000'; end if;
 operation := (envelope->>'operationID')::uuid; installation := (envelope->>'storeID')::uuid;
 expected := (envelope->>'expectedRevision')::bigint; predecessor := (envelope->>'predecessorID')::uuid;
 if operation is null or installation is null or expected is null or expected<0 or coalesce(envelope->>'kind','')=''
 then raise exception 'Invalid operation' using errcode='22023'; end if;
 payload_bytes := decode(envelope->>'payload','base64');
 if payload_bytes is null or octet_length(payload_bytes)>8388608
  or encode(sha256(payload_bytes),'hex') is distinct from envelope->>'payloadHash'
 then raise exception 'Invalid payload hash or size' using errcode='22023'; end if;
 select * into existing from staygrubby.sync_operations where account_id=owner and operation_id=operation;
 if found then
  if (existing.store_id,existing.kind,existing.payload_hash,existing.expected_revision,existing.predecessor_id)
   is distinct from (installation,envelope->>'kind',envelope->>'payloadHash',expected,predecessor)
  then raise exception 'Operation identity reused' using errcode='23505'; end if;
  return existing.receipt;
 end if;
 if predecessor is not null then
  select * into prior from staygrubby.sync_operations where account_id=owner and operation_id=predecessor and store_id=installation;
  if not found then raise exception 'Invalid predecessor' using errcode='22023'; end if;
 end if;
 if expected<>revision and not (predecessor is not null and prior.accepted_revision=revision
   and expected between prior.expected_revision and prior.accepted_revision)
 then raise exception 'Revision conflict' using errcode='40001'; end if;
 changes := convert_from(payload_bytes,'UTF8')::jsonb;
 if jsonb_typeof(changes->'upserts') is distinct from 'array' or jsonb_typeof(changes->'deletions') is distinct from 'array'
  or jsonb_array_length(changes->'upserts')+jsonb_array_length(changes->'deletions')>20000
  or jsonb_array_length(changes->'upserts')+jsonb_array_length(changes->'deletions')=0
 then raise exception 'Invalid change set' using errcode='22023'; end if;
 if exists(select 1 from jsonb_array_elements(changes->'upserts') r group by r->'reference' having count(*)>1)
  or exists(select 1 from jsonb_array_elements(changes->'deletions') r group by r having count(*)>1)
 then raise exception 'Duplicate reference' using errcode='22023'; end if;
 -- Deletions first: free active Source/version uniqueness, never physically remove identities.
 for row in select value from jsonb_array_elements(changes->'deletions') loop
  entity := row->>'entity'; identity := row->>'key';
  target := case entity when 'dish' then 'dishes' when 'source' then 'dish_sources'
   when 'attempt' then 'cooking_attempts' when 'rankedItem' then 'ranked_items'
   when 'comparison' then 'comparisons' when 'media' then 'media' when 'tag' then 'tags' end;
  if target is null then raise exception 'Infrastructure deletion forbidden' using errcode='22023'; end if;
  if entity='tag' then
   update staygrubby.tags set deleted_at=clock_timestamp() where account_id=owner and tag_key=identity and deleted_at is null;
   if not found and not exists(select 1 from staygrubby.tags where account_id=owner and tag_key=identity)
   then raise exception 'Unknown deletion' using errcode='22023'; end if;
   update staygrubby.attempt_tags set deleted_at=clock_timestamp() where account_id=owner and tag_key=identity and deleted_at is null;
  else
   execute format('update staygrubby.%I set deleted_at=clock_timestamp() where account_id=$1 and id=$2 and deleted_at is null',target) using owner,identity::uuid;
   execute format('select exists(select 1 from staygrubby.%I where account_id=$1 and id=$2)',target) into known using owner,identity::uuid;
   if not known then raise exception 'Unknown deletion' using errcode='22023'; end if;
   if entity='attempt' then
    update staygrubby.attempt_tags set deleted_at=clock_timestamp() where account_id=owner and attempt_id=identity::uuid and deleted_at is null;
   end if;
  end if;
 end loop;
 for row in select value from jsonb_array_elements(changes->'upserts') loop
  entity := row->'reference'->>'entity'; identity := row->'reference'->>'key';
  data := convert_from(decode(row->>'data','base64'),'UTF8')::jsonb;
  if identity is null or (entity<>'legacyArchive' and jsonb_typeof(data) is distinct from 'object')
  then raise exception 'Invalid record' using errcode='22023'; end if;
  case entity
  when 'ranking' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.rankings where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.rankings as current(account_id,id,name,created_at_ref,role)
    values(owner,(data->>'id')::uuid,(data->>'name')::text,(data->>'createdAt')::double precision,'historical')
    on conflict(account_id,id) do update set name=excluded.name,created_at_ref=excluded.created_at_ref
    where (current.name,current.created_at_ref) is distinct from (excluded.name,excluded.created_at_ref);
  when 'dish' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.dishes where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.dishes as current(account_id,id,name,default_course_code,created_at_ref,source_id)
    values(owner,(data->>'id')::uuid,(data->>'name')::text,(data->>'defaultCategoryCode')::text,(data->>'createdAt')::double precision,(data->>'sourceID')::uuid)
    on conflict(account_id,id) do update set name=excluded.name,default_course_code=excluded.default_course_code,created_at_ref=excluded.created_at_ref,source_id=excluded.source_id
    where (current.name,current.default_course_code,current.created_at_ref,current.source_id) is distinct from (excluded.name,excluded.default_course_code,excluded.created_at_ref,excluded.source_id);
  when 'source' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.dish_sources where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.dish_sources as current(account_id,id,type_code,created_at_ref,updated_at_ref,dish_id,cookbook_title,cookbook_authors,cookbook_recipe_name,cookbook_page,restaurant_name,restaurant_dish_name,restaurant_location,online_recipe_name,online_website,online_url,social_creator,social_platform,social_url,social_dish_name,friend_name,friend_note,other_name,other_details)
    values(owner,(data->>'id')::uuid,(data->>'typeCode')::text,(data->>'createdAt')::double precision,(data->>'updatedAt')::double precision,(data->>'dishID')::uuid,(data->>'cookbookTitle')::text,(data->>'cookbookAuthors')::text,(data->>'cookbookRecipeName')::text,(data->>'cookbookPage')::text,(data->>'restaurantName')::text,(data->>'restaurantDishName')::text,(data->>'restaurantLocation')::text,(data->>'onlineRecipeName')::text,(data->>'onlineWebsite')::text,(data->>'onlineURL')::text,(data->>'socialCreator')::text,(data->>'socialPlatform')::text,(data->>'socialURL')::text,(data->>'socialDishName')::text,(data->>'friendName')::text,(data->>'friendNote')::text,(data->>'otherName')::text,(data->>'otherDetails')::text)
    on conflict(account_id,id) do update set type_code=excluded.type_code,created_at_ref=excluded.created_at_ref,updated_at_ref=excluded.updated_at_ref,dish_id=excluded.dish_id,cookbook_title=excluded.cookbook_title,cookbook_authors=excluded.cookbook_authors,cookbook_recipe_name=excluded.cookbook_recipe_name,cookbook_page=excluded.cookbook_page,restaurant_name=excluded.restaurant_name,restaurant_dish_name=excluded.restaurant_dish_name,restaurant_location=excluded.restaurant_location,online_recipe_name=excluded.online_recipe_name,online_website=excluded.online_website,online_url=excluded.online_url,social_creator=excluded.social_creator,social_platform=excluded.social_platform,social_url=excluded.social_url,social_dish_name=excluded.social_dish_name,friend_name=excluded.friend_name,friend_note=excluded.friend_note,other_name=excluded.other_name,other_details=excluded.other_details
    where (current.type_code,current.created_at_ref,current.updated_at_ref,current.dish_id,current.cookbook_title,current.cookbook_authors,current.cookbook_recipe_name,current.cookbook_page,current.restaurant_name,current.restaurant_dish_name,current.restaurant_location,current.online_recipe_name,current.online_website,current.online_url,current.social_creator,current.social_platform,current.social_url,current.social_dish_name,current.friend_name,current.friend_note,current.other_name,current.other_details) is distinct from (excluded.type_code,excluded.created_at_ref,excluded.updated_at_ref,excluded.dish_id,excluded.cookbook_title,excluded.cookbook_authors,excluded.cookbook_recipe_name,excluded.cookbook_page,excluded.restaurant_name,excluded.restaurant_dish_name,excluded.restaurant_location,excluded.online_recipe_name,excluded.online_website,excluded.online_url,excluded.social_creator,excluded.social_platform,excluded.social_url,excluded.social_dish_name,excluded.friend_name,excluded.friend_note,excluded.other_name,excluded.other_details);
  when 'rankedItem' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.ranked_items where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.ranked_items as current(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty,session_diagnostics)
    values(owner,(data->>'id')::uuid,(data->>'rankingID')::uuid,(data->>'name')::text,(data->>'createdAt')::double precision,(data->>'strength')::double precision,(data->>'uncertainty')::double precision,decode(data->>'sessionDiagnosticsData','base64'))
    on conflict(account_id,id) do update set ranking_id=excluded.ranking_id,name=excluded.name,created_at_ref=excluded.created_at_ref,strength=excluded.strength,uncertainty=excluded.uncertainty,session_diagnostics=excluded.session_diagnostics
    where (current.ranking_id,current.name,current.created_at_ref,current.strength,current.uncertainty,current.session_diagnostics) is distinct from (excluded.ranking_id,excluded.name,excluded.created_at_ref,excluded.strength,excluded.uncertainty,excluded.session_diagnostics);
  when 'attempt' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.cooking_attempts where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.cooking_attempts as current(account_id,id,dish_id,ranked_item_id,cooked_at_ref,version_title,notes,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import)
    values(owner,(data->>'id')::uuid,(data->>'dishID')::uuid,(data->>'rankedItemID')::uuid,(data->>'cookedAt')::double precision,(data->>'versionTitle')::text,(data->>'notes')::text,(data->>'categoryCode')::text,(data->>'sequenceNumber')::integer,(data->>'createdAt')::double precision,(data->>'updatedAt')::double precision,(data->>'isLegacyImport')::boolean)
    on conflict(account_id,id) do update set dish_id=excluded.dish_id,ranked_item_id=excluded.ranked_item_id,cooked_at_ref=excluded.cooked_at_ref,version_title=excluded.version_title,notes=excluded.notes,course_code=excluded.course_code,sequence_number=excluded.sequence_number,created_at_ref=excluded.created_at_ref,updated_at_ref=excluded.updated_at_ref,is_legacy_import=excluded.is_legacy_import
    where (current.dish_id,current.ranked_item_id,current.cooked_at_ref,current.version_title,current.notes,current.course_code,current.sequence_number,current.created_at_ref,current.updated_at_ref,current.is_legacy_import) is distinct from (excluded.dish_id,excluded.ranked_item_id,excluded.cooked_at_ref,excluded.version_title,excluded.notes,excluded.course_code,excluded.sequence_number,excluded.created_at_ref,excluded.updated_at_ref,excluded.is_legacy_import);
   if jsonb_typeof(data->'tagKeys') is distinct from 'array' then raise exception 'Invalid memberships' using errcode='22023'; end if;
   update staygrubby.attempt_tags set deleted_at=clock_timestamp() where account_id=owner and attempt_id=identity::uuid
    and deleted_at is null and not (data->'tagKeys' ? tag_key);
   insert into staygrubby.attempt_tags as current(account_id,attempt_id,tag_key)
    select owner,identity::uuid,value from jsonb_array_elements_text(data->'tagKeys')
    on conflict(account_id,attempt_id,tag_key) do update set deleted_at=null where current.deleted_at is not null;
  when 'comparison' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.comparisons where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.comparisons as current(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref)
    values(owner,(data->>'id')::uuid,(data->>'rankingID')::uuid,(data->>'firstItemID')::uuid,(data->>'secondItemID')::uuid,(data->>'preferredItemID')::uuid,(data->>'isTie')::boolean,(data->>'timestamp')::double precision)
    on conflict(account_id,id) do update set ranking_id=excluded.ranking_id,first_item_id=excluded.first_item_id,second_item_id=excluded.second_item_id,preferred_item_id=excluded.preferred_item_id,is_tie=excluded.is_tie,timestamp_ref=excluded.timestamp_ref
    where (current.ranking_id,current.first_item_id,current.second_item_id,current.preferred_item_id,current.is_tie,current.timestamp_ref) is distinct from (excluded.ranking_id,excluded.first_item_id,excluded.second_item_id,excluded.preferred_item_id,excluded.is_tie,excluded.timestamp_ref);
  when 'media' then
   if (data->>'id')::uuid is distinct from identity::uuid then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.media where account_id=owner and id=identity::uuid and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.media as current(account_id,id,attempt_id,kind_code,display_filename,thumbnail_filename,pixel_width,pixel_height,sort_order,created_at_ref)
    values(owner,(data->>'id')::uuid,(data->>'attemptID')::uuid,(data->>'kindCode')::text,(data->>'displayFilename')::text,(data->>'thumbnailFilename')::text,(data->>'pixelWidth')::integer,(data->>'pixelHeight')::integer,(data->>'sortOrder')::integer,(data->>'createdAt')::double precision)
    on conflict(account_id,id) do update set attempt_id=excluded.attempt_id,kind_code=excluded.kind_code,display_filename=excluded.display_filename,thumbnail_filename=excluded.thumbnail_filename,pixel_width=excluded.pixel_width,pixel_height=excluded.pixel_height,sort_order=excluded.sort_order,created_at_ref=excluded.created_at_ref
    where (current.attempt_id,current.kind_code,current.display_filename,current.thumbnail_filename,current.pixel_width,current.pixel_height,current.sort_order,current.created_at_ref) is distinct from (excluded.attempt_id,excluded.kind_code,excluded.display_filename,excluded.thumbnail_filename,excluded.pixel_width,excluded.pixel_height,excluded.sort_order,excluded.created_at_ref);
  when 'tag' then
   if data->>'key' is distinct from identity then raise exception 'Identity mismatch' using errcode='22023'; end if;
   if exists(select 1 from staygrubby.tags where account_id=owner and tag_key=identity and deleted_at is not null)
   then raise exception 'Deleted identity' using errcode='55000'; end if;
   insert into staygrubby.tags as current(account_id,tag_key,kind_code,value,label)
    values(owner,identity,data->>'kindCode',data->>'value',data->>'label')
    on conflict(account_id,tag_key) do update set kind_code=excluded.kind_code,value=excluded.value,label=excluded.label
    where (current.kind_code,current.value,current.label) is distinct from (excluded.kind_code,excluded.value,excluded.label);
  when 'library' then
   if identity<>'local' or data->>'key' is distinct from 'local' or (data->>'bridgeVersion')::integer is distinct from 1
    or not exists(select 1 from staygrubby.account_libraries where account_id=owner and deleted_at is null
     and global_ranking_id=(data->>'globalRankingID')::uuid)
   then raise exception 'Library identity immutable' using errcode='55000'; end if;
  when 'legacyArchive' then
   if identity<>'items' or jsonb_typeof(data) is distinct from 'array'
    or exists(select 1 from jsonb_array_elements(data) v where jsonb_typeof(v)<>'number')
   then raise exception 'Invalid legacy archive' using errcode='22023'; end if;
   update staygrubby.account_libraries set legacy_item_dates=data where account_id=owner and legacy_item_dates is distinct from data;
  else raise exception 'Unknown entity' using errcode='22023';
  end case;
 end loop;
 -- A complete live graph may not reference any absent or tombstoned parent.
 if not exists(select 1 from staygrubby.account_libraries l join staygrubby.rankings r
    on r.account_id=l.account_id and r.id=l.global_ranking_id and r.role='global' and r.deleted_at is null
    where l.account_id=owner and l.deleted_at is null)
 then raise exception 'Invalid global library' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.dishes r where r.account_id=owner and r.deleted_at is null and (r.source_id is not null and not exists(select 1 from staygrubby.dish_sources p where p.account_id=owner and p.id=r.source_id and p.dish_id=r.id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.dish_sources r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.dishes p where p.account_id=owner and p.id=r.dish_id and p.source_id=r.id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.ranked_items r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.rankings p where p.account_id=owner and p.id=r.ranking_id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.cooking_attempts r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.dishes p where p.account_id=owner and p.id=r.dish_id and p.deleted_at is null) or not exists(select 1 from staygrubby.ranked_items p where p.account_id=owner and p.id=r.ranked_item_id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.comparisons r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.ranked_items p where p.account_id=owner and p.id=r.first_item_id and p.ranking_id=r.ranking_id and p.deleted_at is null) or not exists(select 1 from staygrubby.ranked_items p where p.account_id=owner and p.id=r.second_item_id and p.ranking_id=r.ranking_id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.media r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.cooking_attempts p where p.account_id=owner and p.id=r.attempt_id and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.attempt_tags r where r.account_id=owner and r.deleted_at is null and (not exists(select 1 from staygrubby.cooking_attempts p where p.account_id=owner and p.id=r.attempt_id and p.deleted_at is null) or not exists(select 1 from staygrubby.tags p where p.account_id=owner and p.tag_key=r.tag_key and p.deleted_at is null)))
 then raise exception 'Invalid active relationships' using errcode='55000'; end if;
 if exists(select 1 from staygrubby.ranked_items r join staygrubby.account_libraries l on l.account_id=r.account_id and l.global_ranking_id=r.ranking_id
 where r.account_id=owner and r.deleted_at is null and not exists(select 1 from staygrubby.cooking_attempts a where a.account_id=owner and a.ranked_item_id=r.id and a.deleted_at is null))
 then raise exception 'Orphan cooking item' using errcode='55000'; end if;
 update staygrubby.accounts set sync_revision=sync_revision+1 where id=owner returning sync_revision into revision;
 result := jsonb_build_object('operationID',operation,'storeID',installation,'accountID',owner,'payloadHash',envelope->>'payloadHash','revision',revision);
 insert into staygrubby.sync_operations(account_id,operation_id,store_id,kind,payload_hash,expected_revision,predecessor_id,accepted_revision,receipt)
  values(owner,operation,installation,envelope->>'kind',envelope->>'payloadHash',expected,predecessor,revision,result);
 return result;
end $$;
revoke all on function staygrubby.apply_cooking_operation(jsonb) from public,anon;
grant execute on function staygrubby.apply_cooking_operation(jsonb) to authenticated;
create function api.apply_cooking_operation(envelope jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.apply_cooking_operation(envelope) $$;
revoke all on function api.apply_cooking_operation(jsonb) from public,anon;
grant execute on function api.apply_cooking_operation(jsonb) to authenticated;

-- Serialize complete snapshot/initialization with account applies.
create or replace function staygrubby.open_account_library() returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
 receipt jsonb; owner uuid; ranking uuid; graph jsonb;
begin
 -- Same authenticated identity/live-session check and per-user lock as provisioning.
 receipt := staygrubby.provision_account(); owner := (receipt->>'account_id')::uuid;
 perform 1 from staygrubby.accounts where id=owner for update;
 perform staygrubby.provision_account(); -- Recheck session after snapshot/apply serialization.
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
notify pgrst,'reload schema';
commit;
