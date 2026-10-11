# Nexora form improvements — 10 October 2026

## Phase 1 — Audit

Inspected the existing website authentication/recovery, candidate wizard, employer profile, job posting/editing, job application, assisted hiring, search filters, support/report, verification, interview and administration forms. Inspected Android authentication, candidate/owner editing, job posting/editing, search, application consent and category administration. Reviewed Supabase constraints, triggers, owner RLS, category master/relationships, request handlers and saved drafts.

The supplied Android screenshot shows a typed role without the category ID required by the backend. The current source already had category selection, but lacked explanatory copy. Several web selects had no inline errors; native browser validation could prevent handlers from running. Cross-field salary/experience errors appeared at the bottom. Contact email and owner address were unnecessarily required in the web UI. Android lacked field guidance, appropriate keyboards and inline errors; its busy flag was set inside a coroutine, allowing a rapid-tap race. Native Retry reloaded data instead of retrying the failed action. A zero-row write could be treated as success. Optional additional profiles were incompatible with the previous singleton category trigger, and Freelance was excluded by the employment constraint.

## Phase 2 — Implementation

- Reusable website guidance/validation in `dist/forms.js`; Compose guidance and validators in `FormGuidance.kt`, integrated into the existing UI/MVVM.
- Explicit Job Title question, exact helper/example, selection placeholder and missing-title message. Roles still come from the same existing Supabase category master, with no default Beautician or free-text primary title.
- Optional additional Required Profiles; one primary title remains mandatory. Sets prevent duplicate IDs.
- Practical hints/examples, required/optional markers, field-associated accessible errors, numeric/email/phone keyboards, salary units and file size/type guidance.
- Existing candidate multiple selection, saved photo and profile draft behavior retained. Contact email and owner address optional where the backend already permits it.
- Inline validation, first-invalid-field scrolling, draft/value preservation, loading indicators, busy guards and useful error/retry feedback. Android uses IME padding and resize.
- Stable new-job submission UUIDs prevent another row when retrying after a lost response. Success requires returned saved rows.

## Phase 3 — Bug fixes / database

Applied only `20261010122404_nexora_form_role_options.sql`: the primary title must be included in the required category IDs, allowing explicitly chosen additional profiles; Freelance is allowed by the employment check. Existing duplicate/unknown/new-inactive category validation and historical references remain. RLS policies and category rows were not changed. No customer records were reset or deleted. Hash comparisons of the two existing candidate records and existing job were unchanged during the continuation.

## Phase 4 — Verification

| Workflow | Evidence |
|---|---|
| Website forms | DOM regression tests with controlled transport; real anonymous category/search reads. Title copy/options, salary/vacancy errors, preserved values, one request in flight, server error/retry, extra profile IDs and Freelance payload verified. Existing profile/photo, consent, filters and routes also passed. |
| Candidate / employer | Authenticated Supabase REST: save with optional blank email, multiple candidate IDs, logout/login restore, owner profile save. |
| Job posting/editing | Authenticated REST: valid create/edit, publication/search, canonical category title, normalized additional relationships, duplicate row ID protection. Missing/invalid title, invalid salary/vacancies, duplicate/unknown/missing-primary category relationships rejected. Cross-user edit denied. |
| Application | Real application to an isolated approved QA vacancy succeeded. |
| Assisted hiring / report | Real submissions succeeded. The initial assistance test omitted required urgency; corrected to the actual full UI payload and reran successfully. |
| Android | Build and validation results recorded below. Device UI, camera, keyboard visibility, TalkBack and small-screen behavior require physical/emulator testing. |
| Other forms | Shared controls and source inspected; live verification-document uploads, interviews, admin operations, signup confirmation and recovery emails were not submitted in this task. |

The Android app retains its existing website handoff for applications requiring a resume or screening answers. Assisted hiring/report forms remain website workflows; no separate disconnected native screens were created.

Temporary QA job is closed, QA candidate is not discoverable, and both QA users have zero sessions. Deleting the two temporary accounts failed with the Supabase connector's `Invalid or expired requestState` error. Those isolated test accounts/related rows remain; existing customer rows are intact.

## Phase 5 — Deliverables

Website: `dist/forms.js`, existing app/portal scripts, HTML and form CSS. Android: existing Compose screens/components, repository, models, ViewModel, manifest and new shared guidance/validation. Tests: `qa/portal.mjs`, native title instrumentation source and `JobFormValidationTest.kt`. SQL: mirrored applied migration and `backend/form-refinements.sql`.

APK version 1.0.5 / code 6 is generated only after a successful final build. This rebuild uses a new debug signing certificate because the previous local build environment/key was unavailable. Android may require uninstalling the old APK before installing; that removes unsaved local drafts. Saved backend profiles and jobs return after login. No physical-device installation is claimed.

Final validation: Android build successful; all 5 JVM validation tests passed. Instrumentation sources compiled, not executed. APK size 13041342 bytes; SHA-256 `4d76532431dbcb3893c695588011d95052177c7062cd26077f4d46023362557b`. Signing certificate verified.
