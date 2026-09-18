-- ============================================================
-- Loan-readiness assessment: extend `assessments` with a concrete
-- lender-readiness checklist, in place of the old free-text-only form.
--
-- Scoped deliberately: this captures the 7 checklist items a lender
-- actually asks for (registration, tax compliance, bank statement
-- history, turnover, collateral, audited accounts, operating history),
-- plus the specific extra fields needed for a KCB MSME readiness
-- checklist and a short red-flag list. This is NOT the full
-- multi-domain credit-scoring framework (financial ratios, DSCR,
-- normalized question/response tables, etc.) — that's out of scope
-- for this project's timeline; explicit typed columns on the existing
-- table were chosen over a JSON blob to match how the rest of this
-- schema (tasks, consultant_assignments, documents) is modeled.
--
-- Scores are computed in the Flutter app at submission time (pure
-- functions over these same columns) rather than via a Postgres
-- trigger — unlike e.g. tasks.completed_at, these aren't values that
-- need to stay consistent if the row is edited outside the app; an
-- assessment is a point-in-time snapshot.
-- ============================================================

alter table public.assessments
  add column business_started_date date,
  add column registration_status varchar(30)
    check (registration_status in ('Unregistered', 'Sole Proprietor', 'Partnership', 'Limited Company')),
  add column tax_compliant boolean,
  add column tax_compliance_notes text,
  add column has_six_months_bank_statements boolean,
  add column bank_name varchar(100),
  add column annual_turnover numeric,
  add column has_collateral boolean,
  add column collateral_description text,
  add column has_audited_accounts boolean,
  -- KCB MSME readiness checklist extras — not part of the base 7
  -- criteria, but needed to compute that checklist.
  add column has_valid_business_permit boolean,
  add column positive_crb_status boolean,
  add column has_financial_records boolean,
  add column loan_purpose text,
  -- Computed outputs (see scoring note above)
  add column business_health_score numeric,
  add column credit_readiness_score numeric,
  add column kcb_requirements_met integer,
  add column red_flags text[];

-- New assessments from this form are all the same "type" conceptually
-- (loan/credit readiness) — default it so the app doesn't need to ask
-- for an arbitrary free-text label on every submission.
alter table public.assessments
  alter column assessment_type set default 'Loan Readiness';
