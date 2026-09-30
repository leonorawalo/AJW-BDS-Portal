import 'package:flutter/material.dart';

import '../../../core/widgets/progress_dialog.dart';
import '../models/document.dart';
import 'document_viewer_screen.dart' deferred as viewer;

bool _viewerLoaded = false;

/// Opens [viewer.DocumentViewerScreen]. The import is deferred so that on
/// web the PDF viewer (pdfx) is only downloaded the first time someone opens
/// a document, not as part of every first page load.
Future<void> openDocumentViewer(BuildContext context, WorkstreamDocument document) async {
  if (!_viewerLoaded) {
    await withProgress(context, 'Opening viewer…', viewer.loadLibrary());
    _viewerLoaded = true;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => viewer.DocumentViewerScreen(document: document),
  ));
}
