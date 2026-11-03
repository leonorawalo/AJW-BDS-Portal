-- Consent to store sensitive personal data outside Kenya (3 Nov 2026).
--
-- Section 49(1) of the Kenya Data Protection Act, 2019: sensitive
-- personal data may be processed outside Kenya only with the data
-- subject's consent AND confirmation of appropriate safeguards. The
-- portal's database and files are with Supabase in Ireland (European
-- Union), and enterprise records can hold sensitive personal data as the
-- Act defines it (for example property details, and family details in
-- success stories). The ODPC's Guidance Notes for Cross-border Data
-- Transfers (September 2026) confirm cloud hosting abroad is a transfer.
--
-- The consent screen now asks for this as its own required answer,
-- recorded in user_consents like the others (append-only, versioned to
-- the Privacy Policy).
--
-- Idempotent: safe to run twice.

alter table public.user_consents drop constraint if exists user_consents_purpose_check;
alter table public.user_consents
  add constraint user_consents_purpose_check
  check (purpose in ('terms_of_service', 'privacy_policy', 'age_18_or_over', 'programme_emails', 'sensitive_data_transfer'));

-- Retention schedule (Privacy Policy 2.1, section 7): chat messages and
-- closed data requests are kept 2 years. Only fills in periods nobody has
-- set yet; an Administrator's own choice is left alone. Deletion still
-- runs only when an Administrator presses "Apply retention".
update public.retention_settings set keep_days = 730, updated_at = now()
where key in ('chat_messages', 'closed_data_requests') and keep_days is null;

-- People can now add their own phone number in Settings and privacy. The
-- app saves one form (+254712345678); the database refuses anything else
-- so the unique constraint can't be dodged with spaces or a leading 0.
-- NOT VALID: older rows (all empty today) aren't re-checked.
alter table public.users drop constraint if exists users_phone_number_format;
alter table public.users
  add constraint users_phone_number_format
  check (phone_number is null or phone_number ~ '^\+[0-9]{9,15}$') not valid;
