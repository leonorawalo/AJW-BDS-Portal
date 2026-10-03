# DO NOT BREAK — AJW BAGS Portal invariants

Things that must stay in place, or must match each other across systems,
for as long as the portal runs on this architecture
(Flutter web + Android · Supabase · Firebase · Google Cloud).
No secret values are stored here, only names and locations.

If you change one side of a pair below, change the other side the same day.

---------------------------------------------------------------------
## 0. Which project is which (they look alike!)

| System | ID (check the address bar, e.g. `?project=`) | Used for |
|---|---|---|
| Supabase | `ajw-bds-portal`, ref `cgnmnqjyvlgyndhmicjl` | Database, logins, files, Edge Functions, invite emails |
| Google Cloud | `ajw-bags-portal` | Google suite: Calendar, Meet, Drive, Docs, Sheets, Slides, Gmail (the Connect button). This is the project Google verifies. |
| Google Cloud | `ajw-bags-sign-in` | ONLY the "Continue with Google" login button |
| Google Cloud / Firebase | `ajwafrica-bags-portal` | Push notifications (FCM) and web hosting |

`ajw-bags-portal` and `ajwafrica-bags-portal` both show the name
"AJW BAGS Portal". Always check the ID, not the name.

Live site: https://ajwafrica-bags-portal.web.app

---------------------------------------------------------------------
## 1. Files that must NEVER be deleted from the repo

| File | Why |
|---|---|
| `web/googlec7b934ad5a1b7fa7.html` | Proves to Google that we own the site (Search Console). Deleted + redeployed = site un-verified = Google verification breaks. |
| `web/about.html`, `web/privacy.html`, `web/terms.html`, `web/legal.css` | Linked from Google's consent screen (Branding) in BOTH Google projects. Google checks they stay live. |
| `web/oauth/google-callback.html` | The redirect relay Google sends users back to after Connect. |
| `web/download.html` | "Get the app" page linked from the invite email (the email must not link the .apk directly: spam signal). Its button points at the APK in Storage `downloads`. |
| `.env` (listed under `flutter: assets:` in `pubspec.yaml`) | App config (Supabase URL + anon key). Removing it from assets = white screen. |
| `supabase/config.toml` | Holds each Edge Function's "Verify JWT" setting. |

`firebase.json` must NOT ignore dotfiles (the app needs `assets/.env` served).

This list is enforced in two places. Change all three together:
- `.gitignore` ends with `!` lines so these files can never be ignored
  (except `.env`, which stays out of git on purpose).
- `scripts/check_do_not_break.js` runs before every hosting deploy
  (`predeploy` in `firebase.json`). It fails the deploy if a file here is
  missing, if `.env` is gone from pubspec assets, if `firebase.json`
  ignores dotfiles, or if the web build is missing any of them.

---------------------------------------------------------------------
## 2. Google: things that must match

### 2a. Suite / Connect (project `ajw-bags-portal`, client "Supabase Auth")
- Client ID + secret == Supabase Edge Function secrets
  `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET`.
- The redirect URI the code uses (Edge secret `GOOGLE_OAUTH_REDIRECT_URI`,
  e.g. `https://ajwafrica-bags-portal.web.app/oauth/google-callback.html`)
  MUST be listed under that client's Authorised redirect URIs.
- Every scope the `google-oauth` function requests MUST be listed under
  Google Auth Platform → Data access:
  openid, userinfo.email, userinfo.profile, calendar.freebusy, drive.file
  (non-sensitive); calendar.events, gmail.send (sensitive).
  Adding a scope later = add it in the console + users reconnect +
  Google re-review.
- Enabled APIs: Calendar, Drive, Docs, Sheets, Slides, Gmail.
- Authorised domain: `ajwafrica-bags-portal.web.app` only (no supabase.co here).
- Privacy Policy must describe every Google permission and keep Google's
  "Limited Use" statement.

### 2b. Login button (project `ajw-bags-sign-in`, client "Supabase sign-in")
- Client ID + secret == Supabase → Authentication → Sign In / Providers → Google.
- Redirect URI: `https://cgnmnqjyvlgyndhmicjl.supabase.co/auth/v1/callback`
- Scopes: openid, email, profile ONLY. Don't add a logo or sensitive
  scopes, or this project will need verification too.
- It only signs in to EXISTING accounts (a database rule blocks new
  accounts from Google).

### 2c. Search Console
- Property `https://ajwafrica-bags-portal.web.app/` verified by the HTML
  file in section 1, under the Google account that owns the Cloud projects.

---------------------------------------------------------------------
## 3. Supabase settings that must match the app

