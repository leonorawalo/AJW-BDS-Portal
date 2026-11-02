# Pre-launch security checklist

Run it before every release and after any change to the database, sign-in, uploads, Edge Functions or the website. Each check says how to verify it. Record the result in the last table (newest run first).

Shortcuts:

- `npx supabase db query --linked -f scripts/security_checks.sql`: checks A1–A11, read-only; every row should say `ok = true`;
- `npx supabase db advisors --linked --type security`: Supabase's own security advisor;
- `node scripts/check_contrast.js`: colour contrast (E16);
- `node scripts/build_legal.js --check` and `node scripts/check_do_not_break.js`: run automatically before each hosting deploy;
- `flutter analyze` and `flutter test`.

## A. Database and storage

| # | Check | How to verify |
|---|---|---|
| A1 | RLS enabled on every table | `security_checks.sql` |
| A2 | No table or view readable by signed-out (anon) users | `security_checks.sql` |
| A3 | No `SECURITY DEFINER` function executable by anon | `security_checks.sql` |
| A4 | Trigger functions not callable directly | `security_checks.sql` |
| A5 | Every function has a fixed `search_path` | `security_checks.sql` |
| A6 | Only the `downloads` bucket is public | `security_checks.sql` |
| A7 | Documents bucket limited to 20 MB | `security_checks.sql` |
| A8 | Audit log can't be changed by app users | `security_checks.sql` |
| A9 | Consent history is append-only | `security_checks.sql` |
| A10 | Google tokens unreadable by the app | `security_checks.sql` |
| A11 | Chat still delivered live | `security_checks.sql` |
| A12 | A consultant cannot open another enterprise's document, even with its direct link or storage path | rolled-back test as a real consultant: `select` on `documents` and `storage.objects` for an unassigned enterprise returns 0 rows |
| A13 | An owner sees only their own enterprise | same test as an owner |
| A14 | Chat: no access between enterprises | same test (`can_access_conversation`) |
| A15 | Supabase security advisor shows no ERROR, and only the accepted WARNs | `npx supabase db advisors --linked --type security` |

## B. Sign-in and sessions

| # | Check | How to verify |
|---|---|---|
| B1 | Every screen except login, forgot password and set password needs a signed-in user | `_publicPaths` in `app_router.dart`; open `/admin` signed out → sent to `/login` |
| B2 | A role can't open another role's screens by address | sign in as a consultant, type `/admin/users` → sent home |
| B3 | Administrator-only Edge Functions refuse others | call `manage-users` and `invite-user` with a consultant's token → 403 |
| B4 | Two-step verification: switched off by AJW (3 Nov 2026), `mfaRequiredRoles` is empty | sign in as each role → straight in after the password |
| B5 | Session times out after 30 idle minutes | leave the app idle → warning at 29 minutes, signed out at 30 |
| B6 | Password policy matches Supabase (8+, mixed case, digits, symbols) | Supabase → Authentication → Policies; `password_rules_test.dart` |
| B7 | Self sign-up is off; Google sign-in can't create accounts | Supabase setting; migration `20260928100000` |
| B8 | The app never stores or logs passwords | `grep -rn "password" lib` shows only the form fields and Supabase calls |
| B9 | Auth rate limits are sensible | Supabase → Authentication → Rate limits (dashboard; see AUDIT_REPORT.md) |

## C. Edge Functions

| # | Check | How to verify |
|---|---|---|
| C1 | Each function checks the token and role first | code review against SECURITY.md section 4; `config.toml` Verify JWT |
| C2 | CORS only for the portal's addresses | `curl -i -X OPTIONS -H "Origin: https://evil.example" <fn>` → no `Access-Control-Allow-Origin` |
| C3 | Errors are generic | force a failure (bad input) → a plain sentence, no SQL |
| C4 | Rate limits work | `rate_limit_hit` test in a rolled-back transaction (3rd call over a limit of 2 → false) |
| C5 | No secret ever returned | code review; responses contain ids, links and statuses only |

## D. Secrets and repository

| # | Check | How to verify |
|---|---|---|
| D1 | No secret in the code or config | search for the patterns in AUDIT_REPORT.md section 2 over the working tree |
| D2 | No secret in git history | the same patterns over `git log --all -p` (gitleaks when available) |
| D3 | `.env` holds only the URL and anon key, and is ignored | `git check-ignore .env`; read `.env.example` |
| D4 | Nothing private in the web build | `check_do_not_break.js` (no `.map`, keys, `.git`, SQL) |

## E. Website and app

