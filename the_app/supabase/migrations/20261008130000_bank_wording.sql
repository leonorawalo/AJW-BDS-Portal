-- ============================================================
-- "KCB" -> generic bank wording in stored task text
-- ============================================================
-- The app no longer names KCB anywhere: the bank's name, if any, is one
-- setting (lib/core/lender.dart). Task rows copy their description from
-- the Terms of Reference template when created, so rows made before the
-- change still say KCB. Only descriptions change: titles and tor_key are
-- untouched (the loan-readiness score reads titles by exact text).
-- The unused assessments.kcb_requirements_met column is left as it is
-- (nothing reads it; dropping it isn't needed for this change).
-- Idempotent.
-- ============================================================

update public.tasks
set description = replace(description, '(KCB''s secured SME lending)', '(secured lending to small and medium enterprises)')
where description like '%(KCB''s secured SME lending)%';
