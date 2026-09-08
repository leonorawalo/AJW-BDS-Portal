import 'package:flutter/material.dart';

/// AJW brand palette, sampled from the AJW Africa logo/website
/// (ajwafrica.org). Values below are a first-pass visual estimate —
/// swap in exact hex codes once available from the original logo file
/// (a designer or brand guide can pull these precisely; this file is
/// the only place that needs updating).
///
/// Deliberate design rule (locked decision, see project ERD notes):
/// [brandRed] is reserved for identity — logo, primary buttons, active
/// nav states. [errorRed] is a different, more saturated red reserved
/// strictly for errors and "Overdue" status. The two must stay visually
/// distinct so a user never confuses "this is a branded button" with
/// "something went wrong."
class AppColors {
  AppColors._();

  // --- Brand identity ---
  static const brandRed = Color(0xFFB3352B);
  static const charcoal = Color(0xFF2B2B2E);
  static const lightGray = Color(0xFFB0B0B0);

  // --- Semantic (never brandRed) ---
  static const errorRed = Color(0xFFE53935);
  static const successGreen = Color(0xFF2E7D32);
  static const pendingAmber = Color(0xFFF9A825);

  // --- Neutrals derived from the charcoal/gray pair, for surfaces/text ---
  static const surfaceLight = Color(0xFFF7F7F7);
  static const textOnLight = charcoal;
  static const textMuted = Color(0xFF6B6B6E);
}