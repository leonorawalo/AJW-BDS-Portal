import 'dart:ui' show Color;

import '../../../core/site_links.dart';
import '../../../core/theme/app_colors.dart';
import 'export_formatting.dart';

/// The one template every generated document follows, Google Doc or PDF:
/// AJW logo in the header, AJW colours on headings and table headers, and
/// a footer on every page naming the document type, the enterprise and
/// the generation date (plus "Page X of Y" where the format allows it).
/// Colours come from [AppColors]; change them there.
class DocumentBrand {
  DocumentBrand._();

  /// A PNG copy of web/brand/ajw-mark.svg, served by the portal site.
  /// Google Docs can't show SVG and fetches the image by address when the
  /// document is created.
  static const logoUrl = '${SiteLinks.site}/brand/ajw-logo.png';

  static const organisation = 'AJW Africa Foundation';
  static const portalName = 'AJW Business Advancement and Growth Services (BAGS) Portal';

  static String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static final heading = hex(AppColors.brandRed);
  static final subheading = hex(AppColors.charcoal);
  static final tableHeaderFill = hex(AppColors.brandRedTint);
  static final rule = hex(AppColors.lightGray);

  /// "Programme Report – Jua Kali Welders · Generated 8 Oct 2026". The page
  /// number is added separately because each format numbers pages its own
  /// way.
  static String footerText({required String documentType, String? enterpriseName, required DateTime generatedAt}) {
    final subject = enterpriseName == null || enterpriseName.trim().isEmpty ? '' : ' – ${enterpriseName.trim()}';
    return '$documentType$subject  ·  Generated ${exportLongDate(generatedAt)}';
  }
}

/// Wraps a document body in the branded template for Google Docs. Drive's
/// HTML import keeps inline styles more reliably than a style sheet, so
/// headings and table headers get their colours inline.
String brandedDocHtml({required String title, required String bodyHtml}) {
  final body = bodyHtml
      .replaceAllMapped(
        RegExp(r'<h1>'),
        (_) => '<h1 style="color:${DocumentBrand.heading};font-family:Arial,sans-serif;">',
      )
      .replaceAllMapped(
        RegExp(r'<h2>'),
        (_) => '<h2 style="color:${DocumentBrand.heading};font-family:Arial,sans-serif;'
            'border-bottom:1px solid ${DocumentBrand.rule};">',
      )
      .replaceAllMapped(
        RegExp(r'<h3>'),
        (_) => '<h3 style="color:${DocumentBrand.subheading};font-family:Arial,sans-serif;">',
      )
      .replaceAllMapped(
        RegExp(r'<th>'),
        (_) => '<th style="background-color:${DocumentBrand.tableHeaderFill};color:${DocumentBrand.subheading};">',
      );
  return '<html><head><meta charset="utf-8"><title>${esc(title)}</title></head>'
      '<body style="font-family:Arial,sans-serif;color:${DocumentBrand.subheading};">'
      '<table style="border:none;width:100%;"><tr>'
      '<td style="border:none;width:64px;"><img src="${DocumentBrand.logoUrl}" height="56" alt="AJW logo"></td>'
      '<td style="border:none;"><b style="color:${DocumentBrand.heading};font-size:14pt;">${DocumentBrand.organisation}</b><br>'
      '<span style="color:${DocumentBrand.subheading};font-size:9pt;">${DocumentBrand.portalName}</span></td>'
      '</tr></table>'
      '<hr style="border:none;border-top:2px solid ${DocumentBrand.heading};">'
      '$body'
      '</body></html>';
}
