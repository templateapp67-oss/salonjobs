# Job Profile and primary Job Title — 10 October 2026

## Audit

The existing central `nexora_job_categories` table had 32 active rows, including all 15 requested professions. One English label was `Mehndi Artist`; it is now the explicitly requested `Mehandi Artist`, using the same UUID and slug. Candidate IDs already lived in `job_profile_category_ids`, and jobs used `required_category_ids`. Existing normalized `nexora_job_candidate_categories` and `nexora_job_required_categories` tables have composite primary keys and are synchronized by database triggers. These tables were reused.

Website and native Android already had a hoisted candidate checkbox selector, but job posting combined a free-text title with multiple categories. New vacancies now require one primary Job Title from the same live master. Category filter selections now update results without needing a separate Apply action.

## Safe migrations

1. `backend/job-title-selection.sql`: updates the existing 15 English labels/order, deactivates the other 17 without deleting them, and adds nullable `primary_category_id` with a category foreign key and index. Existing vacancies are deliberately not automatically classified. Their original title and category relationships remain intact until an authorized employer explicitly chooses a primary title while editing.
2. A private, SECURITY INVOKER trigger requires an active primary category for new/changed titles, stores its canonical label and requires the matching singleton `required_category_ids`. It runs before existing validation/moderation guards. Existing RLS and category relationship synchronization remain in force.
3. `backend/category-history-upsert.sql`: the candidate RPC uses INSERT ... ON CONFLICT, whose initial INSERT trigger previously rejected deactivated historical categories. Validation now checks only the authenticated owner's existing IDs before the upsert. Newly added inactive/unknown/duplicate IDs remain rejected.

Server-returned migration timestamps are mirrored in `supabase/migrations/`. No tables were reset, no category UUIDs were replaced, and no existing candidate/job records were deleted.

## Website and Android implementation

- The candidate Job Profile control is expandable, searchable, supports multiple checkboxes, purple selected states, selected count, Clear Selection and required selection errors. Selections remain in draft state when collapsed or navigating away and reload from the existing saved records.
- The employer Job Title control is a required single dropdown. It starts empty, uses stable category IDs and has no automatic Beautician default. Candidate multi-selection stays separate.
- Post/edit payloads save `primary_category_id` and the corresponding singleton required-category relationship. Job cards/details resolve the primary category label from the central master, with the original title as the fallback for preserved legacy vacancies.
- Job and candidate filters use category UUID arrays with actual any/all matching. Both clients load the same Supabase category table dynamically. Android keeps selection state in the existing MVVM/encrypted drafts and rejects stale inactive new draft titles.
- Profile-photo source, storage and unrelated pages were not redesigned or changed.

## Verification

| Check | Result |
|---|---|
| Exact 15 active labels and order | PASS: live Supabase; all 32 original category rows retained |
| Website multi-select, collapse/reopen and navigation draft | PASS: DOM workflow test |
| Website required Job Title, no default, canonical primary ID payload | PASS |
| Website selected title on card and details | PASS |
| Website category filter changes displayed results | PASS |
| Real candidate save and logout/password-login restoration | PASS: temporary confirmed QA account, both IDs restored |
| Real job posting validation, canonical title and authorized editing | PASS: Supabase REST with temporary employer account |
| Candidate search and normalized relationship synchronization | PASS: real REST and rollback SQL |
| Any/all job category searches | PASS: live search RPC under anon RLS in rollback transaction |
| Empty, duplicate, unknown, inactive selections and inactive upsert history | PASS: live rollback SQL |
| Cross-user category/job writes and unauthorized relationship writes | PASS: real REST and SQL RLS |
| Existing candidate/job record preservation | PASS: original saved-record checksums unchanged; an additional non-test candidate created during work was preserved |
| Native APK build + instrumentation test-source compilation | PASS |
| Native UI, small-screen/font scaling and screen-reader device tests | NOT RUN: no emulator or physical Android device available |
| Full browser visual interaction | NOT RUN: browser-control plugin unavailable; DOM checks were used |

Original-record preservation: original candidate count 1, hash `69b52e68e3e0dac3893cdcdd74b7497d`; job count 1, hash `e6d3a8167879f626d3dc89c08367d239` (excluding the newly added nullable column). A separate live, non-test candidate was created during this task; it was preserved, so the final candidate count is 2. The original candidate checksum still matches exactly. Temporary REST QA jobs/accounts were removed after logout; transaction fixtures were rolled back.

`node qa/portal.mjs` passed the existing workflows and new category/title checks. DOM transport uses controlled fixtures; production operations continue to use Supabase. Native instrumented tests for candidate collapse/clear/history and single-title/no-default/draft restoration were compiled, not run on-device.

APK: package `com.nexora.jobs`, v1.0.4, versionCode 5, Android 8+, 13,250,931 bytes. SHA-256 `263d958004c144b20ffff3e4be25519bb11c93ea2c8204d3d8fca094b159ad99`. Signature verified and matches v1.0.1–1.0.3. This is the existing early-access debug signer.

Supabase security advisors were checked; no new primary-title validator/category RLS findings appeared. Existing findings on unrelated shared-project modules were not changed. Linter guidance: https://supabase.com/docs/guides/database/database-linter and https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
