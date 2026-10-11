-- Atomic rollback test: no accounts or records survive.
begin;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
('de000000-0000-4000-8000-000000000001','nexora-qa-candidate@example.invalid','{}','{}'),
('de000000-0000-4000-8000-000000000002','nexora-qa-employer@example.invalid','{}','{}'),
('de000000-0000-4000-8000-000000000003','nexora-qa-outsider@example.invalid','{}','{}'),
('de000000-0000-4000-8000-000000000004','nexora-qa-admin@example.invalid','{"job_portal_role":"admin"}','{}');
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
insert into public.nexora_job_posts(id,employer_id,title,salon_name,city,description,salary_min,salary_max,state,required_category_ids) values('de000000-0000-4000-8000-000000000010',auth.uid(),'Makeup Artist','QA Salon','Delhi','QA rollback test',10000,20000,'Delhi',array[(select id from public.nexora_job_categories where slug='makeup-artist')]);
do $$begin
 if not exists(select 1 from public.nexora_job_candidates where job_profile_category_ids && array[(select id from public.nexora_job_categories where slug='makeup-artist')]) then raise exception 'Candidate category search failed';end if;
 if exists(select 1 from public.nexora_job_posts where required_category_ids && array[(select id from public.nexora_job_categories where slug='nail-technician')]) then raise exception 'Unrelated job matched';end if;
end$$;
-- New jobs are pending; owner cannot self-approve. Admin moderation is server-authorized.
do $$begin begin update public.nexora_job_posts set moderation_status='approved' where id='de000000-0000-4000-8000-000000000010';raise exception 'Owner self-approval allowed';exception when insufficient_privilege then null;end;
begin update public.nexora_job_employers set verification_status='verified' where user_id=auth.uid();raise exception 'Owner self-verification allowed';exception when insufficient_privilege then null;end;end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"job_portal_role":"admin"}}',true);
set local role authenticated;
update public.nexora_job_posts set moderation_status='approved' where id='de000000-0000-4000-8000-000000000010';
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
insert into public.nexora_job_invitations(job_id,employer_id,candidate_id) values('de000000-0000-4000-8000-000000000010',auth.uid(),'de000000-0000-4000-8000-000000000001');
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$begin
 if not exists(select 1 from public.nexora_job_posts where required_category_ids && (select job_profile_category_ids from public.nexora_job_candidates where user_id=auth.uid())) then raise exception 'Job match failed';end if;
 if not exists(select 1 from public.nexora_job_invitations where candidate_id=auth.uid()) then raise exception 'Invitation not visible';end if;
end$$;
insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000010',auth.uid(),true);
do $$begin
 begin
 update public.nexora_job_applications set status='hired' where candidate_id=auth.uid();raise exception 'Candidate could self hire';
 exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
update public.nexora_job_applications set status='shortlisted' where job_id='de000000-0000-4000-8000-000000000010';
insert into public.nexora_job_interviews(application_id,employer_id,candidate_id,scheduled_at,mode,details) select id,auth.uid(),candidate_id,now()+interval '1 day','Video','QA interview' from public.nexora_job_applications where job_id='de000000-0000-4000-8000-000000000010';
do $$begin if (select status from public.nexora_job_applications where job_id='de000000-0000-4000-8000-000000000010')<>'interview_scheduled' then raise exception 'Interview status sync failed';end if;end$$;
update public.nexora_job_posts set status='closed' where id='de000000-0000-4000-8000-000000000010';
do $$begin
 begin
 update public.nexora_job_posts set title='Must fail' where id='de000000-0000-4000-8000-000000000010';raise exception 'Closed job edit allowed';
 exception when check_violation then null;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$declare p jsonb;begin
