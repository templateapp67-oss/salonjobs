# Profile and photo audit — 10 October 2026

The existing website wizard had candidate fields in Supabase but lacked a top photo panel, signed preview, upload progress/retry, remove/change controls, explicit Cancel and saved completion. The existing native Compose/MVVM profile omitted gallery/camera, email, qualifications, languages, skills, preferences, employment, resume and portfolio. Owner personal photos had no database field. Existing authentication refresh, encrypted Android drafts, category selection and private storage were reused.

A live transactional test exposed an existing `guard_record` error on private-profile UPDATE: it evaluated `NEW.status` on a record without that column. The minimal fix returns from the candidate-private branch after the same ownership/identity checks and timestamp update. Other trigger branches keep their existing behavior.

## Delivered

- Existing candidate and salon-owner forms now start with a reusable photo panel. Gallery, camera where supported, preview, change, removal, default avatar, progress, upload success/failure and retry are integrated.
- Candidate fields and optional resume/portfolio uploads are saved through the existing atomic `nexora_job_save_candidate` RPC. Native app loads the complete saved candidate/private records and uses encrypted per-user drafts.
- Owner personal information and photo reuse the existing employer record. Candidate job preferences and qualifications are excluded from owner forms.
- Personal/professional/skills/preferences/files sections, Save and Cancel, missing-field guidance, saved completion and dashboard photo display are integrated. Native cancellation restores server state. Website cancellation discards the form draft.
- Website and native app use identical candidate/private/employer records. Photo references remain stable private object paths; short-lived signed display URLs are generated on load rather than saved as expiring URLs.
- Only `profile_photo_path` on employers, a private image validation trigger, and the existing profile UPDATE trigger correction were added. No bucket, category, authentication configuration or existing user records were replaced.
- JPG/PNG/WebP maximum 5 MB. Native additionally decodes image headers and rejects format mismatch/over 40 megapixels. Uploads create unique owner UUID paths. Failed replacements do not overwrite the saved reference. Old/unreferenced files remain private; historical documents are not deleted automatically.

## Verification

- `node qa/portal.mjs`: PASS. Existing workflow regressions plus profile preview, failed upload preservation/retry, saved photo restore, actual saved completion, Cancel/removal and owner photo payload. DOM/XHR upload failures use controlled test doubles; this is not physical browser/device verification.
- `backend/acceptance-profile.sql`: PASS against live Supabase inside a rollback transaction. Full candidate field persistence, candidate/owner photo references, removal, failed replacement preservation, MIME/size/foreign path rejection, private reads and cross-user writes. Storage rows in this SQL test are metadata fixtures, not uploaded files.
- Real HTTP Supabase integration: PASS using two temporary confirmed QA accounts. Password login, actual PNG upload, signed download byte equality, atomic profile save, failed replacement preservation, logout/login restore, removal and cross-account private read/sign/upload denial. Uploaded test objects and test accounts were removed afterward; existing accounts were untouched.
- `assembleDebug`: PASS. Updated native APK v1.0.3 / versionCode 4, Android 8+, package `com.nexora.jobs`.
- `compileDebugAndroidTestKotlin`: PASS. Instrumentation source compilation only; device tests were not executed.
- APK signature verified; same debug signer as v1.0.1 and v1.0.2. SHA-256 certificate: `ae64e7757594a98b5a12524ecf0ffdd32c50f0bd1c02ac77cc47887dec0b7deb`.
- Final APK SHA-256: `586a243eb8d8c264390b3ae1fbedf101ec5a9dd30da2bd09f4b023ac565a3e4c`.

## Remaining device checks

No emulator/physical phone or browser-control plugin was available. Android Photo Picker, camera app handoff, Android logout/login UI, rotation during capture, TalkBack, large fonts and small-screen visual interaction require device QA. Website camera capture depends on the browser/device capture support. The APK is an early-access debug-signed build, not a Play Store release.

Supabase advisors were checked. No new profile-table RLS or photo-validator findings appeared. Existing shared-project findings outside this scope were preserved; relevant linter guidance: https://supabase.com/docs/guides/database/database-linter and https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
