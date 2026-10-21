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
-- JSON snapshots must retain exact Double dates/cache values on hosted sessions with float_digits=0.
begin;
alter function staygrubby.open_account_library() set extra_float_digits=3;
notify pgrst,'reload schema';
commit;
-- Private immutable media manifests. Bytes are changed/deleted only through Storage API.
begin;
create table staygrubby.media_backups (
 account_id uuid not null,
 media_id uuid not null,
 display_hash text not null check(display_hash ~ '^[0-9a-f]{64}$'),
 thumbnail_hash text not null check(thumbnail_hash ~ '^[0-9a-f]{64}$'),
 display_bytes integer not null check(display_bytes between 1 and 2097152),
 thumbnail_bytes integer not null check(thumbnail_bytes between 1 and 2097152),
 display_key text not null,
 thumbnail_key text not null,
 ready boolean not null default false,
 cleaned boolean not null default false,
 primary key(account_id,media_id),
 foreign key(account_id,media_id) references staygrubby.media(account_id,id),
 unique(display_key), unique(thumbnail_key),
 check(display_key=account_id::text || '/' || media_id::text || '/display-' || display_hash || '.jpg'),
 check(thumbnail_key=account_id::text || '/' || media_id::text || '/thumbnail-' || thumbnail_hash || '.jpg')
);
alter table staygrubby.media_backups enable row level security;
revoke all on staygrubby.media_backups from public,anon,authenticated;

-- Read-only resolver: Storage authorization never provisions an account.
create function staygrubby.media_owner() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; sid uuid;
begin
 begin sid := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then return null; end;
 select l.account_id into owner from auth.users u
 join auth.sessions s on s.user_id=u.id
 join staygrubby.auth_account_links l on l.auth_user_id=u.id
 join staygrubby.accounts a on a.id=l.account_id
 where u.id=auth.uid() and s.id=sid and u.deleted_at is null
 and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now()) and a.status='active';
 return owner;
end $$;
revoke all on function staygrubby.media_owner() from public,anon;
grant execute on function staygrubby.media_owner() to authenticated;
grant select on staygrubby.media_backups to authenticated;
create policy own_media_manifests on staygrubby.media_backups for select to authenticated
using(account_id=(select staygrubby.media_owner()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('cooking-photos','cooking-photos',false,2097152,array['image/jpeg']);

-- Shared account lock serializes object authorization with structured tombstones.
-- Operation-specific SELECT permits Storage deletion of retired objects without
-- allowing a download/list to expose those objects. No SQL object deletion occurs.
create function staygrubby.cooking_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; retired boolean;
begin
 if bucket is distinct from 'cooking-photos' or mode is null or mode not in ('read','write','delete') then return false; end if;
 if mode='write' and not storage.allow_any_operation(array['object.upload','object.upload_update']) then return false; end if;
 if mode='delete' and not storage.allow_any_operation(array['object.delete','object.delete_many']) then return false; end if;
 owner := staygrubby.media_owner(); if owner is null then return false; end if;
 perform 1 from staygrubby.accounts where id=owner for share;
 if staygrubby.media_owner() is distinct from owner then return false; end if;
 select m.deleted_at is not null or a.deleted_at is not null or d.deleted_at is not null
 into retired from staygrubby.media_backups b
 join staygrubby.media m on m.account_id=b.account_id and m.id=b.media_id
 join staygrubby.cooking_attempts a on a.account_id=m.account_id and a.id=m.attempt_id
 join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id
 where b.account_id=owner and not b.cleaned and path in (b.display_key,b.thumbnail_key);
 if not found then return false; end if;
 if mode='delete' then return retired; end if;
 if mode='read' and storage.allow_any_operation(array['object.delete','object.delete_many']) then return retired; end if;
 if mode='read' and not storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info',
   'object.head_authenticated_info','object.info_authenticated','object.list','object.list_v2','object.upload','object.upload_update'])
 then return false; end if;
 return not retired;
end $$;
revoke all on function staygrubby.cooking_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.cooking_object_allowed(text,text,text) to authenticated;
create policy cooking_photo_read on storage.objects for select to authenticated
using(staygrubby.cooking_object_allowed(bucket_id,name,'read'));
create policy cooking_photo_insert on storage.objects for insert to authenticated
with check(staygrubby.cooking_object_allowed(bucket_id,name,'write'));
create policy cooking_photo_update on storage.objects for update to authenticated
using(staygrubby.cooking_object_allowed(bucket_id,name,'write'))
with check(staygrubby.cooking_object_allowed(bucket_id,name,'write'));
create policy cooking_photo_delete on storage.objects for delete to authenticated
using(staygrubby.cooking_object_allowed(bucket_id,name,'delete'));

