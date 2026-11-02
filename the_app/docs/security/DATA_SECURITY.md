# Data security

What personal and sensitive data the AJW BAGS Portal holds, where it is, who can see it, and how it is protected, kept and deleted. The Kenya Data Protection Act, 2019 (the Act) is the baseline. The public version for users is the Privacy Policy (`legal/privacy-policy.md`).

## 1. Data inventory

Sensitivity: **High** = identity, financial or legal documents and private messages; **Medium** = personal contact and programme records; **Low** = operational.

| Data | Where | Who can see it (see AUTH.md) | Sensitivity |
|---|---|---|---|
| Name, email, role, specialisation | `public.users`, Supabase Auth (`auth.users`) | the person, collaborators on shared enterprises, Administrators | Medium |
| Password (hashed, bcrypt) | Supabase Auth only | nobody (not even Administrators) | High |
| Two-step verification secret | Supabase Auth (`auth.mfa_factors`) | nobody; an Administrator can only delete it | High |
| Business details: name, owner name, phone, email, county, KRA PIN, registration number | `public.enterprises` | owner, assigned consultants, Administrators | Medium |
| Financial facts: annual turnover, start date, loan purpose | `public.enterprises` | same | High |
| Licences, certificates, registration papers, bank statements and other uploads | Storage `documents` (private) + `public.documents` | same; links last 5 minutes; views and downloads logged | High |
| Tasks, comments, recommendations, assessments, visit notes | `tasks`, `task_comments`, `recommendations`, `assessments`, `enterprise_visits` | same (consultants: their specialisation) | Medium |
| Success stories (may mention staff, families; under 18 only with a guardian's consent) | `public.success_stories` | assigned consultants, Administrators | Medium |
| Meetings: times, participants, Meet links | `consultation_sessions`, `session_participants`; the event itself is in the organiser's Google Calendar | organiser, participants, Administrators | Medium |
| Meeting notes and transcripts (dormant feature) | Google Docs in the organiser's Drive; links in `enterprise_files` | the meeting's participants | High |
| Google files (Docs, Sheets, Slides) | the creator's Google Drive; listed in `enterprise_files` | shared with the owner and active consultants | Medium–High |
| Emails written in the portal | the sender's Gmail (Sent); the portal keeps nothing | sender and recipients | Medium |
| Email inbox (dormant) | read live from the user's Gmail; nothing stored | the user | High |
| Chat messages and attachments | `chat_messages`; Storage `chat-attachments` (private) | conversation members only | High |
| Workshop attendees: name, phone, business | `workshop_attendees`; registration lists in Storage `documents` | the team (Administrators and consultants) | Medium |
| Google refresh tokens | `google_connections` (no app access) | server only | High |
| Push notification tokens | `device_tokens` | the device's user; server | Low |
| Consent history, email preferences | `user_consents`, `data_consents`, `email_preferences` | the person, Administrators | Low |
| Data requests | `data_requests` | the person, Administrators | Medium |
| Audit log (who did what; names in summaries) | `audit_log` | Administrators | Medium |
| Rate-limit counters (keys contain user ids) | `rate_limits` | server only; tidied after 2 days | Low |

**Not collected:** payment details, national identity numbers as fields (an uploaded document may contain one), location, analytics or advertising identifiers. `users.phone_number` exists but no screen collects it. AJW may drop the column.

## 2. Protection

- **In transit:**
  - HTTPS everywhere, with HSTS on the website;
  - TLS to Supabase (including the WebSocket for chat);
  - TLS to Google APIs.
- **At rest:** Supabase encrypts the database and storage at rest (AES-256, Amazon Web Services). Google encrypts Drive, Gmail and Calendar data.
- **Access:**
  - RLS on every table, with least-privilege grants (AUTH.md);
  - private buckets with 5-minute signed links;
  - two-step verification for Administrators and Owners;
  - 30-minute idle sign-out.
- **Access logging:**
  - every document upload, view and download;
  - user, assignment, task, enterprise, meeting, file, visit, workshop and data-request changes.
  - All of these go into `audit_log` (append-only for the app).
- **Uploads:** type list, size limits and a content check (SECURITY.md section 2).

## 3. Retention and deletion

| Data | Kept | How it goes |
|---|---|---|
| Account and programme records | For the programme and AJW's reporting obligations. [AJW RETENTION SCHEDULE: placeholder] | Erasure on request (below); otherwise kept |
| Chat messages | Until deleted or the configured period | Administrator sets a period in Data requests → "How long data is kept", then "Delete old data now" (`apply_retention()`) |
| Closed data requests | Configured period | same |
| Audit log | Permanently | never deleted. Erasure replaces the person's name and email with "a deleted user". |
| Google connection | Until disconnect | disconnect, `invalid_grant`, or erasure |
| Device tokens | Until sign-out on the device | sign-out, suspension, erasure |
| Rate-limit counters | 2 days | deleted automatically |

**Carrying out a deletion request.** An Administrator opens Data requests and chooses "Carry out deletion". This calls `manage-users` `erase` → `erase_user_personal_data()`, which:

1. refuses if the person is a consultant with active assignments (end them first), is the caller, or is the last active Administrator;
2. deletes their chat message texts and attachments, device tokens, Google connection, attention dots and email preferences;
3. clears the owner name, email and phone on enterprises they own (the business record stays: it belongs to the programme);
4. replaces their name and email with "Deleted user" and `deleted-<id>@deleted.invalid`, and suspends them;
5. replaces their name and email in the audit log with "a deleted user";
6. in Supabase Auth, removes their two-step factors and metadata, replaces the email and bans the login permanently;
7. marks the request completed and emails a confirmation from the Administrator's Gmail (if connected; otherwise the Administrator is told to notify them).

**What is kept** (programme records others rely on): tasks, documents, comments, visit notes, meetings, assessments. They stay linked to the anonymised account. AJW's lawyer should confirm this split. [LAWYER TO CONFIRM]

## 4. Third parties (processors)

| Provider | Receives | Location | Transfer basis |
|---|---|---|---|
| Supabase Inc. (on Amazon Web Services) | everything in the database and storage | European Union: Ireland, `eu-west-1` | Supabase Data Processing Addendum. [AJW TO SIGN/CONFIRM] |
| Google Firebase (Hosting, Cloud Messaging) | website visitors' IP addresses; push tokens and notification texts | Google global network (incl. United States) | Google Cloud / Firebase data processing terms |
| Google Workspace APIs (Calendar, Meet, Drive, Docs, Sheets, Slides, Gmail) | only what each feature sends, into the user's own Google account | Google global | the user's own Google terms + Google API Services User Data Policy (Limited Use) |
| Google (Gmail SMTP, `ajw.bags.portal@gmail.com`) | invitees' email addresses, invite and reset emails | Google global | Google terms |
| Google gstatic.com | visitors' IP addresses (CanvasKit engine, fallback fonts) | Google global | no personal data stored; no cookies |
| Bluehost (DNS for `ajwafrica.org`) | none (name resolution only) | United States | — |

There are no analytics, advertising or tracking services in the app, the website or any package (see `AUDIT_REPORT.md`, software development kit (SDK) audit).

Cross-border transfers (sections 48 to 50 of the Act and the Data Protection (General) Regulations, 2021): data leaves Kenya for the EU and for Google's network. The basis must be documented by AJW and confirmed by its lawyer. [LAWYER TO CONFIRM]

## 5. Breach response

A breach is any loss, leak or unauthorised access to personal data, for example a leaked key, a wrong RLS policy, a lost unlocked phone or a hacked Administrator account.

| Step | Who | When |
|---|---|---|
| 1. Contain: rotate the leaked secret, suspend affected accounts (`manage-users`), fix or revert the policy, redeploy | Technical lead (currently the developer). [AJW TO NAME] | immediately |
| 2. Assess: what data, whose, how many, since when. Use `audit_log`, Supabase logs and `net._http_response`. | Technical lead + data protection officer | within 24 hours |
| 3. Notify the Office of the Data Protection Commissioner (ODPC) | Data protection officer. [DATA PROTECTION OFFICER CONTACT] | **within 72 hours** of becoming aware (section 43 of the Act) |
| 4. Notify affected people (what happened, what to do), unless the data was unintelligible | Data protection officer | without undue delay |
| 5. Record and learn: entry in `AUDIT_REPORT.md`, new checks in `SECURITY_CHECKLIST.md` | Technical lead | within 2 weeks |

Keep a record of every breach, even ones not notified (what, effects, action taken).
