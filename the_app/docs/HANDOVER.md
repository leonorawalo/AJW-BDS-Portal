# AJW BAGS Portal: technical handover

For whoever maintains the portal next. Written 6 October 2026.

- **What the programme and each screen are for**, in plain words: [`docs/BAGS_Portal_Guide.md`](BAGS_Portal_Guide.md).
- **Rules that must never be broken** (files, settings that must match across systems, deploy guards): [`DO_NOT_BREAK.md`](../DO_NOT_BREAK.md). Read it before changing config, deploys, Google, Supabase or `web/`.
- **Running history of decisions** (not in git): `context.txt` next to this repo's `pubspec.yaml`, if you were given it.

This document covers how the system is built, how to run, change and release it, and where things go wrong.

---

## 1. The system at a glance

| Part | Technology | Where |
| --- | --- | --- |
| App (web + Android) | Flutter 3.44, Dart 3.12, Riverpod, go_router | This repo, `lib/` |
| Database, logins, files | Supabase: Postgres with Row Level Security, Auth, Storage | Project `ajw-bds-portal`, ref `cgnmnqjyvlgyndhmicjl` |
| Server code | Supabase Edge Functions (Deno, TypeScript) | `supabase/functions/` |
| Website hosting | Firebase Hosting | Project `ajwafrica-bags-portal`, served at https://portal.ajwafrica.org |
| Push notifications | Firebase Cloud Messaging (Android) | Same Firebase project |
| Google Calendar, Meet, Gmail, Drive, Docs, Sheets, Slides | Each user's own Google account, via OAuth | Google Cloud project `ajw-bags-portal` |
| "Continue with Google" sign-in | Supabase Auth Google provider | Google Cloud project `ajw-bags-sign-in` |
| Domain | Bluehost DNS: CNAME `portal` → `ajwafrica-bags-portal.web.app` | ajwafrica.org |
| Android downloads | Supabase Storage bucket `downloads` | Linked from `web/download.html` |

There is no separate backend server. The app talks to Supabase directly. Anything that needs a secret (Google tokens, the service-role key, Firebase keys) runs in an Edge Function.

```
 Phone / browser ──► Flutter app ──► Supabase (Postgres + RLS, Auth, Storage)
                         │                    │
                         │                    └─► Database Webhooks ─► send-push ─► FCM ─► phones
                         └─► Edge Functions ─► Google APIs (with the user's own refresh token)
```

**The security boundary is the database, not the app.** Every table has Row Level Security. Hiding a button is only a convenience; the database independently refuses what a role may not do. Write the policy first, then the screen.

---

## 2. Accounts and access you need

| What | Why | Notes |
| --- | --- | --- |
| Supabase dashboard (owner/admin of `ajw-bds-portal`) | Database, Auth settings, Storage, Edge Function secrets | Free plan: **no automatic backups** (see section 11) |
| Google Cloud: `ajw-bags-portal` and `ajw-bags-sign-in` | OAuth clients, consent screen, verification | Two projects look alike; check the ID in the address bar |
| Firebase: `ajwafrica-bags-portal` | Hosting deploys, push | Also shows as "AJW BAGS Portal" |
| Bluehost (ajwafrica.org DNS) | The `portal` CNAME | Deleting it takes the site offline |
| Gmail `ajw.bags.portal@gmail.com` | Sends invite and reset emails (SMTP app password) | Changing its password or 2-Step Verification kills the app password |
| GitHub repo | Source | `master` is the only branch in use |
| Android signing key | Every APK must be signed with it | `C:\Users\user\AJW-BDS-Keys\ajw-bags-upload.jks`, alias `upload`, password in `README-KEEP-THIS-SAFE.txt` beside it. **Losing it means installed apps can never update.** Hand it over privately, never through git. |

No secret value is stored in this repo. `.env` holds only the Supabase URL and the public anon key.

---

## 3. Repository layout

