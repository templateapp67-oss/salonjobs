create or replace function nexora_jobs_private.validate_primary_job_title() returns trigger language plpgsql security invoker set search_path='' as $$
declare category_name text; active boolean; changed boolean:=true;
begin
 if TG_OP='UPDATE' then changed:=NEW.primary_category_id is distinct from OLD.primary_category_id;end if;
 if NEW.primary_category_id is null then
  if TG_OP='INSERT' then raise exception 'Select a Job Title' using errcode='23514';end if;
  if OLD.primary_category_id is not null or NEW.title is distinct from OLD.title or NEW.required_category_ids is distinct from OLD.required_category_ids then raise exception 'Select a Job Title before editing job title or profiles' using errcode='23514';end if;
  return NEW;
 end if;
 select name,is_active into category_name,active from public.nexora_job_categories where id=NEW.primary_category_id;
 if category_name is null then raise exception 'Invalid Job Title category' using errcode='23514';end if;
 if not active and changed then raise exception 'Choose an active Job Title' using errcode='23514';end if;
 if not (NEW.primary_category_id=any(coalesce(NEW.required_category_ids,'{}'::uuid[]))) then raise exception 'Required profiles must include the primary Job Title' using errcode='23514';end if;
 if changed then NEW.title:=category_name;
 elsif TG_OP='UPDATE' and NEW.title is distinct from OLD.title and NEW.title<>category_name then raise exception 'Job Title must match its category' using errcode='23514';end if;
 return NEW;
end$$;
alter table public.nexora_job_posts drop constraint nexora_job_posts_employment_type_check;
alter table public.nexora_job_posts add constraint nexora_job_posts_employment_type_check check(employment_type in ('Full-time','Part-time','Contract','Internship','Freelance'));
notify pgrst,'reload schema';
