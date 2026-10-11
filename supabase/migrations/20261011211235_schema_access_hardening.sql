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
