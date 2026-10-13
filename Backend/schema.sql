-- Private foundation reference, mirrored by the initial Supabase migration.
-- Apply new changes through supabase/migrations; never reapply this first-install file.
-- No credentials, Auth provider configuration, Storage buckets, or social tables.
begin;
create schema staygrubby;
revoke all on schema staygrubby from public;
grant usage on schema staygrubby to authenticated;

create table staygrubby.accounts (
 id uuid primary key default gen_random_uuid(),
 status text not null default 'active' check (status in ('active','deleting')),
 sync_revision bigint not null default 0 check (sync_revision >= 0),
 created_at timestamptz not null default now()
);
create table staygrubby.auth_account_links (
 auth_user_id uuid primary key references auth.users(id) on delete cascade,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 created_at timestamptz not null default now()
);
create index auth_account_links_account on staygrubby.auth_account_links(account_id);

-- Private lookup: no supplied account ID, no editable user_metadata claims.
create function staygrubby.current_account_id() returns uuid
language sql stable security definer set search_path = '' as $$
 select l.account_id from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id
 where l.auth_user_id=auth.uid() and a.status='active'
$$;
revoke all on function staygrubby.current_account_id() from public;
grant execute on function staygrubby.current_account_id() to authenticated;

create function staygrubby.stamp_record() returns trigger
language plpgsql set search_path = '' as $$
begin
 if TG_OP='UPDATE' then
  if new.account_id is distinct from old.account_id then raise exception 'Ownership is immutable'; end if;
  if (to_jsonb(new)->'id',to_jsonb(new)->'tag_key',to_jsonb(new)->'library_key',to_jsonb(new)->'operation_id',to_jsonb(new)->'import_id')
   is distinct from (to_jsonb(old)->'id',to_jsonb(old)->'tag_key',to_jsonb(old)->'library_key',to_jsonb(old)->'operation_id',to_jsonb(old)->'import_id')
  then raise exception 'Identity is immutable'; end if;
  new.row_version=old.row_version+1;
 else
  new.row_version=1;
 end if;
 new.server_updated_at=clock_timestamp();
 return new;
end $$;
revoke all on function staygrubby.stamp_record() from public;

create table staygrubby.profiles (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 display_name text not null default '',
 username text,
 primary key(account_id)
);

create table staygrubby.rankings (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 name text not null,
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 role text not null check(role in ('global','historical')),
 engine_version integer,
 cache_graph_hash text,
 primary key(account_id,id)
);

create table staygrubby.account_libraries (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 library_key text not null check(library_key='local'),
 global_ranking_id uuid not null,
 bridge_version integer not null,
 legacy_item_dates jsonb not null default '[]',
 primary key(account_id),
 foreign key(account_id,global_ranking_id) references staygrubby.rankings(account_id,id) deferrable initially deferred
);

create table staygrubby.dishes (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 name text not null,
 default_course_code text not null,
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 source_id uuid,
 primary key(account_id,id)
);

create table staygrubby.dish_sources (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 dish_id uuid not null,
 type_code text not null check(type_code in ('original','cookbook','restaurant','onlineRecipe','socialMedia','friendFamily','other')),
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 updated_at_ref double precision not null check(updated_at_ref > '-Infinity'::double precision and updated_at_ref < 'Infinity'::double precision),
 cookbook_title text,
 cookbook_authors text,
 cookbook_recipe_name text,
 cookbook_page text,
 restaurant_name text,
 restaurant_dish_name text,
 restaurant_location text,
 online_recipe_name text,
 online_website text,
 online_url text,
 social_creator text,
 social_platform text,
 social_url text,
 social_dish_name text,
 friend_name text,
 friend_note text,
 other_name text,
 other_details text,
 primary key(account_id,id),
 unique(account_id,dish_id,id),
 foreign key(account_id,dish_id) references staygrubby.dishes(account_id,id) deferrable initially deferred
);

create table staygrubby.ranked_items (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 ranking_id uuid not null,
 name text not null,
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 strength double precision not null check(strength > '-Infinity'::double precision and strength < 'Infinity'::double precision),
 uncertainty double precision not null check(uncertainty>=0 and uncertainty<'Infinity'::double precision),
 session_diagnostics bytea,
 primary key(account_id,id),
 unique(account_id,ranking_id,id),
 foreign key(account_id,ranking_id) references staygrubby.rankings(account_id,id) deferrable initially deferred
);

