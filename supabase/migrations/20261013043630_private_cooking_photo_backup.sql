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