| # | Check | How to verify |
|---|---|---|
| E1 | Security headers on | `curl -sI https://portal.ajwafrica.org/` shows Content-Security-Policy, Strict-Transport-Security, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy |
| E2 | The app works with them on | open the portal, sign in, open a document, send a chat message, schedule a meeting; browser console shows no "Content Security Policy" errors |
| E3 | No inline scripts | `check_do_not_break.js` |
| E4 | Release builds only | `flutter build web --release`; `flutter build apk --release` (no debug banner; `debuggable` false) |
| E5 | Cookie banner on the first visit; equal buttons; choice remembered; re-asked on a new policy version | private window → banner; choose → gone; change `POLICY_VERSION` → asked again |
| E6 | Sign-up consent: unticked boxes; Terms + Privacy + 18 or over required; programme emails optional; recorded with versions | new account → consent screen; `select * from user_consents where user_id = ...` |
| E7 | Deletion request end to end | person asks → Administrator "Carry out deletion" → person's data anonymised, login banned, confirmation email |
| E8 | Unsubscribe link works without signing in | `optional_email_permission(user)` token → open `/unsubscribe.html?token=...` → "You are unsubscribed"; preference off |
| E9 | Legal pages reachable signed out | links on the sign-in screen and every page footer |
| E16 | Colour contrast meets WCAG 2.1 AA | `node scripts/check_contrast.js` |
| E17 | Keyboard: Tab order, visible focus, Enter/Space, Escape closes dialogs, "Skip to main content" | web, keyboard only, on the sign-in screen and one page per role |
| E18 | Reduced motion and large text | system "reduce motion" on → no drifting shapes or intro animation; font size 200% → no clipped text |

## Results

### Run 1: 16–17 October 2026 (Claude Code, before the live deploy)

| # | Result | Evidence |
|---|---|---|
| A1, A2, A6, A7, A8, A10, A11 | **pass** | `security_checks.sql` on the live database |
| A3, A4, A5 | **fail before the migration** → **pass in a rolled-back test of migration `20261016100000`** | the advisor listed 22 anon-callable trigger functions and 5 without a `search_path`; the migration revokes and fixes them. **Re-run after applying.** |
| A9 | pending (the table is created by migration `20261016100000`); passed in the rolled-back test (update and forged source blocked, 42501) | |
| A12–A14 | pass (previous run, 8 Oct; chat isolation tested as real users); not re-run, as no policy changed except the new tables | |
| A15 | before: 0 ERROR, WARNs: 22 anon-callable definer functions (fixed by the migration), 5 mutable search paths (fixed), "authenticated can execute definer functions" (accepted: these are the app's own checked RPCs), OTP expiry 24 hours (accepted: invite links must last a day, DO_NOT_BREAK.md section 3), leaked-password protection off (needs a paid plan) | `npx supabase db advisors` |
| B1, B2, B7, B8 | pass | code review of `app_router.dart`, `auth_repository.dart`; `grep` |
| B3–B6 | pass (code review; B4–B6 tested by the user on 8 Oct) | |
| B9 | **not verified**: dashboard only | AUDIT_REPORT.md |
| C1, C5 | pass | code review of all 11 functions |
| C2, C3, C4 | C4 pass (rolled-back test); C2/C3 **pending deploy** | |
| D1, D2 | pass: no private keys, Google client secrets, Supabase secret keys or service-role tokens; only the public anon key (2026-08-21, a renamed `.env.example`) and Firebase public client ids | pattern scan of 78 commits; gitleaks not installed on this PC |
| D3, D4 | pass | `check_do_not_break.js` |
| E1–E3 | pass locally: headers served by a local copy of the hosting rules; login page, cookie banner and Supabase API + live-chat socket work with no policy violations; an outside domain is blocked; framing is blocked. **Re-check E1/E2 on the live site, signed in, after deploy.** | headless Edge |
| E4 | web: pass (`--release`). Android: built in release only (Flutter turns R8 shrinking on and `debuggable` off) | |
| E5, E6, E9 | pass locally (banner, legal links); E6 needs the live migration | screenshots |
| E7, E8 | pass in the rolled-back database test; end-to-end **pending deploy** | |
| E16 | **3 failures fixed**: AJW red text buttons on the page background 4.39 → 6.6:1 (now `brandRedDeep`); amber score and "Invited" #F9A825 1.97 → 5.43:1 (#9A5B00); "not done" grey #B2B2B2 2.12 → 3.56:1 (#8C8782). All 49 pairs now pass. | `check_contrast.js` |
| E17 | partly: skip link added (web), dialogs close on Escape (Flutter default), Tab order follows reading order. Focus indicators use Material's default focus highlight, which is faint on some buttons: **not verified to be 3:1** | |
| E18 | pass: the drifting shapes, intro animation and loader respect reduce motion; no text-scale clamps in the code | `grep` |
