// Disposable SQL catalog only; never a claim of Storage HTTP/S3 byte testing.
export const storageStubSQL = `create schema storage;
create table storage.buckets(id text primary key,name text,public boolean default false,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb,owner_id text,unique(bucket_id,name));
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated,anon;
grant select,insert,update,delete on storage.objects to authenticated,anon;
create function storage.allow_any_operation(expected text[]) returns boolean language sql stable as $$
 select coalesce(replace(current_setting('storage.operation',true),'storage.','')=any(expected),false) $$;`;