```
the_app/
├── lib/
│   ├── core/           router, theme, app shell (side menu), shared widgets, site links, app version
│   ├── shared/models/  cross-feature models (UserProfile)
│   └── features/<name>/
│       ├── data/          one repository per entity (talks to Supabase or an Edge Function)
│       ├── models/        one model per entity, plus static data (e.g. ToR checklists, tour text)
│       ├── providers/     Riverpod wiring
│       └── presentation/  screens and widgets
├── supabase/
│   ├── migrations/     every database change, in order (never edit an applied one)
│   ├── functions/      Edge Functions; _shared/ holds Google token helpers
│   └── scripts/        one-off SQL (e.g. the test-data flush)
├── web/                index.html (loading screen), legal pages, download page, OAuth relay page
├── scripts/check_do_not_break.js   runs before every hosting deploy
├── test/               unit and widget tests
└── docs/               this file, the plain-language guide, email templates, Google verification
```

**Convention:** one file per model and per repository. A duplicate class at a slightly different path is the bug that cost this project the most time; search `lib/` for `class Name` before trusting an edit.

### Features

| Folder | What it does |
| --- | --- |
| `auth` | Sign-in, set password (invites), reset, password rules |
| `enterprises` | Register, list, details, business facts, loan purpose, owner link |
| `consultants` | Assign the trio, a consultant's portfolio |
| `legal_workstream` | Historical name: tasks for all three disciplines, ToR checklists, comments, documents, recommendations, the loan-readiness dashboard and scoring |
| `visits` | Visit log |
| `calendar` | Google connection, sessions (Calendar + Meet) |
| `email` | Write email via Gmail, find past emails |
| `drive_files` | Google Docs/Sheets/Slides created per enterprise |
| `google_exports` | Loan-readiness report (PDF on device, or Google Doc), data Sheet, Slides deck, portfolio Sheet |
| `portfolio` | Programme clock, ToR measures, monthly report |
| `workshops` | Workshops, attendees, registration list submitted as a CSV to admin Documents |
| `user_management` | Invites, users screen, suspend, role and specialization changes |
| `audit` | Audit log screen (written only by database triggers) |
| `notifications` | FCM device registration |
| `attention` | Red dots |
| `tutorial` | Guided tours (spotlight tips) |
| `app_update` | Android "new version available" banner |

---

## 4. Running it locally

1. Install Flutter 3.44 (stable) and Android Studio's SDK (compileSdk 36 is set explicitly in `android/app/build.gradle.kts` for plugins that need it).
2. Put `.env` in the project root (`SUPABASE_URL=...`, `SUPABASE_ANON_KEY=...`). It's listed under `flutter: assets:` in `pubspec.yaml`; without it the app shows a configuration error screen.
3. `flutter pub get`
4. Web: `flutter run -d chrome --web-port 3000` (debug web is slow to load; use `--release` for a realistic check). Android: `flutter run` with a phone connected.
5. Checks: `flutter analyze` and `flutter test` (55 tests). Both must be clean before any deploy.

The Supabase CLI is used through `npx supabase`, already logged in and linked on the original machine (`npx supabase link --project-ref cgnmnqjyvlgyndhmicjl` on a new one). `npx supabase db query --linked "select ..."` runs SQL against the live database.

---

## 5. The database

### Rules

- **Never edit a migration that has been applied.** Put every fix in a new, idempotent migration (`create or replace`, `if not exists`). An earlier tool edited applied migrations and those edits never reached the live database.
- "Recorded as applied" is not the same as "live". If behaviour and migrations disagree, compare the live schema (`information_schema`, `pg_policies`). On 4 Oct two old migrations turned out never to have run.
- Apply with `npx supabase db push --linked`. Test risky ones first inside `begin; ... rollback;` with `npx supabase db query --linked -f file.sql`, impersonating a role with `set local role authenticated` and `request.jwt.claims`.
- New tables in `public` get RLS switched on automatically (event trigger `ensure_rls`) and are unreadable until you add policies **and** GRANTs. "Automatically expose new tables" is off.
- Derived values (`tasks.completed_at`, `enterprises.going_concern_achieved_at`, audit log rows) are set by triggers, never by the app.

### Role helpers (all `SECURITY DEFINER`)

`is_admin()`, `is_assigned_consultant(enterprise_id)`, `is_enterprise_owner(enterprise_id)`, `is_bds_team()` (Admin or Consultant), `current_user_specialization()`.

### Main tables

