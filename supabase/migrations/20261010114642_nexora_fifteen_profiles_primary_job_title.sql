-- Reuse existing category UUIDs and relationships. Retain excluded categories as history.
do $$begin
 if (select count(*) from public.nexora_job_categories where slug in ('beautician','unisex-beautician','makeup-artist','gents-hairdresser','ladies-hairdresser','ladies-hairstylist','gents-hairstylist','nail-technician','mehndi-artist','receptionist','salon-manager','hair-colorist','spa-therapist','waxing-expert','tattoo-artist'))<>15 then raise exception 'Expected 15 existing category rows; migration stopped without creating duplicates';end if;
end$$;
with requested(slug,name,sort_order) as (values
('beautician','Beautician',0),('unisex-beautician','Unisex Beautician',1),('makeup-artist','Makeup Artist',2),('gents-hairdresser','Gents Hairdresser',3),('ladies-hairdresser','Ladies Hairdresser',4),('ladies-hairstylist','Ladies Hairstylist',5),('gents-hairstylist','Gents Hairstylist',6),('nail-technician','Nail Technician',7),('mehndi-artist','Mehandi Artist',8),('receptionist','Receptionist',9),('salon-manager','Salon Manager',10),('hair-colorist','Hair Colorist',11),('spa-therapist','Spa Therapist',12),('waxing-expert','Waxing Expert',13),('tattoo-artist','Tattoo Artist',14))
update public.nexora_job_categories c set name=r.name,sort_order=r.sort_order,is_active=true from requested r where c.slug=r.slug and (c.name,c.sort_order,c.is_active) is distinct from (r.name,r.sort_order,true);
update public.nexora_job_categories set is_active=false where is_active and slug not in ('beautician','unisex-beautician','makeup-artist','gents-hairdresser','ladies-hairdresser','ladies-hairstylist','gents-hairstylist','nail-technician','mehndi-artist','receptionist','salon-manager','hair-colorist','spa-therapist','waxing-expert','tattoo-artist');
-- Existing vacancies remain unchanged and unclassified until an owner chooses a primary title.
alter table public.nexora_job_posts add column primary_category_id uuid references public.nexora_job_categories(id) on delete restrict;
create index nexora_job_posts_primary_category_idx on public.nexora_job_posts(primary_category_id);
create function nexora_jobs_private.validate_primary_job_title() returns trigger language plpgsql security invoker set search_path='' as $$
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
 if NEW.required_category_ids is distinct from ARRAY[NEW.primary_category_id] then raise exception 'A vacancy must target its one primary Job Title' using errcode='23514';end if;
 if changed then NEW.title:=category_name;
 elsif TG_OP='UPDATE' and NEW.title is distinct from OLD.title and NEW.title<>category_name then raise exception 'Job Title must match its category' using errcode='23514';end if;
 return NEW;
end$$;
revoke all on function nexora_jobs_private.validate_primary_job_title() from public,anon,authenticated;
-- Run before existing category and moderation guards so they see the canonical title.
create trigger a_validate_primary_job_title before insert or update on public.nexora_job_posts for each row execute function nexora_jobs_private.validate_primary_job_title();
notify pgrst,'reload schema';
