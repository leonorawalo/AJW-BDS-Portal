import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal/legal_documents.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/consent_record.dart';
import '../models/privacy_notice.dart';
import '../providers/privacy_providers.dart';
import '../../../core/widgets/security_gates.dart';

/// Before anything else, everyone accepts the current Terms of Service,
/// confirms they have read the Privacy Policy, consents to sensitive
/// personal data being stored outside Kenya (section 49 of the Kenya Data
/// Protection Act, 2019) and confirms they are 18 or over. Programme emails are a
/// separate, optional choice. Nothing is ticked in advance, and saying no
/// is one tap ("Don't agree and sign out"). Every answer is kept in
/// user_consents with the document version; a new version asks again.
class ConsentGate extends ConsumerStatefulWidget {
  const ConsentGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<ConsentGate> {
  bool _termsAndPrivacy = false;
  bool _transfer = false;
  bool _adult = false;
  bool _programmeEmails = false;
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(privacyRepositoryProvider);
      await repo.recordAnswers({
        ConsentPurpose.termsOfService: true,
        ConsentPurpose.privacyPolicy: true,
        ConsentPurpose.sensitiveDataTransfer: true,
        ConsentPurpose.age18OrOver: true,
        ConsentPurpose.programmeEmails: _programmeEmails,
      });
      // Phones on older app versions check this table.
      await repo.recordConsent(PrivacyNotice.version);
      ref.invalidate(consentStatusProvider);
    } catch (e) {
      setState(() => _error = 'Could not save your answer. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(consentStatusProvider);
    // A failed check (e.g. offline) doesn't lock anyone out; it asks
    // again next time.
    if (status.value?.isComplete == true || status.hasError) return widget.child;
    if (status.isLoading) return const Scaffold(body: AjwLoadingView());

    return standaloneScreen('consent', _ConsentScreen(
      termsAndPrivacy: _termsAndPrivacy,
      transfer: _transfer,
      adult: _adult,
      programmeEmails: _programmeEmails,
      saving: _saving,
      error: _error,
      onTermsAndPrivacy: (v) => setState(() => _termsAndPrivacy = v),
      onTransfer: (v) => setState(() => _transfer = v),
      onAdult: (v) => setState(() => _adult = v),
      onProgrammeEmails: (v) => setState(() => _programmeEmails = v),
      onAccept: _accept,
    ));
  }
}

class _ConsentScreen extends ConsumerWidget {
  const _ConsentScreen({
    required this.termsAndPrivacy,
    required this.transfer,
    required this.adult,
    required this.programmeEmails,
    required this.saving,
    required this.error,
    required this.onTermsAndPrivacy,
    required this.onTransfer,
    required this.onAdult,
    required this.onProgrammeEmails,
    required this.onAccept,
  });
  final bool termsAndPrivacy;
  final bool transfer;
  final bool adult;
  final bool programmeEmails;
  final bool saving;
  final String? error;
  final ValueChanged<bool> onTermsAndPrivacy;
  final ValueChanged<bool> onTransfer;
  final ValueChanged<bool> onAdult;
  final ValueChanged<bool> onProgrammeEmails;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget docLink(LegalDocument doc) => TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text('Read the ${doc.title}'),
          onPressed: () => launchUrl(Uri.parse(doc.url), mode: LaunchMode.externalApplication),
        );
    final allRequired = termsAndPrivacy && transfer && adult;
    final canAccept = allRequired && !saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Your data and privacy')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Before you continue, please read how the AJW Business Advancement and Growth Services (BAGS) '
                  'Portal uses your information, and the rules for using it.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: Space.lg),
                for (final (heading, body) in PrivacyNotice.summary) ...[
                  Text(heading, style: text.titleSmall),
                  const SizedBox(height: Space.xs),
                  Text(body, style: text.bodyMedium),
                  const SizedBox(height: Space.md),
                ],
                Wrap(
                  spacing: Space.sm,
                  children: [
                    docLink(LegalDocuments.termsOfService),
                    docLink(LegalDocuments.privacyPolicy),
                    docLink(LegalDocuments.dataProtectionNotice),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text('Required', style: text.titleSmall),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: termsAndPrivacy,
                  onChanged: (v) => onTermsAndPrivacy(v ?? false),
                  title: Text(
                    'I agree to the Terms of Service (version ${LegalDocuments.termsOfService.version}) and '
                    'I have read the Privacy Policy (version ${LegalDocuments.privacyPolicy.version}).',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: transfer,
                  onChanged: (v) => onTransfer(v ?? false),
                  title: const Text(
                    'I consent to my personal data, including sensitive personal data such as property and '
                    "family details, being stored and processed outside Kenya by the portal's service providers "
                    '(Supabase in the European Union, and Google), with the safeguards described in the '
                    'Privacy Policy.',
                  ),
                  subtitle: const Text(
                    'Section 49 of the Kenya Data Protection Act, 2019 requires this consent. The portal cannot '
                    'run without these providers. You can withdraw it at any time by asking for your data to be '
                    'deleted in Settings and privacy.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: adult,
                  onChanged: (v) => onAdult(v ?? false),
                  title: const Text('I am 18 years old or older.'),
                ),
                const SizedBox(height: Space.sm),
                Text('Optional', style: text.titleSmall),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: programmeEmails,
                  onChanged: (v) => onProgrammeEmails(v ?? false),
                  title: const Text('Send me programme news and updates by email.'),
                  subtitle: const Text('You can change this at any time in Settings and privacy.'),
                ),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.md,
                  runSpacing: Space.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: saving ? null : () => ref.read(authRepositoryProvider).signOut(),
                      child: const Text("Don't agree and sign out"),
                    ),
                    FilledButton(
                      onPressed: canAccept ? onAccept : null,
                      child: saving ? const AjwLoader(dotSize: 6) : const Text('Agree and continue'),
                    ),
                  ],
                ),
                if (!allRequired) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'Tick all three required boxes to continue.',
                    style: text.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: Space.md),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
