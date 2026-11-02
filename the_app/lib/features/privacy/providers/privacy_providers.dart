import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/privacy_repository.dart';
import '../models/consent_record.dart';
import '../models/data_request.dart';
import '../models/retention_setting.dart';

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  return PrivacyRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's consents: whether they have accepted the current
/// Terms of Service and Privacy Policy (ConsentGate), and their optional
/// email choice.
final consentStatusProvider = FutureProvider<ConsentStatus>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(privacyRepositoryProvider).consentStatus();
});

final myDataRequestsProvider = FutureProvider.autoDispose<List<DataRequest>>((ref) {
  return ref.watch(privacyRepositoryProvider).requests();
});

final allDataRequestsProvider = FutureProvider.autoDispose<List<DataRequest>>((ref) {
  return ref.watch(privacyRepositoryProvider).requests(everyone: true);
});

final retentionSettingsProvider = FutureProvider.autoDispose<List<RetentionSetting>>((ref) {
  return ref.watch(privacyRepositoryProvider).retention();
});
