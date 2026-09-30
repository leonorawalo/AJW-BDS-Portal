import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/email_repository.dart';
import '../models/email_contact.dart';

final emailRepositoryProvider = Provider<EmailRepository>((ref) {
  return EmailRepository(ref.watch(supabaseClientProvider));
});

final enterpriseEmailContactsProvider =
    FutureProvider.autoDispose.family<List<EmailContact>, String>((ref, enterpriseId) {
  return ref.watch(emailRepositoryProvider).fetchContacts(enterpriseId);
});