p:=jsonb_build_object('full_name','QA Candidate','city','Delhi','state','Delhi','category_ids',jsonb_build_array((select id from public.nexora_job_categories where slug='makeup-artist')),'consent',true,'skills',jsonb_build_array('Bridal makeup'),'expected_salary',12000);
perform public.nexora_job_save_candidate(p,jsonb_build_object('mobile','9999999999','email','qa@example.invalid'));
if (select count(*) from public.nexora_job_candidate_categories where candidate_id=auth.uid())<>1 then raise exception 'Relational sync failed';end if;
begin perform public.nexora_job_save_candidate(p,jsonb_build_object('mobile','bad'));raise exception 'Invalid phone accepted';exception when check_violation then null;end;
begin insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000010',auth.uid(),true);raise exception 'Closed job application accepted';exception when check_violation then null;end;
if not exists(select 1 from public.nexora_job_notifications where user_id=auth.uid()) then raise exception 'Inbox notification missing';end if;
if not exists(select 1 from public.nexora_job_interviews where candidate_id=auth.uid()) then raise exception 'Interview invisible to candidate';end if;
begin perform public.nexora_job_admin_users();raise exception 'User directory exposed';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000003","role":"authenticated","user_metadata":{"job_portal_role":"admin"}}',true);
set local role authenticated;
do $$begin
if exists(select 1 from public.nexora_job_candidate_private) then raise exception 'Private contact leaked';end if;
if exists(select 1 from public.nexora_job_applications) then raise exception 'Other applications leaked';end if;
if exists(select 1 from public.nexora_job_interviews) then raise exception 'Other interviews leaked';end if;
begin perform public.nexora_job_admin_users();raise exception 'User metadata forged admin';exception when insufficient_privilege then null;end;
end$$;
reset role;
-- Real numeric database filtering, pagination and expired applications.
select set_config('request.jwt.claims','{}',true);
insert into public.nexora_job_posts(id,employer_id,title,salon_name,city,state,description,salary_min,salary_max,required_category_ids,moderation_status,benefits,experience_min,experience_max,application_deadline) values
('de000000-0000-4000-8000-000000000011','de000000-0000-4000-8000-000000000002','Nail technician','QA Salon','Delhi','Delhi','QA rollback search',25000,30000,array[(select id from public.nexora_job_categories where slug='nail-technician')],'approved',array['Food'],2,4,current_date+1);
set local role anon;
do $$declare r jsonb;begin
r:=public.nexora_job_search('{"city":"Delhi","query":"Nail technician","salary":20000,"experience":"2-3","benefits":["Food"]}',1,1);
if (r->>'total')::int<>1 or jsonb_array_length(r->'results')<>1 then raise exception 'Combined search failed';end if;
if (public.nexora_job_search('{"city":"Delhi","query":"Nail technician","salary":40000}',1,12)->>'total')::int<>0 then raise exception 'Salary filter failed';end if;
if jsonb_array_length(public.nexora_job_search('{"city":"Delhi","query":"Nail technician"}',2,1)->'results')<>0 then raise exception 'Pagination failed';end if;
if has_table_privilege('anon','public.nexora_job_candidate_private','select') then raise exception 'Anonymous private table has grant';end if;
end$$;
reset role;
-- Saved records, consent, verification, assistance, protected storage and suspension.
select set_config('request.jwt.claims','{}',true);
insert into storage.objects(bucket_id,name) values('nexora-job-verification','de000000-0000-4000-8000-000000000002/verification/qa.pdf'),('nexora-job-private','de000000-0000-4000-8000-000000000001/resume/qa.pdf');
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
insert into public.nexora_job_saved(user_id,job_id) values(auth.uid(),'de000000-0000-4000-8000-000000000011');
do $$begin
begin insert into public.nexora_job_saved(user_id,job_id) values(auth.uid(),'de000000-0000-4000-8000-000000000011');raise exception 'Duplicate saved job accepted';exception when unique_violation then null;end;
begin insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000011',auth.uid(),false);raise exception 'Missing consent accepted';exception when check_violation then null;end;
end$$;
insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000011',auth.uid(),true);
do $$begin begin insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000011',auth.uid(),true);raise exception 'Duplicate application accepted';exception when unique_violation then null;end;end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
insert into public.nexora_job_verifications(employer_id,document_path) values(auth.uid(),'de000000-0000-4000-8000-000000000002/verification/qa.pdf');
insert into public.nexora_job_assistance(employer_id,contact_name,mobile,salon_name,city,required_category_ids,positions,salary_budget,urgency,services) values(auth.uid(),'QA employer','9999999999','QA Salon','Delhi',array[(select id from public.nexora_job_categories where slug='makeup-artist')],2,20000,'This week',array['Shortlisting']);
do $$begin
if not exists(select 1 from storage.objects where bucket_id='nexora-job-private' and name='de000000-0000-4000-8000-000000000001/resume/qa.pdf') then raise exception 'Consented employer document unavailable';end if;
begin update public.nexora_job_verifications set status='verified' where employer_id=auth.uid();exception when insufficient_privilege then null;end;if exists(select 1 from public.nexora_job_verifications where employer_id=auth.uid() and status='verified') then raise exception 'Employer self verification accepted';end if;
begin update public.nexora_job_assistance set status='completed' where employer_id=auth.uid();raise exception 'Employer marked service completed';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$begin if exists(select 1 from storage.objects where name like 'de000000-%/resume/qa.pdf' or name like 'de000000-%/verification/qa.pdf') then raise exception 'Outsider reads private storage';end if;end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"job_portal_role":"admin"}}',true);
set local role authenticated;
update public.nexora_job_verifications set status='verified',admin_note='QA approval' where employer_id='de000000-0000-4000-8000-000000000002';
update public.nexora_job_assistance set status='in_progress' where employer_id='de000000-0000-4000-8000-000000000002';
insert into public.nexora_job_accounts(user_id,suspended,reason) values('de000000-0000-4000-8000-000000000001',true,'QA suspension');
do $$begin if not exists(select 1 from public.nexora_job_public_salons where user_id='de000000-0000-4000-8000-000000000002' and verified) then raise exception 'Verified projection not synchronized';end if;if not exists(select 1 from public.nexora_job_audit) then raise exception 'Audit not recorded';end if;end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$begin begin update public.nexora_job_candidates set bio='Suspended mutation' where user_id=auth.uid();exception when insufficient_privilege then null;end;if exists(select 1 from public.nexora_job_candidates where user_id=auth.uid() and bio='Suspended mutation') then raise exception 'Suspension failed';end if;end$$;
reset role;

select set_config('request.jwt.claims','{}',true);
update public.nexora_job_posts set application_deadline=current_date-1,status='closed' where id='de000000-0000-4000-8000-000000000011';
select set_config('request.jwt.claims','{"sub":"de000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$begin begin insert into public.nexora_job_applications(job_id,candidate_id,consent_to_share) values('de000000-0000-4000-8000-000000000011',auth.uid(),true);raise exception 'Expired job accepts application';exception when check_violation then null;end;end$$;
reset role;
rollback;

