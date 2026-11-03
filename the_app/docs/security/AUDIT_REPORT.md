# Security and compliance audit: 16–17 October 2026

**Scope:** the AJW BAGS Portal (Flutter web + Android, Supabase project `cgnmnqjyvlgyndhmicjl`, Edge Functions, Firebase Hosting), checked against `docs/security/SECURITY.md`, the Kenya Data Protection Act, 2019, and the legal, privacy and accessibility prompt (`06/10/2026_meeting_updates_requested.txt`, second part). The previous audit is `docs/SECURITY_REPORT_2026-10-08.md`.

**Status words:**

- **Fixed:** done and verified as described.
- **Fixed, pending deploy:** done in the code or migration and tested locally, but not yet live.
- **Open:** needs AJW's input or decision.
- **Not verified:** could not be checked from here. That does not mean it is safe.

## 1. Issues found

| # | Issue | Severity | Status | How it was verified |
|---|---|---|---|---|
| 1 | 22 trigger functions (`SECURITY DEFINER`) callable as plain functions by signed-out visitors, and all trigger functions by signed-in users (advisor `anon_security_definer_function_executable`). Postgres refuses to run a trigger function outside a trigger, so nothing could actually be done with them, but they should not be exposed. | Low | Fixed, pending deploy (migration `20261016100000`) | rolled-back test: direct call refused (42501); triggers still fire (data request deadline set, `updated_at` set, audit rows written) |
| 2 | 5 functions without a fixed `search_path` (advisor `function_search_path_mutable`) | Low | Fixed, pending deploy (same migration) | `scripts/security_checks.sql` A5 after apply |
| 3 | Every Edge Function answered browsers from any website (`Access-Control-Allow-Origin: *`) | Medium | Fixed, pending deploy: `_shared/http.ts` allows only the portal's addresses and localhost | code; check C2 after deploy |
| 4 | Edge Functions returned raw error text (SQL errors, Google error bodies, `e.message`) with status 500 | Medium | Fixed, pending deploy: `serverError()` logs the detail and returns a plain sentence | code review of all 10 functions |
| 5 | No rate limits on the functions that send email, create meetings or call Google | Medium | Fixed, pending deploy: per-user hourly limits (`rate_limits`, `rate_limit_hit()`) | rolled-back test (limit 2: true, true, false) |
| 6 | Web hosting sent no security headers (no Content-Security-Policy, HSTS, nosniff, frame protection, referrer or permissions policy) | Medium | Fixed, pending deploy (`firebase.json`); inline scripts moved to files (`boot.js`, `splash.js`, `oauth/google-callback.js`) | local server with the same headers: app, banner, Supabase API and live chat work; outside domains and framing blocked |
| 7 | The app showed raw exception text to users in about 25 places (for example `PostgrestException(message: ..., code: ...)`) | Low | Fixed (`userMessage()`); keeps the readable sentences our database rules raise | unit tests |
| 8 | Uploads checked by file extension only (a renamed program would be accepted as `.pdf`) | Medium | Fixed: first-bytes check for documents and chat attachments (`file_signature.dart`) | unit tests |
| 9 | Refusing a data request did not require a reason | Low | Fixed, pending deploy: database rule + the app asks for one | rolled-back test |
| 10 | No record of agreement to the Terms of Service, no 18-or-over confirmation, no separate optional-email consent | Medium (legal) | Fixed, pending deploy: `user_consents` (append-only, versioned) + new consent screen | unit tests; rolled-back database test |
| 11 | No way to actually carry out an approved deletion request (only a status change) | Medium (legal) | Fixed, pending deploy: `erase_user_personal_data()` + `manage-users` `erase` + "Carry out deletion" | rolled-back test on a real owner: profile, enterprise contact fields and audit names anonymised; refused for a consultant with active assignments |
| 12 | Success stories could mention children without a guardian's consent | Medium (legal) | Fixed, pending deploy: "under 18" + guardian consent, enforced by a database constraint | code; constraint in the migration |
| 13 | Colour contrast below WCAG 2.1 AA: red text buttons on the page background (4.39:1), amber score ring and "Invited" label (1.97:1), "not done" grey ticks (2.12:1) | Medium (accessibility) | Fixed; all 49 checked pairs pass | `node scripts/check_contrast.js` |
| 14 | Two icon-only controls without a screen-reader label (send comment, viewed image) | Low | Fixed | code |
| 15 | No "skip to main content" on the web | Low | Fixed (`SkipToContent` in the app shell; skip link on every public page) | code |
| 16 | Legal pages edited as HTML by hand, so there was no single editable source, no versions, and no cookie or refund policy | — | Fixed: `legal/*.md` + `legal/business.json` → `scripts/build_legal.js`; the deploy fails if pages are stale | `--check` mode |
| 17 | Unused packages `fl_chart` (removed). `cupertino_icons` kept: a dependency needs its font. | Low | Fixed | build |
| 18 | `users.phone_number` exists, is unique, is never collected | Low (data minimisation) | Open, for AJW: drop the column, or keep it unused. The Privacy Policy now says the portal doesn't collect it. | |
| 19 | No backups (Supabase free plan) | High | Open, for AJW: upgrade to Pro (daily backups) or approve the parked weekly audit export (`supabase/pending_approval/`) | |
| 20 | Audit-log hardening (actor role, database-level append-only guard, weekly backup) is still parked | Medium | Open, for AJW: approve `supabase/pending_approval/audit_log_role_append_only_backup.sql` (needs a scheduled job and a new secret) | |
| 21 | Two-step verification is required for Administrators and Owners only; consultants can see several enterprises' documents | Medium | Open, for AJW: add Consultant to `mfaRequiredRoles` (one line, but every consultant must enrol at the next sign-in) | |
| 22 | Two-step verification is enforced in the app, not yet by database policies (`aal2`) | Medium | Open: do it after everyone has enrolled (2026-10-08 report, item 4) | |
| 23 | Password change doesn't sign out other devices | Low | Open: `signOut(scope: others)` after a change; a behaviour change for AJW to approve | |
| 24 | The documents bucket doesn't restrict content types (old APK 1.2.1 uploads without one) | Low | Open: set `allowed_mime_types` once every phone runs the next APK. The new content check covers the app side. | |
| 25 | (Fixed 3 Nov 2026, see section 10) The PDF viewer on the **web** needs pdf.js, which is not loaded in `web/index.html`, so PDFs open with "Could not load this document" on the web (Android works) | Low (existing bug) | Open: not caused by this change; fix by adding pdf.js (and its domain to the Content-Security-Policy), or open PDFs in a new tab on the web | code reading only, **not verified in a browser** |
| 26 | Material's default keyboard focus highlight is faint on some buttons | Low (accessibility) | Open: a stronger focus ring needs a theme change for every button type; not done to avoid restyling the app without approval | |
| 27 | Major package updates available (go_router 14 → 18, Firebase 4 → 5, file_picker 12 → 13, flutter_dotenv 5 → 6) | Low | Open: each has breaking changes; update one at a time on a branch with a full test. Minor and patch updates were applied (flutter_riverpod 3.4.3, supabase_flutter 2.18.3, url_launcher 6.3.3, file_picker 12.3.0). | `flutter pub outdated` |