create function staygrubby.media_backup(action text,manifest jsonb default null) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; mid uuid; stored_media staygrubby.media%rowtype; stored_backup staygrubby.media_backups%rowtype; result jsonb;
begin
 owner := staygrubby.media_owner();
 if owner is null then raise exception 'Authenticated account required' using errcode='42501'; end if;
 if action='list' then perform 1 from staygrubby.accounts where id=owner for share;
 else perform 1 from staygrubby.accounts where id=owner for update; end if;
 if staygrubby.media_owner() is distinct from owner then raise exception 'Session unavailable' using errcode='42501'; end if;
 if action is null or action not in ('list','register','complete','cleaned') then raise exception 'Invalid action' using errcode='22023'; end if;
 if action<>'list' then
  if (manifest->>'accountID')::uuid is distinct from owner then raise exception 'Account mismatch' using errcode='42501'; end if;
  mid := (manifest->>'mediaID')::uuid;
  select * into stored_media from staygrubby.media where account_id=owner and id=mid;
  if not found then raise exception 'Media not accepted' using errcode='40001'; end if;
  if action in ('register','complete') and (stored_media.deleted_at is not null or not exists(
    select 1 from staygrubby.cooking_attempts a join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id
    where a.account_id=owner and a.id=stored_media.attempt_id and a.deleted_at is null and d.deleted_at is null))
  then raise exception 'Media retired' using errcode='40001'; end if;
  if action='register' then
   if manifest->>'displayHash' !~ '^[0-9a-f]{64}$' or manifest->>'thumbnailHash' !~ '^[0-9a-f]{64}$'
    or (manifest->>'displayBytes')::integer not between 1 and 2097152
    or (manifest->>'thumbnailBytes')::integer not between 1 and 2097152
   then raise exception 'Invalid integrity manifest' using errcode='22023'; end if;
   insert into staygrubby.media_backups(account_id,media_id,display_hash,thumbnail_hash,display_bytes,thumbnail_bytes,display_key,thumbnail_key)
   values(owner,mid,manifest->>'displayHash',manifest->>'thumbnailHash',(manifest->>'displayBytes')::integer,(manifest->>'thumbnailBytes')::integer,
    owner::text || '/' || mid::text || '/display-' || (manifest->>'displayHash') || '.jpg',
    owner::text || '/' || mid::text || '/thumbnail-' || (manifest->>'thumbnailHash') || '.jpg')
   on conflict(account_id,media_id) do nothing;
  end if;
  select * into stored_backup from staygrubby.media_backups where account_id=owner and media_id=mid;
  if not found then raise exception 'Manifest missing' using errcode='55000'; end if;
  if (stored_backup.display_hash,stored_backup.thumbnail_hash,stored_backup.display_bytes,stored_backup.thumbnail_bytes) is distinct from
   (manifest->>'displayHash',manifest->>'thumbnailHash',(manifest->>'displayBytes')::integer,(manifest->>'thumbnailBytes')::integer)
  then raise exception 'Immutable manifest mismatch' using errcode='23505'; end if;
  if action='complete' then
   if not exists(select 1 from storage.objects where bucket_id='cooking-photos' and name=stored_backup.display_key
     and (metadata->>'size')::bigint=stored_backup.display_bytes and metadata->>'mimetype'='image/jpeg')
    or not exists(select 1 from storage.objects where bucket_id='cooking-photos' and name=stored_backup.thumbnail_key
     and (metadata->>'size')::bigint=stored_backup.thumbnail_bytes and metadata->>'mimetype'='image/jpeg')
   then raise exception 'Bytes not backed up' using errcode='55000'; end if;
   update staygrubby.media_backups set ready=true where account_id=owner and media_id=mid;
  elsif action='cleaned' then
   if stored_media.deleted_at is null then raise exception 'Active media cannot be cleaned' using errcode='40001'; end if;
   if exists(select 1 from storage.objects where bucket_id='cooking-photos' and name in (stored_backup.display_key,stored_backup.thumbnail_key))
   then raise exception 'Storage cleanup pending' using errcode='55000'; end if;
   update staygrubby.media_backups set cleaned=true where account_id=owner and media_id=mid;
  end if;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('accountID',b.account_id,'mediaID',b.media_id,
  'displayHash',b.display_hash,'thumbnailHash',b.thumbnail_hash,'displayBytes',b.display_bytes,'thumbnailBytes',b.thumbnail_bytes,
  'displayKey',b.display_key,'thumbnailKey',b.thumbnail_key,'state',
  case when m.deleted_at is not null then 'deleted' when b.ready
   and exists(select 1 from storage.objects o where o.bucket_id='cooking-photos' and o.name=b.display_key and (o.metadata->>'size')::bigint=b.display_bytes and o.metadata->>'mimetype'='image/jpeg')
   and exists(select 1 from storage.objects o where o.bucket_id='cooking-photos' and o.name=b.thumbnail_key and (o.metadata->>'size')::bigint=b.thumbnail_bytes and o.metadata->>'mimetype'='image/jpeg')
   then 'ready' else 'pending' end) order by b.media_id),'[]'::jsonb)
 into result from staygrubby.media_backups b join staygrubby.media m on m.account_id=b.account_id and m.id=b.media_id
 where b.account_id=owner and not b.cleaned and (action='list' or b.media_id=mid);
 return jsonb_build_object('accountID',owner,'backups',result);