create table staygrubby.cooking_attempts (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 dish_id uuid not null,
 ranked_item_id uuid not null,
 cooked_at_ref double precision check(cooked_at_ref > '-Infinity'::double precision and cooked_at_ref < 'Infinity'::double precision),
 version_title text,
 notes text,
 course_code text not null,
 sequence_number integer not null check(sequence_number>0),
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 updated_at_ref double precision not null check(updated_at_ref > '-Infinity'::double precision and updated_at_ref < 'Infinity'::double precision),
 is_legacy_import boolean not null,
 primary key(account_id,id),
 unique(account_id,ranked_item_id),
 foreign key(account_id,dish_id) references staygrubby.dishes(account_id,id) deferrable initially deferred,
 foreign key(account_id,ranked_item_id) references staygrubby.ranked_items(account_id,id) deferrable initially deferred
);

create table staygrubby.comparisons (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 ranking_id uuid not null,
 first_item_id uuid not null,
 second_item_id uuid not null,
 preferred_item_id uuid,
 is_tie boolean not null,
 timestamp_ref double precision not null check(timestamp_ref > '-Infinity'::double precision and timestamp_ref < 'Infinity'::double precision),
 primary key(account_id,id),
 check(first_item_id<>second_item_id),
 check((is_tie and preferred_item_id is null) or (not is_tie and preferred_item_id is not null and preferred_item_id in (first_item_id,second_item_id))),
 foreign key(account_id,ranking_id) references staygrubby.rankings(account_id,id) deferrable initially deferred,
 foreign key(account_id,ranking_id,first_item_id) references staygrubby.ranked_items(account_id,ranking_id,id) deferrable initially deferred,
 foreign key(account_id,ranking_id,second_item_id) references staygrubby.ranked_items(account_id,ranking_id,id) deferrable initially deferred
);

create table staygrubby.tags (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 tag_key text not null,
 kind_code text not null check(kind_code in ('dietary','allergy','contains','custom')),
 value text not null,
 label text not null,
 primary key(account_id,tag_key),
 check(tag_key=kind_code || ':' || value)
);

create table staygrubby.attempt_tags (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 attempt_id uuid not null,
 tag_key text not null,
 primary key(account_id,attempt_id,tag_key),
 foreign key(account_id,attempt_id) references staygrubby.cooking_attempts(account_id,id) deferrable initially deferred,
 foreign key(account_id,tag_key) references staygrubby.tags(account_id,tag_key) deferrable initially deferred
);

create table staygrubby.media (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 id uuid not null,
 attempt_id uuid not null,
 kind_code text not null check(kind_code='image'),
 display_filename text not null,
 thumbnail_filename text not null,
 pixel_width integer not null check(pixel_width>0),
 pixel_height integer not null check(pixel_height>0),
 sort_order integer not null,
 created_at_ref double precision not null check(created_at_ref > '-Infinity'::double precision and created_at_ref < 'Infinity'::double precision),
 display_object_key text,
 thumbnail_object_key text,
 transfer_state text not null default 'pending' check(transfer_state in ('pending','ready','deleted')),
 primary key(account_id,id),
 foreign key(account_id,attempt_id) references staygrubby.cooking_attempts(account_id,id) deferrable initially deferred,
 check(display_filename<>'' and display_filename not in ('.','..') and position('/' in display_filename)=0 and position(chr(92) in display_filename)=0),
 check(thumbnail_filename<>'' and thumbnail_filename not in ('.','..') and position('/' in thumbnail_filename)=0 and position(chr(92) in thumbnail_filename)=0)
);

create table staygrubby.sync_operations (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 operation_id uuid not null,
 store_id uuid not null,
 kind text not null,
 payload_hash text not null,
 expected_revision bigint not null,
 predecessor_id uuid,
 accepted_revision bigint not null check(accepted_revision>=0),
 receipt jsonb not null,
 primary key(account_id,operation_id),
 foreign key(account_id,predecessor_id) references staygrubby.sync_operations(account_id,operation_id) deferrable initially deferred
);

create table staygrubby.sync_imports (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 row_version bigint not null default 1 check (row_version > 0),
 server_created_at timestamptz not null default now(),
 server_updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 import_id uuid not null,
 manifest_hash text not null,
 state text not null check(state in ('staging','metadataReady','complete','failed')),
 inventory jsonb not null,
 progress jsonb not null default '{}',
 primary key(account_id,import_id)
);

create unique index one_active_global_ranking on staygrubby.rankings(account_id) where role='global' and deleted_at is null;
create unique index one_active_source_per_dish on staygrubby.dish_sources(account_id,dish_id) where deleted_at is null;
create unique index one_active_version_number on staygrubby.cooking_attempts(account_id,dish_id,sequence_number) where deleted_at is null;
create unique index profile_username_unique on staygrubby.profiles(lower(username)) where username is not null;
-- Username reservation/history policy deliberately deferred. No rename/recycling function.
alter table staygrubby.dishes add foreign key(account_id,id,source_id)
 references staygrubby.dish_sources(account_id,dish_id,id) deferrable initially deferred;

