# Nexora Salon Jobs

Existing Sites website and native Jetpack Compose + MVVM Android client, using one shared Supabase backend. Start with [the upgrade report](qa/UPGRADE_REPORT.md) for the four requested audit/implementation/database/verification phases and known configuration/testing limits.

- `dist/`: responsive website, real Auth/PostgREST/Storage workflows; no build step.
- `android/`: native category selection, profiles, posting, matching, applications and invitations. Advanced resume/screening applications continue on the website.
- `supabase/migrations/`: applied additive upgrades. Existing core SQL is in `backend/schema.sql`; never reset or rerun it on the connected project.
- `backend/acceptance-upgrade.sql`: authoritative current rollback-only RLS/functional acceptance suite. `acceptance.sql` documents the historical pre-upgrade schema contract.
- `qa/portal.mjs`: DOM integration tests plus live anonymous category/search access. Run `cd qa && npm ci && npm test`. Writes are mocked here and tested independently in SQL.
- `backend/email-templates/`: prepared templates; global Auth/SMTP configuration remains owner-dependent.

Production website: https://nexora-salon-job-portal.templateapp67.chatgpt.site

Build Android with JDK 17 (full JDK including javac), Android SDK 35/Build Tools 35.0.0 and `./gradlew assembleDebug compileDebugAndroidTestKotlin`. Min Android 8.0/API 26; package `com.nexora.jobs`. The downloadable APK is an early-access debug-signed build, not a Play Store release. Native draft selections and sessions use Android Keystore AES-GCM encryption. No Firebase or WebView wrapper is used.

An authorized Supabase project owner can grant `app_metadata.job_portal_role=admin` to the correct existing user. Do not use user metadata or expose Admin/service-role credentials in clients. No user is automatically elevated. Logout/login refreshes the role claim. Portal admin actions are isolated from other apps in the shared project.

Use the supplied original salon image assets. Never seed invented vacancies, verification badges, user counts or testimonials as production data. Full legal policies and verified public contact details require owner-supplied business information. Alerts are in-app; email/push delivery is not configured. Browser/device visual, upload and accessibility QA must be completed before a production store launch.
