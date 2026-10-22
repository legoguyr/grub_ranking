-- App-only Recipes/Tickets. No private cooking graph or ranking writes.
begin;
create table staygrubby.recipes (
 id uuid primary key, owner_id uuid not null references staygrubby.accounts(id) on delete cascade,
 content jsonb not null, visibility text not null default 'private' check(visibility in('private','friends')),
 revision integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index recipes_owner on staygrubby.recipes(owner_id,created_at desc,id);
create table staygrubby.recipe_tickets (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 recipe_id uuid not null references staygrubby.recipes(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(account_id,recipe_id)
);
create table staygrubby.recipe_cooks (
 id uuid primary key, account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 recipe_id uuid references staygrubby.recipes(id) on delete set null,
 item_id uuid not null, attempt_id uuid, snapshot jsonb not null, recipe_revision integer not null,
 created_at timestamptz not null default now(), completed_at timestamptz,
 unique(account_id,item_id)
);
create index recipe_cooks_recipe on staygrubby.recipe_cooks(recipe_id);
-- Permanently reserve published slugs; deleted owners leave an anonymous reservation, not a redirect.
create table staygrubby.profile_routes (
 username text primary key, account_id uuid references staygrubby.accounts(id) on delete set null
);
insert into staygrubby.profile_routes select username,account_id from staygrubby.profiles where username is not null and deleted_at is null;
alter table staygrubby.recipes enable row level security;
alter table staygrubby.recipe_tickets enable row level security;
alter table staygrubby.recipe_cooks enable row level security;
alter table staygrubby.profile_routes enable row level security;
revoke all on staygrubby.recipes,staygrubby.recipe_tickets,staygrubby.recipe_cooks,staygrubby.profile_routes from public,anon,authenticated;
create function staygrubby.reserve_profile_route() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.username is not null and (tg_op='INSERT' or new.username is distinct from old.username) then
  insert into staygrubby.profile_routes(username,account_id) values(new.username,new.account_id) on conflict do nothing;
  if not exists(select 1 from staygrubby.profile_routes where username=new.username and account_id=new.account_id) then raise exception 'Username unavailable' using errcode='23505'; end if;
 end if; return new;
end $$;
revoke all on function staygrubby.reserve_profile_route() from public,anon,authenticated;
create trigger reserve_profile_route before insert or update of username on staygrubby.profiles for each row execute function staygrubby.reserve_profile_route();

create function staygrubby.recipe_visible(viewer uuid,recipe uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.recipes r join staygrubby.accounts a on a.id=r.owner_id and a.status='active'
 where r.id=recipe and (r.owner_id=viewer or (r.visibility='friends' and staygrubby.shared_friends(viewer,r.owner_id))))
$$;
revoke all on function staygrubby.recipe_visible(uuid,uuid) from public,anon,authenticated;
create function staygrubby.recipe_card(viewer uuid,recipe uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'isOwner',r.owner_id=viewer,'creator',staygrubby.social_person(viewer,r.owner_id),'content',r.content,
 'visibility',r.visibility,'revision',r.revision,'createdAt',extract(epoch from r.created_at),'updatedAt',extract(epoch from r.updated_at),
 'saved',exists(select 1 from staygrubby.recipe_tickets t where t.account_id=viewer and t.recipe_id=r.id))
 from staygrubby.recipes r where r.id=recipe and staygrubby.recipe_visible(viewer,r.id)
$$;
revoke all on function staygrubby.recipe_card(uuid,uuid) from public,anon,authenticated;
create function staygrubby.recipe_content(value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare part jsonb; clean jsonb;
begin
 if jsonb_typeof(value) is distinct from 'object' or octet_length(value::text)>50000
 or length(btrim(coalesce(value->>'title',''))) not between 1 and 120
 or length(coalesce(value->>'description',''))>4000
 or jsonb_typeof(value->'ingredients') is distinct from 'array' or jsonb_array_length(value->'ingredients')>100
 or jsonb_typeof(value->'steps') is distinct from 'array' or jsonb_array_length(value->'steps')>100
 then raise exception 'Invalid recipe' using errcode='22023'; end if;
 for part in select x from jsonb_array_elements(value->'ingredients') x loop
  if jsonb_typeof(part) is distinct from 'string' or length(btrim(part#>>'{}')) not between 1 and 500 then raise exception 'Invalid ingredient' using errcode='22023'; end if;
 end loop;
 for part in select x from jsonb_array_elements(value->'steps') x loop
  if jsonb_typeof(part) is distinct from 'string' or length(btrim(part#>>'{}')) not between 1 and 2000 then raise exception 'Invalid step' using errcode='22023'; end if;
 end loop;
 if value->>'externalURL' is not null and (length(value->>'externalURL')>2048 or value->>'externalURL' !~ '^https://[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]+)?(/[^[:cntrl:][:space:]]*)?$') then raise exception 'Use an HTTPS source link' using errcode='22023'; end if;
 if length(coalesce(value->>'source',''))>500 or length(coalesce(value->>'course',''))>50 or length(coalesce(value->>'cuisine',''))>80 then raise exception 'Invalid attribution' using errcode='22023'; end if;
 -- Explicit allowlist: no supplied owner, creator, private notes, score, photo, or evidence.
 clean:=jsonb_strip_nulls(jsonb_build_object('title',btrim(value->>'title'),'description',value->>'description','ingredients',value->'ingredients','steps',value->'steps','course',value->>'course','cuisine',value->>'cuisine','source',value->>'source','externalURL',value->>'externalURL'));
 return clean;
end $$;
revoke all on function staygrubby.recipe_content(jsonb) from public,anon,authenticated;

create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); rid uuid:=(payload->>'recipeID')::uuid; oid uuid:=(payload->>'originID')::uuid;
 owned_recipe staygrubby.recipes%rowtype; claim staygrubby.recipe_cooks%rowtype; result jsonb; source uuid;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='save' then
  if rid is null or payload->>'visibility' not in('private','friends') then raise exception 'Invalid recipe' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||rid::text,0));
  select * into owned_recipe from staygrubby.recipes where id=rid for update;
  if owned_recipe.id is not null and owned_recipe.owner_id<>owner then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  if owned_recipe.id is not null and owned_recipe.revision is distinct from (payload->>'expectedRevision')::integer then raise exception 'Recipe changed; reload before editing' using errcode='40001'; end if;
  insert into staygrubby.recipes(id,owner_id,content,visibility) values(rid,owner,staygrubby.recipe_content(payload->'recipe'),payload->>'visibility')
  on conflict(id) do update set content=excluded.content,visibility=excluded.visibility,revision=staygrubby.recipes.revision+1,updated_at=now();
  return staygrubby.recipe_card(owner,rid);
 elsif action='delete' then
  delete from staygrubby.recipes where id=rid and owner_id=owner;
  if not found then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  return '{}'::jsonb;
 elsif action='unticket' then
  delete from staygrubby.recipe_tickets where account_id=owner and recipe_id=rid; return '{}'::jsonb;
 elsif action='tickets' then
  select coalesce(jsonb_agg(jsonb_build_object('id',t.recipe_id,'createdAt',extract(epoch from t.created_at),'recipe',staygrubby.recipe_card(owner,t.recipe_id)) order by t.created_at desc,t.recipe_id),'[]'::jsonb) into result
  from staygrubby.recipe_tickets t where t.account_id=owner;
  return jsonb_build_object('tickets',result);
 elsif action='list' then
  select coalesce(jsonb_agg(staygrubby.recipe_card(owner,r.id) order by r.created_at desc,r.id),'[]'::jsonb) into result from staygrubby.recipes r where r.owner_id=owner;
  return jsonb_build_object('recipes',result);
 elsif action='provenance' then
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'recipeID',c.recipe_id,'snapshot',c.snapshot,'revision',c.recipe_revision) order by c.created_at),'[]'::jsonb) into result
  from staygrubby.recipe_cooks c join staygrubby.cooking_attempts a on a.account_id=owner and a.id=c.attempt_id and a.deleted_at is null
  where c.account_id=owner and c.item_id=(payload->>'targetID')::uuid and c.completed_at is not null;
  return jsonb_build_object('cooks',result);
 elsif action='complete' then
  select * into claim from staygrubby.recipe_cooks where id=oid and account_id=owner for update;
  if claim.id is null then raise exception 'Recipe origin unavailable' using errcode='42501'; end if;
  select id into source from staygrubby.cooking_attempts where account_id=owner and ranked_item_id=claim.item_id and deleted_at is null;
  if source is null then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
  update staygrubby.recipe_cooks set attempt_id=source,completed_at=coalesce(completed_at,now()) where id=claim.id; return '{}'::jsonb;
 end if;
 if not staygrubby.recipe_visible(owner,rid) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
 if action='get' then return staygrubby.recipe_card(owner,rid);
 elsif action='ticket' then
  insert into staygrubby.recipe_tickets(account_id,recipe_id) values(owner,rid) on conflict do nothing; return staygrubby.recipe_card(owner,rid);
 elsif action='begin' then
  select * into owned_recipe from staygrubby.recipes where id=rid for share;
  if oid is null then raise exception 'Origin required' using errcode='22023'; end if;
  insert into staygrubby.recipe_cooks(id,account_id,recipe_id,item_id,snapshot,recipe_revision) values(oid,owner,rid,gen_random_uuid(),owned_recipe.content,owned_recipe.revision) on conflict(id) do nothing;
  select * into claim from staygrubby.recipe_cooks where id=oid and account_id=owner and recipe_id=rid;
  if claim.id is null then raise exception 'Origin unavailable' using errcode='42501'; end if;
  return jsonb_build_object('id',claim.id,'itemID',claim.item_id,'kind','recipe','completed',claim.completed_at is not null,
   'metadata',jsonb_build_object('title',claim.snapshot->>'title','course',claim.snapshot->>'course','cuisine',null), 'recipeOriginID',claim.id,'recipeSnapshot',claim.snapshot);
 else raise exception 'Unknown recipe action' using errcode='22023'; end if;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
revoke all on function api.recipes(text,jsonb) from public,anon;
grant execute on function api.recipes(text,jsonb) to authenticated;

create function staygrubby.profile_link(action text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); person jsonb; peer uuid; handle text:=payload->>'username';
begin
 if octet_length(payload::text)>4096 or action<>'resolve' or handle !~ '^[a-z0-9]+(_[a-z0-9]+)*$' or length(handle) not between 3 and 24 then raise exception 'Link unavailable' using errcode='22023'; end if;
 select r.account_id into peer from staygrubby.profile_routes r join staygrubby.profiles p on p.account_id=r.account_id where r.username=handle and p.discoverable and p.deleted_at is null;
 person:=staygrubby.social_person(owner,peer);
 if person is null then raise exception 'Link unavailable' using errcode='42501'; end if;
 return jsonb_build_object('people',jsonb_build_array(person),'isOwn',peer=owner);
end $$;
revoke all on function staygrubby.profile_link(text,jsonb) from public,anon;
grant execute on function staygrubby.profile_link(text,jsonb) to authenticated;
create function api.profile_link(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.profile_link(action,payload) $$;
revoke all on function api.profile_link(text,jsonb) from public,anon;
grant execute on function api.profile_link(text,jsonb) to authenticated;

-- Existing social provenance remains independent. Only attach a recipe already explicitly linked to this cook.
alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_recipes;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_recipes(viewer,post); recipe uuid;
begin
 if card is null then return null; end if;
 select c.recipe_id into recipe from staygrubby.recipe_cooks c join staygrubby.social_posts p on p.author_id=c.account_id and p.source_attempt_id=c.attempt_id
 where p.id=post and c.completed_at is not null and staygrubby.recipe_visible(viewer,c.recipe_id);
 return card||jsonb_build_object('recipeID',recipe);
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;
alter function staygrubby.social_cooking(text,jsonb) rename to social_cooking_before_recipes;
revoke all on function staygrubby.social_cooking_before_recipes(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); result jsonb; recipe uuid; snapshot jsonb; version integer; source_owner uuid; source_attempt uuid; claim uuid;
begin
 result:=staygrubby.social_cooking_before_recipes(action,payload);
 if action='recreate' then select author_id,source_attempt_id into source_owner,source_attempt from staygrubby.social_posts where id=(payload->>'postID')::uuid;
 elsif action='claim' then select owner_id,source_attempt_id into source_owner,source_attempt from staygrubby.shared_cooks where id=(payload->>'eventID')::uuid;
 else return result; end if;
 select c.recipe_id,c.snapshot,c.recipe_revision into recipe,snapshot,version from staygrubby.recipe_cooks c where c.account_id=source_owner and c.attempt_id=source_attempt and c.completed_at is not null;
 if recipe is not null and staygrubby.recipe_visible(owner,recipe) then
  claim:=(result->>'id')::uuid;
  insert into staygrubby.recipe_cooks(id,account_id,recipe_id,item_id,snapshot,recipe_revision) values(claim,owner,recipe,(result->>'itemID')::uuid,snapshot,version) on conflict(account_id,item_id) do nothing;
  select id into claim from staygrubby.recipe_cooks where account_id=owner and item_id=(result->>'itemID')::uuid;
  result:=result||jsonb_build_object('recipeOriginID',claim,'recipeSnapshot',snapshot);
 end if;
 return result;
end $$;
revoke all on function staygrubby.social_cooking(text,jsonb) from public,anon;
grant execute on function staygrubby.social_cooking(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
