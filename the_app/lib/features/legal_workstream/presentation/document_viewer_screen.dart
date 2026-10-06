import 'dart:typed_data';

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
    try {
      if (widget.document.isPdf) {
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
        child: Center(child: Image.memory(_imageBytes!)),
      );
    }
    if (_signedUrl != null) {
      return Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in browser'),
          onPressed: () => launchUrl(Uri.parse(_signedUrl!), mode: LaunchMode.externalApplication),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}