| Table | Holds |
| --- | --- |
| `roles`, `users` | Three roles; a profile per Auth user (role, status, specialization) |
| `enterprises` | Businesses; `owner_user_id` (permanent once set), lifecycle and going-concern status, business facts |
| `consultant_assignments` | One active consultant per enterprise and discipline; assigning a new one ends the old and hands over unfinished tasks |
| `tasks`, `task_comments` | ToR and custom tasks (`tor_key` unique per enterprise + discipline) |
| `documents` | Uploaded files; per enterprise, or programme files (`enterprise_id` null, `workshop_id` set) |
| `recommendations`, `enterprise_visits` | Advice and the visit log |
| `consultation_sessions`, `session_participants` | Meetings booked through Google Calendar |
| `enterprise_files` | Google files created per enterprise |
| `workshops`, `workshop_attendees` | Workshops and registration lists |
| `google_connections`, `google_oauth_states` | Each user's Google refresh token; RLS with no policies (Edge Functions only) |
| `device_tokens` | FCM tokens, one user per device |
| `audit_log` | Key changes, written by triggers only |
| `attention_seen` | When each user last opened each page (red dots); written only via `mark_seen()` |
| `assessments` | Legacy; unused by the app |

### Important functions and triggers

- `ensure_tor_tasks(enterprise, specialization)`: adds missing ToR tasks; called when Tasks opens.
- `completed_loan_readiness_tasks(enterprise, titles[])`: lets the dashboard know which scored tasks are done across disciplines.
- `my_attention()` / `mark_seen()`: red dots (latest definition in migration `20261005120000`).
- `enterprise_owner_link_rules`: an enterprise's owner can be set once, never swapped; must be an Enterprise Owner account.
- `set_assignment_specialization_and_end_conflicts`: one active consultant per discipline, task handover.
- `block_specialization_change_with_assignments`, `restrict_non_admin_user_updates`, `restrict_non_admin_enterprise_updates`: guard roles and fields.

---

## 6. Edge Functions

Deploy with the CLI only (`npx supabase functions deploy <name>`); the dashboard invents random names. "Verify JWT" is kept in `supabase/config.toml`.

| Function | Verify JWT | Purpose |
| --- | --- | --- |
| `invite-user` | on | Admin invites; sets `invited_by` / `invited_as` metadata the invite email uses; links an owner to an enterprise |
| `manage-users` | on | Suspend (Supabase Auth ban), role and specialization changes |
| `google-oauth` | **off** | Connect/disconnect Google; Google redirects here through `web/oauth/google-callback.html` |
| `calendar-sessions` | on | Free/busy check, create and cancel Calendar events with Meet |
| `gmail-send` | on | Sends one email from the user's Gmail (recipients limited to the enterprise's contacts) |
| `drive-files` | on | Create and share Docs/Sheets/Slides |
| `google-export` | on | Writes the report, data sheet and deck into the user's Drive |
| `send-push` | **off** | Called by Database Webhooks (header `x-webhook-secret`), sends FCM pushes |

