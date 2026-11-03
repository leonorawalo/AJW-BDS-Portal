import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document.dart';
import '../providers/legal_workstream_providers.dart';
import '../../../core/widgets/ajw_loader.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.document});
  final WorkstreamDocument document;

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _loading = true;
  String? _error;
  Uint8List? _imageBytes;
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(documentRepositoryProvider);
    repo.logAccess(widget.document.id, download: !(widget.document.isPdf || widget.document.isImage));
    try {
      if (widget.document.isPdf && kIsWeb) {
        // On the web the in-app PDF viewer (pdfx) needs Mozilla's pdf.js,
        // which the site doesn't load (and the Content-Security-Policy
        // would block). Every browser has a good PDF viewer of its own, so
        // the web opens PDFs there through a 5-minute link instead.
        _signedUrl = await repo.getDownloadUrl(widget.document.storagePath);
      } else if (widget.document.isPdf) {
        final bytes = await repo.downloadBytes(widget.document.storagePath);
        _pdfController = PdfControllerPinch(document: PdfDocument.openData(bytes));
      } else if (widget.document.isImage) {
        _imageBytes = await repo.downloadBytes(widget.document.storagePath);
      } else {
        // Rare fallback: genuinely uncommon file type for this app's
        // documents (registration certs, IDs, PDFs, photos), so a
        // browser tab is an acceptable exception rather than building
        // a viewer for every possible file format.
        _signedUrl = await repo.getDownloadUrl(widget.document.storagePath);
      }
    } catch (e) {
      _error = 'Could not load this document.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.fileName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AjwLoadingView();
    if (_error != null) return Center(child: Text(_error!));

    if (_pdfController != null) {
      return PdfViewPinch(controller: _pdfController!);
    }
    if (_imageBytes != null) {
      return InteractiveViewer(
        child: Center(child: Image.memory(_imageBytes!, semanticLabel: widget.document.fileName)),
      );
    }
    if (_signedUrl != null) {
      final isWebPdf = widget.document.isPdf;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWebPdf) ...[
                const Text(
                  'This PDF opens in a new browser tab.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(isWebPdf ? 'Open PDF' : 'Open in browser'),
                onPressed: () => launchUrl(Uri.parse(_signedUrl!), mode: LaunchMode.externalApplication),
              ),
              const SizedBox(height: 12),
              Text(
                'For security, this link works for 5 minutes. Come back here for a new one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}