## 2. Secrets: repository and history

- **Working tree:** only the Supabase URL and anon key (`.env`, ignored, in assets by design) and Firebase public client ids. `client_secret_*.json` is in the folder but ignored and never committed. `.env.example` added (placeholders only).
- **History:** all 78 commits on all branches were scanned for private keys, Google OAuth client secrets (`GOCSPX-`), Supabase secret keys (`sb_secret_`), JSON Web Tokens, AWS, GitHub and Slack tokens, and `sk-` keys.
  - The only JWT found is the **anon** key (role `anon`), committed on 21 Aug 2026 and later renamed. It is public by design, so no rotation is needed.
  - The "PRIVATE KEY" matches are the code that parses the Firebase key (`send-push`), not a key.
  - `gitleaks` and `trufflehog` are not installed on this PC, so this was a pattern scan. Run gitleaks once in Continuous Integration (CI) or on another machine for a second opinion.
- **Keys you must rotate:** none.

## 3. Software development kit (SDK) and third-party audit

| Package or service | What it does | Data it receives | Tracks users? | Needed? |
|---|---|---|---|---|
| supabase_flutter | Database, sign-in, storage, realtime | all app data, over HTTPS | no | yes |
| firebase_core, firebase_messaging | Android push notifications (not started on the web) | device token, notification text | no (no Analytics package) | yes |
| go_router, flutter_riverpod | navigation, state | none | no | yes |
| flutter_dotenv | reads `.env` | none | no | yes |
| file_picker | choose and save files | the chosen file, locally | no | yes |
| url_launcher | open links | the link | no | yes |
| pdfx | in-app PDF viewer | the document, locally | no | yes (Android; see issue 25 for the web) |
| pdf, printing, barcode | build and share PDF reports; QR code for two-step set-up | local only (printing loads pdf.js from unpkg.com only for printing or rasterising, which the app doesn't use) | no | yes |
| http | fetches `android-latest.json` (update notice) | none | no | yes |
| cupertino_icons | icon font a dependency needs | none | no | yes |
| fl_chart | charts | — | no | **removed** (unused) |
| Google gstatic.com (from the Flutter engine) | CanvasKit graphics engine, fallback fonts | IP address | no cookies | yes (web) |
| Dev only: flutter_lints, flutter_launcher_icons, marked, supabase CLI | build tools | none at run time | — | yes |

All processors are named in the Privacy Policy, section 6.

## 4. Fixed without changing features (contradictions)

Issues 1–9 and 13–17. None changes what anyone can see or do. These ones change wording or appearance only:

- Error messages are plainer.
- Text buttons are a deeper red.
- The amber and "not done" colours are darker.
- "My data and privacy" is now **Settings and privacy**.
- An open data request now reads "Received".

## 5. Behaviour changes made, because the prompt asked for them

- **Everyone is asked once** to accept the Terms of Service 2.0 and Privacy Policy 2.0 and confirm they are 18 or over. Saying no signs them out.
- Administrators can **carry out** deletion requests.
- The first visit to the website shows a **cookie banner**.

## 6. Behaviour changes NOT made, waiting for AJW's decision

Issues 18–27 above. In short:

- two-step verification for consultants;
- signing out other devices on a password change;
- restricting bucket types;
- dropping `phone_number`;
- the backup plan;
- the audit-log hardening;
- a stronger focus ring;
- major package updates.

## 7. Could not verify from here

- **Supabase Auth dashboard settings:**
  - rate limits (sign-in, sign-up, password reset, one-time codes: check Authentication → Rate limits);
  - leaked-password protection (paid plan);
  - redirect URL list (DO_NOT_BREAK.md section 3).
- **Google Cloud Console:** the redirect URIs and authorised domains (unchanged; Google's review is in progress).
- **Live headers and CORS:** until the hosting and functions deploy, results come from a local copy of the same rules.
- **Signed-in flows on the live site with the new security headers:** please click through once as each role (checklist E2).
- **Whether the Supabase dashboard accounts use two-step verification.**

## 8. Honest and fair design (checked 3 November 2026)

Checked the app code (`lib/`), the public web pages (`web/*.html`) and the legal texts (`legal/`).

- **Dark patterns:** no pre-ticked boxes. Every consent box on the consent screen starts unticked. "Don't agree and sign out" sits beside "Agree", and declining is as easy as accepting. Deletion is reachable in Settings and privacy.
- **Hidden fees:** none. The portal takes no payments, and the About page and Refund Policy say so.
- **Fake reviews and testimonials:** none in the app, the web pages or the seed data. No ratings, client logos or invented success stories. Success stories are entered by Administrators about real enterprises.
- **Unsupported claims:** none found. No "guaranteed", "100% secure" or "trusted by thousands" wording. The loan-readiness scores say they are "guidance, not a credit decision", and the Terms do not promise uninterrupted access. The "100%" figures in task descriptions are the programme's own targets from the Terms of Reference (ToR), not claims.

## 9. AJW decisions (3 November 2026)

- **Two-step verification switched off for every role** (items 21 and 22 closed). `mfaRequiredRoles` is empty, so everyone signs in with a password only. The Privacy Policy and Terms no longer mention it. Add a role back in `mfa_gate.dart` to turn it on again. Accepted risk: a stolen password alone now opens an account.
- **Business details supplied:** Apprentice Job Work Africa, Block D, Merchant Square, Riverside Drive, +254 716 523 556. There is no registration number, so it was removed from the pages. The data protection contact is the portal email, because a data protection officer is optional under section 24 of the Act.
- **Effective date** of the legal pages set to 3 November 2026, the day they went live.
- The deploy on 3 November used the web build from 16 October, because Flutter was not on the terminal's PATH. Rebuild with `C:\Users\user\flutter\bin\flutter build web --release` before the next hosting deploy.

## 10. Fixes and decisions (3 November 2026, second pass)

- **Consent checkboxes didn't respond (bug, fixed).** `standaloneScreen()` built its page once (`onGenerateRoute`), so ticks never showed and "Agree and continue" stayed disabled. It now uses the Navigator `pages` list, which redraws on every change. This also fixes the same latent bug in the two-step verification screens.
- **Sign out other devices on a password change (item 23): done.** `setPassword()` calls `signOut(scope: others)`.
- **PDFs on the web (item 25): fixed.** The web now opens PDFs in the browser's own viewer through the 5-minute link. Android keeps the in-app viewer.
- **Major package updates (item 27): declined by AJW.** Stay on the current versions while the app works.
- **Legal review.**
  - New required consent to store sensitive personal data outside Kenya: section 49(1) of the Act, plus the ODPC Guidance Notes for Cross-border Data Transfers (September 2026). Recorded as `sensitive_data_transfer` (migration `20261103100000`).
  - "Agree to the Privacy Policy" became "have read" it.
  - Lawful bases corrected: contract for enterprises; contract or legitimate interests for consultants and staff; consent only where it is genuinely needed.
  - New sections: sensitive data, and what must be provided.
  - Retention schedule filled in.
  - Disputes clause and third-party-data clause added to the Terms.
  - Draft banners removed.
  - Privacy Policy, Data Protection Notice and Terms are now version 2.1, so everyone is asked once more.
- **Still for AJW:**
  - Write the transfer assessment the Privacy Policy promises (section 6).
  - Tell workshop attendees how their details are used.
  - Delete records when their retention period ends. Only chat and closed requests have an in-app clean-up; the rest is manual until a scheduled job is built. Nothing is due before late 2027.
