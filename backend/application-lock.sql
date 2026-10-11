create function nexora_jobs_private.lock_application_job(p_job uuid,p_candidate uuid) returns public.nexora_job_posts language plpgsql security definer set search_path='' as $$declare j public.nexora_job_posts;begin if auth.uid() is null or (auth.uid()<>p_candidate and not nexora_jobs_private.is_admin()) then raise exception 'Application identity is not authorized' using errcode='42501';end if; select * into j from public.nexora_job_posts where id=p_job and status='published' and moderation_status='approved' and (application_deadline is null or application_deadline>=current_date) for share;return j;end$$;
revoke all on function nexora_jobs_private.lock_application_job(uuid,uuid) from public;
grant execute on function nexora_jobs_private.lock_application_job(uuid,uuid) to authenticated;
create or replace function public.nexora_job_guard_application() returns trigger language plpgsql set search_path='' as $$declare job public.nexora_job_posts;begin
 if TG_OP='INSERT' then
  job:=nexora_jobs_private.lock_application_job(NEW.job_id,NEW.candidate_id);
  if job.id is null or job.status<>'published' or job.moderation_status<>'approved' or job.application_deadline<current_date or NEW.status<>'applied' then raise exception 'This job is not accepting applications' using errcode='23514';end if;
  if not NEW.consent_to_share then raise exception 'Consent to share application details is required' using errcode='23514';end if;
  if job.requires_resume and NEW.resume_path='' then raise exception 'This job requires a resume' using errcode='23514';end if;
  if NEW.resume_path<>'' and split_part(NEW.resume_path,'/',1)<>NEW.candidate_id::text then raise exception 'Invalid resume ownership' using errcode='23514';end if;
  if cardinality(NEW.screening_answers)<>cardinality(job.screening_questions) then raise exception 'Answer all screening questions' using errcode='23514';end if;
 else
  if NEW.job_id<>OLD.job_id or NEW.candidate_id<>OLD.candidate_id or NEW.id<>OLD.id then raise exception 'Application identity cannot be changed' using errcode='23514';end if;
  if not nexora_jobs_private.is_admin() then
   if auth.uid()=OLD.candidate_id and (NEW.status<>'withdrawn' or (to_jsonb(NEW)-ARRAY['status','updated_at']) is distinct from (to_jsonb(OLD)-ARRAY['status','updated_at'])) then raise exception 'Candidates can only withdraw applications' using errcode='42501';end if;
   if auth.uid()<>OLD.candidate_id and (OLD.status='withdrawn' or NEW.status='withdrawn' or (to_jsonb(NEW)-ARRAY['status','updated_at']) is distinct from (to_jsonb(OLD)-ARRAY['status','updated_at'])) then raise exception 'Only application status may be changed by the employer' using errcode='42501';end if;
  end if;
 end if;NEW.updated_at:=now();return NEW;end$$;
