# Supabase email templates

Each `.html` file here is copy-ready: open it, select all, copy, paste
into the **Body** box of the matching Supabase template. Nothing else in
the file needs removing.

Supabase → Authentication → Emails → Templates (custom SMTP must be on
to edit them).

| Supabase template | Subject (paste into "Subject") | Body file |
|---|---|---|
| **Invite user** | `Your invitation to the AJW BAGS Portal` | `invite.html` |
| **Reset password** | `Reset your AJW BAGS Portal password` | `reset.html` |

Leave the other templates (Confirm signup, Magic link, Change email,
Reauthentication) as Supabase's defaults: the portal doesn't use them.

## Links and the domain

Both bodies build every link from `{{ .SiteURL }}`, which Supabase fills
from Authentication → URL Configuration → Site URL
(`https://portal.ajwafrica.org`). So the emails follow the domain
automatically; never type the domain into a template.

The set-password links are fixed by the app (DO_NOT_BREAK.md section 3).
Don't change anything inside `href="…"`. The "who invited you" line uses
`invited_by` / `invited_as`, set by the `invite-user` Edge Function.

## Why they look like this (spam)

- No link to the `.apk` itself: the invite links to `/download.html` on
  our own site, which has the download button and install steps.
- Short and plain: a greeting with the person's name, one main link, no
  all-caps, no images, sentence case.
- Every link is on our own domain.
- Supabase sends the HTML body only (there's no separate plain-text
  field), so the HTML is kept simple enough to read as plain text.

## Sender settings (Authentication → Emails → SMTP settings)

- Sender name: `AJW BAGS Portal`
- Sender email: `ajw.bags.portal@gmail.com` (must be the Gmail account
  whose app password is configured; sending "as" another address fails
  Gmail's checks and lands in spam).
