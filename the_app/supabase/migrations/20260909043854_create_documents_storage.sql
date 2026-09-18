-- ============================================================
-- Migration 6: Storage bucket for documents
-- ============================================================

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- Path convention: {enterprise_id}/{filename} — policies below check
-- the first path segment against the same helper functions used for
-- the documents table itself.

create policy "storage_documents_all_admin"
  on storage.objects for all to authenticated
  using (bucket_id = 'documents' and public.is_admin())
  with check (bucket_id = 'documents' and public.is_admin());

create policy "storage_documents_all_assigned_consultant"
  on storage.objects for all to authenticated
  using (
    bucket_id = 'documents'
    and public.is_assigned_consultant((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'documents'
    and public.is_assigned_consultant((storage.foldername(name))[1]::uuid)
  );

create policy "storage_documents_select_and_insert_owner"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'documents'
    and public.is_enterprise_owner((storage.foldername(name))[1]::uuid)
  );

create policy "storage_documents_insert_owner"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'documents'
    and public.is_enterprise_owner((storage.foldername(name))[1]::uuid)
  );