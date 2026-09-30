import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/document.dart';
import '../providers/legal_workstream_providers.dart';
import 'open_document_viewer.dart';
import '../../../core/widgets/ajw_loader.dart';

class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.enterpriseId, required this.readOnly});
  final String enterpriseId;
  // Owner CAN upload per SRS ("comment/upload") — readOnly here only
  // affects whether this flag suppresses upload; currently the button
  // always shows regardless, matching that both roles may upload.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider(enterpriseId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUpload(context, ref),
        child: const Icon(Icons.upload_file),
      ),
      body: docsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => const Center(child: Text('Could not load documents.')),
        data: (docs) {
          if (docs.isEmpty) return const Center(child: Text('No documents yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              return Card(
                child: ListTile(
                  leading: Icon(d.isImage ? Icons.image : (d.isPdf ? Icons.picture_as_pdf : Icons.description)),
                  title: Text(d.fileName),
                  subtitle: Text(d.category ?? 'Uncategorized'),
                  onTap: () => openDocumentViewer(context, d),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    String category = documentCategories.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Upload "${file.name}"'),
          content: DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: documentCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? category),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Upload')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final uploadedBy = ref.read(authRepositoryProvider).currentUser!.id;
    await ref.read(documentRepositoryProvider).uploadDocument(
          enterpriseId: enterpriseId,
          uploadedByUserId: uploadedBy,
          fileName: file.name,
          bytes: bytes,
          category: category,
          mimeType: file.extension,
        );
    ref.invalidate(documentsProvider(enterpriseId));
  }
}