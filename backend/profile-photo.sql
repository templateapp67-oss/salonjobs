-- Reuse private bucket and candidate contact/photo row. Add only owner personal photo.
alter table public.nexora_job_employers add column profile_photo_path text not null default '';
create function nexora_jobs_private.validate_profile_photo() returns trigger language plpgsql security definer set search_path='' as $$declare p text; u uuid;begin
 u:=NEW.user_id;p:=case when TG_TABLE_NAME='nexora_job_employers' then to_jsonb(NEW)->>'profile_photo_path' else to_jsonb(NEW)->>'photo_path' end;
 if coalesce(p,'')<>'' then
  if split_part(p,'/',1)<>u::text then raise exception 'Invalid profile photo ownership' using errcode='23514';end if;
  if not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name=p and metadata->>'mimetype' in ('image/jpeg','image/png','image/webp') and coalesce((metadata->>'size')::bigint,0) between 1 and 5242880) then raise exception 'Upload a valid JPG, PNG or WebP profile photo (maximum 5 MB)' using errcode='23514';end if;
 end if;return NEW;end$$;
revoke all on function nexora_jobs_private.validate_profile_photo() from public,anon,authenticated;
create trigger validate_candidate_photo before insert or update of photo_path on public.nexora_job_candidate_private for each row execute function nexora_jobs_private.validate_profile_photo();
create trigger validate_owner_photo before insert or update of profile_photo_path on public.nexora_job_employers for each row execute function nexora_jobs_private.validate_profile_photo();
notify pgrst,'reload schema';
