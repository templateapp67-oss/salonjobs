-- Nexora Salon Job Portal. Isolated from existing SalonOS tables.
create table public.nexora_job_categories (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0), name_hi text not null,
 slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'), description text not null default '',
 is_active boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.nexora_job_candidates (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check(length(trim(full_name))>0), city text not null check(length(trim(city))>0),
 experience_years integer not null default 0 check(experience_years between 0 and 70), bio text not null default '',
 job_profile_category_ids uuid[] not null, discoverable boolean not null default false, alerts_enabled boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.nexora_job_employers (
 user_id uuid primary key references auth.users(id) on delete cascade,
 salon_name text not null check(length(trim(salon_name))>0), city text not null check(length(trim(city))>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.nexora_job_posts (
 id uuid primary key default gen_random_uuid(), employer_id uuid not null references public.nexora_job_employers(user_id),
 title text not null check(length(trim(title))>0), salon_name text not null check(length(trim(salon_name))>0),
 city text not null check(length(trim(city))>0), description text not null check(length(trim(description))>0),
 salary_min integer not null check(salary_min>=0), salary_max integer not null check(salary_max>=salary_min),
 employment_type text not null default 'Full-time' check(employment_type in ('Full-time','Part-time','Contract','Internship')),
 required_category_ids uuid[] not null, status text not null default 'published' check(status in ('draft','published','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.nexora_job_applications (
 id uuid primary key default gen_random_uuid(), job_id uuid not null references public.nexora_job_posts(id),
 candidate_id uuid not null references public.nexora_job_candidates(user_id),
 status text not null default 'applied' check(status in ('applied','shortlisted','rejected','hired','withdrawn')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(job_id,candidate_id)
);
create table public.nexora_job_invitations (
 id uuid primary key default gen_random_uuid(), job_id uuid not null references public.nexora_job_posts(id),
 employer_id uuid not null references public.nexora_job_employers(user_id), candidate_id uuid not null references public.nexora_job_candidates(user_id),
 created_at timestamptz not null default now(), unique(job_id,candidate_id)
);
create index nexora_job_posts_categories_gin on public.nexora_job_posts using gin(required_category_ids);
create index nexora_job_candidates_categories_gin on public.nexora_job_candidates using gin(job_profile_category_ids);
create index nexora_job_posts_employer_idx on public.nexora_job_posts(employer_id);
create index nexora_job_applications_candidate_idx on public.nexora_job_applications(candidate_id);
create index nexora_job_invitations_candidate_idx on public.nexora_job_invitations(candidate_id);
create index nexora_job_invitations_employer_idx on public.nexora_job_invitations(employer_id);
create index nexora_job_posts_status_created_idx on public.nexora_job_posts(status,created_at desc);

create function public.nexora_job_validate_categories() returns trigger language plpgsql set search_path='' as $$
declare chosen uuid[]; previous uuid[] := '{}';
begin
 if TG_TABLE_NAME = 'nexora_job_candidates' then
  chosen := NEW.job_profile_category_ids;
  if TG_OP = 'UPDATE' then previous := OLD.job_profile_category_ids; end if;
 else
  chosen := NEW.required_category_ids;
  if TG_OP = 'UPDATE' then previous := OLD.required_category_ids; end if;
 end if;
 if chosen is null or cardinality(chosen)=0 then raise exception 'Select at least one job profile' using errcode='23514'; end if;
 if cardinality(chosen) > 100 or array_position(chosen,null) is not null or cardinality(chosen) <> (select count(distinct x) from unnest(chosen) x) then
  raise exception 'Duplicate or invalid category IDs' using errcode='23514'; end if;
 if exists(select 1 from unnest(chosen) x left join public.nexora_job_categories c on c.id=x where c.id is null or (not c.is_active and not (x=any(previous)))) then
  raise exception 'Invalid or inactive job profile category' using errcode='23514'; end if;
 NEW.updated_at := now(); return NEW;
end $$;
create trigger nexora_job_candidate_categories before insert or update on public.nexora_job_candidates for each row execute function public.nexora_job_validate_categories();
create trigger nexora_job_post_categories before insert or update on public.nexora_job_posts for each row execute function public.nexora_job_validate_categories();
create function public.nexora_job_touch() returns trigger language plpgsql set search_path='' as $$begin NEW.updated_at := now(); return NEW; end$$;
create trigger nexora_job_category_touch before update on public.nexora_job_categories for each row execute function public.nexora_job_touch();
create trigger nexora_job_employer_touch before update on public.nexora_job_employers for each row execute function public.nexora_job_touch();
create function public.nexora_job_guard_post() returns trigger language plpgsql set search_path='' as $$begin
 if OLD.status='closed' then raise exception 'Closed jobs cannot be edited' using errcode='23514'; end if;
 if NEW.employer_id <> OLD.employer_id or NEW.id <> OLD.id then raise exception 'Job ownership cannot be changed' using errcode='23514'; end if;
 return NEW; end$$;
create trigger nexora_job_post_guard before update on public.nexora_job_posts for each row execute function public.nexora_job_guard_post();
create function public.nexora_job_guard_application() returns trigger language plpgsql set search_path='' as $$begin
 if TG_OP='INSERT' then
  if NEW.status <> 'applied' or not exists(select 1 from public.nexora_job_posts where id=NEW.job_id and status='published') then raise exception 'This job is not accepting applications' using errcode='23514'; end if;
 else
  if NEW.job_id<>OLD.job_id or NEW.candidate_id<>OLD.candidate_id or NEW.id<>OLD.id then raise exception 'Application identity cannot be changed' using errcode='23514'; end if;
  if auth.uid()=OLD.candidate_id and NEW.status<>'withdrawn' then raise exception 'Candidates can only withdraw applications' using errcode='42501'; end if;
 end if;
 NEW.updated_at:=now();return NEW;
end $$;
create trigger nexora_job_application_guard before insert or update on public.nexora_job_applications for each row execute function public.nexora_job_guard_application();

alter table public.nexora_job_categories enable row level security;
alter table public.nexora_job_candidates enable row level security;
alter table public.nexora_job_employers enable row level security;
alter table public.nexora_job_posts enable row level security;
alter table public.nexora_job_applications enable row level security;
alter table public.nexora_job_invitations enable row level security;
create policy categories_read on public.nexora_job_categories for select to anon,authenticated using(true);
create policy categories_admin on public.nexora_job_categories for all to authenticated using((select auth.jwt())->'app_metadata'->>'job_portal_role'='admin') with check((select auth.jwt())->'app_metadata'->>'job_portal_role'='admin');
create policy candidates_read on public.nexora_job_candidates for select to authenticated using(
 user_id=(select auth.uid()) or (discoverable and exists(select 1 from public.nexora_job_employers e where e.user_id=(select auth.uid())))
 or exists(select 1 from public.nexora_job_applications a join public.nexora_job_posts j on j.id=a.job_id where a.candidate_id=user_id and j.employer_id=(select auth.uid()))
);
create policy candidates_insert on public.nexora_job_candidates for insert to authenticated with check(user_id=(select auth.uid()));
create policy candidates_update on public.nexora_job_candidates for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy employers_read on public.nexora_job_employers for select to authenticated using(user_id=(select auth.uid()));
create policy employers_insert on public.nexora_job_employers for insert to authenticated with check(user_id=(select auth.uid()));
create policy employers_update on public.nexora_job_employers for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy jobs_read on public.nexora_job_posts for select to anon,authenticated using(status in ('published','closed') or employer_id=(select auth.uid()));
create policy jobs_insert on public.nexora_job_posts for insert to authenticated with check(employer_id=(select auth.uid()));
create policy jobs_update on public.nexora_job_posts for update to authenticated using(employer_id=(select auth.uid())) with check(employer_id=(select auth.uid()));
create policy applications_read on public.nexora_job_applications for select to authenticated using(candidate_id=(select auth.uid()) or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=(select auth.uid())));
create policy applications_insert on public.nexora_job_applications for insert to authenticated with check(candidate_id=(select auth.uid()));
create policy applications_update on public.nexora_job_applications for update to authenticated using(candidate_id=(select auth.uid()) or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=(select auth.uid()))) with check(candidate_id=(select auth.uid()) or exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=(select auth.uid())));
create policy invitations_read on public.nexora_job_invitations for select to authenticated using(candidate_id=(select auth.uid()) or employer_id=(select auth.uid()));
create policy invitations_insert on public.nexora_job_invitations for insert to authenticated with check(employer_id=(select auth.uid()) and exists(select 1 from public.nexora_job_posts j where j.id=job_id and j.employer_id=(select auth.uid()) and j.status='published') and exists(select 1 from public.nexora_job_candidates c where c.user_id=candidate_id and c.discoverable));

grant select on public.nexora_job_categories,public.nexora_job_posts to anon;
grant select,insert,update on public.nexora_job_categories,public.nexora_job_candidates,public.nexora_job_employers,public.nexora_job_posts,public.nexora_job_applications to authenticated;
grant select,insert on public.nexora_job_invitations to authenticated;
revoke all on function public.nexora_job_validate_categories(), public.nexora_job_touch(), public.nexora_job_guard_post(), public.nexora_job_guard_application() from public,anon,authenticated;

insert into public.nexora_job_categories(name,name_hi,slug,sort_order) values
('Beautician','ब्यूटीशियन','beautician',0),
('Unisex Beautician','यूनिसेक्स ब्यूटीशियन','unisex-beautician',1),
('Makeup Artist','मेकअप आर्टिस्ट','makeup-artist',2),
('Gents Hairdresser','जेंट्स हेयरड्रेसर','gents-hairdresser',3),
('Ladies Hairdresser','लेडीज़ हेयरड्रेसर','ladies-hairdresser',4),
('Ladies Hairstylist','लेडीज़ हेयरस्टाइलिस्ट','ladies-hairstylist',5),
('Gents Hairstylist','जेंट्स हेयरस्टाइलिस्ट','gents-hairstylist',6),
('Nail Technician','नेल टेक्नीशियन','nail-technician',7),
('Mehndi Artist','मेहंदी आर्टिस्ट','mehndi-artist',8),
('Receptionist','रिसेप्शनिस्ट','receptionist',9),
('Salon Manager','सैलून मैनेजर','salon-manager',10),
('Hair Colorist','हेयर कलरिस्ट','hair-colorist',11),
('Spa Therapist','स्पा थेरेपिस्ट','spa-therapist',12),
('Waxing Expert','वैक्सिंग विशेषज्ञ','waxing-expert',13),
('Tattoo Artist','टैटू आर्टिस्ट','tattoo-artist',14),
('Beauty Therapist','ब्यूटी थेरेपिस्ट','beauty-therapist',15),
('Cosmetologist','कॉस्मेटोलॉजिस्ट','cosmetologist',16),
('Hair Extension / Wig Specialist','हेयर एक्सटेंशन / विग विशेषज्ञ','hair-extension-wig-specialist',17),
('Eyelash Artist','आईलैश आर्टिस्ट','eyelash-artist',18),
('Pedicurist','पेडिक्यूरिस्ट','pedicurist',19),
('Manicurist','मैनिक्यूरिस्ट','manicurist',20),
('Beauty Trainer','ब्यूटी ट्रेनर','beauty-trainer',21),
('Hair Trainer','हेयर ट्रेनर','hair-trainer',22),
('Makeup Trainer','मेकअप ट्रेनर','makeup-trainer',23),
('Salon Assistant / Helper','सैलून सहायक','salon-assistant-helper',24),
('Beauty Academy Instructor','ब्यूटी अकादमी प्रशिक्षक','beauty-academy-instructor',25),
('Massage Therapist','मसाज थेरेपिस्ट','massage-therapist',26),
('Sales / Retail Professional','सेल्स / रिटेल प्रोफेशनल','sales-retail-professional',27),
('Other','अन्य','other',28);
