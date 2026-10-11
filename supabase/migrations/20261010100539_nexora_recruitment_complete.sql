-- Nexora Salon Jobs: additive expansion. Existing UUID arrays remain compatible with Android.
create schema if not exists nexora_jobs_private;
revoke all on schema nexora_jobs_private from public;
grant usage on schema nexora_jobs_private to anon,authenticated;
create function nexora_jobs_private.is_admin() returns boolean language sql stable set search_path='' as $$select coalesce(auth.jwt()->'app_metadata'->>'job_portal_role'='admin',false) and auth.uid() is not null$$;
revoke all on function nexora_jobs_private.is_admin() from public;
grant execute on function nexora_jobs_private.is_admin() to anon,authenticated;

alter table public.nexora_job_candidates
 add column state text not null default '', add column current_title text not null default '',
 add column skills text[] not null default '{}',add column services text[] not null default '{}',
 add column qualification text not null default '',add column languages text[] not null default '{}',
 add column preferred_locations text[] not null default '{}',add column expected_salary integer not null default 0 check(expected_salary>=0),
 add column availability text not null default '',add column preferred_salon_category text not null default '',
 add column employment_history text not null default '',add column terms_accepted_at timestamptz;
alter table public.nexora_job_employers
 add column contact_name text not null default '',add column mobile text not null default '' check(mobile='' or mobile ~ '^\+?[0-9]{10,15}$'),
 add column email text not null default '',add column state text not null default '',add column locality text not null default '',
 add column address text not null default '',add column business_category text not null default 'Unisex Salon',
 add column outlets integer not null default 1 check(outlets>0),add column description text not null default '',
 add column logo_url text not null default '',add column public_phone text not null default '' check(public_phone='' or public_phone ~ '^\+?[0-9]{10,15}$'),
 add column contact_public boolean not null default false,add column website text not null default '',
 add column verification_status text not null default 'pending' check(verification_status in ('pending','verified','rejected','additional_information_required')),
 add column verification_note text not null default '',add column terms_accepted_at timestamptz;
alter table public.nexora_job_posts drop constraint nexora_job_posts_status_check;
alter table public.nexora_job_posts
 add constraint nexora_job_posts_status_check check(status in ('draft','published','paused','closed','filled','archived')),
 add column moderation_status text not null default 'approved' check(moderation_status in ('pending','approved','rejected','paused','removed')),
 add column moderation_note text not null default '',add column state text not null default '',
 add column locality text not null default '',add column public_address text not null default '',
 add column country text not null default 'India',add column salon_category text not null default 'Unisex Salon' check(salon_category in ('Men''s Salon','Ladies'' Salon','Unisex Salon')),
 add column vacancies integer not null default 1 check(vacancies between 1 and 1000),
 add column responsibilities text not null default '',add column experience_min integer not null default 0 check(experience_min between 0 and 70),
 add column experience_max integer check(experience_max between 0 and 70 and experience_max>=experience_min),
 add column required_skills text[] not null default '{}',add column qualification text not null default '',
 add column languages text[] not null default '{}',add column gender_preference text not null default 'Any' check(gender_preference in ('Any','Male','Female')),
 add column preference_justification text not null default '',add column joining_availability text not null default '',
 add column work_location_type text not null default 'On-site' check(work_location_type in ('On-site','Home service','Hybrid')),
 add column negotiable boolean not null default false,add column incentive_details text not null default '',
 add column benefits text[] not null default '{}',add column other_benefits text not null default '',
 add column is_urgent boolean not null default false,add column application_deadline date,
 add column contact_public boolean not null default false,add column public_phone text not null default '' check(public_phone='' or public_phone ~ '^\+?[0-9]{10,15}$'),
 add column screening_questions text[] not null default '{}',add column requires_resume boolean not null default false,
 add column faqs jsonb not null default '[]' check(jsonb_typeof(faqs)='array');
-- Preserve approved existing records; new listings require admin review.
alter table public.nexora_job_posts alter column moderation_status set default 'pending';
alter table public.nexora_job_applications drop constraint nexora_job_applications_status_check;
alter table public.nexora_job_applications
 add constraint nexora_job_applications_status_check check(status in ('applied','under_review','shortlisted','interview_scheduled','selected','hired','rejected','withdrawn')),
 add column cover_message text not null default '',add column relevant_experience text not null default '',
 add column expected_salary integer check(expected_salary>=0),add column availability text not null default '',
 add column resume_path text not null default '',add column screening_answers text[] not null default '{}',
 add column consent_to_share boolean not null default false;

