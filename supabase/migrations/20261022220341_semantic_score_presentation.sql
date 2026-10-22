-- Same presentation transform as ScoreCalibration.swift. No ranking/evidence writes.
begin;
create function staygrubby.calibrated_cooking_score(strength double precision,diagnostics bytea) returns double precision
language plpgsql immutable security invoker set search_path='' as $$
declare record jsonb; reaction text; x double precision; lo double precision:=1; span double precision:=9; e double precision;
begin
 begin record:=convert_from(diagnostics,'UTF8')::jsonb;
 exception when others then record:=null; end;
 reaction:=record->>'latestSemanticReaction';
 if reaction is null or reaction not in ('Liked it','It was fine','Didn''t like it') then reaction:=record->>'initialReaction'; end if;
 if strength is null or strength in ('Infinity'::float8,'-Infinity'::float8,'NaN'::float8) then strength:=0; end if;
 x:=strength/2;
 if reaction='Liked it' then lo:=7; span:=3; x:=strength/1.6-0.4;
 elsif reaction='It was fine' then lo:=4.8; span:=3; x:=strength/1.6;
 elsif reaction='Didn''t like it' then lo:=1; span:=4.8; x:=strength/1.6;
 end if;
 -- Stable sigmoid, matching the client without exponential overflow.
 e:=exp(-least(abs(x),700));
 return lo+span*(case when x>=0 then 1/(1+e) else e/(1+e) end);
end $$;
revoke all on function staygrubby.calibrated_cooking_score(double precision,bytea) from public,anon,authenticated;

alter function staygrubby.social_content(text,jsonb) rename to social_content_before_calibration;
revoke all on function staygrubby.social_content_before_calibration(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); existed boolean; result jsonb; pid uuid;
begin
 if action<>'prepare' then return staygrubby.social_content_before_calibration(action,payload); end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post-source:'||owner::text||':'||coalesce(payload->>'attemptID',''),0));
 select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=(payload->>'attemptID')::uuid and deleted_at is null) into existed;
 result:=staygrubby.social_content_before_calibration(action,payload);
 pid:=(result->'posts'->0->>'id')::uuid;
 if not existed then
  -- The original preparation owns eligibility/unlock checks. Null scores remain null.
  update staygrubby.social_posts p set score_text=round(staygrubby.calibrated_cooking_score(i.strength,i.session_diagnostics)::numeric,1)::text
  from staygrubby.cooking_attempts a join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id
  where p.id=pid and p.author_id=owner and p.score_text is not null and a.account_id=owner and a.id=p.source_attempt_id;
 end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create or replace function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;
notify pgrst,'reload schema';
commit;
