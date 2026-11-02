# Sign-in and permissions

How people get into the AJW BAGS Portal, how long they stay in, and what each role can do. It is written from the code and the live database as of 17 October 2026.

## 1. Accounts

- **No public sign-up.** "Allow new users to sign up" is OFF in Supabase. Accounts exist only because an Administrator invited someone:
  - the `invite-user` Edge Function (Administrator only) sends the invite email;
  - the invite email's link (`/#/set-password?token_hash=...&type=invite`) lets the person choose a password.
- **Passwords**: handled entirely by Supabase Authentication, which stores them hashed (bcrypt). The app never stores, logs or sends a password anywhere except to Supabase's sign-in endpoint over HTTPS.
  - Policy: at least 8 characters, with lower case, upper case, digits and symbols (Supabase Auth settings; must match `PasswordRules` in `lib/features/auth/presentation/password_field.dart`).
- **Forgot password**: Supabase sends a one-time reset link. A new request cancels the previous link. The app only lets the link's own account set the new password (see `DO_NOT_BREAK.md` section 3).
- **"Continue with Google"**: only for existing accounts. A database rule (migration `20260928100000`) refuses to create a user from a Google sign-in. It uses its own Google project (`ajw-bags-sign-in`) with basic scopes only.
- **First sign-in gates** (`lib/core/widgets/security_gates.dart`, in this order):
  1. Consent (`ConsentGate`):
     - Required: the Terms of Service and Privacy Policy in their current versions, and confirming 18 or over. Both boxes start unticked.
     - Optional: programme emails.
     - The answers are kept in `user_consents`. A new document version asks again.
  2. Two-step verification for the roles in `mfaRequiredRoles`. **Currently none**: AJW decided on 3 Nov 2026 that everyone signs in with a password only. The gate stays in the code so roles can be added back in one line. It uses an authenticator app (Time-based One-Time Password, TOTP). Another Administrator can reset it (`manage-users` `reset_mfa`).
  3. Automatic sign-out after 30 minutes without activity (`InactivityLogout`), with a warning one minute before.

## 2. Sessions

| Item | Value |
|---|---|
| Access token (JSON Web Token, JWT) lifetime | 1 hour (Supabase default) |
| Refresh | Automatic by `supabase_flutter`, with refresh-token rotation on |
| Where the session is kept | Web: browser local storage (`sb-cgnmnqjyvlgyndhmicjl-auth-token`). Android: the app's private storage. |
| Idle sign-out | 30 minutes (app side) |
| Sign-out | Clears the session. The app releases the phone's push notification token *before* signing out (`AuthRepository.addBeforeSignOut`). |
| Suspension | `manage-users` `suspend`: the account is banned in Supabase Auth (no new sign-ins or refreshes; an open access token lasts at most an hour), and the push tokens are deleted. The router signs out a suspended profile at once. |
| Password change | Supabase keeps the other sessions until their refresh. [GAP: sign out other devices on a password change; listed in AUDIT_REPORT.md] |

## 3. Roles

Stored in `public.users.role_id` → `public.roles.role_name`. A trigger stops non-Administrators changing role, status, specialisation or email.

| Role | Who |
|---|---|
| Administrator | AJW programme staff |
| Consultant (Legal, Accounting or Marketing) | Business consultants assigned to enterprises (`users.specialization`) |
| Enterprise Owner | The owner of an enrolled business (`enterprises.owner_user_id`) |

Helper functions used by the policies (all `SECURITY DEFINER`, not callable by signed-out visitors):

- `is_admin()`;
- `is_assigned_consultant(enterprise)`: an active row in `consultant_assignments`;
- `is_enterprise_owner(enterprise)`;
- `is_collaborator(user)`;
- `is_bds_team()`: Administrators and consultants;
- `can_schedule_for_enterprise(enterprise)`: Administrators, assigned consultants and the owner;
- `can_access_conversation(conversation)`.

## 4. Permission matrix

Legend:

- **R** read, **C** create, **U** update, **D** delete; "—" none.
- "own" = rows they created or that are about them.
- "assigned" = enterprises with an active assignment.

Enforcement is the RLS policy named in the last column. The app's screens follow it.

### Tables

