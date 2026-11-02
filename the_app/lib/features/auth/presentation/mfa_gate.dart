import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../shared/models/user_profile.dart';
import '../data/mfa_repository.dart';
import '../providers/auth_providers.dart';
import '../../../core/widgets/security_gates.dart';
import '../../../core/user_message.dart';

/// Roles that must use two-step verification: they can see every
/// enterprise (Admins) or their own business's identity documents
/// (Owners). Change it here only.
const mfaRequiredRoles = {UserRole.administrator, UserRole.enterpriseOwner};

final mfaRepositoryProvider = Provider<MfaRepository>((ref) => MfaRepository(ref.watch(supabaseClientProvider)));

enum _MfaStep { checking, ok, enrol, verify, unavailable }

/// Stands in front of the app for Admins and Owners until two-step
/// verification is done: first time, set up an authenticator app; every
/// sign-in after, enter its 6-digit code. Other roles pass straight
/// through. If two-step verification is switched off for the project
/// (Supabase dashboard), people are let in rather than locked out.
class MfaGate extends ConsumerStatefulWidget {
  const MfaGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MfaGate> createState() => _MfaGateState();
}

class _MfaGateState extends ConsumerState<MfaGate> {
  _MfaStep _step = _MfaStep.checking;
  String? _checkedFor;

  Future<void> _check(UserProfile profile) async {
    _checkedFor = profile.id;
    if (!mfaRequiredRoles.contains(profile.role)) {
      setState(() => _step = _MfaStep.ok);
      return;
    }
    final repo = ref.read(mfaRepositoryProvider);
    try {
      if (repo.needsCode) {
        setState(() => _step = _MfaStep.verify);
      } else if ((await repo.verifiedFactors()).isEmpty) {
        setState(() => _step = _MfaStep.enrol);
      } else {
        setState(() => _step = _MfaStep.ok);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MFA check failed: ${userMessage(e)}');
      setState(() => _step = _MfaStep.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    if (profile == null) return widget.child;
    if (_checkedFor != profile.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check(profile);
      });
    }
    return switch (_step) {
      _MfaStep.ok || _MfaStep.unavailable => widget.child,
      _MfaStep.checking => const Scaffold(body: AjwLoadingView()),
      _MfaStep.enrol => standaloneScreen('mfa-enrol', _EnrolScreen(onDone: () => setState(() => _step = _MfaStep.ok))),
      _MfaStep.verify => standaloneScreen('mfa-verify', _VerifyScreen(onDone: () => setState(() => _step = _MfaStep.ok))),
    };
  }
}

class _Frame extends ConsumerWidget {
  const _Frame({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
        decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
        onSubmitted: (_) => onSubmitted(),
      );
}

class _EnrolScreen extends ConsumerStatefulWidget {
  const _EnrolScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends ConsumerState<_EnrolScreen> {
  final _code = TextEditingController();
  AuthMFAEnrollResponse? _enrolment;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final e = await ref.read(mfaRepositoryProvider).startEnrolment();
      if (mounted) setState(() => _enrolment = e);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the set-up: ${userMessage(e)}');
    }
  }

  Future<void> _verify() async {
    final e = _enrolment;
    if (e == null || _code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(mfaRepositoryProvider).verify(e.id, _code.text);
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _error = "That code didn't match. Check the app and try the newest code.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totp = _enrolment?.totp;
    return _Frame(
      title: 'Set up two-step verification',
      children: [
        Text(
          'Your account can see sensitive business and identity documents, so it needs a second step at sign-in. '
          'Install an authenticator app (for example Google Authenticator or Microsoft Authenticator), then:',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Space.lg),
        if (totp == null && _error == null) const AjwLoadingView(),
        if (totp != null) ...[
          Text('1. Scan this code with the app', style: text.titleSmall),
          const SizedBox(height: Space.sm),
          Center(child: _QrCode(data: totp.uri, size: 200)),
          const SizedBox(height: Space.sm),
          if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('On this phone? Open the authenticator app'),
              onPressed: () => launchUrl(Uri.parse(totp.uri), mode: LaunchMode.externalApplication),
            ),
          Text("Can't scan? Enter this key in the app instead:", style: text.bodySmall),
          SelectableText(totp.secret, style: text.bodyMedium?.copyWith(fontFamily: 'monospace')),
          const SizedBox(height: Space.lg),
          Text('2. Enter the 6-digit code the app shows', style: text.titleSmall),
          const SizedBox(height: Space.sm),
          _CodeField(controller: _code, onSubmitted: _verify),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy ? const AjwLoader(dotSize: 6) : const Text('Turn on two-step verification'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          // Set-up couldn't even start (e.g. two-step verification is off
          // for the project): don't lock the person out; they're asked
          // again next sign-in.
          if (totp == null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton(onPressed: widget.onDone, child: const Text('Continue for now')),
          ],
        ],
      ],
    );
  }
}

class _VerifyScreen extends ConsumerStatefulWidget {
  const _VerifyScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<_VerifyScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(mfaRepositoryProvider);
      final factors = await repo.verifiedFactors();
      await repo.verify(factors.first.id, _code.text);
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _error = "That code didn't match. Check the app and try the newest code.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      title: 'Two-step verification',
      children: [
        Text('Enter the 6-digit code from your authenticator app.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Space.lg),
        _CodeField(controller: _code, onSubmitted: _verify),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy ? const AjwLoader(dotSize: 6) : const Text('Continue'),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: Space.lg),
        Text(
          'Lost your phone? Ask an AJW administrator to reset two-step verification for your account.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A QR code drawn from the barcode package's squares (no image file).
class _QrCode extends StatelessWidget {
  const _QrCode({required this.data, required this.size});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'QR code for your authenticator app',
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: CustomPaint(size: Size.square(size), painter: _QrPainter(data)),
        ),
      );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    for (final e in Barcode.qrCode().make(data, width: size.width, height: size.height)) {
      if (e is BarcodeBar && e.black) {
        canvas.drawRect(Rect.fromLTWH(e.left, e.top, e.width, e.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
