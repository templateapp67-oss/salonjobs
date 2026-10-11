create or replace function nexora_jobs_private.guard_record() returns trigger language plpgsql set search_path='' as $$begin
 if TG_TABLE_NAME='nexora_job_candidate_private' then
  if NEW.photo_path<>'' and split_part(NEW.photo_path,'/',1)<>NEW.user_id::text or NEW.resume_path<>'' and split_part(NEW.resume_path,'/',1)<>NEW.user_id::text or exists(select 1 from unnest(NEW.portfolio_paths) x where split_part(x,'/',1)<>NEW.user_id::text) then raise exception 'Invalid document ownership' using errcode='23514';end if;
 elsif TG_TABLE_NAME='nexora_job_interviews' then
  if NEW.scheduled_at<=now() and TG_OP='INSERT' then raise exception 'Choose a future interview time' using errcode='23514';end if;
  if not exists(select 1 from public.nexora_job_applications a join public.nexora_job_posts j on j.id=a.job_id where a.id=NEW.application_id and a.candidate_id=NEW.candidate_id and j.employer_id=NEW.employer_id and a.status not in ('withdrawn','rejected')) then raise exception 'Invalid interview participants' using errcode='23514';end if;
 elsif TG_TABLE_NAME='nexora_job_assistance' then
  if cardinality(NEW.required_category_ids)=0 or cardinality(NEW.required_category_ids)<>(select count(distinct x) from unnest(NEW.required_category_ids)x) or exists(select 1 from unnest(NEW.required_category_ids)x left join public.nexora_job_categories c on c.id=x where c.id is null or not c.is_active) then raise exception 'Select valid active job profiles' using errcode='23514';end if;
 elsif TG_TABLE_NAME='nexora_job_verifications' then
  if split_part(NEW.document_path,'/',1)<>NEW.employer_id::text then raise exception 'Invalid verification document' using errcode='23514';end if;
 end if;
 if TG_OP='UPDATE' then
  if TG_TABLE_NAME='nexora_job_candidate_private' and (to_jsonb(NEW)->>'user_id') is distinct from (to_jsonb(OLD)->>'user_id') then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME in ('nexora_job_assistance','nexora_job_verifications') and ((to_jsonb(NEW)->>'employer_id') is distinct from (to_jsonb(OLD)->>'employer_id') or (to_jsonb(NEW)->>'id') is distinct from (to_jsonb(OLD)->>'id')) then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME='nexora_job_reports' and ((to_jsonb(NEW)->>'user_id') is distinct from (to_jsonb(OLD)->>'user_id') or (to_jsonb(NEW)->>'id') is distinct from (to_jsonb(OLD)->>'id') or (to_jsonb(NEW)->>'job_id') is distinct from (to_jsonb(OLD)->>'job_id')) then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME='nexora_job_interviews' and ((to_jsonb(NEW)->>'id') is distinct from (to_jsonb(OLD)->>'id') or (to_jsonb(NEW)->>'application_id') is distinct from (to_jsonb(OLD)->>'application_id') or (to_jsonb(NEW)->>'employer_id') is distinct from (to_jsonb(OLD)->>'employer_id') or (to_jsonb(NEW)->>'candidate_id') is distinct from (to_jsonb(OLD)->>'candidate_id')) then raise exception 'Interview participants cannot be changed';end if;
  if not nexora_jobs_private.is_admin() then
   if TG_TABLE_NAME in ('nexora_job_reports','nexora_job_verifications') and (NEW.status<>OLD.status or NEW.admin_note<>OLD.admin_note) then raise exception 'Administrator review required' using errcode='42501';end if;
   if TG_TABLE_NAME='nexora_job_assistance' and (NEW.status not in ('pending','cancelled') or NEW.admin_note<>OLD.admin_note) then raise exception 'Administrator review required' using errcode='42501';end if;
  end if;
 elsif not nexora_jobs_private.is_admin() and TG_TABLE_NAME in ('nexora_job_reports','nexora_job_verifications','nexora_job_assistance') then
  if NEW.status<>'pending' or NEW.admin_note<>'' then raise exception 'Administrator review required' using errcode='42501';end if;
 end if;
 if TG_TABLE_NAME<>'nexora_job_notifications' then NEW.updated_at:=now();end if;return NEW;end$$;
create or replace function nexora_jobs_private.notify_event() returns trigger language plpgsql security definer set search_path='' as $$declare owner uuid;begin
 if TG_TABLE_NAME='nexora_job_applications' then
  select employer_id into owner from public.nexora_job_posts where id=NEW.job_id;
  if TG_OP='INSERT' then insert into public.nexora_job_notifications(user_id,title,message) values(owner,'New application','A candidate applied to your job. Review applications in My jobs.'),(NEW.candidate_id,'Application received','Your application has been saved in Nexora Salon Jobs.');
  elsif (to_jsonb(NEW)->>'status') is distinct from (to_jsonb(OLD)->>'status') then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Application status updated','Your application status is now '||replace(NEW.status,'_',' ')||'.');end if;
 elsif TG_TABLE_NAME='nexora_job_invitations' then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Invitation to apply','An employer invited you to apply. Open Job alerts & invitations.');
 elsif TG_TABLE_NAME='nexora_job_interviews' then
  if NEW.status='scheduled' then update public.nexora_job_applications set status='interview_scheduled' where id=NEW.application_id;end if;
  insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Interview update','Your interview is '||NEW.status||'. Check Interviews for details.');
 elsif TG_TABLE_NAME='nexora_job_verifications' and TG_OP='UPDATE' and (to_jsonb(NEW)->>'status') is distinct from (to_jsonb(OLD)->>'status') then
  update public.nexora_job_employers set verification_status=NEW.status,verification_note=NEW.admin_note where user_id=NEW.employer_id;
  insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Verification update','Your salon verification status is '||replace(NEW.status,'_',' ')||'.');
 elsif TG_TABLE_NAME='nexora_job_posts' and TG_OP='UPDATE' and (to_jsonb(NEW)->>'moderation_status') is distinct from (to_jsonb(OLD)->>'moderation_status') then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Job moderation update','Your job is '||NEW.moderation_status||'. '||NEW.moderation_note);
 elsif TG_TABLE_NAME='nexora_job_assistance' and TG_OP='UPDATE' and (to_jsonb(NEW)->>'status') is distinct from (to_jsonb(OLD)->>'status') then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Assisted hiring update','Your request is '||replace(NEW.status,'_',' ')||'. '||NEW.admin_note);
 end if;return NEW;end$$;
