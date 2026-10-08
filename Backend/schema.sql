-- Phase 3B declarative foundation. Apply only to an approved Supabase development project.
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

-- FK indexes for scoped joins, endpoint cleanup and final account erasure.
create index source_dish on staygrubby.dish_sources(account_id,dish_id);
create index item_ranking on staygrubby.ranked_items(account_id,ranking_id);
create index attempt_dish on staygrubby.cooking_attempts(account_id,dish_id);
create index comparison_first on staygrubby.comparisons(account_id,ranking_id,first_item_id);
create index comparison_second on staygrubby.comparisons(account_id,ranking_id,second_item_id);
create index membership_tag on staygrubby.attempt_tags(account_id,tag_key);
create index media_attempt on staygrubby.media(account_id,attempt_id);
commit;