alter table staygrubby.profiles enable row level security;
create policy owner_read on staygrubby.profiles for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.profiles to authenticated;
create trigger server_stamp before insert or update on staygrubby.profiles
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.rankings enable row level security;
create policy owner_read on staygrubby.rankings for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.rankings to authenticated;
create trigger server_stamp before insert or update on staygrubby.rankings
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.account_libraries enable row level security;
create policy owner_read on staygrubby.account_libraries for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.account_libraries to authenticated;
create trigger server_stamp before insert or update on staygrubby.account_libraries
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.dishes enable row level security;
create policy owner_read on staygrubby.dishes for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.dishes to authenticated;
create trigger server_stamp before insert or update on staygrubby.dishes
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.dish_sources enable row level security;
create policy owner_read on staygrubby.dish_sources for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.dish_sources to authenticated;
create trigger server_stamp before insert or update on staygrubby.dish_sources
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.ranked_items enable row level security;
create policy owner_read on staygrubby.ranked_items for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.ranked_items to authenticated;
create trigger server_stamp before insert or update on staygrubby.ranked_items
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.cooking_attempts enable row level security;
create policy owner_read on staygrubby.cooking_attempts for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.cooking_attempts to authenticated;
create trigger server_stamp before insert or update on staygrubby.cooking_attempts
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.comparisons enable row level security;
create policy owner_read on staygrubby.comparisons for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.comparisons to authenticated;
create trigger server_stamp before insert or update on staygrubby.comparisons
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.tags enable row level security;
create policy owner_read on staygrubby.tags for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.tags to authenticated;
create trigger server_stamp before insert or update on staygrubby.tags
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.attempt_tags enable row level security;
create policy owner_read on staygrubby.attempt_tags for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.attempt_tags to authenticated;
create trigger server_stamp before insert or update on staygrubby.attempt_tags
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.media enable row level security;
create policy owner_read on staygrubby.media for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.media to authenticated;
create trigger server_stamp before insert or update on staygrubby.media
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.sync_operations enable row level security;
create policy owner_read on staygrubby.sync_operations for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.sync_operations to authenticated;
create trigger server_stamp before insert or update on staygrubby.sync_operations
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.sync_imports enable row level security;
create policy owner_read on staygrubby.sync_imports for select to authenticated
 using (account_id=(select staygrubby.current_account_id()));
grant select on staygrubby.sync_imports to authenticated;
create trigger server_stamp before insert or update on staygrubby.sync_imports
 for each row execute function staygrubby.stamp_record();

alter table staygrubby.accounts enable row level security;
create policy owner_read on staygrubby.accounts for select to authenticated using(id=(select staygrubby.current_account_id()));
grant select on staygrubby.accounts to authenticated;
alter table staygrubby.auth_account_links enable row level security;
-- No read/write grants or client policies for private Auth mappings.
-- No direct client INSERT/UPDATE/DELETE grants on any table. Phase 3C must supply
-- narrowly authorized atomic RPCs; clients cannot forge versions, owners or receipts.

create function staygrubby.immutable_comparison() returns trigger
language plpgsql set search_path='' as $$
begin
 if (new.id,new.ranking_id,new.first_item_id,new.second_item_id,new.preferred_item_id,new.is_tie,new.timestamp_ref)
  is distinct from (old.id,old.ranking_id,old.first_item_id,old.second_item_id,old.preferred_item_id,old.is_tie,old.timestamp_ref)
 then raise exception 'Comparison observations are immutable'; end if;
 return new;
end $$;
revoke all on function staygrubby.immutable_comparison() from public;
create trigger immutable_observation before update on staygrubby.comparisons
 for each row execute function staygrubby.immutable_comparison();

-- Explicitly neutralize inherited client privileges before selective read grants.
-- This also denies TRUNCATE/REFERENCES/TRIGGER/MAINTAIN, which RLS does not replace.
revoke all on all tables in schema staygrubby from public, anon, authenticated;
grant select on staygrubby.accounts, staygrubby.profiles, staygrubby.rankings,
 staygrubby.account_libraries, staygrubby.dishes, staygrubby.dish_sources,
 staygrubby.ranked_items, staygrubby.cooking_attempts, staygrubby.comparisons,
 staygrubby.tags, staygrubby.attempt_tags, staygrubby.media,
 staygrubby.sync_operations, staygrubby.sync_imports to authenticated;
revoke all on all functions in schema staygrubby from public, anon, authenticated;
grant execute on function staygrubby.current_account_id() to authenticated;

