import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'package:the_app/core/file_signature.dart';
import 'package:the_app/core/legal/legal_documents.dart';
import 'package:the_app/core/user_message.dart';
import 'package:the_app/features/privacy/models/consent_record.dart';
import 'package:the_app/features/privacy/models/data_request.dart';

ConsentAnswer _answer(ConsentPurpose p, {bool granted = true, String? version}) => ConsentAnswer(
      purpose: p,
      version: version ?? p.currentVersion,
      granted: granted,
      recordedAt: DateTime(2026, 10, 17),
    );

void main() {
  group('ConsentStatus', () {
    test('needs Terms, Privacy Policy, transfer consent and 18 or over, in the current versions', () {
      final all = {
        for (final p in [
          ConsentPurpose.termsOfService,
          ConsentPurpose.privacyPolicy,
          ConsentPurpose.sensitiveDataTransfer,
          ConsentPurpose.age18OrOver,
        ])
          p: _answer(p),
      };
      expect(ConsentStatus(all).isComplete, isTrue);

      for (final missing in all.keys) {
        expect(ConsentStatus({...all}..remove(missing)).isComplete, isFalse, reason: '$missing missing');
      }
      expect(
        ConsentStatus({...all, ConsentPurpose.age18OrOver: _answer(ConsentPurpose.age18OrOver, granted: false)})
            .isComplete,
        isFalse,
      );
    });

    test('a new Terms of Service version asks again', () {
      final status = ConsentStatus({
        ConsentPurpose.termsOfService: _answer(ConsentPurpose.termsOfService, version: '1.0-old'),
        ConsentPurpose.privacyPolicy: _answer(ConsentPurpose.privacyPolicy),
        ConsentPurpose.sensitiveDataTransfer: _answer(ConsentPurpose.sensitiveDataTransfer),
        ConsentPurpose.age18OrOver: _answer(ConsentPurpose.age18OrOver),
      });
      expect(status.isComplete, isFalse);
    });

    test('programme emails are off unless chosen, and not required', () {
      expect(const ConsentStatus({}).programmeEmails, isFalse);
      expect(ConsentStatus({ConsentPurpose.programmeEmails: _answer(ConsentPurpose.programmeEmails)}).programmeEmails,
          isTrue);
    });

    test('purposes match the database values', () {
      for (final p in ConsentPurpose.values) {
        expect(ConsentPurposeX.fromDb(p.dbValue), p);
      }
      expect(ConsentPurpose.termsOfService.currentVersion, LegalDocuments.termsOfService.version);
      expect(ConsentPurpose.programmeEmails.currentVersion, '');
    });
  });

  group('userMessage', () {
    test('never shows raw database errors', () {
      expect(
        userMessage(const PostgrestException(message: 'relation "tasks" does not exist', code: '42P01')),
        'Something went wrong. Please try again.',
      );
      expect(
        userMessage(const PostgrestException(
            message: 'new row violates row-level security policy for table "tasks"', code: '42501')),
        "You don't have permission to do that.",
      );
    });

    test('keeps sentences our own rules raise', () {
      expect(
        userMessage(const PostgrestException(message: 'Give the person a reason when refusing a request', code: '23514')),
        'Give the person a reason when refusing a request',
      );
      expect(userMessage(Exception('The file is too large.')), 'The file is too large.');
      expect(
        userMessage(const FunctionException(status: 429, details: {'error': 'Too many requests.'})),
        'Too many requests.',
      );
      expect(userMessage(StateError('boom')), 'Something went wrong. Please try again.');
    });
  });

  test('every data request kind has a person-facing action', () {
    expect(DataRequestKind.deletion.actionLabel, 'Request deletion of my data');
    expect(DataRequestStatus.open.label, 'Received');
  });

  test('legal documents link to the portal and are versioned', () {
    for (final doc in LegalDocuments.all) {
      expect(doc.url, startsWith('https://portal.ajwafrica.org/'));
      expect(doc.version, isNotEmpty);
      expect(DateTime.tryParse(doc.lastUpdated), isNotNull);
    }
  });

  group('contentMatchesExtension', () {
    Uint8List b(List<int> v) => Uint8List.fromList(v);
    test('accepts real files', () {
      expect(contentMatchesExtension(b('%PDF-1.7 '.codeUnits), 'pdf'), isTrue);
      expect(contentMatchesExtension(b([0x0A, 0x0A, ...'%PDF-1.4'.codeUnits]), 'pdf'), isTrue);
      expect(contentMatchesExtension(b([0xFF, 0xD8, 0xFF, 0xE0]), 'JPG'), isTrue);
      expect(contentMatchesExtension(b([0x50, 0x4B, 0x03, 0x04, 1]), 'docx'), isTrue);
      expect(contentMatchesExtension(b('name,phone'.codeUnits), 'csv'), isTrue);
    });
    test('refuses renamed files', () {
      expect(contentMatchesExtension(b([0x4D, 0x5A, 0x90, 0x00]), 'pdf'), isFalse); // a Windows program
      expect(contentMatchesExtension(b([0x89, 0x50, 0x4E, 0x47]), 'jpg'), isFalse);
      expect(contentMatchesExtension(b([0x4D, 0x5A, 0x00, 0x00]), 'txt'), isFalse);
      expect(contentMatchesExtension(b('%PDF-1.7'.codeUnits), 'exe'), isFalse);
    });
  });
}
