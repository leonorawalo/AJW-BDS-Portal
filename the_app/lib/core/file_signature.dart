import 'dart:typed_data';

/// Whether a file's first bytes match its extension, so a renamed file
/// (for example a program called "licence.pdf") is refused before upload.
/// Rule: docs/security/SECURITY.md, "Uploads". Unknown extensions return
/// false; the callers' own type lists decide what is offered at all.
bool contentMatchesExtension(Uint8List bytes, String extension) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (bytes.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  const zip = [0x50, 0x4B, 0x03, 0x04]; // docx, xlsx, pptx are zip files
  const ole = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]; // doc, xls, ppt
  switch (extension.toLowerCase()) {
    case 'pdf':
      // The PDF standard lets "%PDF-" start anywhere in the first 1 KB.
      for (var i = 0; i < 1024 && i < bytes.length; i++) {
        if (startsWith('%PDF-'.codeUnits, i)) return true;
      }
      return false;
    case 'jpg':
    case 'jpeg':
      return startsWith([0xFF, 0xD8, 0xFF]);
    case 'png':
      return startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    case 'gif':
      return startsWith('GIF87a'.codeUnits) || startsWith('GIF89a'.codeUnits);
    case 'webp':
      return startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8);
    case 'heic':
      return startsWith('ftyp'.codeUnits, 4);
    case 'docx':
    case 'xlsx':
    case 'pptx':
      return startsWith(zip);
    case 'doc':
    case 'xls':
    case 'ppt':
      return startsWith(ole);
    case 'csv':
    case 'txt':
      // Text: no NUL bytes near the start (binary files nearly always have one).
      final end = bytes.length < 4096 ? bytes.length : 4096;
      for (var i = 0; i < end; i++) {
        if (bytes[i] == 0) return false;
      }
      return true;
    default:
      return false;
  }
}
