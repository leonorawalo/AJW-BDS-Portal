-- ============================================================
-- Two facts about an enterprise that genuinely can't be derived from
-- anything else in the schema (no task or document captures a number
-- or a date) — annual turnover and when the business started. These
-- live directly on `enterprises` as current, editable-anytime facts,
-- not a repeated form submission: set once, updated when known better.
--
-- Everything else the loan-readiness dashboard needs (registration,
-- tax compliance, bank statement history, collateral, audited
-- accounts, business permit, CRB check) is read live from ToR task
-- completion (standardLegalChecklist / standardAccountingChecklist)
-- instead of a separate manually-filled assessment.
-- ============================================================

alter table public.enterprises
  add column annual_turnover numeric,
  add column business_started_date date,
  add column loan_purpose text;