| Table | Administrator | Consultant | Enterprise Owner | Enforced by |
|---|---|---|---|---|
| `users` | R U all | R own + collaborators; U own (not role/status/email) | same as Consultant | `users_select_own_or_admin_or_collaborator`, `users_update_own_or_admin`, trigger `users_restrict_non_admin_updates` |
| `roles` | R C U D | R | R | `roles_all_admin`, `roles_select_authenticated` |
| `enterprises` | R C U D | R U assigned (financial facts only) | R U own (financial facts only) | `enterprises_*`, trigger `enterprises_restrict_non_admin_updates`; owner link set once (`enterprises_owner_link_rules`) |
| `consultant_assignments` | R C U D | R own and assigned enterprises | R own enterprise | `assignments_*` |
| `tasks` | R C (not status) | R own specialisation on assigned; C U D own | R C U own enterprise | `tasks_*` (9 policies), trigger `set_task_specialization` |
| `task_comments` | R C U D | R C on assigned enterprises | R C on own enterprise | `task_comments_*` |
| `documents` | R C U D | R C U D on assigned | R C own enterprise | `documents_*` |
| `recommendations` | R C U D | R C U D on assigned | R, U (status) own | `recommendations_*` |
| `assessments` | R C U D | R C U D on assigned | R own | `assessments_*` (RLS switched back on 8 Oct 2026) |
| `consultation_sessions` | R all, U | R organised or invited; C for enterprises they can schedule for; U own | same as Consultant | `consultation_sessions_*` |
| `session_participants` | R | R own and sessions they organise; C (organiser, checked by `can_add_session_participant`) | same | `session_participants_*` |
| `enterprise_files` | R; D | R C on their enterprises (meeting files: participants only); U D own | same | `enterprise_files_*` |
| `enterprise_visits` | R; D | R assigned; C U D own | R own enterprise | `enterprise_visits_*` |
| `success_stories` | R C U D | R C U D on assigned (U D own) | — | `success_stories_*`; under-18 check `success_stories_minor_needs_guardian` |
| `workshops`, `workshop_attendees` | R C U D | R C U (team) | — | `workshops_*`, `workshop_attendees_team_all` |
| `chat_conversations`, `chat_members`, `chat_messages` | members only | members only | members only | `can_access_conversation()`; send only as yourself |
| `chat_reads` | own | own | own | `chat_reads_select_own`; written via `mark_chat_read()` |
| `device_tokens` | own | own | own | `device_tokens_all_own`; `claim_device_token()` |
| `audit_log` | R | — | — | `audit_log_select_admin`; no C U D grants; written by triggers |
| `data_consents`, `user_consents` | R all; C own | R C own | R C own | `*_select`, `*_insert_own`; no U D (append-only) |
| `email_preferences` | R | R own (no token) | R own | column grant hides `unsubscribe_token`; changed only through `user_consents` |
| `data_requests` | R all; U (status, note) | R C own | R C own | `data_requests_*`, trigger `data_requests_rules` (deadlines, refusal reason) |
| `retention_settings` | R U | — | — | `retention_settings_admin` |
| `rate_limits` | — | — | — | service role only |
| `google_connections`, `google_oauth_states`, `attention_seen` | — | — | — | RLS on, no policies: server only (`get_my_google_connection()`, `mark_seen()`) |

### Storage buckets

| Bucket | Public? | Administrator | Consultant | Enterprise Owner |
|---|---|---|---|---|
| `documents` (20 MB) | private | everything | R C U D in assigned enterprises' folders | R C own enterprise's folder |
| `documents` workshop lists (`<workshop id>/...`) | private | R | C own lists for team workshops, R own | — |
| `chat-attachments` (10 MB, types limited) | private | members of the conversation | members | members |
| `downloads` | **public on purpose** (the Android app file only) | — | — | — |

Files open through signed links that expire after **5 minutes**. Views and downloads are logged (`log_document_access()`).

### Screens (app router, `lib/core/router/app_router.dart`)

- Signed out: only `/login`, `/forgot-password` and `/set-password`. The public legal pages are separate static pages on the website.
- Each role has its own home (`/admin`, `/consultant`, `/owner`). Typing another role's address sends you back to yours.
- `/workstream/...` (Task Detail) is shared by all three roles. RLS decides what it shows.
- Administrator-only menu items: Users, Audit log, Data requests, Programme, Workshops, Documents. The server enforces each one too (functions check `is_admin()`, and the tables use the policies above).

### Edge Functions

| Function | Verify JWT | Who may call | Extra checks |
|---|---|---|---|
| `invite-user` | on | Administrator (`is_admin()`) | input validation, 50 per hour |
| `manage-users` | on | Administrator | not yourself; not the last Administrator; 60 per hour |
| `calendar-sessions` | on | signed-in; enterprise access via `can_schedule_for_enterprise` with the caller's JWT | 120 per hour |
| `gmail-send` | on | signed-in; recipients must be in `enterprise_email_contacts()` (Administrators: any active user) | 20 recipients max, 30 per hour |
| `gmail-inbox` | on | signed-in; enterprise contacts only | dormant until `gmail.readonly` is approved |
| `drive-files` | on | signed-in; `can_schedule_for_enterprise` | 60 per hour |
| `google-export` | on | signed-in (files go to the caller's own Drive) | 2 MB body max, 40 per hour |
| `meeting-notes` | on | session organiser or participant | dormant until `meetings.space.readonly` is approved |
| `google-oauth` | off | `start` and `disconnect`: caller's JWT checked inside; callback: random single-use `state`, 15 minutes | 30 per hour |
| `send-push` | off | Database Webhooks and `calendar-sessions` only (`x-webhook-secret`) | refuses everything if the secret is unset |
| `email-unsubscribe` | off | anyone holding a person's unsubscribe token | 30 per 10 minutes per address |

## 5. Google connections

Two separate Google features:

1. **Google suite** (project `ajw-bags-portal`), one connection per person (Sessions tab, "Connect"):
   - `google-oauth` stores the **refresh token** in `google_connections`. That table has RLS on and no policies, so only the server can read it. The app never sees a Google token.
   - Edge Functions exchange the refresh token for a one-hour access token on each use (`_shared/google.ts` `accessTokenFor`).
   - `invalid_grant` (revoked, or expired in Testing) deletes the connection, so the app offers "Connect" again.
   - "Disconnect" revokes the token at Google and deletes the row.
2. **"Continue with Google"** (project `ajw-bags-sign-in`): sign-in only. Scopes: openid, email, profile. No token is kept.

Scopes requested by `google-oauth`, and why:

| Scope | Sensitivity | Why |
|---|---|---|
| `openid`, `email` | non-sensitive | Which Google account is connected |
| `calendar.events` | sensitive | Create and cancel the meeting events the person books in the portal |
| `calendar.freebusy` | non-sensitive | Check availability before booking (free or busy only) |
| `drive.file` | non-sensitive | Create and open only the files the portal makes |
| `gmail.send` | sensitive | Send emails the person writes in the portal, from their Gmail |
| `meetings.space.readonly` | sensitive | NOT requested yet (meeting notes, dormant) |
| `gmail.readonly` | restricted | NOT requested yet (inbox, dormant) |

Google's app verification has been under review since 5 October 2026. Change nothing in Google Auth Platform until it ends (`DO_NOT_BREAK.md` section 7).
