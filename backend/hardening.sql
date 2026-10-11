-- Follow-up: participant visibility, private file integrity, approved publication requirements and administrative inbox.
create function nexora_jobs_private.applied_job(p_job uuid) returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and exists(select 1 from public.nexora_job_applications where job_id=p_job and candidate_id=auth.uid())$$;
revoke all on function nexora_jobs_private.applied_job(uuid) from public;
grant execute on function nexora_jobs_private.applied_job(uuid) to anon,authenticated;
create function nexora_jobs_private.saved_job(p_job uuid) returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and exists(select 1 from public.nexora_job_saved where job_id=p_job and user_id=auth.uid())$$;
revoke all on function nexora_jobs_private.saved_job(uuid) from public;
grant execute on function nexora_jobs_private.saved_job(uuid) to anon,authenticated;
drop policy jobs_read on public.nexora_job_posts;
create policy jobs_read on public.nexora_job_posts for select to anon,authenticated using((status='published' and moderation_status='approved' and (application_deadline is null or application_deadline>=current_date)) or employer_id=auth.uid() or nexora_jobs_private.is_admin() or nexora_jobs_private.applied_job(id) or nexora_jobs_private.saved_job(id));
create policy notifications_admin_read on public.nexora_job_notifications for select to authenticated using(nexora_jobs_private.is_admin());
create policy notifications_admin_insert on public.nexora_job_notifications for insert to authenticated with check(nexora_jobs_private.is_admin());
grant insert on public.nexora_job_notifications to authenticated;
create function nexora_jobs_private.enforce_publish() returns trigger language plpgsql set search_path='' as $$begin
 if NEW.status='published' and (TG_OP='INSERT' or (to_jsonb(NEW)-ARRAY['moderation_status','moderation_note','updated_at']) is distinct from (to_jsonb(OLD)-ARRAY['moderation_status','moderation_note','updated_at'])) then
  if length(trim(NEW.state))=0 then raise exception 'State is required to publish a job' using errcode='23514';end if;
 end if;
 if NEW.public_phone<>'' and not NEW.contact_public then NEW.public_phone:='';end if;
 return NEW;end$$;
revoke all on function nexora_jobs_private.enforce_publish() from public,anon,authenticated;
create trigger validate_publication before insert or update on public.nexora_job_posts for each row execute function nexora_jobs_private.enforce_publish();
create function nexora_jobs_private.document_exists() returns trigger language plpgsql security definer set search_path='' as $$begin
 if TG_TABLE_NAME='nexora_job_verifications' then
  if not exists(select 1 from storage.objects where bucket_id='nexora-job-verification' and name=NEW.document_path) then raise exception 'Upload a valid verification document first' using errcode='23514';end if;
 elsif TG_TABLE_NAME='nexora_job_candidate_private' then
  if NEW.resume_path<>'' and not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name=NEW.resume_path) or NEW.photo_path<>'' and not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name=NEW.photo_path) or exists(select 1 from unnest(NEW.portfolio_paths)p where not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name=p)) then raise exception 'Invalid uploaded document reference' using errcode='23514';end if;
 elsif TG_TABLE_NAME='nexora_job_applications' and NEW.resume_path<>'' then
  if not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name=NEW.resume_path) then raise exception 'Upload a valid resume first' using errcode='23514';end if;
 end if;return NEW;end$$;
revoke all on function nexora_jobs_private.document_exists() from public,anon,authenticated;
create trigger verify_document_exists before insert or update on public.nexora_job_verifications for each row execute function nexora_jobs_private.document_exists();
create trigger candidate_document_exists before insert or update on public.nexora_job_candidate_private for each row execute function nexora_jobs_private.document_exists();
create trigger application_document_exists before insert or update on public.nexora_job_applications for each row execute function nexora_jobs_private.document_exists();
-- Fill only unambiguous configured city-to-state matches, preserving all user IDs and content.
update public.nexora_job_employers e set state=l.state from public.nexora_job_locations l where e.state='' and lower(e.city)=lower(l.city) and (select count(*) from public.nexora_job_locations x where lower(x.city)=lower(e.city))=1;
update public.nexora_job_posts j set state=l.state from public.nexora_job_locations l where j.state='' and lower(j.city)=lower(l.city) and (select count(*) from public.nexora_job_locations x where lower(x.city)=lower(j.city))=1;
notify pgrst,'reload schema';
