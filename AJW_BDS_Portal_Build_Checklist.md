# AJW BDS Portal — Full Build Checklist

A single reference for every phase, broken down into individual steps. Checked items reflect what's actually been done in this project so far; unchecked items are what's ahead. Update this file as you go — it doubles as your attachment report's progress log.

---

## Phase 0 — Foundation

**Project setup**
- [x] Flutter project created (`the_app`)
- [x] Web platform target enabled
- [x] Directory structure decided (feature-first: `lib/core`, `lib/features/<name>`, `lib/shared`)

**Design**
- [x] ERD drafted — 14 entities, relationships mapped
- [x] Going Concern vs. Loan Ready modeled as two independent fields (not one status enum)
- [x] EnterpriseVisits scaffolded in design (TOR-driven, not in original SRS)
- [x] Open questions resolved (startup baseline, visit scaffolding timing, nullable owner_user_id)

**Supabase account & project**
- [x] Supabase account created
- [x] Project created (`ajw-bds-portal`, region: eu-west-1 / Europe)
- [x] "Automatically expose new tables" unchecked at project creation
- [x] Project URL retrieved (`https://<project-id>.supabase.co`)
- [x] Anon key retrieved (from **Legacy anon, service_role API keys** tab — not the newer Publishable/Secret keys, for `supabase_flutter` ^2.5.6 compatibility)

**Environment config**
- [x] `.env` created with real `SUPABASE_URL` / `SUPABASE_ANON_KEY`
- [x] `.env` added to `pubspec.yaml` under `flutter: assets:`
- [x] `.env` added to `.gitignore`
- [x] `pubspec.yaml` dependencies added: `flutter_riverpod`, `go_router`, `supabase_flutter`, `flutter_dotenv`

**Environment troubleshooting (Windows-specific)**
- [x] Windows Developer Mode enabled (`start ms-settings:developers`) — required for plugin symlink support
- [x] Project moved out of OneDrive-synced folder (`C:\Users\user\AJW-BDS-Portal`) — OneDrive file-locking breaks `pub get` / builds
- [x] `ios/Flutter/ephemeral` excluded from the OneDrive→local move (or `ios/` folder removed, if not targeting iOS yet)

**Git / GitHub hygiene**
- [x] Confirmed correct git repo root (was accidentally one level up from `the_app/`)
- [x] `node_modules/` removed from tracking (`git rm -r --cached node_modules`) — was pulling in a 121 MB Supabase CLI binary that exceeded GitHub's 100 MB limit
- [x] Flutter SDK folder removed from tracking (was accidentally sitting inside the repo as an embedded/submodule-like folder)
- [x] Old prototype (`ajw_bds_app_flutter_v1`) and stray `.zip` files excluded via `.gitignore`
- [x] `.gitignore` includes: `node_modules/`, `build/`, `.dart_tool/`, `*.zip`, `flutter/`, `.env`
- [x] Fresh clone verified working outside OneDrive, connected to `origin` (GitHub)
- [x] Confirmed `.env` was never committed (`git ls-files | findstr .env` returns nothing)

**Verify it runs**
- [x] `flutter pub get` completes with no errors
- [ ] `flutter pub outdated` reviewed (informational only — not blocking)

---

## Phase 1 — Module 1: Auth & RBAC

**Database**
- [x] Migration written: `roles` + `users` tables
- [x] Default roles seeded (Administrator, Consultant, Enterprise Owner)
- [x] `handle_new_user()` trigger written (auto-creates `public.users` row on sign-up, reads `role_name` from metadata)
- [x] `is_admin()` helper function written (SECURITY DEFINER, avoids RLS recursion)
- [x] RLS enabled on `roles` and `users`
- [x] RLS policies written (roles: read-all/admin-write; users: own-row-or-admin read/write)
- [x] Migration applied to live Supabase project (`supabase link` + `supabase db push`)

**App code**
- [x] `AuthRepository` built (signIn, signUp, resetPassword, signOut, fetchUserProfile)
- [x] `UserProfile` model + `UserRole` enum built
- [x] Riverpod providers built (`supabaseClientProvider`, `authRepositoryProvider`, `authStateChangesProvider`, `currentUserProfileProvider`)
- [x] `GoRouterRefreshStream` bridge built (stream → Listenable for router redirects)
- [x] `app_router.dart` built — role-based redirect logic, suspension check
- [x] `LoginScreen` built
- [x] `RegisterScreen` built (⚑ temporary role-picker dropdown — flagged for replacement in Phase 9)
- [x] `ForgotPasswordScreen` built
- [x] `main.dart` wired (dotenv load → Supabase.initialize → runApp)
- [x] `app.dart` wired (MaterialApp.router + routerProvider)
- [x] Placeholder home screens built (`/admin`, `/consultant`, `/owner`)

**Outstanding config**
- [ ] Fix Supabase email domain restriction (currently rejecting valid addresses like gmail.com)
- [ ] Check "Confirm email" toggle in Supabase Auth settings — decide on/off for dev phase
- [ ] Clean up stray leftover test file / duplicate `flutter:` blocks in `pubspec.yaml` if not already resolved

**Milestone check (Phase 1 complete when all true)**
- [ ] Register one test account per role (Administrator, Consultant, Enterprise Owner)
- [ ] Each role signs in successfully
- [ ] Each role lands on its correct placeholder home screen
- [ ] Unauthorized cross-role navigation is blocked

---

## Phase 2 — Module 2: Enterprise Management