end $$;
revoke all on function staygrubby.media_backup(text,jsonb) from public,anon;
grant execute on function staygrubby.media_backup(text,jsonb) to authenticated;
create function api.media_backup(action text,manifest jsonb default null) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.media_backup(action,manifest) $$;
revoke all on function api.media_backup(text,jsonb) from public,anon;
grant execute on function api.media_backup(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
-- Durable, self-only account deletion coordination. Privileged erasure remains
-- server-only; clients can neither choose an owner nor invoke finalization.
begin;

grant usage on schema api to service_role;

create table staygrubby.account_deletion_jobs (
 auth_user_id uuid primary key references auth.users(id) on delete cascade,
 account_id uuid not null unique,
 state text not null default 'requested'
  check (state in ('requested','apple_revoked','storage_cleared','account_erased')),
 object_keys jsonb not null default '[]'::jsonb check (jsonb_typeof(object_keys)='array'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table staygrubby.account_deletion_jobs enable row level security;
revoke all on staygrubby.account_deletion_jobs from public, anon, authenticated;

create function staygrubby.account_deletion_actor() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := auth.uid(); sid uuid;
begin
 if actor is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
 begin sid := nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then
  raise exception 'Authenticated session required' using errcode='42501';
 end;
 if sid is null or not exists(
  select 1 from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=actor and s.id=sid and u.deleted_at is null
   and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
 ) then raise exception 'Authenticated session required' using errcode='42501'; end if;
 return actor;
end $$;
revoke all on function staygrubby.account_deletion_actor() from public,anon;
grant execute on function staygrubby.account_deletion_actor() to authenticated;

create function staygrubby.account_deletion_state() returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); job staygrubby.account_deletion_jobs%rowtype;
begin
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=actor;
 if found then
  return jsonb_build_object('pending',true,'account_id',job.account_id,'state',job.state);
 end if;
 return jsonb_build_object('pending',false);
end $$;
revoke all on function staygrubby.account_deletion_state() from public,anon;
grant execute on function staygrubby.account_deletion_state() to authenticated;

create function api.account_deletion_state() returns jsonb
language sql volatile security invoker set search_path='' as $$
 select staygrubby.account_deletion_state()
$$;
revoke all on function api.account_deletion_state() from public,anon;
grant execute on function api.account_deletion_state() to authenticated;

create function staygrubby.begin_account_deletion() returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); owner uuid; job staygrubby.account_deletion_jobs%rowtype; keys jsonb;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || actor::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=actor for update;
 if found then
  return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
 end if;
 select l.account_id into owner from staygrubby.auth_account_links l where l.auth_user_id=actor;
 if owner is null then raise exception 'Account unavailable' using errcode='42501'; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 select coalesce(jsonb_agg(value order by value),'[]'::jsonb) into keys from (
  select display_key value from staygrubby.media_backups where account_id=owner and not cleaned
  union select thumbnail_key from staygrubby.media_backups where account_id=owner and not cleaned
 ) paths;
 insert into staygrubby.account_deletion_jobs(auth_user_id,account_id,object_keys)
 values(actor,owner,keys) returning * into job;
 update staygrubby.accounts set status='deleting' where id=owner;
 return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
end $$;
revoke all on function staygrubby.begin_account_deletion() from public,anon;
grant execute on function staygrubby.begin_account_deletion() to authenticated;

create function api.begin_account_deletion() returns jsonb
language sql volatile security invoker set search_path='' as $$
 select staygrubby.begin_account_deletion()
$$;
revoke all on function api.begin_account_deletion() from public,anon;
grant execute on function api.begin_account_deletion() to authenticated;

create function staygrubby.advance_account_deletion(target_auth_user uuid,target_state text) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype; current_step integer; next_step integer;
begin
 if target_state not in ('apple_revoked','storage_cleared') then raise exception 'Invalid deletion stage' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 current_step := case job.state when 'requested' then 0 when 'apple_revoked' then 1 when 'storage_cleared' then 2 else 3 end;
 next_step := case target_state when 'apple_revoked' then 1 else 2 end;
 if next_step > current_step then
  if next_step <> current_step + 1 then raise exception 'Deletion stage out of order' using errcode='55000'; end if;
  update staygrubby.account_deletion_jobs set state=target_state,updated_at=clock_timestamp()
   where auth_user_id=target_auth_user returning * into job;
 end if;
 return jsonb_build_object('accountID',job.account_id,'state',job.state,'objectKeys',job.object_keys);
end $$;
revoke all on function staygrubby.advance_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function staygrubby.advance_account_deletion(uuid,text) to service_role;

create function api.advance_account_deletion(target_auth_user uuid,target_state text) returns jsonb
language sql volatile security definer set search_path='' as $$
 select staygrubby.advance_account_deletion(target_auth_user,target_state)
$$;
revoke all on function api.advance_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function api.advance_account_deletion(uuid,text) to service_role;

create function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;
 if exists(select 1 from storage.objects where bucket_id='cooking-photos'
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
revoke all on function staygrubby.erase_account_data(uuid) from public,anon,authenticated;
grant execute on function staygrubby.erase_account_data(uuid) to service_role;

create function api.erase_account_data(target_auth_user uuid) returns jsonb
language sql volatile security definer set search_path='' as $$
 select staygrubby.erase_account_data(target_auth_user)
$$;
revoke all on function api.erase_account_data(uuid) from public,anon,authenticated;
grant execute on function api.erase_account_data(uuid) to service_role;

notify pgrst,'reload schema';
commit;
-- Optional Dish metadata only. No new tables, grants, owners, ranks or evidence.
-- Existing clients omit cuisine; preserve it on their updates. New clients send
-- an explicit JSON null to remove it. Account ownership/deletion follows Dish.
begin;
alter table staygrubby.dishes add column cuisine jsonb;
alter table staygrubby.dishes add constraint dish_cuisine_value check (
 cuisine is null or (
  jsonb_typeof(cuisine)='object' and cuisine - array['id','label'] = '{}'::jsonb
  and jsonb_typeof(cuisine->'id')='string' and length(cuisine->>'id') between 1 and 160
  and jsonb_typeof(cuisine->'label')='string' and length(btrim(cuisine->>'label')) between 1 and 80
  and cuisine ? 'id' and cuisine ? 'label'
 )
);

create or replace function staygrubby.apply_cooking_operation(envelope jsonb) returns jsonb
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
   insert into staygrubby.dishes as current(account_id,id,name,default_course_code,created_at_ref,source_id,cuisine)
    values(owner,(data->>'id')::uuid,(data->>'name')::text,(data->>'defaultCategoryCode')::text,(data->>'createdAt')::double precision,(data->>'sourceID')::uuid,nullif(data->'cuisine','null'::jsonb))
    on conflict(account_id,id) do update set name=excluded.name,default_course_code=excluded.default_course_code,created_at_ref=excluded.created_at_ref,source_id=excluded.source_id,cuisine=case when data ? 'cuisine' then excluded.cuisine else current.cuisine end
    where (current.name,current.default_course_code,current.created_at_ref,current.source_id,current.cuisine) is distinct from (excluded.name,excluded.default_course_code,excluded.created_at_ref,excluded.source_id,case when data ? 'cuisine' then excluded.cuisine else current.cuisine end);
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
create or replace function staygrubby.open_account_library() returns jsonb
language plpgsql volatile security definer set search_path = '' set extra_float_digits=3 as $$
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
 'dishes',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'defaultCategoryCode',r.default_course_code,'createdAt',r.created_at_ref,'sourceID',r.source_id,'cuisine',r.cuisine)) from staygrubby.dishes r where r.account_id=owner and r.deleted_at is null),'[]'::jsonb),
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
-- Optional social identity, separate from the private cooking/sync graph.
begin;
alter table staygrubby.profiles add column discoverable boolean not null default false;
create table staygrubby.username_reservations (
 username text primary key,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 expires_at timestamptz not null
);
alter table staygrubby.username_reservations enable row level security;
revoke all on staygrubby.username_reservations from public,anon,authenticated;

