# Google OAuth verification: AJW BAGS Portal

Why: while the OAuth consent screen is in Testing (or published but
unverified), only listed test users can connect (or everyone sees an
"unverified app" warning, capped at 100 users). Verification removes both.

Google Cloud project: **ajw-bags-portal** · OAuth client: **Supabase Auth** (Web application)

## What changed in the app for verification

Google requires every redirect URI to be on a domain the developer owns and
has verified in Search Console. `*.supabase.co` can't be verified by AJW, so:

- **Calendar / Meet / exports connection** (`google-oauth` Edge Function):
  Google now redirects to
  `https://portal.ajwafrica.org/oauth/google-callback.html`, a relay
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
| `https://www.googleapis.com/auth/calendar.events` | **Sensitive**: needs justification | Create / cancel consultation meetings (with Google Meet links) on the organizer's own calendar |
| `https://www.googleapis.com/auth/calendar.freebusy` | Non-sensitive | Check participants' availability before booking (busy/free only) |
| `https://www.googleapis.com/auth/drive.file` | Non-sensitive | Create exported Docs / Sheets / Slides in the user's own Drive; the app can only see files it created |
| `https://www.googleapis.com/auth/gmail.send` | **Sensitive**: needs justification | "Write email": send a message the user wrote in the portal from their own Gmail (send only; no reading) |

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

## Demo video: recording script (about 2½ minutes)

### Pre-recording checklist

**Record as the demo Consultant.** Consultants use both sensitive scopes
(they schedule sessions and email the enterprise's people), and the script
signs in as one.

**The enterprise** (set up as Admin the day before):
- [ ] One demo enterprise with a realistic name, county and industry. Its
      **Owner** is the demo owner account, so the Owner shows up as a
      meeting invitee and an email recipient.
- [ ] The demo Consultant is **assigned** to it (Assign consultants, with
      their specialization). Sign in as the Consultant once and open
      **Tasks**: the ToR tasks appear by themselves.
- [ ] Make it look lived-in: mark 3–4 ToR tasks **Completed** (the
      Dashboard scores move), add one recommendation, log one visit,
      upload one document.
- [ ] Fill the Business facts on the Dashboard (turnover, start date, loan
      purpose).
- [ ] No leftover test enterprises in the Consultant's portfolio (only the
      demo one, so the switcher and portfolio look clean).

**Reset the Google connection, so the consent screen appears:**
- [ ] As the Consultant: Sessions → Google card → **Disconnect**.
- [ ] In the Google account you'll connect, go to
      https://myaccount.google.com/permissions → **AJW Africa BAGS
      Portal** → **Remove all access**. Then the consent screen lists every
      permission fresh. (Connect always asks for consent, but after a
      revoke the list is complete and clean.)
- [ ] If the Consultant has never connected, the "Connect your Google
      suite" prompt appears after sign-in. Tap **Later** before recording,
      so step 2 starts from the Sessions card as scripted.
- [ ] Dry run once (Connect, schedule, cancel, send one email), then reset
      again with the two steps above.

**Browser and screen:**
- [ ] Use a **separate Chrome profile** signed in only to the demo Google
      account. Then Google's account picker shows no personal accounts,
      and no personal bookmarks or autofill appear.
- [ ] Hide the bookmarks bar (Ctrl+Shift+B), set zoom to 100%, and close
      other tabs. Have Google Calendar and Gmail → Sent open in two tabs
      for steps 6 and 9.
- [ ] Windows: turn on **Do not disturb** (no pop-up notifications), close
      WhatsApp, email and chat apps, and hide desktop icons if they'll show.
- [ ] Red dots in the portal menu are fine to show. Open any dotted
      sections beforehand if you'd rather start clean.
- [ ] Until verification passes, Google shows an "unverified app" warning
      before the consent screen. That's expected: click **Advanced →
      Go to AJW Africa BAGS Portal**, and keep it in the recording.
- [ ] Don't show the Supabase/Google consoles, test_logins.txt, or any
      password on screen.

**Upload:** YouTube, **Unlisted**, in English. Say the lines out loud or
put them on screen as captions; either works.

| # | Time | Do (click / show) | Say |
|---|---|---|---|
| 1 | 0:00–0:15 | Open `https://portal.ajwafrica.org`. Click the address bar so the domain is readable. Sign in as a **Consultant**. | "This is AJW Africa BAGS Portal, used by AJW's business advisers and the enterprises they support. I'm signing in as a consultant." |
| 2 | 0:15–0:25 | Open an enterprise → **Sessions** in the side menu → on the "Connect your Google account" card, **Connect**. | "To hold meetings and send email from their own Google account, a user connects it once." |
| 3 | 0:25–0:50 | On Google's consent screen **stop for 5 seconds**. Show the app name **"AJW Africa BAGS Portal"** and the permission list. Click the address bar once so `client_id=` is visible. Scroll slowly through the permissions, then **Continue**. | "Google shows the app name, AJW Africa BAGS Portal, and exactly what it asks for: create calendar events, check free/busy, files the app creates, and send email on my behalf." |
| 4 | 0:50–0:55 | Back in the portal, show **Google account connected**. | "The account is now connected." |
| 5 | 0:55–1:20 | **Schedule meeting**: pick the participant, set a time and title, **Schedule** (the free/busy check runs here; a clash shows "Calendar clash"). | "Scheduling a consultation. The app checks the participant's availability, then creates one event on my own calendar with a Google Meet link and invites them. This is the calendar.events permission." |
| 6 | 1:20–1:35 | New tab → **Google Calendar**: open the new event and show the **Meet link** and the **invited participant**. | "Here is the event it created, with the Meet link and the invitee." |
| 7 | 1:35–1:50 | Back in the portal, **Cancel session**. Refresh Google Calendar to show the event is gone. | "Cancelling in the portal deletes that same event. The app only touches events it created." |
| 8 | 1:50–2:20 | Top bar **Email** (envelope) → **Write email**. Tick one recipient, type a short subject and message, then **Send via Gmail**. | "To email people working on this enterprise, I write the message here and choose from the enterprise's contacts. Send uses the gmail.send permission, one message and only when I click Send." |
| 9 | 2:20–2:35 | New tab → **Gmail → Sent**: open the message just sent. | "It's sent from my own Gmail and appears in my Sent folder. The app never reads, searches or deletes my email." |
| 10 | 2:35–2:45 | Optionally show the **Privacy policy** link on `https://portal.ajwafrica.org/privacy.html`. | "Google user data is used only for these features, as described in our privacy policy." |

