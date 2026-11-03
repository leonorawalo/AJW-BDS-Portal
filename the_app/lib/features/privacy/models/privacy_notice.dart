import '../../../core/legal/legal_documents.dart';

/// The privacy summary people accept before using the portal, with the
/// Terms of Service (ConsentGate). The full texts are the public pages
/// built from legal/ (scripts/build_legal.js); changing a page's version
/// there asks everyone to accept it again.
///
/// The legal texts are DRAFTS for AJW's lawyer: see the [PLACEHOLDERS] in
/// legal/business.json and docs/security/AUDIT_REPORT.md.
class PrivacyNotice {
  PrivacyNotice._();

  /// Also written to data_consents, which phones on older app versions
  /// still check.
  static final version = LegalDocuments.privacyPolicy.version;

  static final fullNoticeUrl = LegalDocuments.dataProtectionNotice.url;

  static const summary = <(String, String)>[
    (
      'What we collect',
      'Your name, email address and role; for enterprises, business details, '
          'registration documents, licences and certificates, financial facts, tasks, visit notes, '
          'meetings and messages.',
    ),
    (
      'Why',
      "To deliver AJW's Business Advancement and Growth Services (BAGS) programme: track each "
          "enterprise's progress, coordinate consultants, report to programme partners and prepare "
          'businesses to apply for bank loans.',
    ),
    (
      'Who sees it',
      "Only the enterprise's owner, its assigned consultants and AJW administrators. Documents are "
          'stored privately and opened through links that expire within minutes. Every view, upload '
          'and change of a document is logged.',
    ),
    (
      'Where it is stored',
      'With our service providers Supabase (in the European Union) and Google, so outside Kenya. '
          'Because some records are sensitive personal data under the Act (for example property or family '
          'details), we ask for your consent to this below. The Privacy Policy lists the providers and the '
          'safeguards.',
    ),
    (
      'Your rights',
      'Under the Kenya Data Protection Act, 2019 you can get a copy of your data, ask for corrections '
          'or ask for deletion, from "Settings and privacy" in the menu. We answer access requests within '
          '7 days and correction or deletion requests within 14 days.',
    ),
  ];
}