create table public.nexora_job_candidate_private (
 user_id uuid primary key references public.nexora_job_candidates(user_id) on delete cascade,
 mobile text not null check(mobile ~ '^\+?[0-9]{10,15}$'),email text not null default '',
 photo_path text not null default '',resume_path text not null default '',portfolio_paths text[] not null default '{}',
 updated_at timestamptz not null default now()
);
create table public.nexora_job_candidate_categories(candidate_id uuid references public.nexora_job_candidates(user_id) on delete cascade,category_id uuid references public.nexora_job_categories(id),primary key(candidate_id,category_id));
create table public.nexora_job_required_categories(job_id uuid references public.nexora_job_posts(id) on delete cascade,category_id uuid references public.nexora_job_categories(id),primary key(job_id,category_id));
create index on public.nexora_job_candidate_categories(category_id);
create index on public.nexora_job_required_categories(category_id);
create table public.nexora_job_public_salons (
 user_id uuid primary key references public.nexora_job_employers(user_id) on delete cascade,
 salon_name text not null,city text not null,state text not null,locality text not null,public_address text not null,
 business_category text not null,description text not null,logo_url text not null,website text not null,
 public_phone text not null,verified boolean not null default false,updated_at timestamptz not null default now()
);
create table public.nexora_job_saved (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 job_id uuid not null references public.nexora_job_posts(id),created_at timestamptz not null default now(),unique(user_id,job_id)
);
create table public.nexora_job_interviews (
 id uuid primary key default gen_random_uuid(),application_id uuid not null references public.nexora_job_applications(id),
 employer_id uuid not null references public.nexora_job_employers(user_id),candidate_id uuid not null references public.nexora_job_candidates(user_id),
 scheduled_at timestamptz not null,mode text not null check(mode in ('In person','Phone','Video')),
 details text not null default '',status text not null default 'scheduled' check(status in ('scheduled','completed','cancelled')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.nexora_job_assistance (
 id uuid primary key default gen_random_uuid(),employer_id uuid not null references public.nexora_job_employers(user_id),
 contact_name text not null check(length(trim(contact_name))>0),mobile text not null check(mobile ~ '^\+?[0-9]{10,15}$'),
 salon_name text not null,city text not null,locality text not null default '',required_category_ids uuid[] not null,
 positions integer not null check(positions>0),experience text not null default '',salary_budget integer not null check(salary_budget>=0),
 urgency text not null,services text[] not null,notes text not null default '',
 status text not null default 'pending' check(status in ('pending','in_progress','completed','cancelled')),
 admin_note text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.nexora_job_reports (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),job_id uuid references public.nexora_job_posts(id),
 reason text not null check(length(trim(reason))>0),details text not null default '',
 status text not null default 'pending' check(status in ('pending','reviewing','resolved','dismissed')),
 admin_note text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.nexora_job_verifications (
 id uuid primary key default gen_random_uuid(),employer_id uuid not null references public.nexora_job_employers(user_id),
 document_path text not null,notes text not null default '',
 status text not null default 'pending' check(status in ('pending','verified','rejected','additional_information_required')),
 admin_note text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.nexora_job_notifications (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 title text not null,message text not null,link text not null default '#dashboard',is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.nexora_job_accounts (
 user_id uuid primary key references auth.users(id),suspended boolean not null default false,
 reason text not null default '',updated_at timestamptz not null default now()
);
create table public.nexora_job_audit (
 id bigint generated always as identity primary key,actor_id uuid,event text not null,record_id text not null,
 changes jsonb not null default '{}',created_at timestamptz not null default now()
);
create table public.nexora_job_locations (
 id uuid primary key default gen_random_uuid(),city text not null,state text not null,is_active boolean not null default true,
 unique(city,state),created_at timestamptz not null default now()
);
create table public.nexora_job_content (
 slug text primary key,title text not null,body text not null,published boolean not null default false,
 updated_at timestamptz not null default now()
);
insert into public.nexora_job_content(slug,title,body,published) values
 ('privacy','Privacy policy','Nexora Salon Jobs stores your account and recruitment profile to provide job discovery, applications and hiring tools. Candidate profiles are private by default. If you enable discovery, salon employers can see your professional profile. When you apply and consent, the employer for that job can access your application and shared contact details or resume. Private documents use protected storage. You can change profile visibility, withdraw applications, and submit data or account requests through Contact. Never include unnecessary sensitive information in your public biography. This operational policy requires the business owner to add its legal entity, verified privacy contact and retention schedule before a production legal launch.',false),
 ('terms','Terms and conditions','Nexora Salon Jobs provides recruitment tools for candidates and salon employers. Supply accurate information and publish only genuine vacancies. Employers are responsible for lawful and appropriate eligibility criteria, interviews and hiring decisions. Verification is performed by an authorized administrator; registration does not confer verification. A job application, invitation or assisted hiring request does not guarantee employment or a hiring timeline. No platform hiring charge is currently configured. Report misleading jobs through Report Job. The business owner must approve and publish these terms with the legal entity, jurisdiction and applicable commercial terms before production legal launch.',false),
 ('contact','Contact Nexora','Use the support request form to report a problem or request help with your account. Your request is stored for authorized administrators. A public support email and phone have not yet been supplied by the business owner.',true)
 on conflict do nothing;
insert into public.nexora_job_locations(city,state) values ('Delhi','Delhi'),('Mumbai','Maharashtra'),('Pune','Maharashtra'),('Bengaluru','Karnataka'),('Hyderabad','Telangana'),('Chennai','Tamil Nadu'),('Jaipur','Rajasthan'),('Kolkata','West Bengal'),('Lucknow','Uttar Pradesh'),('Ahmedabad','Gujarat') on conflict do nothing;
insert into public.nexora_job_categories(name,name_hi,slug,sort_order) values
 ('Unisex Hairdresser','यूनिसेक्स हेयरड्रेसर','unisex-hairdresser',29),('Nail Artist','नेल आर्टिस्ट','nail-artist',30),('Trainer','ट्रेनर','trainer',31) on conflict(slug) do nothing;

create function nexora_jobs_private.active_account() returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and not exists(select 1 from public.nexora_job_accounts where user_id=auth.uid() and suspended)$$;
revoke all on function nexora_jobs_private.active_account() from public;
grant execute on function nexora_jobs_private.active_account() to authenticated;
-- Private trigger functions are not exposed as RPCs. Definer is required for derived relations, sanitized projections, notifications and audit writes.
create function nexora_jobs_private.sync_categories() returns trigger language plpgsql security definer set search_path='' as $$begin
 if TG_TABLE_NAME='nexora_job_candidates' then
  delete from public.nexora_job_candidate_categories where candidate_id=NEW.user_id;
  insert into public.nexora_job_candidate_categories select NEW.user_id,x from unnest(NEW.job_profile_category_ids) x;
 else
  delete from public.nexora_job_required_categories where job_id=NEW.id;
  insert into public.nexora_job_required_categories select NEW.id,x from unnest(NEW.required_category_ids) x;
 end if;return NEW;end$$;
create trigger sync_candidate_categories after insert or update of job_profile_category_ids on public.nexora_job_candidates for each row execute function nexora_jobs_private.sync_categories();
create trigger sync_required_categories after insert or update of required_category_ids on public.nexora_job_posts for each row execute function nexora_jobs_private.sync_categories();
insert into public.nexora_job_candidate_categories select user_id,unnest(job_profile_category_ids) from public.nexora_job_candidates on conflict do nothing;
insert into public.nexora_job_required_categories select id,unnest(required_category_ids) from public.nexora_job_posts on conflict do nothing;

create function nexora_jobs_private.sync_business() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.nexora_job_public_salons values(NEW.user_id,NEW.salon_name,NEW.city,NEW.state,NEW.locality,NEW.address,NEW.business_category,NEW.description,NEW.logo_url,NEW.website,case when NEW.contact_public then NEW.public_phone else '' end,NEW.verification_status='verified',now())
 on conflict(user_id) do update set salon_name=excluded.salon_name,city=excluded.city,state=excluded.state,locality=excluded.locality,public_address=excluded.public_address,business_category=excluded.business_category,description=excluded.description,logo_url=excluded.logo_url,website=excluded.website,public_phone=excluded.public_phone,verified=excluded.verified,updated_at=now();return NEW;end$$;
create trigger sync_business_public after insert or update on public.nexora_job_employers for each row execute function nexora_jobs_private.sync_business();
insert into public.nexora_job_public_salons select user_id,salon_name,city,state,locality,address,business_category,description,logo_url,website,case when contact_public then public_phone else '' end,verification_status='verified',now() from public.nexora_job_employers;
create function nexora_jobs_private.guard_employer() returns trigger language plpgsql set search_path='' as $$begin
 if not nexora_jobs_private.is_admin() and auth.uid() is not null then
  if TG_OP='INSERT' and (NEW.verification_status<>'pending' or NEW.verification_note<>'') then raise exception 'Verification requires administrator review' using errcode='42501';end if;
  if TG_OP='UPDATE' and (NEW.user_id<>OLD.user_id or NEW.verification_status<>OLD.verification_status or NEW.verification_note<>OLD.verification_note) then raise exception 'Verification and ownership cannot be changed' using errcode='42501';end if;
 end if;return NEW;end$$;
create trigger guard_employer_verification before insert or update on public.nexora_job_employers for each row execute function nexora_jobs_private.guard_employer();

create or replace function public.nexora_job_guard_post() returns trigger language plpgsql set search_path='' as $$begin
 if TG_OP='UPDATE' and (NEW.employer_id<>OLD.employer_id or NEW.id<>OLD.id) then raise exception 'Job ownership cannot be changed' using errcode='23514';end if;
 if not nexora_jobs_private.is_admin() and auth.uid() is not null then
  if TG_OP='INSERT' then if NEW.moderation_status<>'pending' or NEW.moderation_note<>'' then raise exception 'Only administrators can approve jobs' using errcode='42501';end if;
  else
   if NEW.moderation_status<>OLD.moderation_status or NEW.moderation_note<>OLD.moderation_note then raise exception 'Only administrators can moderate jobs' using errcode='42501';end if;
   if OLD.status in ('closed','filled','archived') and NEW.status not in ('published','archived') then raise exception 'Reopen this job before editing' using errcode='23514';end if;
   if (to_jsonb(NEW)-ARRAY['status','updated_at']) is distinct from (to_jsonb(OLD)-ARRAY['status','updated_at']) then NEW.moderation_status:='pending';end if;
  end if;
 end if;
 if NEW.status='published' and NEW.application_deadline<current_date then raise exception 'Application deadline is in the past' using errcode='23514';end if;
 if not NEW.contact_public then NEW.public_phone:='';end if;
 if NEW.gender_preference<>'Any' and length(trim(NEW.preference_justification))<10 then raise exception 'Explain the lawful job-specific reason for a gender preference' using errcode='23514';end if;
 if not (NEW.benefits <@ ARRAY['Accommodation','Food','Incentives','Overtime Pay','One-Side Fare','Salary in Bank']) then raise exception 'Invalid benefit' using errcode='23514';end if;
 if cardinality(NEW.required_skills)>100 or cardinality(NEW.screening_questions)>20 then raise exception 'Too many skills or screening questions' using errcode='23514';end if;
 return NEW;end$$;
drop trigger nexora_job_post_guard on public.nexora_job_posts;
create trigger nexora_job_post_guard before insert or update on public.nexora_job_posts for each row execute function public.nexora_job_guard_post();
create or replace function public.nexora_job_guard_application() returns trigger language plpgsql set search_path='' as $$declare job public.nexora_job_posts;begin
 if TG_OP='INSERT' then
  select * into job from public.nexora_job_posts where id=NEW.job_id for share;
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

create function nexora_jobs_private.guard_record() returns trigger language plpgsql set search_path='' as $$begin
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
  if TG_TABLE_NAME='nexora_job_candidate_private' and NEW.user_id<>OLD.user_id then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME in ('nexora_job_assistance','nexora_job_verifications') and (NEW.employer_id<>OLD.employer_id or NEW.id<>OLD.id) then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME='nexora_job_reports' and (NEW.user_id<>OLD.user_id or NEW.id<>OLD.id or NEW.job_id is distinct from OLD.job_id) then raise exception 'Identity cannot be changed';end if;
  if TG_TABLE_NAME='nexora_job_interviews' and (NEW.id<>OLD.id or NEW.application_id<>OLD.application_id or NEW.employer_id<>OLD.employer_id or NEW.candidate_id<>OLD.candidate_id) then raise exception 'Interview participants cannot be changed';end if;
  if not nexora_jobs_private.is_admin() then
   if TG_TABLE_NAME in ('nexora_job_reports','nexora_job_verifications') and (NEW.status<>OLD.status or NEW.admin_note<>OLD.admin_note) then raise exception 'Administrator review required' using errcode='42501';end if;
   if TG_TABLE_NAME='nexora_job_assistance' and (NEW.status not in ('pending','cancelled') or NEW.admin_note<>OLD.admin_note) then raise exception 'Administrator review required' using errcode='42501';end if;
  end if;
 elsif not nexora_jobs_private.is_admin() and TG_TABLE_NAME in ('nexora_job_reports','nexora_job_verifications','nexora_job_assistance') then
  if NEW.status<>'pending' or NEW.admin_note<>'' then raise exception 'Administrator review required' using errcode='42501';end if;
 end if;
 if TG_TABLE_NAME<>'nexora_job_notifications' then NEW.updated_at:=now();end if;return NEW;end$$;
create trigger guard_private before insert or update on public.nexora_job_candidate_private for each row execute function nexora_jobs_private.guard_record();
create trigger guard_interviews before insert or update on public.nexora_job_interviews for each row execute function nexora_jobs_private.guard_record();
create trigger guard_assistance before insert or update on public.nexora_job_assistance for each row execute function nexora_jobs_private.guard_record();
create trigger guard_reports before insert or update on public.nexora_job_reports for each row execute function nexora_jobs_private.guard_record();
create trigger guard_verifications before insert or update on public.nexora_job_verifications for each row execute function nexora_jobs_private.guard_record();

create function nexora_jobs_private.notify_event() returns trigger language plpgsql security definer set search_path='' as $$declare owner uuid;begin
 if TG_TABLE_NAME='nexora_job_applications' then
  select employer_id into owner from public.nexora_job_posts where id=NEW.job_id;
  if TG_OP='INSERT' then insert into public.nexora_job_notifications(user_id,title,message) values(owner,'New application','A candidate applied to your job. Review applications in My jobs.'),(NEW.candidate_id,'Application received','Your application has been saved in Nexora Salon Jobs.');
  elsif NEW.status<>OLD.status then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Application status updated','Your application status is now '||replace(NEW.status,'_',' ')||'.');end if;
 elsif TG_TABLE_NAME='nexora_job_invitations' then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Invitation to apply','An employer invited you to apply. Open Job alerts & invitations.');
 elsif TG_TABLE_NAME='nexora_job_interviews' then
  if NEW.status='scheduled' then update public.nexora_job_applications set status='interview_scheduled' where id=NEW.application_id;end if;
  insert into public.nexora_job_notifications(user_id,title,message) values(NEW.candidate_id,'Interview update','Your interview is '||NEW.status||'. Check Interviews for details.');
 elsif TG_TABLE_NAME='nexora_job_verifications' and TG_OP='UPDATE' and NEW.status<>OLD.status then
  update public.nexora_job_employers set verification_status=NEW.status,verification_note=NEW.admin_note where user_id=NEW.employer_id;
  insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Verification update','Your salon verification status is '||replace(NEW.status,'_',' ')||'.');
 elsif TG_TABLE_NAME='nexora_job_posts' and TG_OP='UPDATE' and NEW.moderation_status<>OLD.moderation_status then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Job moderation update','Your job is '||NEW.moderation_status||'. '||NEW.moderation_note);
 elsif TG_TABLE_NAME='nexora_job_assistance' and TG_OP='UPDATE' and NEW.status<>OLD.status then insert into public.nexora_job_notifications(user_id,title,message) values(NEW.employer_id,'Assisted hiring update','Your request is '||replace(NEW.status,'_',' ')||'. '||NEW.admin_note);
 end if;return NEW;end$$;
create trigger notify_application after insert or update on public.nexora_job_applications for each row execute function nexora_jobs_private.notify_event();
create trigger notify_invitation after insert on public.nexora_job_invitations for each row execute function nexora_jobs_private.notify_event();
create trigger notify_interview after insert or update on public.nexora_job_interviews for each row execute function nexora_jobs_private.notify_event();
create trigger notify_verification after update on public.nexora_job_verifications for each row execute function nexora_jobs_private.notify_event();
create trigger notify_job after update on public.nexora_job_posts for each row execute function nexora_jobs_private.notify_event();
create trigger notify_assistance after update on public.nexora_job_assistance for each row execute function nexora_jobs_private.notify_event();
create function nexora_jobs_private.audit_event() returns trigger language plpgsql security definer set search_path='' as $$begin
 if nexora_jobs_private.is_admin() then insert into public.nexora_job_audit(actor_id,event,record_id,changes) values(auth.uid(),TG_TABLE_NAME||':'||TG_OP,coalesce(to_jsonb(NEW)->>'id',to_jsonb(NEW)->>'user_id',to_jsonb(NEW)->>'slug'),jsonb_build_object('status',coalesce(to_jsonb(NEW)->>'status',to_jsonb(NEW)->>'verification_status',to_jsonb(NEW)->>'moderation_status'),'suspended',to_jsonb(NEW)->'suspended'));end if;return NEW;end$$;
do $$declare tab text;begin
 foreach tab in array ARRAY['categories','employers','posts','reports','verifications','assistance','accounts','locations','content'] loop
 execute format('create trigger audit_admin after insert or update on public.nexora_job_%I for each row execute function nexora_jobs_private.audit_event()',tab);end loop;end$$;

-- RLS. Existing policies are replaced only for this isolated portal.
do $$declare p record;begin for p in select tablename,policyname from pg_policies where schemaname='public' and tablename in ('nexora_job_candidates','nexora_job_employers','nexora_job_posts','nexora_job_applications','nexora_job_invitations') loop execute format('drop policy %I on public.%I',p.policyname,p.tablename);end loop;end$$;
create policy candidates_read on public.nexora_job_candidates for select to authenticated using(user_id=auth.uid() or nexora_jobs_private.is_admin() or (discoverable and nexora_jobs_private.active_account() and exists(select 1 from public.nexora_job_employers where user_id=auth.uid())) or exists(select 1 from public.nexora_job_applications a join public.nexora_job_posts j on j.id=a.job_id where a.candidate_id=user_id and j.employer_id=auth.uid()));
create policy candidates_insert on public.nexora_job_candidates for insert to authenticated with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy candidates_update on public.nexora_job_candidates for update to authenticated using(user_id=auth.uid() and nexora_jobs_private.active_account()) with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy employers_read on public.nexora_job_employers for select to authenticated using(user_id=auth.uid() or nexora_jobs_private.is_admin());
create policy employers_insert on public.nexora_job_employers for insert to authenticated with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy employers_update on public.nexora_job_employers for update to authenticated using((user_id=auth.uid() and nexora_jobs_private.active_account()) or nexora_jobs_private.is_admin()) with check((user_id=auth.uid() and nexora_jobs_private.active_account()) or nexora_jobs_private.is_admin());
create policy jobs_read on public.nexora_job_posts for select to anon,authenticated using((status='published' and moderation_status='approved' and (application_deadline is null or application_deadline>=current_date)) or employer_id=auth.uid() or nexora_jobs_private.is_admin() or exists(select 1 from public.nexora_job_saved s where s.job_id=nexora_job_posts.id and s.user_id=auth.uid()));
create policy jobs_insert on public.nexora_job_posts for insert to authenticated with check(employer_id=auth.uid() and nexora_jobs_private.active_account());
create policy jobs_update on public.nexora_job_posts for update to authenticated using((employer_id=auth.uid() and nexora_jobs_private.active_account()) or nexora_jobs_private.is_admin()) with check((employer_id=auth.uid() and nexora_jobs_private.active_account()) or nexora_jobs_private.is_admin());
create policy applications_read on public.nexora_job_applications for select to authenticated using(candidate_id=auth.uid() or nexora_jobs_private.is_admin() or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=auth.uid()));
create policy applications_insert on public.nexora_job_applications for insert to authenticated with check(candidate_id=auth.uid() and nexora_jobs_private.active_account());
create policy applications_update on public.nexora_job_applications for update to authenticated using((candidate_id=auth.uid() or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=auth.uid())) and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin()) with check((candidate_id=auth.uid() or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=auth.uid())) and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin());
create policy invitations_read on public.nexora_job_invitations for select to authenticated using(candidate_id=auth.uid() or employer_id=auth.uid() or nexora_jobs_private.is_admin());
create policy invitations_insert on public.nexora_job_invitations for insert to authenticated with check(employer_id=auth.uid() and nexora_jobs_private.active_account() and exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=auth.uid() and j.status='published' and j.moderation_status='approved' and (j.application_deadline is null or j.application_deadline>=current_date)) and exists(select 1 from public.nexora_job_candidates c where c.user_id=candidate_id and c.discoverable));

do $$declare tab text;begin foreach tab in array ARRAY['candidate_private','candidate_categories','required_categories','public_salons','saved','interviews','assistance','reports','verifications','notifications','accounts','audit','locations','content'] loop execute format('alter table public.nexora_job_%I enable row level security',tab);end loop;end$$;
create policy private_read on public.nexora_job_candidate_private for select to authenticated using(user_id=auth.uid() or nexora_jobs_private.is_admin() or exists(select 1 from public.nexora_job_applications a join public.nexora_job_posts j on j.id=a.job_id where a.candidate_id=user_id and a.consent_to_share and j.employer_id=auth.uid()));
create policy private_insert on public.nexora_job_candidate_private for insert to authenticated with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy private_update on public.nexora_job_candidate_private for update to authenticated using(user_id=auth.uid() and nexora_jobs_private.active_account()) with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy candidate_rel_read on public.nexora_job_candidate_categories for select to authenticated using(exists(select 1 from public.nexora_job_candidates c where c.user_id=candidate_id));
create policy job_rel_read on public.nexora_job_required_categories for select to anon,authenticated using(exists(select 1 from public.nexora_job_posts j where j.id=job_id));
create policy salons_read on public.nexora_job_public_salons for select to anon,authenticated using(true);
create policy saved_read on public.nexora_job_saved for select to authenticated using(user_id=auth.uid());
create policy saved_insert on public.nexora_job_saved for insert to authenticated with check(user_id=auth.uid() and nexora_jobs_private.active_account() and exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.status='published' and j.moderation_status='approved'));
create policy saved_delete on public.nexora_job_saved for delete to authenticated using(user_id=auth.uid());
create policy interviews_read on public.nexora_job_interviews for select to authenticated using(candidate_id=auth.uid() or employer_id=auth.uid() or nexora_jobs_private.is_admin());
create policy interviews_insert on public.nexora_job_interviews for insert to authenticated with check(employer_id=auth.uid() and nexora_jobs_private.active_account());
create policy interviews_update on public.nexora_job_interviews for update to authenticated using(employer_id=auth.uid() and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin()) with check(employer_id=auth.uid() and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin());
create policy assistance_read on public.nexora_job_assistance for select to authenticated using(employer_id=auth.uid() or nexora_jobs_private.is_admin());
create policy assistance_insert on public.nexora_job_assistance for insert to authenticated with check(employer_id=auth.uid() and nexora_jobs_private.active_account());
create policy assistance_update on public.nexora_job_assistance for update to authenticated using(employer_id=auth.uid() and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin()) with check(employer_id=auth.uid() and nexora_jobs_private.active_account() or nexora_jobs_private.is_admin());
create policy reports_read on public.nexora_job_reports for select to authenticated using(user_id=auth.uid() or nexora_jobs_private.is_admin());
create policy reports_insert on public.nexora_job_reports for insert to authenticated with check(user_id=auth.uid() and nexora_jobs_private.active_account());
create policy reports_admin on public.nexora_job_reports for update to authenticated using(nexora_jobs_private.is_admin()) with check(nexora_jobs_private.is_admin());
create policy verification_read on public.nexora_job_verifications for select to authenticated using(employer_id=auth.uid() or nexora_jobs_private.is_admin());
create policy verification_insert on public.nexora_job_verifications for insert to authenticated with check(employer_id=auth.uid() and nexora_jobs_private.active_account());
create policy verification_admin on public.nexora_job_verifications for update to authenticated using(nexora_jobs_private.is_admin()) with check(nexora_jobs_private.is_admin());
create policy notifications_read on public.nexora_job_notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_update on public.nexora_job_notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy accounts_read on public.nexora_job_accounts for select to authenticated using(user_id=auth.uid() or nexora_jobs_private.is_admin());
create policy accounts_admin on public.nexora_job_accounts for all to authenticated using(nexora_jobs_private.is_admin()) with check(nexora_jobs_private.is_admin());
create policy audit_read on public.nexora_job_audit for select to authenticated using(nexora_jobs_private.is_admin());
create policy locations_read on public.nexora_job_locations for select to anon,authenticated using(is_active or nexora_jobs_private.is_admin());
create policy locations_admin on public.nexora_job_locations for all to authenticated using(nexora_jobs_private.is_admin()) with check(nexora_jobs_private.is_admin());
create policy content_read on public.nexora_job_content for select to anon,authenticated using(published or nexora_jobs_private.is_admin());
create policy content_admin on public.nexora_job_content for all to authenticated using(nexora_jobs_private.is_admin()) with check(nexora_jobs_private.is_admin());
grant select on public.nexora_job_public_salons,public.nexora_job_required_categories,public.nexora_job_locations,public.nexora_job_content to anon,authenticated;
grant select on public.nexora_job_candidate_categories,public.nexora_job_audit to authenticated;
grant select,insert,update on public.nexora_job_candidate_private,public.nexora_job_interviews,public.nexora_job_assistance,public.nexora_job_reports,public.nexora_job_verifications,public.nexora_job_accounts,public.nexora_job_locations,public.nexora_job_content to authenticated;
grant select,insert,delete on public.nexora_job_saved to authenticated;
grant select,update(is_read) on public.nexora_job_notifications to authenticated;
revoke all on all functions in schema nexora_jobs_private from public;
grant execute on function nexora_jobs_private.is_admin() to anon,authenticated;
grant execute on function nexora_jobs_private.active_account() to authenticated;

