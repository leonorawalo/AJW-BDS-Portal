# Supabase email templates

Paste these into Supabase → Authentication → Emails → Templates (custom SMTP
must be on to edit them). Keep this file and the dashboard in step.

Why they look like this (spam):
- No link to the `.apk` itself. A direct app-file link in an email is a
  strong spam signal, so the email links to `/download.html` on our own
  site, which has the download button and install steps.
- Short and plain: a greeting with the person's name, one main link,
  no all-caps, no images, sentence case.
- Every link is on our own domain (the portal's Site URL).
- Supabase sends the HTML template only; there's no separate plain-text
  field in the dashboard. Keeping the HTML this simple means mail apps
  that show plain text still get a clean, readable message.

The set-password link format is fixed by the app (DO_NOT_BREAK.md
section 3). Don't change anything inside `href="…"` except as noted.

## Invite user

**Subject**

```
Your invitation to the AJW BAGS Portal
```

**Body (HTML)**

```html
<p>Hello {{ .Data.first_name }},</p>

<p>{{ if .Data.invited_by }}{{ .Data.invited_by }} has invited you{{ else }}You have been invited{{ end }} to the AJW BAGS Portal{{ if .Data.invited_as }} as {{ .Data.invited_as }}{{ end }}.</p>

<p>To get started, choose your password:</p>

<p><a href="{{ .SiteURL }}/#/set-password?token_hash={{ .TokenHash }}&amp;type=invite">Set my password</a></p>

<p>The link works once and expires after 24 hours. If it has expired, ask your AJW administrator to send a new one.</p>

<p>After that you can use the portal in your browser, or get the Android app here: <a href="{{ .SiteURL }}/download.html">{{ .SiteURL }}/download.html</a></p>

<p>If you weren't expecting this invitation, you can ignore this email.</p>

<p>AJW Africa<br>Business Advancement and Growth Services</p>
```

## Reset password

**Subject**

```
Reset your AJW BAGS Portal password
```

**Body (HTML)**

```html
<p>Hello,</p>

<p>We received a request to reset the password for your AJW BAGS Portal account.</p>

<p><a href="{{ .SiteURL }}/#/set-password?token_hash={{ .TokenHash }}&amp;type=recovery">Choose a new password</a></p>

<p>The link works once and expires after 24 hours. If you didn't ask for this, you can ignore this email and your password stays the same.</p>

<p>AJW Africa<br>Business Advancement and Growth Services</p>
```

## Sender settings (Authentication → Emails → SMTP settings)

- Sender name: `AJW BAGS Portal`
- Sender email: `ajw.bags.portal@gmail.com` (must be the Gmail account
  whose app password is configured; sending "as" another address fails
  Gmail's checks and lands in spam).