Secrets (Supabase → Edge Functions → Secrets): `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`, `APP_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `WEBHOOK_SECRET`.

Push notifications come from four Database Webhooks (users insert, consultant_assignments insert, tasks insert, tasks update) pointing at `send-push`.

---

## 7. Releasing

### Website

```
flutter analyze && flutter test
flutter build web --release
npx firebase-tools deploy --only hosting
```

The deploy first runs `scripts/check_do_not_break.js`, which stops it if a protected file is missing, `.env` isn't bundled, dotfiles are ignored, a commercial font would ship, the old `web.app` address is hard-coded, or the version numbers disagree. Fix the cause; never remove the check.

The site has **no service worker** (custom `web/flutter_bootstrap.js`), and `index.html` removes any old one, so a reload always loads the newest version. Cache headers in `firebase.json` keep code `no-cache`.

### Android (APK, not in the Play Store)

1. Bump `version:` in `pubspec.yaml` **and** `lib/core/app_version.dart` (same name and build number; the deploy check compares them).
2. `cd android && ./gradlew --stop`, close heavy apps (the build needs about 2 GB free on a 7.8 GB machine), then:
   `flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm`
3. Check the signature matches the release key: `apksigner verify --print-certs` (SHA-256 `0dbd495f...`).
4. Upload to Storage `downloads`, replacing the old files (the CLI can't overwrite, so remove then copy, with `--content-type application/vnd.android.package-archive`):
   - `app-arm64-v8a-release.apk` → `ajw-bags-portal.apk`
   - `app-armeabi-v7a-release.apk` → `ajw-bags-portal-32bit.apk`
5. Update `web/download.html` (version line and the `?v=` on both links) and `web/android-latest.json` (version, build).
6. Deploy the website. Phones on 1.2.1 or later then show "A new version of the app is available" on their next launch.

Updates install over the old app and keep people signed in, as long as the same signing key is used.

---

## 8. Where to change common things

| To change | Edit |
| --- | --- |
| A ToR task | `lib/features/legal_workstream/models/task_template.dart`. Never change or reuse a `key`: a new key adds a second copy everywhere. |
| Loan-readiness weights or factors | `lib/features/legal_workstream/models/loan_readiness.dart` (one place: dashboard, PDF, Docs, Sheets and Slides all use it). Scored task titles must match the checklist exactly; `test/tor_checklist_test.dart` checks. |
| A tip (tour bubble) | `lib/features/tutorial/models/tour_catalog.dart`. Bubbles are 2 to 3 sentences (a test enforces it). A new spot needs a `TourAnchor` around the widget. |
| Red-dot events | A new migration replacing `my_attention()`; section names must equal the app's menu keys. |
| Brand colours, fonts | `lib/core/theme/` (`app_colors.dart`, `app_theme.dart`). Commercial brand fonts must never ship (DO_NOT_BREAK section 8). |
| Side menu items | `lib/core/widgets/app_shell.dart` and the `sections` lists in the workspace screens |
| Public links (site, download, legal pages) | `lib/core/site_links.dart` |
| Email templates | `docs/email/` then paste into Supabase → Authentication → Emails |

---

## 9. Tests

`flutter test` runs 55 tests, including:

- scoring and report content (`loan_readiness_report_test.dart`), ToR checklist integrity (`tor_checklist_test.dart`);
- the side menu at short heights for every role, red dots (`app_shell_test.dart`);
- every tour bubble's text rules and that each spot exists (`tutorial_test.dart`);
- the workshop CSV, password rules, programme measures, file filters, the update banner.

Database rules have no automated suite: they were tested by hand as real roles in rolled-back transactions (see the migration commit messages). Do the same for any new policy.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| White screen on the website | `.env` missing from the build, or dotfiles ignored in `firebase.json` | Restore `- .env` under `flutter: assets:`; the deploy check catches this |
| An old version still shows after a deploy | A browser still had the old service worker | One reload clears it now; `index.html` removes it |
| "Could not find the 'x' column ... schema cache" | A migration never reached the live DB | Compare live columns; add a new migration; `notify pgrst, 'reload schema'` |
| Google Connect fails with `redirect_uri_mismatch` | `GOOGLE_OAUTH_REDIRECT_URI` differs from the OAuth client's list | Make them identical, character for character |
| Invites stop arriving | SMTP app password revoked (Gmail password or 2-Step Verification changed) | New app password in Supabase SMTP settings |
| No push notifications | Webhook secret mismatch, or the phone has an old APK | Check `send-push` logs; reinstall the current APK |
| APK build crashes the machine | Not enough RAM | `./gradlew --stop`, close Chrome, retry |
| A consultant sees no tasks | No specialization set, or not assigned | Set it on Users; assign them |

---

## 11. Open items at handover

- **Google verification** was submitted on 5 Oct 2026 (review up to 4 to 6 weeks). Change nothing in Google Auth Platform until Google answers. After approval, remove the old `web.app` redirect URI and authorised domain.
- **Backups:** the free Supabase plan has none. Decide on a paid plan or scheduled manual dumps (`pg_dump`) before real data accumulates.
- **Offline use** during field visits isn't supported.
- **Lifecycle statuses** come from the original SRS, not the ToR, and nothing updates them automatically; **going concern** is a switch an Admin sets.
- **Scores** are this portal's own guide, not part of the ToR; AJW should confirm the weights.
- **One-step sign-in** (one Google consent that both signs in and connects the suite) is possible once Google approves; not built.
