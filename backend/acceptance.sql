-- Atomic rollback test: no accounts or records survive.
begin;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
('de000000-0000-4000-8000-000000000001','nexora-qa-candidate@example.invalid','{}','{}'),
('de000000-0000-4000-8000-000000000002','nexora-qa-employer@example.invalid','{}','{}'),
('de000000-0000-4000-8000-000000000003','nexora-qa-outsider@example.invalid','{}','{}');
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$declare ids uuid[];begin
 select array_agg(id) into ids from (select id from public.nexora_job_categories where is_active order by sort_order limit 3) c;
 if cardinality(ids)<>3 then raise exception 'Missing categories';end if;
 insert into public.nexora_job_candidates(user_id,full_name,city,job_profile_category_ids,discoverable,alerts_enabled) values(auth.uid(),'QA Candidate','Delhi',ids,true,true);
 if (select cardinality(job_profile_category_ids) from public.nexora_job_candidates where user_id=auth.uid())<>3 then raise exception 'Multi profile persistence failed';end if;
 begin
 update public.nexora_job_candidates set job_profile_category_ids='{}' where user_id=auth.uid();raise exception 'Empty IDs accepted';
 exception when check_violation then null;end;
 begin
 update public.nexora_job_candidates set job_profile_category_ids=array[ids[1],ids[1]] where user_id=auth.uid();raise exception 'Duplicate IDs accepted';
 exception when check_violation then null;end;
 begin
 update public.nexora_job_candidates set job_profile_category_ids=array['de000000-0000-4000-8000-000000000099'::uuid] where user_id=auth.uid();raise exception 'Unknown IDs accepted';
 exception when check_violation then null;end;
 begin
 insert into public.nexora_job_categories(name,name_hi,slug) values('Unauthorized','Unauthorized','unauthorized-qa');raise exception 'Unauthorized category admin accepted';
 exception when insufficient_privilege then null;end;
end$$;
reset role;
update public.nexora_job_categories set is_active=false where slug='beautician';
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$begin
 update public.nexora_job_candidates set bio='Saved inactive category retained' where user_id=auth.uid();
 if not exists(select 1 from public.nexora_job_candidates where user_id=auth.uid() and (select id from public.nexora_job_categories where slug='beautician')=any(job_profile_category_ids)) then raise exception 'History lost';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$declare inactive uuid;begin
 select id into inactive from public.nexora_job_categories where slug='beautician';
 begin
 insert into public.nexora_job_candidates(user_id,full_name,city,job_profile_category_ids) values(auth.uid(),'Outsider','Delhi',array[inactive]);raise exception 'Inactive new selection accepted';
 exception when check_violation then null;end;
 begin
 insert into public.nexora_job_candidates(user_id,full_name,city,job_profile_category_ids) values('de000000-0000-4000-8000-000000000002','Forged','Delhi',array[(select id from public.nexora_job_categories where slug='makeup-artist')]);raise exception 'Forged owner accepted';
 exception when insufficient_privilege then null;end;
 if exists(select 1 from public.nexora_job_candidates where user_id='de000000-0000-4000-8000-000000000001') then raise exception 'Candidate directory exposed to non employers';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
insert into public.nexora_job_employers(user_id,salon_name,city) values(auth.uid(),'QA Salon','Delhi');
insert into public.nexora_job_posts(id,employer_id,title,salon_name,city,description,salary_min,salary_max,required_category_ids) values('de000000-0000-4000-8000-000000000010',auth.uid(),'Makeup Artist','QA Salon','Delhi','QA rollback test',10000,20000,array[(select id from public.nexora_job_categories where slug='makeup-artist')]);
do $$begin
 if not exists(select 1 from public.nexora_job_candidates where job_profile_category_ids && array[(select id from public.nexora_job_categories where slug='makeup-artist')]) then raise exception 'Candidate category search failed';end if;
 if exists(select 1 from public.nexora_job_posts where required_category_ids && array[(select id from public.nexora_job_categories where slug='nail-technician')]) then raise exception 'Unrelated job matched';end if;
end$$;
insert into public.nexora_job_invitations(job_id,employer_id,candidate_id) values('de000000-0000-4000-8000-000000000010',auth.uid(),'de000000-0000-4000-8000-000000000001');
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$begin
 if not exists(select 1 from public.nexora_job_posts where required_category_ids && (select job_profile_category_ids from public.nexora_job_candidates where user_id=auth.uid())) then raise exception 'Job match failed';end if;
 if not exists(select 1 from public.nexora_job_invitations where candidate_id=auth.uid()) then raise exception 'Invitation not visible';end if;
end$$;
insert into public.nexora_job_applications(job_id,candidate_id) values('de000000-0000-4000-8000-000000000010',auth.uid());
do $$begin
 begin
 update public.nexora_job_applications set status='hired' where candidate_id=auth.uid();raise exception 'Candidate could self hire';
 exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
update public.nexora_job_applications set status='shortlisted' where job_id='de000000-0000-4000-8000-000000000010';
update public.nexora_job_posts set status='closed' where id='de000000-0000-4000-8000-000000000010';
do $$begin
 begin
 update public.nexora_job_posts set title='Must fail' where id='de000000-0000-4000-8000-000000000010';raise exception 'Closed job edit allowed';
 exception when check_violation then null;end;
end$$;
reset role;
rollback;
