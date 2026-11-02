import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/email_repository.dart';
import '../data/inbox_repository.dart';
import '../models/email_contact.dart';
import '../models/inbox_message.dart';
import '../models/inbox_page.dart';

final emailRepositoryProvider = Provider<EmailRepository>((ref) {
  return EmailRepository(ref.watch(supabaseClientProvider));
});

final enterpriseEmailContactsProvider =
    FutureProvider.autoDispose.family<List<EmailContact>, String>((ref, enterpriseId) {
  return ref.watch(emailRepositoryProvider).fetchContacts(enterpriseId);
});

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(ref.watch(supabaseClientProvider));
});

/// The first page of an enterprise's inbox.
final enterpriseInboxProvider = FutureProvider.autoDispose.family<InboxPage, String>((ref, enterpriseId) {
  return ref.watch(inboxRepositoryProvider).list(enterpriseId);
});

/// One opened message, keyed by (enterprise id, message id).
final inboxMessageProvider =
    FutureProvider.autoDispose.family<InboxMessage, (String, String)>((ref, key) {
  return ref.watch(inboxRepositoryProvider).get(key.$1, key.$2);
});