- Authentication → URL Configuration:
  - Site URL = `https://ajwafrica-bags-portal.web.app`
  - Redirect URLs include `https://ajwafrica-bags-portal.web.app/**`,
    `http://localhost:3000/**`, `ajwbags://login-callback`
- `ajwbags://login-callback` == the intent filter in
  `android/app/src/main/AndroidManifest.xml` (scheme `ajwbags`, host `login-callback`).
- "Allow new users to sign up" = OFF (people only join by Admin invite).
- Email OTP expiration = 86400 (24 h), so invite links last a day.
- Invite email template link MUST be exactly:
  `{{ .SiteURL }}/#/set-password?token_hash={{ .TokenHash }}&amp;type=invite`
- The template's "who invited you" line uses metadata set by the
  `invite-user` function (`invited_by`, `invited_as`). Renaming either key
  in the function breaks that line:
  `{{ if .Data.invited_by }}{{ .Data.invited_by }} invited you as {{ .Data.invited_as }}.{{ end }}`
- Reset Password ("Forgot password") template link MUST be exactly:
  `{{ .SiteURL }}/#/set-password?token_hash={{ .TokenHash }}&amp;type=recovery`
  (the app exchanges the token, then makes the person choose a new
  password before anything else).
- Password policy (Authentication → Sign In / Providers → Email, or
  Policies): minimum length 8; requirements "Lowercase, uppercase
  letters, digits and symbols". Must match `PasswordRules` in
  `lib/features/auth/presentation/password_field.dart`.
- Templates are only editable while custom SMTP is on.
- SMTP = Gmail `ajw.bags.portal@gmail.com` with an APP PASSWORD.
  Changing that Gmail's password or turning off 2-Step Verification
  kills the app password, and then invite emails stop.
- Storage bucket `downloads` (public) holds `ajw-bags-portal.apk`;
  `web/download.html` links to that exact file name. The invite email
  links to `/download.html`, never to the .apk itself.

### Edge Function secrets (names must match the code)
GOOGLE_CLIENT_ID · GOOGLE_CLIENT_SECRET · GOOGLE_OAUTH_REDIRECT_URI ·
APP_URL · FIREBASE_PROJECT_ID · FIREBASE_CLIENT_EMAIL ·
FIREBASE_PRIVATE_KEY · WEBHOOK_SECRET
(SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY are automatic.)

### Edge Functions
- Names must be exact, and deploy via the CLI only (the dashboard invents
  random names like "swift-processor"): send-push, google-oauth,
  calendar-sessions, google-export, invite-user, manage-users,
  gmail-send, drive-files.
- Verify JWT: OFF for `send-push` and `google-oauth`, ON for the rest
  (kept in `supabase/config.toml`).

### Push notifications
- 4 Database Webhooks (users, consultant_assignments, tasks insert,
  tasks update) → `.../functions/v1/send-push`, header
  `x-webhook-secret` == Edge secret `WEBHOOK_SECRET`.
- Firebase service-account key in use: `2c6526fc66…` (stored only in the
  FIREBASE_* secrets). To rotate: generate new key → update secrets →
  delete the old key.
- One phone = one user at a time (`device_tokens` is unique per token).

---------------------------------------------------------------------
## 4. Database rules

- Never edit a migration that has already been applied; fix things in a
  NEW migration.
- "Recorded as applied" ≠ "live". Check the live DB when behaviour and
  migrations disagree.
- "Automatically expose new tables" is OFF. Every new table needs
  explicit GRANTs: to `authenticated` (plus RLS policies) if the app
  uses it, and to `service_role` if an Edge Function uses it.
- Terms of Reference tasks: each checklist item's `key` in
  `lib/features/legal_workstream/models/task_template.dart` is stored in
  `tasks.tor_key`, unique per enterprise + discipline. Never change or
  reuse a key (a changed key adds a second copy of that task everywhere).
  Titles marked "score" are read by the loan-readiness dashboard by exact
  text (a unit test checks this). Tasks are added only through
  `ensure_tor_tasks()` (migration 20261003100000), never by a hand-made
  checklist button.
- The audit log is written only by database triggers, never by the app.
- Non-admins can't change role/status/specialization/email (a trigger
  guards it). Don't remove it.

---------------------------------------------------------------------
## 5. Deploying and building

- Web: after any app change → `flutter build web --release` →
  `npx firebase-tools deploy --only hosting`. The live site does not
  update by itself. The deploy runs `scripts/check_do_not_break.js`
  first and stops if it fails. Fix the cause, don't remove the check.
