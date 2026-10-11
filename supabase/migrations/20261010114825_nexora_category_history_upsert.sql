-- Candidate RPC uses INSERT ... ON CONFLICT. Read the owner's saved IDs before
-- INSERT validation so deactivated historical selections survive an ordinary edit.
create or replace function public.nexora_job_validate_categories() returns trigger language plpgsql security invoker set search_path='' as $$
declare chosen uuid[]; previous uuid[] := '{}';
begin
 if TG_TABLE_NAME='nexora_job_candidates' then
  chosen:=NEW.job_profile_category_ids;
  if TG_OP='UPDATE' then previous:=OLD.job_profile_category_ids;
  elsif NEW.user_id=auth.uid() then
   select coalesce(c.job_profile_category_ids,'{}') into previous from public.nexora_job_candidates c where c.user_id=NEW.user_id;
   previous:=coalesce(previous,'{}');
  end if;
 else
  chosen:=NEW.required_category_ids;
  if TG_OP='UPDATE' then previous:=OLD.required_category_ids;end if;
 end if;
 if chosen is null or cardinality(chosen)=0 then raise exception 'Select at least one job profile' using errcode='23514';end if;
 if cardinality(chosen)>100 or array_position(chosen,null) is not null or cardinality(chosen)<>(select count(distinct x) from unnest(chosen)x) then raise exception 'Duplicate or invalid category IDs' using errcode='23514';end if;
 if exists(select 1 from unnest(chosen)x left join public.nexora_job_categories c on c.id=x where c.id is null or (not c.is_active and not (x=any(previous)))) then raise exception 'Invalid or inactive job profile category' using errcode='23514';end if;
 NEW.updated_at:=now();return NEW;
end$$;