- [ ] Migration: `enterprises` table (lifecycle_status, going_concern_status, going_concern_achieved_at, enrolled_at, owner_user_id nullable FK)
- [ ] Decide: model status-change history now (`enterprise_status_log`) or defer
- [ ] RLS policies: Admin full access; Consultant sees only assigned enterprises; Owner sees only their own
- [ ] Migration applied (`supabase db push`)
- [ ] `Enterprise` model built
- [ ] `EnterpriseRepository` built (CRUD)
- [ ] Riverpod providers for enterprise list/detail
- [ ] Admin: Register Enterprise screen (form)
- [ ] Admin: Enterprise list screen
- [ ] Admin: Enterprise detail screen
- [ ] `/admin` route wired to real screens (replacing placeholder)
- [ ] **Milestone check:** Admin creates/edits an enterprise; status transitions persist correctly

---

## Phase 3 — Module 3: Consultant Assignment & Portfolio

- [ ] Migration: `consultant_assignments` table
- [ ] RLS: consultant sees only their own assignments; admin sees all
- [ ] `ConsultantAssignment` model + repository built
- [ ] Admin: Assign Consultant screen
- [ ] Consultant: Portfolio Home screen (filtered enterprise list)
- [ ] `/consultant` route wired to real screens
- [ ] **Milestone check:** consultant sees only their assigned enterprises (RLS-enforced, not just UI-filtered)

---

## Phase 4 — Module 4: Legal Workstream (largest phase — plan ~2 weeks)

- [ ] Migration: `assessments` table
- [ ] Migration: `tasks` table
- [ ] Migration: `task_comments` table
- [ ] Migration: `recommendations` table
- [ ] Migration: `documents` table (with nullable `task_id` FK for attachments)
- [ ] Seed TOR-derived legal compliance task checklist template
- [ ] RLS policies for all five tables above
- [ ] Models + repositories built for Task, Assessment, Recommendation
- [ ] Consultant: Assessment screen
- [ ] Consultant: Task list/detail screen (create, update, mark complete)
- [ ] Consultant: Recommendation screen
- [ ] Enterprise Owner: read-only workstream view
- [ ] Enterprise Owner: comment on task
- [ ] Enterprise Owner: mark recommendation as actioned
- [ ] **Milestone check:** full task lifecycle works end-to-end across both roles, correct permission boundaries throughout

---

## Phase 5 — Module 5: Documents

- [ ] Supabase Storage bucket created
- [ ] Storage-level RLS policies written
- [ ] Upload widget built
- [ ] View/download screen built
- [ ] Embedded into task/assessment views
- [ ] **Milestone check:** documents upload, are categorized, and only authorized users can access them

---

## Phase 6 — Module 6: Notifications

- [ ] Firebase project set up
- [ ] FCM configured for Flutter (Android + Web)
- [ ] Migration: `notifications` table
- [ ] Notification Centre widget built (shared component)
- [ ] Event triggers wired: task/document events → notification created
- [ ] **Milestone check:** events generate notifications within seconds; badge/read-state work correctly

---

## Phase 7 — Module 7: Enterprise Portal + Google Calendar

- [ ] Owner dashboard aggregation screen built
- [ ] Migration: `google_credentials` table (already designed in ERD)
- [ ] Google OAuth Edge Function written
- [ ] Calendar sync Edge Function written
- [ ] "Connect Google Calendar" settings toggle built
- [ ] **Milestone check:** connecting Calendar once, then setting a task due date, creates a real calendar event

---

## Phase 8 — Module 8: Reporting

- [ ] Migration: `reports` table
- [ ] PDF report generation built (consultant + enterprise reports)
- [ ] Google Sheets export Edge Function written
- [ ] Admin KPI dashboard built (totals, Going Concern %, overdue count)
- [ ] **Milestone check:** reports generate from live data and export correctly

---

## Phase 9 — Module 9: User Management & Audit

- [ ] Migration: `audit_logs` table
- [ ] Admin: user create/suspend screens built
- [ ] Register screen's dev-only role dropdown replaced with real Admin-driven invite flow
- [ ] Audit logging hooks wired across every prior module's key actions
- [ ] **Milestone check:** suspended users can't log in; key actions appear in the immutable audit log

---

## Phase 10 — Cross-cutting polish

- [ ] `core/theme` built (deep brand red for primary/logo, semantic red reserved strictly for "Overdue" status)
- [ ] Web build tested/polished specifically for Admin desktop use (layout at wider viewports)
- [ ] Empty states added across all screens
- [ ] Loading states added across all screens
- [ ] Error states added across all screens
- [ ] Full regression pass across all three roles

---

## Phase 11 — Wrap-up

- [ ] Release APK / App Bundle built
- [ ] Demo/walkthrough script prepared for attachment presentation
- [ ] Documentation cleanup — FR/module traceability for attachment report

---

## Appendix: Environment gotchas learned (for your own reference / report)

- **OneDrive + Flutter don't mix.** File-locking during builds causes cryptic "cannot access file/directory" errors. Keep Flutter projects outside any cloud-synced folder.
- **Windows symlink support is off by default.** Several plugins need it during build. Enable via `start ms-settings:developers`.
- **`git add .` only stages the current folder and below** — it won't reach sideways into sibling folders in the same repo. Always check *which* folder you're standing in before assuming `git status`/`git add .` covers everything.
- **Never let npm-installed CLI tools (e.g. Supabase CLI) live inside a git-tracked project folder.** Binaries like `supabase.exe` can exceed GitHub's 100 MB file limit and get an entire push rejected.
- **Supabase has two key systems now** — newer Publishable/Secret keys, and the older anon/service_role keys. `supabase_flutter` ^2.5.6 expects the older format — use the "Legacy" tab when copying keys.
- **New Supabase projects auto-expose new tables to the API by default** — turn this off at project creation so RLS policies are the single source of truth for access control.
- **Supabase Auth can silently reject valid-looking emails** if a domain restriction is configured — check Authentication settings if sign-up fails with an "invalid email" message for an obviously valid address.
