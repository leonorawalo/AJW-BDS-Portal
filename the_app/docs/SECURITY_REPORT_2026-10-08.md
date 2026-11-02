# Security and data protection report: 8 October 2026

Scope: the AJW Business Advancement and Growth Services (BAGS) Portal (Flutter web + Android, Supabase), checked against the Kenya Data Protection Act, 2019 (the Act). Checks ran against the live database (project `cgnmnqjyvlgyndhmicjl`).

## What was checked

| Area | How |
|---|---|
| Row level security (RLS) | Every `public` table on the live database: RLS on or off, number of policies, and what the `anon` and `authenticated` roles are granted. |
| Storage buckets | Public or private, file-size and file-type limits, storage policies. |
| Functions | Which `SECURITY DEFINER` functions signed-out (anonymous) visitors can call. |
| Secrets | The app code, web files and the whole git history, searched for Google client secrets, private keys and Supabase secret keys. |
| Document access | How documents are opened (link lifetime) and whether views and downloads are logged. |
| Uploads | File type and size checks. |
| Sign-in | Password rules, two-step verification, idle sessions. |
| People's rights | Consent, access, correction, deletion, deadlines. |

## Found and fixed

1. **Exposed table: `assessments`.** RLS was **off** on the live database, even though its policies existed. Any signed-in user could read and change every enterprise's assessment rows. RLS is now on (migration `20261008150000`). Re-checked: an Owner now sees only what the policies allow.
2. **Helper functions callable when signed out:** `is_admin`, `is_assigned_consultant`, `is_enterprise_owner`, `is_collaborator`. They returned "false" for signed-out callers, so nothing leaked, but they're now closed to signed-out visitors.
3. **Documents bucket had no size limit.** Now 20 MB per file. The app also refuses file types outside PDF, images, Office files, CSV and text, and stores each with an explicit content type.
4. **Document links lasted 1 hour.** Now 5 minutes.
5. **Document views and downloads weren't logged** (uploads already were). Now recorded in the audit log by `log_document_access()`, which checks the caller may see the document.
6. **No consent record, no way to exercise rights.**
   - A consent screen at first sign-in is now recorded per notice version.
   - "My data and privacy" lets people download their data as JSON, a machine-readable format.
   - People can now ask for access, correction or deletion. Deadlines are set by the database: 7 days for access, 14 days for correction and deletion.
   - Admins have a "Data requests" page showing overdue requests, and every request is audited.
7. **No two-step verification.** It's now required for Admins and Owners (authenticator app). Admins can reset it for someone who loses their phone.
8. **Sessions stayed open indefinitely on shared devices.** There's now an automatic sign-out after 30 idle minutes, with a one-minute warning.
9. **Retention.** Retention periods can now be set for chat messages and closed data requests, with an Admin-run clean-up. The default is to keep everything, and the audit log is never deleted.

## Checked and fine

- Every other table has RLS on with policies. Tables holding Google tokens (`google_connections`, `google_oauth_states`) and `attention_seen` have no app access at all, by design.
- Buckets: `documents` and `chat-attachments` are private. `downloads` is public on purpose: it holds the Android app file only.
- New tables added today (chat, success stories, consents, data requests, retention) have RLS and least-privilege grants. Chat isolation between two enterprises was tested as real users.
- Secrets: none in the app, the web files or the git history.
  - The `AIza…` values in `firebase_options.dart` and `google-services.json` are Firebase's public client identifiers, not secrets.
  - `.env` holds only the Supabase address and the public anonymous key.
  - The service-role key, Google client secret and Firebase private key exist only as Edge Function secrets.
- The password policy (8+ characters with lower case, upper case, digits and symbols) already matches Supabase.

## Data we may not need (for AJW to decide)

| Field | Why flag it |
|---|---|
| `users.phone_number` | Collected but not used by any feature (no SMS, no calls from the app). Drop it, or say in the notice what it's for. |
| `assessments` table (all columns, including `kcb_requirements_met`) | Replaced by scores computed from tasks; nothing in the app reads it any more. Can be exported and dropped. |
| `enterprises.annual_turnover` | Needed for the loan-readiness score; keep, but it's sensitive financial data: covered by RLS. |
| Chat messages and attachments | Kept forever unless a retention period is set (Admin, "Data requests" page). |

## Still to do (needs AJW or a decision)

1. **Privacy notice text.** `web/data-protection.html` and the consent screen use placeholder wording. AJW should supply:
   - its Office of the Data Protection Commissioner (ODPC) registration;
   - its data protection officer's contact;
   - its retention schedule.
2. **Audit log hardening and weekly backup** are written but **not applied** (`supabase/pending_approval/`). The weekly export needs a scheduled database job and a new secret, so it needs the project owner's go-ahead.
3. **The documents bucket doesn't restrict file types yet.** Phones on app 1.2.1 upload without a content type, so turn this on once every phone has a newer app.
4. **Two-step verification is enforced in the app, not yet by the database.** A further step would make the most sensitive policies require a two-step session (`aal2`) as well. Do it after everyone has enrolled.
5. **Supabase free plan has no backups.** This still needs a decision; see the handover document.