create function staygrubby.social_actor() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); owner uuid;
begin
 select l.account_id into owner from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id where l.auth_user_id=actor and a.status='active';
 if owner is null then raise exception 'Social account unavailable' using errcode='42501'; end if;
 return owner;
end $$;
revoke all on function staygrubby.social_actor() from public,anon,authenticated;

create function staygrubby.social_identity(action text,payload jsonb default '{}'::jsonb) returns jsonb
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
  select username into previous from staygrubby.profiles where account_id=owner for update;
  update staygrubby.profiles set display_name=label,username=handle,discoverable=visible where account_id=owner;
  if previous is not null and previous<>handle then
   insert into staygrubby.username_reservations(username,account_id,expires_at) values(previous,owner,now()+interval '30 days')
   on conflict(username) do update set account_id=excluded.account_id,expires_at=excluded.expires_at;
  end if;
 elsif action<>'get' then raise exception 'Unknown identity action' using errcode='22023'; end if;
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'discoverable',p.discoverable) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;
revoke all on function staygrubby.social_identity(text,jsonb) from public,anon;
grant execute on function staygrubby.social_identity(text,jsonb) to authenticated;
create function api.social_identity(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_identity(action,payload) $$;
revoke all on function api.social_identity(text,jsonb) from public,anon;
grant execute on function api.social_identity(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
begin;
create table staygrubby.friendships (
 low_id uuid not null references staygrubby.accounts(id) on delete cascade,
 high_id uuid not null references staygrubby.accounts(id) on delete cascade,
 requester_id uuid not null references staygrubby.accounts(id) on delete cascade,
 state text not null check(state in ('pending','friends','declined','cancelled','removed')),
 updated_at timestamptz not null default now(),
 primary key(low_id,high_id), check(low_id<high_id),check(requester_id in (low_id,high_id))
);
create table staygrubby.social_blocks (
 blocker_id uuid not null references staygrubby.accounts(id) on delete cascade,
 blocked_id uuid not null references staygrubby.accounts(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id),check(blocker_id<>blocked_id)
);
alter table staygrubby.friendships enable row level security;
alter table staygrubby.social_blocks enable row level security;
revoke all on staygrubby.friendships,staygrubby.social_blocks from public,anon,authenticated;
create index friendships_recipient on staygrubby.friendships(high_id,state);
create index social_blocks_target on staygrubby.social_blocks(blocked_id);

create function staygrubby.social_blocked(a uuid,b uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.social_blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a))
$$;
revoke all on function staygrubby.social_blocked(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_person(viewer uuid,target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,
 'relationship',case when f.state='friends' then 'friends' when f.state='pending' and f.requester_id=viewer then 'outgoing' when f.state='pending' then 'incoming' else 'none' end)
 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id
 left join staygrubby.friendships f on f.low_id=least(viewer,target) and f.high_id=greatest(viewer,target)
 where p.account_id=target and p.username is not null and p.deleted_at is null and a.status='active'
 and not staygrubby.social_blocked(viewer,target)
 and (p.discoverable or viewer=target or f.state in ('friends','pending'))
$$;
revoke all on function staygrubby.social_person(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_people(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid := staygrubby.social_actor(); peer uuid; lo uuid; hi uuid; relation staygrubby.friendships%rowtype; query text; people jsonb;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid social request' using errcode='22023'; end if;
 if not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and deleted_at is null)
 then raise exception 'Set up a social identity first' using errcode='22023'; end if;
 if action in ('search','friends','incoming','outgoing') then
  query:=lower(btrim(coalesce(payload->>'query',''))); if left(query,1)='@' then query:=substring(query from 2); end if;
  if action='search' and (length(query)<2 or length(query)>50) then return jsonb_build_object('people','[]'::jsonb); end if;
  select coalesce(jsonb_agg(card order by card->>'username'),'[]'::jsonb) into people from (
   select staygrubby.social_person(owner,p.account_id) card from staygrubby.profiles p
   left join staygrubby.friendships f on f.low_id=least(owner,p.account_id) and f.high_id=greatest(owner,p.account_id)
   where p.account_id<>owner and p.username is not null and p.deleted_at is null
    and p.username>coalesce(payload->>'afterUsername','')
    and ((action='search' and p.discoverable and position(query in p.username)>0)
     or(action='friends' and f.state='friends')
     or(action='incoming' and f.state='pending' and f.requester_id<>owner)
     or(action='outgoing' and f.state='pending' and f.requester_id=owner))
   order by p.username limit 50
  ) r where card is not null;
  return jsonb_build_object('people',people,'nextCursor',case when jsonb_array_length(people)=50 then people->49->>'username' end);
 elsif action='blocked' then
  select coalesce(jsonb_agg(jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,'relationship','blocked') order by p.username),'[]'::jsonb)
  into people from staygrubby.social_blocks b join staygrubby.profiles p on p.account_id=b.blocked_id
  join staygrubby.accounts a on a.id=p.account_id where b.blocker_id=owner and a.status='active' and p.deleted_at is null;
  return jsonb_build_object('people',people);
 end if;
 peer:=(payload->>'peerID')::uuid;
 if peer is null or peer=owner then raise exception 'Invalid person' using errcode='22023'; end if;
 lo:=least(owner,peer);hi:=greatest(owner,peer);
 if action='profile' then
  people:=staygrubby.social_person(owner,peer);
  if people is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  return jsonb_build_object('people',jsonb_build_array(people));
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:pair:'||lo::text||':'||hi::text,0));
 perform staygrubby.social_actor(); -- Recheck live Auth after waiting on the pair lock.
 -- Account deletion locks the account row; recheck active state after pair serialization.
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 select * into relation from staygrubby.friendships where low_id=lo and high_id=hi for update;
 if action='unblock' then
  delete from staygrubby.social_blocks where blocker_id=owner and blocked_id=peer;
  return jsonb_build_object('people','[]'::jsonb);
 elsif action='block' then
  if not exists(select 1 from staygrubby.social_blocks where blocker_id=owner and blocked_id=peer)
   and staygrubby.social_person(owner,peer) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  insert into staygrubby.social_blocks(blocker_id,blocked_id) values(owner,peer) on conflict do nothing;
  update staygrubby.friendships set state='removed',updated_at=now() where low_id=lo and high_id=hi;
  return jsonb_build_object('people','[]'::jsonb);
 end if;
 if staygrubby.social_blocked(owner,peer) then raise exception 'Person unavailable' using errcode='42501'; end if;
 if action='request' then
  if staygrubby.social_person(owner,peer) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  if relation.state='pending' and relation.requester_id<>owner then
   update staygrubby.friendships set state='friends',updated_at=now() where low_id=lo and high_id=hi;
  elsif relation.state in ('friends','pending') then null; -- Idempotent same-direction request.
  else
   if relation.state='declined' and relation.requester_id=owner and relation.updated_at>now()-interval '24 hours'
   then raise exception 'Wait before requesting again' using errcode='40001'; end if;
   if not exists(select 1 from staygrubby.profiles where account_id=peer and discoverable and deleted_at is null)
   then raise exception 'Person unavailable' using errcode='42501'; end if;
   insert into staygrubby.friendships(low_id,high_id,requester_id,state) values(lo,hi,owner,'pending')
   on conflict(low_id,high_id) do update set requester_id=excluded.requester_id,state='pending',updated_at=now();
  end if;
 elsif action in ('accept','decline') then
  if relation.state is distinct from 'pending' or relation.requester_id=owner
  then raise exception 'Request changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state=case action when 'accept' then 'friends' else 'declined' end,updated_at=now() where low_id=lo and high_id=hi;
 elsif action='cancel' then
  if relation.state is distinct from 'pending' or relation.requester_id<>owner then raise exception 'Request changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state='cancelled',updated_at=now() where low_id=lo and high_id=hi;
 elsif action='remove' then
  if relation.state is distinct from 'friends' then raise exception 'Friendship changed; refresh' using errcode='40001'; end if;
  update staygrubby.friendships set state='removed',updated_at=now() where low_id=lo and high_id=hi;
 else raise exception 'Unknown social action' using errcode='22023'; end if;
 people:=staygrubby.social_person(owner,peer);
 return jsonb_build_object('people',case when people is null then '[]'::jsonb else jsonb_build_array(people) end);
end $$;
revoke all on function staygrubby.social_people(text,jsonb) from public,anon;
grant execute on function staygrubby.social_people(text,jsonb) to authenticated;
create function api.social_people(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_people(action,payload) $$;
revoke all on function api.social_people(text,jsonb) from public,anon;
grant execute on function api.social_people(text,jsonb) to authenticated;
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
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'discoverable',p.discoverable) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
begin;
alter table staygrubby.profiles add column social_state text not null default 'active' check(social_state in ('active','hidden'));
create table staygrubby.social_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references staygrubby.accounts(id) on delete cascade,
 source_attempt_id uuid not null,
 title text not null check(length(title) between 1 and 200),
 version_title text check(length(version_title)<=200),
 score_text text check(score_text ~ '^([1-9]\.[0-9]|10\.0)$'),
 achievement text,
 created_at timestamptz not null default now(),
 published boolean not null default false,
 moderation_state text not null default 'active' check(moderation_state in ('active','hidden')),
 deleted_at timestamptz,
 foreign key(author_id,source_attempt_id) references staygrubby.cooking_attempts(account_id,id) on delete cascade
);
create unique index social_post_active_source on staygrubby.social_posts(author_id,source_attempt_id) where deleted_at is null;
create index social_post_timeline on staygrubby.social_posts(created_at desc,id desc) where deleted_at is null and published;
create index social_post_author on staygrubby.social_posts(author_id,created_at desc);
create table staygrubby.social_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references staygrubby.social_posts(id) on delete cascade,
 author_id uuid not null references staygrubby.accounts(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 1000),
 created_at timestamptz not null default now(),
 moderation_state text not null default 'active' check(moderation_state in ('active','hidden'))
);
create index social_comments_author on staygrubby.social_comments(author_id);
create index social_comments_post on staygrubby.social_comments(post_id,created_at,id);
create table staygrubby.social_likes (
 post_id uuid not null references staygrubby.social_posts(id) on delete cascade,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(post_id,account_id)
);
create index social_likes_owner on staygrubby.social_likes(account_id);
create table staygrubby.social_reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references staygrubby.accounts(id) on delete cascade,
 target_type text not null check(target_type in ('profile','post','comment')),
 target_id uuid not null,
 target_account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 target_post_id uuid references staygrubby.social_posts(id) on delete cascade,
 target_comment_id uuid references staygrubby.social_comments(id) on delete cascade,
 reason text not null check(reason in ('harassment','hate','spam','inappropriate','impersonation','other')),
 context text check(length(context)<=500),
 status text not null default 'pending' check(status in ('pending','reviewed','dismissed')),
 created_at timestamptz not null default now(),
 unique(reporter_id,target_type,target_id)
);
create index social_reports_target_account on staygrubby.social_reports(target_account_id);
create index social_reports_post on staygrubby.social_reports(target_post_id);
create index social_reports_comment on staygrubby.social_reports(target_comment_id);
alter table staygrubby.social_posts enable row level security;
alter table staygrubby.social_comments enable row level security;
alter table staygrubby.social_likes enable row level security;
alter table staygrubby.social_reports enable row level security;
revoke all on staygrubby.social_posts,staygrubby.social_comments,staygrubby.social_likes,staygrubby.social_reports from public,anon,authenticated;

