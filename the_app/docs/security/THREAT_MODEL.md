# Threat model

Where the AJW BAGS Portal could be attacked, what could go wrong, and what protects it. It uses STRIDE: Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege. Ratings: Likelihood (L) and Impact (I) are Low, Medium or High.

## Assets

1. Enterprises' legal and financial documents (licences, certificates, bank statements).
2. Personal data of owners, consultants, staff and workshop attendees.
3. Chat messages and Google-held content (Drive files, Gmail, Calendar).
4. Google refresh tokens; the Supabase service role key; the Firebase private key; the Android signing key.
5. Integrity of programme records (tasks, scores, audit log) that AJW reports to partners.
6. Availability of the portal for field work.

## Entry points and trust boundaries

```
 Browser / Android app  (untrusted)
        │ HTTPS: anon key + user JWT
        ▼
 Supabase API (PostgREST, Auth, Storage, Realtime)  ── RLS + storage policies ── boundary 1
        │
 Edge Functions  (service role; Google + Firebase secrets) ── function checks ── boundary 2
        │
 Google APIs (user's own account) · Firebase Cloud Messaging · Gmail SMTP
```

Entry points:

- login, password reset and invite links;
- Google consent (`google-oauth`);
- every table through PostgREST;
- Storage uploads and downloads;
- the Edge Functions;
- Database Webhooks into `send-push`;
- the website's static pages and the Flutter web build;
- the unsubscribe link.

## Threats

| # | Threat | STRIDE | L | I | Current protection | Gap and plan |
|---|---|---|---|---|---|---|
| 1 | One enterprise's owner or consultant sees another enterprise's documents or chat | I | M | H | RLS on `documents`, `chat_*`; storage paths keyed by enterprise or conversation id; tested as real users (chat isolation, 8 Oct) | Re-run the checklist after every new table or bucket |
| 2 | Consultant uses a document's direct link after being unassigned | I | M | M | links last 5 minutes; storage policies re-check `is_assigned_consultant` on each new link | None |
| 3 | Consultant calls Administrator functions or tables directly with their own JWT | E | M | H | Edge Functions check `is_admin()`; RLS admin-only policies; trigger blocks role/status/email changes | None found |
| 4 | Owner edits enterprise fields beyond the financial facts | T | M | M | trigger `restrict_non_admin_enterprise_updates` | None |
| 5 | Stolen Google refresh tokens | I | L | H | tokens only in `google_connections` (no app access); service role only on the server; revocable from the Google account | Supabase dashboard access must be protected with two-step verification. [AJW to confirm for every dashboard user] |
| 6 | Leaked service role key or other secret | E | L | H | not in the app or git (history scanned 16 Oct); secrets in Supabase only | Rotation steps in SECURITY.md section 3 |
| 7 | Account takeover by password guessing | S | M | H | Supabase Auth rate limits; strong password policy; idle sign-out | Two-step verification switched off for all roles by AJW (3 Nov 2026), accepted risk; "leaked password protection" needs a paid Supabase plan |
| 8 | Phishing a reset or invite link | S | M | M | single-use links; a new request cancels old ones; the token sits after `#` (never sent to servers); the link only works for its own account | None |
| 9 | Malicious upload (a program renamed .pdf, oversized file) | T/E | M | M | type list, size limits, content check; files only ever served as downloads with their stored content type; no server-side processing | The bucket doesn't restrict types until every phone has a newer app (DO_NOT_BREAK.md section 4) |
| 10 | Cross-site scripting (XSS) on the web build | T/I | L | H | Flutter renders text, never user HTML; Content-Security-Policy forbids inline and third-party scripts; static pages contain no user input | None |
| 11 | Clickjacking (the portal framed by another site) | T | L | M | `X-Frame-Options: DENY`, `frame-ancestors 'none'` | None |
| 12 | Another website calling Edge Functions with a signed-in user's browser | S | L | M | functions need the JWT in a header (not a cookie); CORS limited to the portal's own addresses | None |
| 13 | Spamming email, invites or Google calls through the functions | D | M | M | per-user hourly rate limits; recipients limited to the portal's own contacts | None |
| 14 | Forged push webhook | S/T | L | L | `x-webhook-secret`; refuses if unset | None |
| 15 | Someone denies doing something ("I never deleted that") | R | M | M | trigger-written audit log, Administrator-read only, no app update or delete | The extra protection (actor role column, database-level append-only guard, weekly backup) is written but parked in `supabase/pending_approval/`, awaiting approval |
| 16 | Losing all data (no backups on the free plan) | D | M | H | none beyond Supabase's own infrastructure | **Open:** AJW must decide on the Pro plan (daily backups) or the parked weekly export |
| 17 | Lost or shared phone left signed in | I | M | M | 30-minute idle sign-out; suspension kills refresh | None |
| 18 | Forged consent records | T | L | M | append-only `user_consents`; time set by the database; "unsubscribe" source only from the server | None |
| 19 | Unsubscribe link abused to unsubscribe someone else | T | L | L | random 128-bit token per person; only turns optional emails off | None |
| 20 | Malicious or compromised package | T/E | L | H | few, well-known packages; minor updates only; no tracking packages | Review majors before upgrading |
