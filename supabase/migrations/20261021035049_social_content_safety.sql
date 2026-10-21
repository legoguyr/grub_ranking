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
