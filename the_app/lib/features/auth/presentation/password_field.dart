import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// The rules for choosing a password. Must match Supabase → Authentication →
/// Policies (min length 8; lowercase, uppercase, digits and symbols), so the
/// app never accepts something the server then rejects. See DO_NOT_BREAK.md
/// section 3.
class PasswordRules {
  PasswordRules._();

  /// Supabase's own symbol set for its "symbols" requirement.
  static const _symbols = r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~''';

  static final rules = <(String, bool Function(String))>[
    ('At least 8 characters', (p) => p.length >= 8),
    ('An uppercase letter', (p) => p.contains(RegExp(r'[A-Z]'))),
    ('A lowercase letter', (p) => p.contains(RegExp(r'[a-z]'))),
    ('A number', (p) => p.contains(RegExp(r'[0-9]'))),
    ('A special character, e.g. ! @ # ?', (p) => p.split('').any(_symbols.contains)),
  ];

  static bool allMet(String p) => rules.every((r) => r.$2(p));
}

/// A password field with a show/hide eye. With [showRules], a calm live
/// checklist under it ticks each rule as it's met, and validation requires
/// all of them (used when choosing a password, never on sign-in).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.showRules = false,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool showRules;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.showRules) widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: (value) {
        final v = value ?? '';
        if (widget.showRules && !PasswordRules.allMet(v)) {
          return 'Your password needs everything in the list below.';
        }
        return widget.validator?.call(value);
      },
    );
    if (!widget.showRules) return field;

    final text = Theme.of(context).textTheme;
    final value = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: Space.md),
        Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, test) in PasswordRules.rules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _RuleRow(label: label, met: test(value), style: text.bodySmall),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met, this.style});
  final String label;
  final bool met;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${met ? 'done' : 'not yet'}',
      excludeSemantics: true,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(met),
              size: 18,
              color: met ? AppColors.successGreen : AppColors.lightGray,
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: met ? AppColors.charcoal : AppColors.charcoalSoft),
            ),
          ),
        ],
      ),
    );
  }
}
