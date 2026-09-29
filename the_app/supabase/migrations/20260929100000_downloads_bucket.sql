-- ============================================================
-- Public "downloads" bucket for the Android APK (Phase 9a)
-- ============================================================
-- Invite emails link to the app for Owners/consultants who don't have it
-- yet. A public bucket gives a stable URL anyone can download from
-- without signing in:
--   https://<project-ref>.supabase.co/storage/v1/object/public/downloads/ajw-bags-portal.apk
-- Public buckets need no SELECT policy for downloads. There are no
-- INSERT/UPDATE policies, so app users can't upload here; the APK is
-- uploaded from the dashboard (Storage -> downloads).
-- Limited to APK files up to 150 MB.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('downloads', 'downloads', true, 157286400, array['application/vnd.android.package-archive'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