-- FK indexes for scoped joins, endpoint cleanup and final account erasure.
create index source_dish on staygrubby.dish_sources(account_id,dish_id);
create index item_ranking on staygrubby.ranked_items(account_id,ranking_id);
create index attempt_dish on staygrubby.cooking_attempts(account_id,dish_id);
create index comparison_first on staygrubby.comparisons(account_id,ranking_id,first_item_id);
create index comparison_second on staygrubby.comparisons(account_id,ranking_id,second_item_id);
create index membership_tag on staygrubby.attempt_tags(account_id,tag_key);
create index media_attempt on staygrubby.media(account_id,attempt_id);
create index operation_predecessor on staygrubby.sync_operations(account_id,predecessor_id);
commit;
-- Hosted advisors found two uncovered composite FKs and an automatic-RLS
-- event-trigger helper with default PUBLIC execution. Keep auto-RLS active.
begin;
create index library_global_ranking on staygrubby.account_libraries(account_id,global_ranking_id);
create index dish_source_reference on staygrubby.dishes(account_id,id,source_id);
-- This hosted helper is optional in local Supabase stacks. Never create it here.
do $$
begin
 if to_regprocedure('public.rls_auto_enable()') is not null then
  execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
 end if;
end $$;
commit;
-- Explicit self-provisioning only. No library initialization, guest import or Auth trigger.
begin;
create schema api;
revoke all on schema api from public, anon;
grant usage on schema api to authenticated;

create function staygrubby.provision_account() returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
 actor uuid := auth.uid();
 session_id uuid;
 account uuid;
 account_status text;
 revision bigint;
begin
 if actor is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
 begin
  session_id := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then
  raise exception 'Authenticated session required' using errcode='42501';
 end;
 if session_id is null or not exists (
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=session_id and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;

 -- Serialize first creation and every retry for this verified identity. Hash collisions
 -- merely serialize unrelated callers; no client-supplied lock or owner is accepted.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:provision:' || actor::text,0));
 select l.account_id into account from staygrubby.auth_account_links l where l.auth_user_id=actor;
 if account is null then
  insert into staygrubby.accounts default values returning id into account;
  insert into staygrubby.auth_account_links(auth_user_id,account_id) values(actor,account);
  insert into staygrubby.profiles(account_id) values(account);
 end if;
 select a.status,a.sync_revision into account_status,revision from staygrubby.accounts a where a.id=account;
 if account_status is distinct from 'active' then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 return pg_catalog.jsonb_build_object('format_version',1,'auth_user_id',actor,
  'account_id',account,'sync_revision',revision,'library_state',
  case when exists(select 1 from staygrubby.account_libraries l where l.account_id=account)
   then 'initialized' else 'uninitialized' end);
end $$;
revoke all on function staygrubby.provision_account() from public, anon;
grant execute on function staygrubby.provision_account() to authenticated;

-- Only this wrapper is intended for the Data API. Trusted writes remain private.
create function api.provision_account() returns jsonb
language sql volatile security invoker set search_path = '' as $$
 select staygrubby.provision_account()
$$;
revoke all on function api.provision_account() from public, anon;
grant execute on function api.provision_account() to authenticated;
-- No new table grants, write policies, ownership parameters, or signup trigger.
-- Retain the existing hosted schemas and add only api. This supported explicit
-- PostgREST override is maintained here, not by the Dashboard exposed-schema UI.
do $$ begin
 if exists(select 1 from pg_catalog.pg_roles where rolname='authenticator') then
  execute 'alter role authenticator set pgrst.db_schemas = ''public,graphql_public,api''';
 end if;
end $$;
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
commit;
-- Check the live Auth session AFTER serialization, including when a caller
-- waited behind another transaction while its session was revoked.
begin;
create or replace function staygrubby.provision_account() returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
 actor uuid := auth.uid();
 session_id uuid;
 account uuid;
 account_status text;
 revision bigint;
begin
 if actor is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
 begin
  session_id := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then
  raise exception 'Authenticated session required' using errcode='42501';
 end;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:provision:' || actor::text,0));
 if session_id is null or not exists (
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=session_id and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;

 select l.account_id into account from staygrubby.auth_account_links l where l.auth_user_id=actor;
 if account is null then
  insert into staygrubby.accounts default values returning id into account;
  insert into staygrubby.auth_account_links(auth_user_id,account_id) values(actor,account);
  insert into staygrubby.profiles(account_id) values(account);
 end if;
 select a.status,a.sync_revision into account_status,revision from staygrubby.accounts a where a.id=account;
 if account_status is distinct from 'active' then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 return pg_catalog.jsonb_build_object('format_version',1,'auth_user_id',actor,
  'account_id',account,'sync_revision',revision,'library_state',
  case when exists(select 1 from staygrubby.account_libraries l where l.account_id=account)
   then 'initialized' else 'uninitialized' end);
end $$;
revoke all on function staygrubby.provision_account() from public, anon;
grant execute on function staygrubby.provision_account() to authenticated;
notify pgrst, 'reload schema';
commit;
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
