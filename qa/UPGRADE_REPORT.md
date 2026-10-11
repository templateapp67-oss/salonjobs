# Nexora Salon Jobs — upgrade report

Date: 10 October 2026. Existing Sites project retained: `appgprj_6ac9beaa71908191bf9729bacaeb97dc`. Shared Supabase project retained: `zilwgiuiygqqardzutxi`. Existing user records and unrelated SalonOS tables/settings were preserved.

## Phase 1 — Audit

The website was buildless HTML/CSS/JavaScript in `dist/`, with hash navigation and direct Supabase Auth/PostgREST. Android was Kotlin, Jetpack Compose, MVVM, SDK 35/minimum 26, with encrypted draft/session persistence and a reusable `JobProfileSelection`. Hosting was public Sites with an actual downloadable debug APK.

Existing routes covered home, jobs, candidates, job details, account/dashboard and category administration. Working elements included 29 bilingual category IDs, multi-selection, profile/job drafts, basic ownership RLS, applications, invitations, opt-in talent discovery and matching alerts. The homepage already had original salon photography and eight skill cards.

The six portal tables were categories, candidates, employers, posts, applications and invitations. Missing workflows included detailed candidate/employer registration, protected uploads, job moderation/verification, saved jobs, combined numeric search/pagination, screening applications, interview scheduling, assisted hiring requests, support reports, notifications, locations/content administration and account suspension. The old APK needed application consent and approval/state compatibility. Branding was inconsistent with the requested “Nexora Salon Jobs”; it is now updated in website headings, navigation, title, favicon and Android labels.

## Phase 2 — Implementation

Changes are in the existing project. The site adds `portal.js`/`portal.css` while reusing the category selector, Auth/API utilities and original visual assets. Primary color is `#77198D`, with Inter typography.

| Feature | Result and verification |
| --- | --- |
| Homepage, original salon hero, eight profiles, benefits, hiring paths, shortcuts, FAQ and APK | Implemented; DOM checks pass. Visual browser/device review remains pending. |
| Shared 32-category master, Hindi/English UUIDs, any/all matches, inactive history | Implemented; live REST, DOM and authenticated rollback SQL checks pass. |
| Five-step candidate profile, professional details, consent, persistent selections | Implemented; DOM flow and atomic database RPC checks pass. |
| Candidate photo/resume/portfolio | Implemented with private Storage, limits, owner paths and short-lived signed URLs. Storage RLS and invalid references tested in rollback SQL; real multipart-upload/device flow not exercised. |
| Complete employer profile, logo, privacy and verification submission | Implemented. Owner self-verification denial and admin verification/projection/audit tested in SQL. Actual document upload and browser admin form not end-to-end tested. |
| Job draft, preview, publication, benefits, screening/questions, deadline/contact settings | Implemented; DOM validation/payload and database ownership/moderation/deadline checks pass. Jobs enter pending review; there is no automatic Beautician assignment or automatic verification. |
| Job filters and pagination | Implemented against database search RPC: profile, title/skills, city/state/locality, numeric salary/experience, gender, salon category and benefits. Combined database search and paging tests pass. |
| Job details and actual-ID links | Implemented at `/?job=<UUID>`; DOM route/JSON-LD checks pass. Includes salon, eligibility, FAQs, benefits, public contact only when authorized, report/share/save and matching similar jobs. |
| Apply and track | Implemented with profile requirement, resume/questions when requested, consent, uniqueness and deadline validation. DOM submission and database status/consent/duplicate/expired-job tests pass. |
| Candidate/employer dashboards, invites, interview scheduling | Implemented. Invitations, shortlist, private applicant access, interview visibility and automatic interview status tested in SQL; all dashboard tabs have not been manually browser-tested. |
| Candidate directory filters | Implemented with database category/skill/location/experience predicates. Exact-category and privacy SQL checks pass; combined talent form not manually browser-tested. |
| Assisted hiring and support/reporting | Real request tables and administrator review UI, with status/inbox updates. Assistance submission DOM and review permissions SQL checks pass. No recruitment outcome, staffing service response time or price is invented. |
| Admin workflows | Implemented verification, job moderation, reports, assistance, users/suspension, profiles/applications, categories, locations, content, inbox and audit. Permissions, suspension and audit tested in SQL; full admin browser walkthrough pending. |
| Notifications | Implemented in-app database inbox and event-trigger updates. SQL checks pass. Email/OS-push delivery is not implemented. |
| Responsive/accessibility | Implemented responsive layout, mobile filter sheet, scrollable selections, semantic labels, keyboard/native checkbox behavior, focus styles, Escape behavior, reduced motion and dialog handling. Real 320dp Android, 200% font and TalkBack checks remain pending. |
| Company pages and contact | About, employers, assisted hiring, FAQ and authenticated support-request routes implemented and DOM-tested. Public company email/phone is blocked by missing verified owner information. |
| Privacy/terms | Content administration and honest operational notices implemented. Complete legal pages are blocked by missing legal entity, legal contact, retention rules and owner-approved wording. Drafts are not presented as approved policies. |
| Auth/reset email branding | Auth/signup/recovery UI implemented. Nexora templates are provided under `backend/email-templates/`; applying global Auth templates/redirect allowlist/SMTP is not completed because this project serves other apps and no project-scoped configuration capability or approved sender was supplied. Confirmation/recovery delivery not tested. |
| Android | Native reusable category selection, encrypted draft persistence, profiles, posting, any/all category search, invitations and applications retained. Updated consent/state/moderation compatibility; advanced resume/screening applications open the website. New website interview/assistance/full-admin workflows are not ported into native screens. Build result and APK signing details are recorded below when complete. |

