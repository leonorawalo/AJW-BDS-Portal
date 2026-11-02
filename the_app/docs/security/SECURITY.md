# Security rules for this project

Who this is for: anyone changing the AJW Business Advancement and Growth Services (BAGS) Portal, including Artificial Intelligence (AI) coding assistants. Read it before every change, together with the other files in `docs/security/`:

- [`AUTH.md`](AUTH.md): who can sign in and do what;
- [`DATA_SECURITY.md`](DATA_SECURITY.md): what data the portal holds and how it is protected;
- [`THREAT_MODEL.md`](THREAT_MODEL.md): what could go wrong;
- [`SECURITY_CHECKLIST.md`](SECURITY_CHECKLIST.md): the checks to run before a release;
- [`AUDIT_REPORT.md`](AUDIT_REPORT.md): the latest audit.

`DO_NOT_BREAK.md` (project root) lists the settings that must match across Supabase, Google and Firebase.

Each rule says what the code does today and what every change must keep doing.

## 1. The real security boundary is the server

The app runs on people's phones and in their browsers, so anyone can change it. Never rely on the app alone to protect data.

| Layer | What it enforces | Where |
|---|---|---|
| Row Level Security (RLS) | Who can read and write each row, on **every** table in `public` | `supabase/migrations/*.sql` |
| Storage policies | Who can read and upload each file | the same migrations (`storage.objects` policies) |
| Database functions and triggers | Derived values, deadlines, the audit log, role checks | `SECURITY DEFINER` functions in the migrations |
| Edge Functions | Anything needing a secret (Google, push notifications, invites, account bans) | `supabase/functions/*` |
| App (`go_router` guards, hidden buttons) | Convenience only | `lib/` |

Rules:

- Write the RLS policy first, then build the screen around what it allows.
- A new table gets RLS (it is switched on automatically by the `ensure_rls` event trigger), least-privilege policies and explicit `GRANT`s. "Automatically expose new tables" is off.
- Never `grant ... to anon` unless a signed-out visitor truly needs it. Today nothing in `public` is readable by `anon`.
- A `SECURITY DEFINER` function must:
  - set `search_path`;
  - check the caller (`auth.uid()`, `is_admin()` and the like) before doing anything;
  - be `revoke`d from `public, anon` (and from `authenticated` if only Edge Functions call it).
- Trigger functions are never callable directly (migration `20261016100000` revokes them).
- Derived fields (`completed_at`, deadlines, `resolved_by`) are set by triggers, never sent by the app.

## 2. Input from users

Treat everything from the app as untrusted.

- **Validate on the server.** Use database `check` constraints, triggers and Edge Function checks. App-side checks are for usability only.
- **Queries.** Use the Supabase client's query builder or `rpc()` with parameters. Never build SQL from strings. In `plpgsql`, use `format('%I', ...)` / `%L` for dynamic identifiers, and avoid dynamic SQL when you can.
- **Uploads.**
  - Documents: at most 20 MB (the `documents` bucket limit, also checked in the app). Chat attachments: at most 10 MB (the `chat-attachments` bucket limit and type list).
  - Allowed types are listed in `DocumentRepository.allowedTypes` and `ChatRepository.allowedTypes`.
  - The app checks the file's first bytes, not just its name (`lib/core/file_signature.dart`).
  - Files are stored with an explicit content type, under a path that starts with the enterprise or conversation id (storage policies depend on it).
- **Displaying content.** Flutter draws text itself; never render user content as HTML. The website's static pages contain no user content. If you ever add HTML rendering (for example an email body), escape it or use a sanitiser, and add a check to the checklist.
- **Lengths.** Every free-text column has a length `check` or a matching limit in the Edge Function (chat 4,000; requests 4,000; email body 20,000 characters).

## 3. Secrets

| Secret | Where it lives | Never in |
|---|---|---|
| Supabase service role key | Edge Function environment (automatic) | the app, `.env`, git, logs |
| `GOOGLE_CLIENT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_OAUTH_REDIRECT_URI` | Supabase Edge Function secrets | the app, git |
| `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PROJECT_ID` | Supabase Edge Function secrets | the app, git |
| `WEBHOOK_SECRET` | Supabase Edge Function secrets + the Database Webhooks' header | the app, git |
| Gmail SMTP app password | Supabase Auth SMTP settings | anywhere else |
| Android signing key | `C:\Users\user\AJW-BDS-Keys\` (outside the repo) | git, OneDrive |

What is safe in the app:

- the Supabase URL and the **anon** key (in `.env`, shipped inside the app; RLS protects the data);
- Firebase's public client identifiers (`AIza...` in `firebase_options.dart` and `google-services.json`).

`.env.example` shows the format with placeholder values. `.env`, `client_secret*.json`, `key.properties` and keystores are in `.gitignore`.

**If a secret leaks:**

1. Rotate it at once: create a new one and revoke the old one. Deleting it from git history is not enough.
2. Update the Supabase secret.
3. Redeploy the functions that use it.
4. Record it in `AUDIT_REPORT.md`.

How to rotate each one: `DO_NOT_BREAK.md` section 3 (Firebase key) and section 2 (Google client).

## 4. Edge Functions

Every function the app calls uses `supabase/functions/_shared/http.ts`:

- `serve()` answers browsers only from `https://portal.ajwafrica.org`, `https://ajwafrica-bags-portal.web.app` and `http://localhost` / `127.0.0.1`. Other web origins get no `Access-Control-Allow-Origin`. The Android app sends no `Origin` header and is unaffected.
- `serverError()` logs the real error and returns a generic sentence. Never return `e.message`, SQL errors, Google error bodies or stack traces with status 500.
- `rateLimited()` limits calls per user per hour (counted in `public.rate_limits`).
  - Current limits: `gmail-send` 30, `google-export` 40, `invite-user` 50, `drive-files` 60, `manage-users` 60, `calendar-sessions` 120, `meeting-notes` 200, `gmail-inbox` 300, `google-oauth` 30.
  - `email-unsubscribe` is limited per address: 30 every 10 minutes.

