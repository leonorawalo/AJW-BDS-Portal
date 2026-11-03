import '../../../core/legal/legal_documents.dart';

/// What a person can agree to (user_consents.purpose, migration
/// 20261016100000; sensitiveDataTransfer added by 20261103100000). All but
/// programmeEmails are required to use the portal.
enum ConsentPurpose { termsOfService, privacyPolicy, age18OrOver, programmeEmails, sensitiveDataTransfer }

extension ConsentPurposeX on ConsentPurpose {
  String get dbValue => switch (this) {
        ConsentPurpose.termsOfService => 'terms_of_service',
        ConsentPurpose.privacyPolicy => 'privacy_policy',
        ConsentPurpose.age18OrOver => 'age_18_or_over',
        ConsentPurpose.programmeEmails => 'programme_emails',
        ConsentPurpose.sensitiveDataTransfer => 'sensitive_data_transfer',
      };

  static ConsentPurpose? fromDb(String v) {
    for (final p in ConsentPurpose.values) {
      if (p.dbValue == v) return p;
    }
    return null;
  }

  /// The document version an answer is tied to ('' = not a document).
  String get currentVersion => switch (this) {
        ConsentPurpose.termsOfService => LegalDocuments.termsOfService.version,
        ConsentPurpose.privacyPolicy => LegalDocuments.privacyPolicy.version,
        // Explained in the Privacy Policy, so a new policy version asks again.
        ConsentPurpose.sensitiveDataTransfer => LegalDocuments.privacyPolicy.version,
        _ => '',
      };
}

/// The latest answer for one purpose.
class ConsentAnswer {
  const ConsentAnswer({required this.purpose, required this.version, required this.granted, required this.recordedAt});

  factory ConsentAnswer.fromMap(Map<String, dynamic> map) => ConsentAnswer(
        purpose: ConsentPurposeX.fromDb(map['purpose'] as String)!,
        version: map['document_version'] as String? ?? '',
        granted: map['granted'] as bool,
        recordedAt: DateTime.parse(map['recorded_at'] as String).toLocal(),
      );

  final ConsentPurpose purpose;
  final String version;
  final bool granted;
  final DateTime recordedAt;
}

/// Everyone's latest answers, and whether they still cover the current
/// Terms of Service and Privacy Policy.
class ConsentStatus {
  const ConsentStatus(this.answers);

  final Map<ConsentPurpose, ConsentAnswer> answers;

  bool _agreed(ConsentPurpose p) {
    final a = answers[p];
    return a != null && a.granted && a.version == p.currentVersion;
  }

  /// Terms accepted and Privacy Policy read in their current versions,
  /// consent to storing sensitive data outside Kenya (section 49 of the
  /// Act) given under the current policy, and confirmed 18 or over.
  bool get isComplete =>
      _agreed(ConsentPurpose.termsOfService) &&
      _agreed(ConsentPurpose.privacyPolicy) &&
      _agreed(ConsentPurpose.sensitiveDataTransfer) &&
      _agreed(ConsentPurpose.age18OrOver);

  bool get programmeEmails => answers[ConsentPurpose.programmeEmails]?.granted ?? false;
}
