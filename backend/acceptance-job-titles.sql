-- All fixtures, temporary deactivations and moderation changes are rolled back.
begin;
do $$declare labels text[];begin
 select array_agg(name order by sort_order) into labels from public.nexora_job_categories where is_active;
 if labels<>ARRAY['Beautician','Unisex Beautician','Makeup Artist','Gents Hairdresser','Ladies Hairdresser','Ladies Hairstylist','Gents Hairstylist','Nail Technician','Mehandi Artist','Receptionist','Salon Manager','Hair Colorist','Spa Therapist','Waxing Expert','Tattoo Artist'] then raise exception '15 exact labels mismatch';end if;
 if (select count(*) from public.nexora_job_categories)<>32 then raise exception 'Category master replaced or duplicated';end if;
end$$;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values ('de200000-0000-4000-8000-000000000001','category-candidate@example.invalid','{}','{}'),('de200000-0000-4000-8000-000000000002','category-owner@example.invalid','{}','{}'),('de200000-0000-4000-8000-000000000003','category-outsider@example.invalid','{}','{}');
select set_config('request.jwt.claims','{"sub":"de200000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select public.nexora_job_save_candidate(jsonb_build_object('full_name','Category QA','city','QA Job Title City','state','Delhi','experience_years',2,'discoverable',true,'consent',true,'category_ids',jsonb_build_array((select id from public.nexora_job_categories where slug='makeup-artist'),(select id from public.nexora_job_categories where slug='nail-technician'))),jsonb_build_object('mobile','9999999999','email','category-candidate@example.invalid'));
do $$declare inactive uuid;begin
 select id into inactive from public.nexora_job_categories where slug='beauty-therapist';
 if (select cardinality(job_profile_category_ids) from public.nexora_job_candidates where user_id=auth.uid())<>2 or (select count(*) from public.nexora_job_candidate_categories where candidate_id=auth.uid())<>2 then raise exception 'Candidate multi-select or relation sync failed';end if;
 begin update public.nexora_job_candidates set job_profile_category_ids='{}' where user_id=auth.uid();raise exception 'Empty candidate profiles accepted';exception when check_violation then null;end;
 begin update public.nexora_job_candidates set job_profile_category_ids=array[inactive] where user_id=auth.uid();raise exception 'Inactive new candidate selection accepted';exception when check_violation then null;end;
 begin update public.nexora_job_candidates set job_profile_category_ids=array[(select id from public.nexora_job_categories where slug='makeup-artist'),(select id from public.nexora_job_categories where slug='makeup-artist')] where user_id=auth.uid();raise exception 'Duplicate profiles accepted';exception when check_violation then null;end;
 begin update public.nexora_job_candidates set job_profile_category_ids=array['de200000-0000-4000-8000-000000000099'::uuid] where user_id=auth.uid();raise exception 'Unknown category accepted';exception when check_violation then null;end;
 begin update public.nexora_job_categories set name='Forged' where slug='makeup-artist';if found then raise exception 'Category master modification accepted';end if;exception when insufficient_privilege then null;end;
end$$;
reset role;
-- Exercise the real upsert RPC, not just a direct UPDATE, with a historical inactive ID.
update public.nexora_job_categories set is_active=false where slug='nail-technician';
select set_config('request.jwt.claims','{"sub":"de200000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select public.nexora_job_save_candidate(jsonb_build_object('full_name','Category QA updated','city','QA Job Title City','state','Delhi','experience_years',3,'discoverable',true,'consent',true,'category_ids',jsonb_build_array((select id from public.nexora_job_categories where slug='makeup-artist'),(select id from public.nexora_job_categories where slug='nail-technician'))),jsonb_build_object('mobile','9999999999','email','category-candidate@example.invalid'));
do $$begin if (select cardinality(job_profile_category_ids) from public.nexora_job_candidates where user_id=auth.uid())<>2 then raise exception 'Historical profile lost in upsert';end if;end$$;
reset role;
update public.nexora_job_categories set is_active=true where slug='nail-technician';
select set_config('request.jwt.claims','{"sub":"de200000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
insert into public.nexora_job_employers(user_id,salon_name,city,state) values(auth.uid(),'Category QA Salon','QA Job Title City','Delhi');
do $$declare makeup uuid; nail uuid; inactive uuid;begin
 select id into makeup from public.nexora_job_categories where slug='makeup-artist';select id into nail from public.nexora_job_categories where slug='nail-technician';select id into inactive from public.nexora_job_categories where slug='beauty-therapist';
 begin insert into public.nexora_job_posts(employer_id,title,salon_name,city,state,description,salary_min,salary_max,required_category_ids,status) values(auth.uid(),'Free text','Category QA Salon','QA Job Title City','Delhi','QA',10000,20000,array[makeup],'draft');raise exception 'Missing primary Job Title accepted';exception when check_violation then null;end;
 begin insert into public.nexora_job_posts(employer_id,title,salon_name,city,state,description,salary_min,salary_max,required_category_ids,primary_category_id,status) values(auth.uid(),'Inactive','Category QA Salon','QA Job Title City','Delhi','QA',10000,20000,array[inactive],inactive,'draft');raise exception 'Inactive Job Title accepted';exception when check_violation then null;end;
 begin insert into public.nexora_job_posts(employer_id,title,salon_name,city,state,description,salary_min,salary_max,required_category_ids,primary_category_id,status) values(auth.uid(),'Mixed','Category QA Salon','QA Job Title City','Delhi','QA',10000,20000,array[makeup,nail],makeup,'draft');raise exception 'Multiple primary title targets accepted';exception when check_violation then null;end;
 insert into public.nexora_job_posts(id,employer_id,title,salon_name,city,state,description,salary_min,salary_max,required_category_ids,primary_category_id,status) values('de200000-0000-4000-8000-000000000010',auth.uid(),'Poisoned free text','Category QA Salon','QA Job Title City','Delhi','QA',10000,20000,array[makeup],makeup,'draft'),('de200000-0000-4000-8000-000000000011',auth.uid(),'Other free text','Category QA Salon','QA Job Title City','Delhi','QA',10000,20000,array[nail],nail,'draft');
 if not exists(select 1 from public.nexora_job_posts where id='de200000-0000-4000-8000-000000000010' and title='Makeup Artist' and primary_category_id=makeup and required_category_ids=array[makeup]) then raise exception 'Canonical title or ID not persisted';end if;
 if (select count(*) from public.nexora_job_required_categories where job_id='de200000-0000-4000-8000-000000000010')<>1 then raise exception 'Required category relation not synced';end if;
 update public.nexora_job_posts set primary_category_id=nail,required_category_ids=array[nail] where id='de200000-0000-4000-8000-000000000010';
 if (select title from public.nexora_job_posts where id='de200000-0000-4000-8000-000000000010')<>'Nail Technician' then raise exception 'Editable job title not changed';end if;
 update public.nexora_job_posts set primary_category_id=makeup,required_category_ids=array[makeup] where id='de200000-0000-4000-8000-000000000010';
 if not exists(select 1 from public.nexora_job_candidates where city='QA Job Title City' and job_profile_category_ids && array[makeup]) then raise exception 'Candidate professional filter missed match';end if;
 if exists(select 1 from public.nexora_job_candidates where city='QA Job Title City' and job_profile_category_ids && array[(select id from public.nexora_job_categories where slug='tattoo-artist')]) then raise exception 'Candidate professional filter returned unrelated match';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{}',true);
update public.nexora_job_posts set status='published',moderation_status='approved' where id in ('de200000-0000-4000-8000-000000000010','de200000-0000-4000-8000-000000000011');
select set_config('request.jwt.claims','{"role":"anon"}',true);set local role anon;
do $$declare result jsonb; makeup uuid; nail uuid;begin
 select id into makeup from public.nexora_job_categories where slug='makeup-artist';select id into nail from public.nexora_job_categories where slug='nail-technician';
 result:=public.nexora_job_search(jsonb_build_object('city','QA Job Title City','category_ids',jsonb_build_array(makeup)),1,12);if (result->>'total')::int<>1 or result->'results'->0->>'title'<>'Makeup Artist' then raise exception 'Single profile search failed';end if;
 result:=public.nexora_job_search(jsonb_build_object('city','QA Job Title City','category_ids',jsonb_build_array(makeup,nail)),1,12);if (result->>'total')::int<>2 then raise exception 'Multiple any-profile search failed';end if;
 result:=public.nexora_job_search(jsonb_build_object('city','QA Job Title City','category_ids',jsonb_build_array(makeup,nail),'match_all',true),1,12);if (result->>'total')::int<>0 then raise exception 'All-profile search failed';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de200000-0000-4000-8000-000000000003","role":"authenticated"}',true);set local role authenticated;
do $$declare changed int;begin
 update public.nexora_job_candidates set job_profile_category_ids=array[(select id from public.nexora_job_categories where slug='tattoo-artist')] where user_id='de200000-0000-4000-8000-000000000001';get diagnostics changed=row_count;if changed<>0 then raise exception 'Cross-user candidate update accepted';end if;
 update public.nexora_job_posts set primary_category_id=(select id from public.nexora_job_categories where slug='tattoo-artist') where id='de200000-0000-4000-8000-000000000010';get diagnostics changed=row_count;if changed<>0 then raise exception 'Cross-user job title update accepted';end if;
 begin insert into public.nexora_job_candidate_categories(candidate_id,category_id) values('de200000-0000-4000-8000-000000000001',(select id from public.nexora_job_categories where slug='tattoo-artist'));raise exception 'Unauthorized relationship write accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;rollback;
select 'PASS: exact 15 labels, same 32 stable IDs, candidate multi-select/relations, validation, inactive upsert history, required canonical primary job title, job edit, real any/all job search, candidate search and RLS denial. All fixtures rolled back.' as category_checks;