- `web/index.html` holds the instant loading screen (`#ajw-splash`), removed
  on Flutter's `flutter-first-frame` event. Keep both if you edit the page.
- Cache headers (`firebase.json`): every `.js/.json/.html` file, `/` and
  `.env` are `no-cache`. They have no content hash in their names, and that
  includes the deferred chunks `main.dart.js_N.part.js`. Only images, fonts
  and the local `/canvaskit/` copy are cached for a day. Never give
  `main.dart.js` or its `.part.js` files a long max-age, or users get a mix
  of old and new code after a deploy.
- The PDF export (`pdf`, `printing`) and the document viewer (`pdfx`) are
  deferred imports (`pdf_export.dart`, `open_document_viewer.dart`).
  Importing those packages or those screens directly anywhere else pulls
  them back into the first download.
- Android: the APK only changes when rebuilt AND re-uploaded to
  Storage → downloads as `ajw-bags-portal.apk`.
- Android release signing key: `C:\Users\user\AJW-BDS-Keys\ajw-bags-upload.jks`
  (alias `upload`; password in `README-KEEP-THIS-SAFE.txt` next to it).
  `android/key.properties` (gitignored) points at it, and release builds
  refuse to run without it (never debug-signed). NEVER lose it: back the
  folder up outside the repo and outside OneDrive. Losing it = installed
  apps can't take updates (users must uninstall and reinstall).
- Release APKs: bump `version:` in pubspec first, then
  `flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm`.
  Upload to Storage `downloads` as `ajw-bags-portal.apk` (arm64, most
  phones) and `ajw-bags-portal-32bit.apk` (armeabi-v7a);
  `web/download.html` links both. The Supabase free plan caps a file at
  50 MB, which is why the APK is split.
- Package name stays `com.ajwafrica.the_app` (Firebase push is registered
  to it).

---------------------------------------------------------------------
## 6. Never commit

- `client_secret*.json` (Google), Firebase service-account JSON,
  keystores / `key.properties`, SMTP/app passwords.
- `.env` holds ONLY the Supabase URL + anon key (public by design).
  Never put the service_role key or any other secret in it; it ships
  inside the app.

---------------------------------------------------------------------
## 7. While Google's app is in Testing / unverified

- Testing: only emails under Audience → Test users can Connect.
- Published but unverified: anyone can connect, sees an "unverified app"
  warning, max 100 users ever.
- Verified: no warning, no cap. Keep scopes, branding pages and domain
  exactly as submitted, or Google may ask for re-review.

---------------------------------------------------------------------
## 8. Brand (AJW Brand Guideline, in `AJW Brand Elements/`)

- Colours come from the guideline, p.9: AJW Red `#D13B3B`, Charcoal
  `#494949`, Light Grey `#B2B2B2`. They live only in
  `lib/core/theme/app_colors.dart`, and every other file reads them from there.
  Error red is a deliberately different crimson (`#B42318`), always with
  an icon and a message.
- Fonts. The guideline's typefaces (pp.12-15), Henderson Sans (headers),
  Jeko (sub-headers) and Ambit (body), are commercial MyFonts fonts with
  NO confirmed web/app licence. They must NOT ship in the app or website
  and must NOT be committed or pushed. `.gitignore` blocks their file
  names, and `scripts/check_do_not_break.js` fails the deploy if one is
  in `assets/fonts`, in the web build, or listed in pubspec.
  The app uses the designer's approved free substitutes from the brand
  folder ("Fonts available on Google", SIL OFL; licence texts in
  `assets/fonts/OFL-*.txt`): Poppins Bold for headers, Livvic Medium for
  sub-headers, Work Sans Regular and Medium for body. They're subset to
  Latin to keep the web download small. The guideline doesn't state
  this mapping; it was chosen by matching each role's look.
  To switch back if AJW confirms web/app licences for the originals:
  (1) put the licensed files in `assets/fonts` and remove their patterns
  from `.gitignore` and the check script, (2) change the `fonts:` block
  in `pubspec.yaml`, (3) change the families, weights and tracking in
  `AppFonts` (`lib/core/theme/app_theme.dart`). Nothing else names a font.
- The logo is vector, taken from the guideline PDF's cover page:
  `lib/core/branding/ajw_logo_paths.dart` (generated) and
  `web/brand/ajw-mark.svg`. The web loading screen uses the SVG. Favicon,
  web icons and `assets/images/ajw_logo.webp` were rendered from it.
  Don't swap in a low-res raster again.
- Personal avatar colours (`AppColors.personalPalette`) belong to users,
  not to AJW. Keep them muted, and keep white text on each at >= 4.5:1.
