import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/document.dart';
import '../providers/legal_workstream_providers.dart';
import 'open_document_viewer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/file_filter_bar.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

class DocumentsTab extends ConsumerStatefulWidget {
  const DocumentsTab({super.key, required this.enterpriseId, required this.readOnly});
  final String enterpriseId;
  // Owner CAN upload per SRS ("comment/upload") — readOnly here only
  // affects whether this flag suppresses upload; currently the button
  // always shows regardless, matching that both roles may upload.
  final bool readOnly;

  @override
  ConsumerState<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<DocumentsTab> {
  FileFilters _filters = const FileFilters();

  String get enterpriseId => widget.enterpriseId;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider(enterpriseId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: TourAnchor(id: TourAnchors.documentsAdd, child: FloatingActionButton.extended(
        onPressed: () => _pickAndUpload(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      )),
      body: docsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load documents",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(documentsProvider(enterpriseId)),
            child: const Text('Try again'),
          ),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No documents yet',
              message: 'Upload certificates, licences, contracts and records for this enterprise.',
            );
          }
          final uploaders = {for (final d in docs) d.uploadedBy: d.uploaderName ?? 'Someone'};
          final shown = docs
              .where((d) => _filters.matches(
                    name: d.fileName,
                    kind: d.category ?? 'Uncategorized',
                    uploaderId: d.uploadedBy,
                    at: d.uploadedAt.toLocal(),
                  ))
              .toList();
          final padding = PageBody.paddingFor(context);
          return ListView(
            padding: padding.copyWith(bottom: padding.bottom + 88),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TourAnchor(id: TourAnchors.documentsFilters, child: FileFilterBar(
                      filters: _filters,
                      onChanged: (f) => setState(() => _filters = f),
                      kindLabel: 'Category',
                      kinds: [...documentCategories, 'Uncategorized'],
                      uploaders: uploaders,
                    )),
                    const SizedBox(height: Space.lg),
                    Text(
                      _filters.isActive ? '${shown.length} of ${docs.length} documents' : '${docs.length} documents',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.charcoalSoft),
                    ),
                    const SizedBox(height: Space.sm),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xl),
                        child: EmptyState(
                          icon: Icons.search_off,
                          title: 'Nothing matches',
                          message: 'Try another search, or clear the filters.',
                          action: OutlinedButton(
                            onPressed: () => setState(() => _filters = const FileFilters()),
                            child: const Text('Clear filters'),
                          ),
                        ),
                      )
                    else
                      for (final d in shown) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              d.isImage
                                  ? Icons.image_outlined
                                  : (d.isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined),
                            ),
                            title: Text(d.fileName, overflow: TextOverflow.ellipsis),
                            subtitle: Text([
                              d.category ?? 'Uncategorized',
                              if (d.uploaderName != null) d.uploaderName!,
                              _day(d.uploadedAt.toLocal()),
                            ].join('  ·  ')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openDocumentViewer(context, d),
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                  ],
                ),
              ),
            ],
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
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
            child: DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: documentCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? category),
          ),
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