Each function must:

1. check the caller's token (`auth.getUser`) unless it is a webhook (`send-push`: shared secret) or a public link (`google-oauth` callback, `email-unsubscribe`: unguessable single-purpose token);
2. check the caller's role or relationship (`is_admin`, `can_schedule_for_enterprise`, ...) using the **caller's** JWT where possible, so RLS still applies;
3. validate and size-limit its input;
4. use the service role client only for what the caller cannot do themselves;
5. never return a secret or a Google token.

"Verify JWT" settings are in `supabase/config.toml`. They are OFF only for `send-push`, `google-oauth` and `email-unsubscribe`. Deploy with the CLI only (`npx supabase functions deploy <name>`).

## 5. The website

- Hosting headers (`firebase.json`, checked by `scripts/check_do_not_break.js`):
  - `Content-Security-Policy`: scripts only from the site itself and Google's gstatic.com (CanvasKit), with WebAssembly allowed; connections only to the site, Supabase and gstatic; no framing; no plugins;
  - `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`.
- No inline `<script>` in any `web/*.html`: the policy blocks it, and the deploy check fails. Put scripts in `.js` files.
- If you add a new external service, add it to the Content-Security-Policy, to the Privacy Policy's processor list and to `DATA_SECURITY.md` in the same change.
- Never upload source maps, `.git`, keys or SQL with the site (the deploy check fails).
- Web builds are always `flutter build web --release`.

## 6. Error messages

- To people: plain sentences only. In the app, show `userMessage(e)` (`lib/core/user_message.dart`). It passes through the sentences our own rules raise, and hides SQL, table names and stack traces.
- To developers: `debugPrint` only inside `if (kDebugMode)`. Edge Functions use `console.error` (Supabase function logs, visible to project admins only).

## 7. Logging

Never log passwords, tokens (Supabase, Google, push notification), invite or reset links, or document and message contents.

- The audit log (`public.audit_log`) records who did what. Only database triggers and `log_document_access()` write to it.
- The audit log is readable by Administrators only, and never deleted by retention. When a person's data is erased, their name and email in it become "a deleted user".

## 8. Dependencies

- Add a package only when it is needed, and pin it to a caret range in `pubspec.yaml`.
- Prefer packages from verified publishers.
- Run `flutter pub outdated` before each release. Apply minor and patch updates, run `flutter analyze` and `flutter test`, and test major updates on their own branch.
- Remove unused packages.
- Every external service a package calls must appear in the Privacy Policy and the Content-Security-Policy.
- Website build tools (`marked`, `supabase` CLI) are `devDependencies`, pinned in `package.json`.

## 9. Code review

Before merging or deploying:

- [ ] `flutter analyze` is clean and `flutter test` passes.
- [ ] New tables, buckets and functions follow section 1. Test them as each role in a `begin; ... rollback;` block (see `docs/HANDOVER.md`).
- [ ] No secret in the diff (`git diff | grep -iE "secret|private key|service_role|GOCSPX|sb_secret"`).
- [ ] Error messages follow section 6.
- [ ] `docs/security/` is updated if the change touches sign-in, roles, data handling, a third party or a header.

## 10. Rules for AI assistants

Follow these on every task:

1. Read `CLAUDE.md`, `DO_NOT_BREAK.md` and this folder before changing config, the database, Edge Functions, sign-in, uploads or the website.
2. Enforce access on the server (RLS, storage policies, function checks). Never only in the app.
3. Never put a secret in code, `.env`, a commit, a log or a chat message. Never print one you come across.
4. Database changes go in a new migration. Never edit an applied migration. Test migrations as real roles in a rolled-back transaction before applying them.
5. Do not weaken a policy, header, rate limit or check to make something work. Find the real cause, or ask.
6. A change that alters what people can see or do needs the project owner's approval first.
7. Update the matching document here, and `SECURITY_CHECKLIST.md`, in the same change.
8. Say what you could not verify. Do not assume it is safe.