create index on public.nexora_job_posts(salary_min);
create index on public.nexora_job_posts(lower(city),lower(state),salon_category);
create index on public.nexora_job_posts(experience_min,experience_max);
create index on public.nexora_job_posts using gin(benefits);
create index on public.nexora_job_posts using gin(to_tsvector('simple',title||' '||salon_name||' '||description));
create index on public.nexora_job_saved(job_id);
create index on public.nexora_job_interviews(application_id);
create index on public.nexora_job_interviews(candidate_id,scheduled_at);
create index on public.nexora_job_interviews(employer_id,scheduled_at);
create index on public.nexora_job_assistance(employer_id,created_at desc);
create index on public.nexora_job_reports(user_id,created_at desc);
create index on public.nexora_job_reports(job_id);
create index on public.nexora_job_verifications(employer_id,created_at desc);
create index on public.nexora_job_notifications(user_id,created_at desc);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('nexora-job-private','nexora-job-private',false,5242880,ARRAY['image/jpeg','image/png','image/webp','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
 ('nexora-job-verification','nexora-job-verification',false,5242880,ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
 ('nexora-job-logos','nexora-job-logos',true,2097152,ARRAY['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy nexora_jobs_upload on storage.objects for insert to authenticated with check(bucket_id in ('nexora-job-private','nexora-job-verification','nexora-job-logos') and (storage.foldername(name))[1]=auth.uid()::text and nexora_jobs_private.active_account());
create policy nexora_jobs_owner_delete on storage.objects for delete to authenticated using(bucket_id in ('nexora-job-private','nexora-job-verification','nexora-job-logos') and (storage.foldername(name))[1]=auth.uid()::text);
create policy nexora_jobs_private_read on storage.objects for select to authenticated using(bucket_id in ('nexora-job-private','nexora-job-verification','nexora-job-logos') and ((storage.foldername(name))[1]=auth.uid()::text or nexora_jobs_private.is_admin() or (bucket_id='nexora-job-private' and exists(select 1 from public.nexora_job_applications a join public.nexora_job_posts j on j.id=a.job_id where a.candidate_id::text=(storage.foldername(name))[1] and a.consent_to_share and j.employer_id=auth.uid()))));
create policy nexora_jobs_owner_update on storage.objects for update to authenticated using(bucket_id in ('nexora-job-private','nexora-job-verification','nexora-job-logos') and (storage.foldername(name))[1]=auth.uid()::text and nexora_jobs_private.active_account()) with check(bucket_id in ('nexora-job-private','nexora-job-verification','nexora-job-logos') and (storage.foldername(name))[1]=auth.uid()::text and nexora_jobs_private.active_account());

-- Secure, paginated database search. SECURITY INVOKER preserves caller RLS.
create function public.nexora_job_search(p_filters jsonb default '{}',p_page integer default 1,p_page_size integer default 12) returns jsonb language sql stable security invoker set search_path='' as $$
with matched as (
 select j.*,b.logo_url,b.verified from public.nexora_job_posts j left join public.nexora_job_public_salons b on b.user_id=j.employer_id
 where j.status='published' and j.moderation_status='approved' and (j.application_deadline is null or j.application_deadline>=current_date)
 and (coalesce(p_filters->>'query','')='' or to_tsvector('simple',j.title||' '||j.salon_name||' '||j.description) @@ websearch_to_tsquery('simple',p_filters->>'query') or exists(select 1 from unnest(j.required_skills)s where s ilike '%'||(p_filters->>'query')||'%'))
 and (coalesce(p_filters->>'city','')='' or j.city ilike '%'||(p_filters->>'city')||'%')
 and (coalesce(p_filters->>'state','')='' or j.state ilike '%'||(p_filters->>'state')||'%')
 and (coalesce(p_filters->>'locality','')='' or j.locality ilike '%'||(p_filters->>'locality')||'%')
 and (coalesce(p_filters->>'salon_category','')='' or j.salon_category=p_filters->>'salon_category')
 and (coalesce(p_filters->>'gender','')='' or j.gender_preference='Any' or j.gender_preference=p_filters->>'gender')
 and j.salary_min>=coalesce(nullif(p_filters->>'salary','')::integer,0)
 and (coalesce(p_filters->>'experience','')='' or (p_filters->>'experience'='fresher' and j.experience_min=0) or (p_filters->>'experience'='2-3' and j.experience_min<=3 and coalesce(j.experience_max,70)>=2) or (p_filters->>'experience'='3-5' and j.experience_min<=5 and coalesce(j.experience_max,70)>=3) or (p_filters->>'experience'='5+' and coalesce(j.experience_max,70)>=5))
 and (jsonb_array_length(coalesce(p_filters->'category_ids','[]'))=0 or (coalesce((p_filters->>'match_all')::boolean,false) and j.required_category_ids @> array(select x::uuid from jsonb_array_elements_text(p_filters->'category_ids')x)) or (not coalesce((p_filters->>'match_all')::boolean,false) and j.required_category_ids && array(select x::uuid from jsonb_array_elements_text(p_filters->'category_ids')x)))
 and j.benefits @> array(select x from jsonb_array_elements_text(coalesce(p_filters->'benefits','[]'))x)
),page as (select * from matched order by created_at desc,id limit least(greatest(p_page_size,1),50) offset (greatest(p_page,1)-1)*least(greatest(p_page_size,1),50))
select jsonb_build_object('results',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'),'total',(select count(*) from matched),'page',greatest(p_page,1),'page_size',least(greatest(p_page_size,1),50))$$;
revoke all on function public.nexora_job_search(jsonb,integer,integer) from public;
grant execute on function public.nexora_job_search(jsonb,integer,integer) to anon,authenticated;

-- Transactional five-step profile save; contact/document details never enter public candidate fields.
create function public.nexora_job_save_candidate(p_profile jsonb,p_private jsonb) returns public.nexora_job_candidates language plpgsql security invoker set search_path='' as $$declare result public.nexora_job_candidates;begin
 if auth.uid() is null or not nexora_jobs_private.active_account() then raise exception 'Active authenticated account required' using errcode='42501';end if;
 if not coalesce((p_profile->>'consent')::boolean,false) then raise exception 'Accept the privacy policy and terms' using errcode='23514';end if;
 if length(trim(coalesce(p_profile->>'state','')))=0 then raise exception 'State is required' using errcode='23514';end if;
 insert into public.nexora_job_candidates(user_id,full_name,city,state,experience_years,bio,job_profile_category_ids,discoverable,alerts_enabled,current_title,skills,services,qualification,languages,preferred_locations,expected_salary,availability,preferred_salon_category,employment_history,terms_accepted_at)
 values(auth.uid(),trim(p_profile->>'full_name'),trim(p_profile->>'city'),trim(p_profile->>'state'),coalesce((p_profile->>'experience_years')::integer,0),coalesce(p_profile->>'bio',''),array(select x::uuid from jsonb_array_elements_text(p_profile->'category_ids')x),coalesce((p_profile->>'discoverable')::boolean,false),coalesce((p_profile->>'alerts_enabled')::boolean,false),coalesce(p_profile->>'current_title',''),array(select jsonb_array_elements_text(coalesce(p_profile->'skills','[]'))),array(select jsonb_array_elements_text(coalesce(p_profile->'services','[]'))),coalesce(p_profile->>'qualification',''),array(select jsonb_array_elements_text(coalesce(p_profile->'languages','[]'))),array(select jsonb_array_elements_text(coalesce(p_profile->'preferred_locations','[]'))),coalesce((p_profile->>'expected_salary')::integer,0),coalesce(p_profile->>'availability',''),coalesce(p_profile->>'preferred_salon_category',''),coalesce(p_profile->>'employment_history',''),now())
 on conflict(user_id) do update set full_name=excluded.full_name,city=excluded.city,state=excluded.state,experience_years=excluded.experience_years,bio=excluded.bio,job_profile_category_ids=excluded.job_profile_category_ids,discoverable=excluded.discoverable,alerts_enabled=excluded.alerts_enabled,current_title=excluded.current_title,skills=excluded.skills,services=excluded.services,qualification=excluded.qualification,languages=excluded.languages,preferred_locations=excluded.preferred_locations,expected_salary=excluded.expected_salary,availability=excluded.availability,preferred_salon_category=excluded.preferred_salon_category,employment_history=excluded.employment_history,terms_accepted_at=excluded.terms_accepted_at returning * into result;
 insert into public.nexora_job_candidate_private(user_id,mobile,email,photo_path,resume_path,portfolio_paths) values(auth.uid(),p_private->>'mobile',coalesce(p_private->>'email',''),coalesce(p_private->>'photo_path',''),coalesce(p_private->>'resume_path',''),array(select jsonb_array_elements_text(coalesce(p_private->'portfolio_paths','[]')))) on conflict(user_id) do update set mobile=excluded.mobile,email=excluded.email,photo_path=excluded.photo_path,resume_path=excluded.resume_path,portfolio_paths=excluded.portfolio_paths;
 return result;end$$;
revoke all on function public.nexora_job_save_candidate(jsonb,jsonb) from public;
grant execute on function public.nexora_job_save_candidate(jsonb,jsonb) to authenticated;

-- Admin account directory is implemented privately with explicit authorization before auth schema reads.
create function nexora_jobs_private.admin_users() returns jsonb language plpgsql security definer set search_path='' as $$begin
 if not nexora_jobs_private.is_admin() then raise exception 'Administrator access required' using errcode='42501';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'email',u.email,'created_at',u.created_at,'suspended',coalesce(a.suspended,false),'reason',coalesce(a.reason,''))) from auth.users u left join public.nexora_job_accounts a on a.user_id=u.id where exists(select 1 from public.nexora_job_candidates c where c.user_id=u.id) or exists(select 1 from public.nexora_job_employers e where e.user_id=u.id)),'[]');end$$;
revoke all on function nexora_jobs_private.admin_users() from public;
grant execute on function nexora_jobs_private.admin_users() to authenticated;
create function public.nexora_job_admin_users() returns jsonb language sql security invoker set search_path='' as $$select nexora_jobs_private.admin_users()$$;
revoke all on function public.nexora_job_admin_users() from public;
grant execute on function public.nexora_job_admin_users() to authenticated;
notify pgrst,'reload schema';