What Google checks: the consent screen matches this app and project (step
3), and each sensitive scope is visibly used: `calendar.events` in steps
5–7 and `gmail.send` in steps 8–9.

## Data access justification (as submitted, 5 Oct 2026)

Google Auth Platform → Data access has **one shared justification box**
(1000-character limit) for all sensitive scopes. This is the exact text
submitted on 5 Oct 2026. Don't edit it here unless it's also changed in
the console (and not while the review is open).

```
AJW BAGS Portal supports AJW Africa's Business Advancement and Growth Services programme (administrators, consultants and enterprise owners).
calendar.events: when a user schedules a meeting in the portal, the app creates one event with a Google Meet link on their own calendar and invites the chosen participants; cancelling deletes that same event. It never reads or edits other events. calendar.freebusy and calendar.readonly cannot create events or Meet links, and we don't request the full calendar scope.
gmail.send: the user writes a message in the portal, picks recipients from the enterprise's contacts and clicks "Send via Gmail"; the app sends exactly that message from their Gmail, so replies reach them. It never reads, searches or deletes email.
Data is used only for these features, never sold or used for ads; tokens are encrypted server-side and deleted on disconnect.
```

## Console checklist

Status as of 2026-10-05 (SUBMITTED). Portal address: **https://portal.ajwafrica.org**
(Firebase custom domain; Bluehost CNAME `portal` →
`ajwafrica-bags-portal.web.app`).

Done:
- [x] Search Console: **Domain property `ajwafrica.org`** verified (DNS).
      The older URL property for web.app stays verified by
      `web/googlec7b934ad5a1b7fa7.html` (never delete it).
- [x] OAuth client "Supabase Auth" → Authorised redirect URIs include
      `https://portal.ajwafrica.org/oauth/google-callback.html`.
- [x] Edge Function secrets
      `GOOGLE_OAUTH_REDIRECT_URI=https://portal.ajwafrica.org/oauth/google-callback.html`
      and `APP_URL=https://portal.ajwafrica.org`. Connect on the new
      domain tested and works.
- [x] Supabase Auth: Site URL `https://portal.ajwafrica.org`, redirect
      `https://portal.ajwafrica.org/**`.
- [x] Sign-in button moved to its own project; both `*.supabase.co`
      redirect URIs removed from this project's client.
- [x] Data access scopes: openid, email, profile, calendar.freebusy,
      drive.file (non-sensitive); calendar.events, gmail.send (sensitive).
- [x] Data access justification pasted (one shared box, see above).
- [x] Branding in **both** projects: app name "AJW Africa BAGS Portal",
      logo, homepage `https://portal.ajwafrica.org/about.html`, privacy
      policy `/privacy.html`, terms `/terms.html`, authorised domain
      `ajwafrica.org`. **Branding verified and published.**
- [x] Audience → published **"In production"** (unverified until the
      review passes: warning shown, 100-user cap).

- [x] Demo video recorded and uploaded to YouTube (Unlisted).
- [x] **Verification SUBMITTED 5 Oct 2026** (video link + justification).
      Google: first email in 3–5 days; full review up to 4–6 weeks.

**While the review is open (from 5 Oct 2026), change NOTHING in the
console:** publishing status, user type, scopes, branding or authorised
domains. So the old web.app redirect URI and the web.app authorised
domain stay **as they are** for now.

After Google approves (later, optional):
- [ ] Google OAuth client "Supabase Auth" (project ajw-bags-portal):
      remove the old redirect URI
      `https://ajwafrica-bags-portal.web.app/oauth/google-callback.html`.
- [ ] Branding → Authorised domains: remove `ajwafrica-bags-portal.web.app`.
- [ ] Then Connect once more on https://portal.ajwafrica.org to confirm
      nothing depended on them.
- [ ] Answer any follow-up email from Google's review team promptly
      (it goes to the project's support/developer contact).

Keep `https://ajwafrica-bags-portal.web.app/**` in **Supabase** →
Authentication → Redirect URLs: that's for the web.app fallback's
"Continue with Google", not part of Google's review.

## Sign-in button (DONE 2026-09-30)

"Continue with Google" (Supabase Auth → Providers → Google) uses only
`openid`, `email`, `profile`, and its redirect URI must be
`https://cgnmnqjyvlgyndhmicjl.supabase.co/auth/v1/callback`, so it can't
live in the verified project.

It now lives in Google Cloud project **ajw-bags-sign-in**, client
**"Supabase sign-in"**, with basic scopes only. It is published, and needs
no verification. Supabase's Google provider uses that client's ID and secret.
Tested: works.