create or replace function staygrubby.social_actor() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid := staygrubby.account_deletion_actor(); owner uuid;
begin
 select l.account_id into owner from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id join staygrubby.profiles p on p.account_id=a.id
 where l.auth_user_id=actor and a.status='active' and p.social_state='active' and p.deleted_at is null;
 if owner is null then raise exception 'Social account unavailable' using errcode='42501'; end if;
 return owner;
end $$;

create function staygrubby.social_can_view(viewer uuid,post uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.social_posts p
 join staygrubby.accounts a on a.id=p.author_id and a.status='active'
 join staygrubby.profiles profile on profile.account_id=a.id and profile.social_state='active' and profile.deleted_at is null
 where exists(select 1 from staygrubby.accounts va join staygrubby.profiles vp on vp.account_id=va.id
  where va.id=viewer and va.status='active' and vp.social_state='active' and vp.deleted_at is null)
 and p.id=post and p.deleted_at is null and p.published and p.moderation_state='active'
 and (viewer=p.author_id or (not staygrubby.social_blocked(viewer,p.author_id) and exists(
  select 1 from staygrubby.friendships f where f.low_id=least(viewer,p.author_id) and f.high_id=greatest(viewer,p.author_id) and f.state='friends'))))
$$;
revoke all on function staygrubby.social_can_view(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_report(action text,payload jsonb default '{}'::jsonb) returns jsonb
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
  where c.id=target and c.moderation_state='active' and staygrubby.social_can_view(owner,c.post_id)
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
revoke all on function staygrubby.social_report(text,jsonb) from public,anon;
grant execute on function staygrubby.social_report(text,jsonb) to authenticated;
create function api.social_report(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_report(action,payload) $$;
revoke all on function api.social_report(text,jsonb) from public,anon;
grant execute on function api.social_report(text,jsonb) to authenticated;

-- Service-only control surface; not a client/admin dashboard or an automated judge.
create function api.moderate_social_content(kind text,target uuid,state text) returns void
language plpgsql volatile security definer set search_path='' as $$
begin
 if state not in ('active','hidden') then raise exception 'Invalid moderation state' using errcode='22023'; end if;
 case kind
 when 'profile' then update staygrubby.profiles set social_state=state where account_id=target;
 when 'post' then update staygrubby.social_posts set moderation_state=state where id=target;
 when 'comment' then update staygrubby.social_comments set moderation_state=state where id=target;
 else raise exception 'Invalid moderation target' using errcode='22023'; end case;
end $$;
revoke all on function api.moderate_social_content(text,uuid,text) from public,anon,authenticated;
grant execute on function api.moderate_social_content(text,uuid,text) to service_role;
create or replace function staygrubby.social_person(viewer uuid,target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.account_id,'displayName',p.display_name,'username',p.username,
 'relationship',case when f.state='friends' then 'friends' when f.state='pending' and f.requester_id=viewer then 'outgoing' when f.state='pending' then 'incoming' else 'none' end)
 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id
 left join staygrubby.friendships f on f.low_id=least(viewer,target) and f.high_id=greatest(viewer,target)
 where p.account_id=target and p.username is not null and p.deleted_at is null and p.social_state='active' and a.status='active'
 and not staygrubby.social_blocked(viewer,target)
 and (p.discoverable or viewer=target or f.state in ('friends','pending'))
$$;
notify pgrst,'reload schema';
commit;
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
  -- Incomplete/cancelled uploads stay private and expire after a day of profile inactivity.
  -- A fresh prepare/profile save refreshes the existing profile timestamp before upload.
  if profile.avatar_draft_path is not null and profile.server_updated_at<now()-interval '1 day' then
   update staygrubby.profiles set avatar_draft_path=null where account_id=owner;
   profile.avatar_draft_path:=null;
  end if;
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
-- Account-level future-entry default. Legacy users remain private. Never publishes history.
begin;
alter table staygrubby.profiles add column auto_share_new_cooks boolean not null default false;
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
  update staygrubby.profiles set display_name=label,username=handle,discoverable=visible,auto_share_new_cooks=coalesce((payload->>'automaticallyShareNewDishes')::boolean,auto_share_new_cooks) where account_id=owner;
  if previous is not null and previous<>handle then
   insert into staygrubby.username_reservations(username,account_id,expires_at) values(previous,owner,now()+interval '30 days')
   on conflict(username) do update set account_id=excluded.account_id,expires_at=excluded.expires_at;
  end if;
 elsif action='sharing' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:social-profile:'||owner::text,0));
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
  if payload->>'automaticallyShareNewDishes' is null then raise exception 'Choose a default' using errcode='22023'; end if;
  if not exists(select 1 from staygrubby.profiles where account_id=owner and username is not null and deleted_at is null)
   then raise exception 'Social identity required' using errcode='42501'; end if;
  update staygrubby.profiles set auto_share_new_cooks=(payload->>'automaticallyShareNewDishes')::boolean where account_id=owner;
 elsif action<>'get' then raise exception 'Unknown identity action' using errcode='22023'; end if;
 select jsonb_build_object('displayName',p.display_name,'username',p.username,'avatarPath',p.avatar_path,'discoverable',p.discoverable,'automaticallyShareNewDishes',p.auto_share_new_cooks) into result
 from staygrubby.profiles p where p.account_id=owner and p.deleted_at is null;
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
