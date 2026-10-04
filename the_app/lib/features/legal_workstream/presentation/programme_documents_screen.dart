import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/file_filter_bar.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';
import '../providers/legal_workstream_providers.dart';
import 'open_document_viewer.dart';

/// Admin's Documents page: programme files that belong to no single
/// enterprise. Today that's the workshop registration lists consultants
/// submit (the ToR's list "to M&E within 5 days"). Admins only, by RLS
/// and by the menu.
class ProgrammeDocumentsScreen extends ConsumerStatefulWidget {
  const ProgrammeDocumentsScreen({super.key});

  @override
  ConsumerState<ProgrammeDocumentsScreen> createState() => _ProgrammeDocumentsScreenState();
}

class _ProgrammeDocumentsScreenState extends ConsumerState<ProgrammeDocumentsScreen> {
  FileFilters _filters = const FileFilters();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(programmeDocumentsProvider);

    return AppShell(
      title: 'Documents',
      globalKey: 'documents',
      body: docsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load documents",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(programmeDocumentsProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No programme documents yet',
              message: 'Workshop registration lists appear here when a consultant submits them. '
                  "Each enterprise's own documents are inside that enterprise.",
            );
          }
          final uploaders = {for (final d in docs) d.uploadedBy: d.uploaderName ?? 'Someone'};
          final workshops = {for (final d in docs) d.workshopTitle ?? 'Workshop removed'}.toList()..sort();
          final shown = docs
              .where((d) => _filters.matches(
                    name: d.fileName,
                    kind: d.workshopTitle ?? 'Workshop removed',
                    uploaderId: d.uploadedBy,
                    at: d.uploadedAt.toLocal(),
                  ))
              .toList();
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: PageBody.paddingFor(context),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Programme files that belong to no single enterprise, such as workshop registration lists. '
                      'Lists open in Excel.',
                      style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft),
                    ),
                    const SizedBox(height: Space.lg),
                    TourAnchor(
                      id: TourAnchors.programmeDocumentsFilters,
                      child: FileFilterBar(
                        filters: _filters,
                        onChanged: (f) => setState(() => _filters = f),
                        kindLabel: 'Workshop',
                        kinds: workshops,
                        uploaders: uploaders,
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Text(
                      _filters.isActive ? '${shown.length} of ${docs.length} files' : '${docs.length} files',
                      style: text.labelMedium?.copyWith(color: AppColors.charcoalSoft),
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
                            leading: const Icon(Icons.table_chart_outlined),
                            title: Text(d.fileName, overflow: TextOverflow.ellipsis),
                            subtitle: Text([
                              d.workshopTitle ?? 'Workshop removed',
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
}
