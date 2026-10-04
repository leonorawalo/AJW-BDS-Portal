-- ============================================================
-- Schema drift repair (found 2026-10-04).
--
-- Two migrations are recorded as applied but never reached the live
-- database (they were run by hand in the SQL editor, which failed or
-- was skipped, and later marked applied):
--   20260916150000_extend_assessments_loan_readiness  (assessments)
--   20260916180000_enterprise_financial_facts         (enterprises)
-- Symptom: saving Business facts failed with PGRST204 "Could not find
-- the 'annual_turnover' column of 'enterprises' in the schema cache".
--
-- Every other table, policy, trigger, function, index and check
-- constraint was compared against the migrations and matches.
--
-- Idempotent: safe on a database where those migrations did run.
-- The assessments columns are unused by the app today (the manual
-- assessment form was replaced by task-derived scores) but are restored
-- so the live schema matches the migration history.
-- ============================================================

alter table public.enterprises
  add column if not exists annual_turnover numeric,
  add column if not exists business_started_date date,
  add column if not exists loan_purpose text;

alter table public.assessments
  add column if not exists business_started_date date,
  add column if not exists registration_status varchar(30),
  add column if not exists tax_compliant boolean,
  add column if not exists tax_compliance_notes text,
  add column if not exists has_six_months_bank_statements boolean,
  add column if not exists bank_name varchar(100),
  add column if not exists annual_turnover numeric,
  add column if not exists has_collateral boolean,
  add column if not exists collateral_description text,
  add column if not exists has_audited_accounts boolean,
  add column if not exists has_valid_business_permit boolean,
  add column if not exists positive_crb_status boolean,
  add column if not exists has_financial_records boolean,
  add column if not exists loan_purpose text,
  add column if not exists business_health_score numeric,
  add column if not exists credit_readiness_score numeric,
  add column if not exists kcb_requirements_met integer,
  add column if not exists red_flags text[];

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'assessments_registration_status_check'
      and conrelid = 'public.assessments'::regclass
  ) then
    alter table public.assessments
      add constraint assessments_registration_status_check
      check (registration_status in ('Unregistered', 'Sole Proprietor', 'Partnership', 'Limited Company'));
  end if;
end $$;

alter table public.assessments
  alter column assessment_type set default 'Loan Readiness';

-- PostgREST caches the schema; make the new columns visible now.
notify pgrst, 'reload schema';
