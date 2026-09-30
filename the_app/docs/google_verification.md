# Google OAuth verification — AJW BAGS Portal

Why: while the OAuth consent screen is in Testing (or published but
unverified), only listed test users can connect (or everyone sees an
"unverified app" warning, capped at 100 users). Verification removes both.

Google Cloud project: **ajw-bags-portal** · OAuth client: **Supabase Auth** (Web application)

## What changed in the app for verification

Google requires every redirect URI to be on a domain the developer owns and
has verified in Search Console. `*.supabase.co` can't be verified by AJW, so:

- **Calendar / Meet / exports connection** (`google-oauth` Edge Function):
  Google now redirects to
  `https://ajwafrica-bags-portal.web.app/oauth/google-callback.html`, a relay
  page on AJW's own hosting that forwards Google's result unchanged to the
  Edge Function. Controlled by the Edge Function secret
  `GOOGLE_OAUTH_REDIRECT_URI` (unset = old direct URL).
- **"Continue with Google" sign-in** (Supabase Auth) must redirect to
  Supabase's own callback on supabase.co, so it can't live in the verified
  project (see "Sign-in button" below).

## Scopes

| Scope | Classification | Used for |
|---|---|---|
| `openid`, `userinfo.email`, `userinfo.profile` | Non-sensitive | Identify which Google account the user connected |
| `https://www.googleapis.com/auth/calendar.events` | **Sensitive** — needs justification | Create / cancel consultation meetings (with Google Meet links) on the organizer's own calendar |
| `https://www.googleapis.com/auth/calendar.freebusy` | Non-sensitive | Check participants' availability before booking (busy/free only) |
| `https://www.googleapis.com/auth/drive.file` | Non-sensitive | Create exported Docs / Sheets / Slides in the user's own Drive; the app can only see files it created |
| `https://www.googleapis.com/auth/gmail.send` | **Sensitive** — needs justification | "Write email": send a message the user wrote in the portal from their own Gmail (send only; no reading) |

## Justification text for `calendar.events` (paste into the verification form)

> AJW BAGS Portal is used by AJW Africa's Business Advancement and Growth
> Services programme, where administrators, business consultants and
> enterprise owners hold consultation meetings about the enterprise's
> progress toward loan readiness.
>
> When a signed-in user schedules a meeting in the portal, the app creates
> one event on that user's own primary Google Calendar with a Google Meet
> conference, and invites the chosen participants by email. When the
> organizer cancels the meeting in the portal, the app deletes that same
> event so participants receive a cancellation. The app only creates and
> deletes the events it made for portal meetings; it does not read, list or
> modify any other events on the user's calendar.
>
> A narrower scope is not sufficient: `calendar.freebusy` is read-only
> availability, `calendar.readonly` cannot create events, and creating a
> Meet conference requires inserting an event (`calendar.events`). We do not
> request the full `calendar` scope.
>
> Google user data is used only to provide these user-facing features, is
> never sold, never used for advertising, and is not shared except as
> needed to send the meeting invitations the user asked for. Refresh tokens
> are stored server-side only, encrypted at rest, and deleted when the user
> disconnects.

## Justification text for `gmail.send` (paste into the verification form)

> Users of AJW BAGS Portal (programme administrators, business
> consultants and enterprise owners) need to email the people working on
> an enterprise, such as its owner or assigned consultants, about programme
> work, from their own identity so that replies come back to them.
>
> In the portal the user writes the message, chooses recipients from the
> people linked to that enterprise, and clicks "Send via Gmail". The app
> then sends exactly that one message from the user's own Gmail account
> using gmail.send. It appears in their Sent folder, and replies go to
> their normal inbox. Nothing is sent without that explicit action.
>
> The app never reads, lists, searches, modifies or deletes the user's
> email, which is why we request only gmail.send and not gmail.readonly,
> gmail.modify or gmail.compose. Recipients are restricted server-side to
> the portal's own contacts for that enterprise. No message content is
> stored by the app.

## Demo video (YouTube, "Unlisted") — shot list

Record the screen of the live site (https://ajwafrica-bags-portal.web.app)
in English, 2–4 minutes, no editing needed. Google checks that the consent
screen shown matches the app and that each sensitive scope is actually used.

1. Show the browser address bar on the portal login page, then sign in as a
   Consultant.
2. Open an enterprise → **Sessions** tab → **Connect** (Google account).
3. On Google's consent screen: pause so the **app name "AJW BAGS Portal"**
   and the **list of permissions** are readable. Click the address bar once
   so the URL (containing `client_id=...`) is visible. Then **Continue**.
4. Back in the portal, show the card says **Google account connected**.
5. **Schedule** a meeting: pick a participant, show the availability check
   (free/busy), set a time, **Schedule**.
6. Open **Google Calendar** in another tab: show the new event with the
   **Google Meet** link and the invited participant (this is the
   `calendar.events` use).
7. Back in the portal, **Cancel session**; refresh Google Calendar to show
   the event is gone.
8. **Email** menu (envelope icon) → **Write email** → tick a recipient,
   type a subject and message → **Send via Gmail**. Then open **Gmail →
   Sent** to show the message (this is the `gmail.send` use).
9. (Optional, non-sensitive) Export menu → **Loan-readiness report — Google
   Docs** → Open, showing it in the "AJW BAGS Portal" Drive folder.

## Console checklist

- [ ] Search Console: verify `https://ajwafrica-bags-portal.web.app/` (URL
      prefix, HTML file method; the file goes in `the_app/web/`).
- [ ] OAuth client "Supabase Auth" → Authorised redirect URIs: **add**
      `https://ajwafrica-bags-portal.web.app/oauth/google-callback.html`.
- [ ] Then set the Edge Function secret
      `GOOGLE_OAUTH_REDIRECT_URI=https://ajwafrica-bags-portal.web.app/oauth/google-callback.html`
      and test Connect.
- [ ] Sign-in button: move to its own project (or remove), then **remove**
      both `*.supabase.co` redirect URIs from this project's client.
- [ ] Branding: app name, support email, logo, homepage
      (`/about.html`), privacy policy (`/privacy.html`), terms
      (`/terms.html`), authorized domain `ajwafrica-bags-portal.web.app`
      only, developer contact email.
- [ ] Audience → **Publish app** (everyone can connect, with a warning,
      while verification is pending).
- [ ] Verification centre → submit with the justification and video link.

## Sign-in button

"Continue with Google" (Supabase Auth → Providers → Google) only uses the
non-sensitive `openid`, `email`, `profile` scopes, but its redirect URI must
be `https://cgnmnqjyvlgyndhmicjl.supabase.co/auth/v1/callback`. Options:

- **Separate Google Cloud project** (e.g. "AJW BAGS Portal Sign-in") with
  its own consent screen and OAuth client using only basic scopes. Basic
  scopes don't require verification, so it can be published straight to
  production. Put that client's ID/secret into Supabase Auth → Google.
- **Remove the button** — email/password (invite) sign-in is unaffected.
- (Later) Supabase custom domain add-on, which puts Supabase on an AJW
  domain and removes the problem entirely.
