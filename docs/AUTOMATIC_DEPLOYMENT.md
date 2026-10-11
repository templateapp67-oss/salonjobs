# Automatic deployment

The repository is prepared for native Vercel Git integration. Project root is the repository root, production branch is `main`, framework is Other, and output directory is `dist`.

`vercel.json` restores and verifies the existing compressed APK during every build using Python 3. It does not rebuild the Android application. To ship Android source changes, first build a new APK successfully, compress it, update its expected checksum in `tools/restore_apk.py`, and push the artifacts together. Do not claim a new APK based only on a website deployment.

Vercel handles production deployments for pushes to `main` and previews for other branches through its Git integration; no Vercel secret is stored in GitHub. SQL migrations are not executed during deployment. The same Supabase client configuration is reused, with backend RLS unchanged. New auth redirect URLs may need to be allowed in Supabase for email verification and password reset.

The existing Sites URL remains an independently published site. GitHub pushes do not update that URL.