## Phase 3 — Database

The original core schema is `backend/schema.sql`; do not rerun it on the connected project. Four additive upgrade migrations have been applied and are mirrored in `supabase/migrations/`:

1. `20261010100539_nexora_recruitment_complete.sql`
2. `20261010102636_nexora_recruitment_hardening.sql`
3. `20261010102840_nexora_recruitment_application_lock.sql`
4. `20261010103949_nexora_recruitment_trigger_record_fix.sql`

The portal now has 20 RLS-protected tables: original six plus private candidate data, candidate/category and job/category relations, sanitized public salons, saved jobs, interviews, assistance, reports, verifications, notifications, suspended accounts, audit, locations and page content. Arrays preserve native compatibility; triggers maintain composite-key/FK category relations. Active IDs, duplicates, salary/experience/vacancies, status and identity are validated server-side. Existing inactive IDs can survive profile/job edits; new inactive selections are rejected.

Indexes support category arrays/joins, full-text job search, locations/status/salary/benefits, applications, interviews, inbox and ownership relationships. `nexora_job_search` and `nexora_job_save_candidate` are invoker RPCs. Private definer helpers are auth-bound and have empty search paths; derived writes and application locking cannot be used to grant client admin privileges. Admin role comes from server-controlled `app_metadata.job_portal_role`, never user metadata.

Private buckets: `nexora-job-private` and `nexora-job-verification`, 5 MB per file. Public logos: `nexora-job-logos`, 2 MB. Storage policies scope paths to the authenticated UUID; consented job employers can read the applicant’s shared documents, administrators can review verification, and unrelated users are denied. Public listing data contains no private candidate contact or employer email/mobile. Suspensions block portal writes/directory access; they do not revoke the shared Auth account or unrelated app access.

For another environment, back up first, apply core only if absent, then these migrations in order and run rollback acceptance checks. They are already applied here. Do not reset the public schema, delete categories or overwrite other app policies. Use a trusted Supabase project owner to grant portal admin app metadata to the correct existing account; no user was automatically elevated. Deploy the matching website/APK afterward. Frontend rollback alone will not make the old consent-free Android application compatible.

The CLI migration creation produced an automatic review rejection for telemetry; migrations were applied through the supported Supabase connector instead. Local timestamps match confirmed server migration history.

## Phase 4 — Verification

Passed: `node --check dist/app.js`, `node --check dist/portal.js`, `node qa/portal.mjs`; live anonymous category reads and paginated search; `backend/acceptance-upgrade.sql` against the connected Supabase database under actual anon/authenticated roles, with all fixtures rolled back.

Routes exercised by DOM tests: home, jobs, actual UUID detail URL, dashboard entry/settings, assisted hiring, about, employers, contact, privacy, terms and FAQ. Modal flows tested: candidate wizard/category collapse/draft restoration/consent, required employer profiles/posting/benefits, combined filters, save/apply consent, assistance and login password non-persistence. Writes in DOM tests use mocks; SQL separately checks live database permissions and persistence. This is not a claim of full browser end-to-end testing.

Observed failures corrected: anonymous search initially depended on a protected saved-table grant; application share locking initially hit candidate UPDATE RLS; shared trigger predicates referenced fields absent on assistance/verification row types. Dedicated auth-bound helpers and JSON-safe cross-table trigger predicates fixed these, and extended acceptance tests now pass. The self-verification assertion was adjusted to handle RLS’s zero-row rejection as well as exceptions. An initial QA selector incorrectly expected a logout button on the overview; the test now opens Account settings.

Browser visual QA, authenticated email delivery, real multipart uploads and physical Android/emulator tests remain unperformed. Client-rendered job metadata is provided; search-engine crawling of this static SPA is not verified. Production release signing/Play Store publication requires the owner’s signing configuration. No fake jobs, users, testimonials, badges or guarantees were seeded.

### APK artifact

Android v1.0.1/version code 2, 9.2 MiB, APK SHA-256 `1523b92b51ac53a75e3a8506c05cf2d3b02714b9d95e71455b164ea918bda3b5`. `assembleDebug` produced this APK; signature verification and package/version checks passed. The earlier v1.0.0 signing certificate differs: uninstall that testing build first, then install and log in to restore cloud profiles. Local unsaved drafts are removed by uninstalling. This is debug signing; release key/store publication is not configured.

Final Android command: `./gradlew assembleDebug compileDebugAndroidTestKotlin` — **BUILD SUCCESSFUL**, 44 tasks. Instrumentation test sources compiled; tests were not run on a device/emulator. Initial build blockers were a JRE without javac and the downloaded JDK’s missing managed proxy CA; a checksum-verified full JDK and the system trusted CA store resolved them without disabling TLS verification. Database security advisor check reported no portal-specific findings; unrelated existing project findings were left untouched.

### Android branding update — v1.0.2

The supplied Nexora wordmark is now the native toolbar logo; the supplied crowned purple emblem is the regular/round adaptive launcher icon and Android 12+ launch screen icon. Exact PNG assets are bundled without altering the supplied artwork. `assembleDebug` passed (35 tasks), APK signature/package/assets verified. Version code 3, version name 1.0.2, 12.4 MiB, SHA-256 `a361beb0aa11feb2144c4a73929cffde0bcb83158c4647d0f5a1dacbf985e7bd`. Signing certificate matches v1.0.1 (`ae64e7757594a98b5a12524ecf0ffdd32c50f0bd1c02ac77cc47887dec0b7deb`), so v1.0.1 can update without uninstalling. Download URLs now include the new version to prevent reuse of a browser-cached APK. Physical launcher/splash verification has not been run in this environment.
