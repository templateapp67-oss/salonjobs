-- Transactional metadata/RLS test; no test accounts or records survive.
begin;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values ('de100000-0000-4000-8000-000000000001','profile-qa@example.invalid','{}','{}'),('de100000-0000-4000-8000-000000000002','profile-owner-qa@example.invalid','{}','{}'),('de100000-0000-4000-8000-000000000003','profile-outsider-qa@example.invalid','{}','{}');
select set_config('request.jwt.claims','{"sub":"de100000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
insert into storage.objects(bucket_id,name,metadata) values
('nexora-job-private',auth.uid()::text||'/photo/good.png','{"mimetype":"image/png","size":100}'),
('nexora-job-private',auth.uid()::text||'/photo/bad.pdf','{"mimetype":"application/pdf","size":100}'),
('nexora-job-private',auth.uid()::text||'/photo/large.png','{"mimetype":"image/png","size":5242881}');
select public.nexora_job_save_candidate(jsonb_build_object('full_name','Profile QA','city','Delhi','state','Delhi','experience_years',3,'bio','Beauty specialist','skills',jsonb_build_array('Makeup'),'services',jsonb_build_array('Bridal'),'qualification','Diploma','languages',jsonb_build_array('Hindi','English'),'preferred_locations',jsonb_build_array('Delhi'),'expected_salary',25000,'availability','Immediately','employment_history','QA Salon','consent',true,'category_ids',jsonb_build_array((select id from public.nexora_job_categories where is_active limit 1))),jsonb_build_object('mobile','9999999999','email','profile-qa@example.invalid','photo_path',auth.uid()::text||'/photo/good.png'));
do $$begin
 if not exists(select 1 from public.nexora_job_candidates where user_id=auth.uid() and qualification='Diploma' and expected_salary=25000 and languages=array['Hindi','English']) then raise exception 'Professional fields not saved';end if;
 if not exists(select 1 from public.nexora_job_candidate_private where user_id=auth.uid() and photo_path=auth.uid()::text||'/photo/good.png') then raise exception 'Photo not restored';end if;
 begin update public.nexora_job_candidate_private set photo_path=auth.uid()::text||'/photo/bad.pdf' where user_id=auth.uid();raise exception 'PDF photo accepted';exception when check_violation then null;end;
 begin update public.nexora_job_candidate_private set photo_path=auth.uid()::text||'/photo/large.png' where user_id=auth.uid();raise exception 'Oversized photo accepted';exception when check_violation then null;end;
 begin update public.nexora_job_candidate_private set photo_path='de100000-0000-4000-8000-000000000002/photo/good.png' where user_id=auth.uid();raise exception 'Foreign photo accepted';exception when check_violation then null;end;
 if not exists(select 1 from public.nexora_job_candidate_private where user_id=auth.uid() and photo_path=auth.uid()::text||'/photo/good.png') then raise exception 'Failed replacement lost original';end if;
 update public.nexora_job_candidate_private set photo_path='' where user_id=auth.uid();
 if not exists(select 1 from public.nexora_job_candidate_private where user_id=auth.uid() and photo_path='') then raise exception 'Removal failed';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de100000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
insert into storage.objects(bucket_id,name,metadata) values('nexora-job-private',auth.uid()::text||'/photo/owner.png','{"mimetype":"image/png","size":100}');
insert into public.nexora_job_employers(user_id,salon_name,contact_name,mobile,email,city,state,address,description,profile_photo_path) values(auth.uid(),'QA Salon','Owner QA','9999999999','profile-owner-qa@example.invalid','Delhi','Delhi','Delhi salon','Salon owner',auth.uid()::text||'/photo/owner.png');
do $$begin if not exists(select 1 from public.nexora_job_employers where user_id=auth.uid() and profile_photo_path=auth.uid()::text||'/photo/owner.png') then raise exception 'Owner photo not persisted';end if;end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"de100000-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
do $$declare changed int;begin
 if exists(select 1 from public.nexora_job_candidate_private where user_id='de100000-0000-4000-8000-000000000001') then raise exception 'Outsider sees candidate private profile';end if;
 if exists(select 1 from public.nexora_job_employers where user_id='de100000-0000-4000-8000-000000000002') then raise exception 'Outsider sees owner private profile';end if;
 if exists(select 1 from storage.objects where name like 'de100000-%/photo/%') then raise exception 'Outsider reads photos';end if;
 update public.nexora_job_candidates set full_name='Forged' where user_id='de100000-0000-4000-8000-000000000001';get diagnostics changed=row_count;if changed<>0 then raise exception 'Outsider modified profile';end if;
 begin insert into storage.objects(bucket_id,name,metadata) values('nexora-job-private','de100000-0000-4000-8000-000000000001/photo/forged.png','{"mimetype":"image/png","size":100}');raise exception 'Foreign upload accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;
select 'PASS: full profile persistence, candidate/owner photos, removal, failed replacement preservation, MIME/size/ownership validation, private reads and cross-user write denial; rolled back all fixtures' as profile_checks;
