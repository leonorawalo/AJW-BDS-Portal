import 'package:flutter/material.dart';

/// AJW BAGS Portal colours. The three core brand colours come straight
/// from the AJW Brand Guideline (page 9, "The core brand colors"); every
/// other colour is a tint or shade built around them. Every other file
/// reads colours from here.
///
/// Rules:
/// - [brandRed] is identity: the logo, brand stripes, primary actions and
///   the active navigation state. White text on it is 4.8:1 (WCAG AA).
/// - [errorRed] is a deeper crimson, and errors always come with an icon
///   and a message, so an error is never signalled by colour alone and
///   can't be mistaken for a branded element.
/// - Personal colours ([personalPalette]) belong to people, not to AJW:
///   each user's avatar gets one, so the app feels like theirs while the
///   frame around it stays AJW.
class AppColors {
  AppColors._();

  // --- Core brand (AJW Brand Guideline p.9) ---
  static const brandRed = Color(0xFFD13B3B);
  static const charcoal = Color(0xFF494949);
  static const lightGray = Color(0xFFB2B2B2);

  // --- Tints / shades of the brand colours for UI states ---
  static const brandRedDeep = Color(0xFFA82E2E); // pressed, text on tints
  static const brandRedTint = Color(0xFFFBE9E7); // selected nav, soft badges
  static const charcoalSoft = Color(0xFF6E6A67); // secondary text (5.4:1 on canvas)

  // --- Surfaces: warm neutrals, so the greys feel personable, not cold ---
  static const canvas = Color(0xFFF7F5F3); // page background
  static const surface = Color(0xFFFFFFFF); // cards, sheets, dialogs
  static const surfaceSunken = Color(0xFFF0EDEA); // input fills, side menu
  static const hairline = Color(0xFFE6E1DD); // borders and dividers

  // --- Semantic ---
  static const errorRed = Color(0xFFB42318);
  static const successGreen = Color(0xFF2E7D32);
  // Was #F9A825 (1.97:1 on white): too pale for the score ring and icons.
  static const pendingAmber = Color(0xFF9A5B00); // 5.4:1 on white

  /// "Not done yet" ticks and dots. Light grey (2.1:1) was too faint for
  /// a mark that carries meaning; this is >= 3:1 on white and canvas.
  static const notDoneMark = Color(0xFF8C8782);

  // Kept for existing call sites.
  static const surfaceLight = canvas;
  static const textOnLight = charcoal;
  static const textMuted = charcoalSoft;

  /// One per person, picked from their user id (see [personalColorFor]).
  /// Muted, mid-tone hues chosen to sit well next to AJW red and
  /// charcoal; all carry white initials at >= 4.5:1.
  static const personalPalette = <Color>[
    Color(0xFF1F7A6D), // teal
    Color(0xFF3F51B5), // indigo
    Color(0xFF8E4585), // plum
    Color(0xFF2D6A9F), // ocean
    Color(0xFF5B7F2A), // olive
    Color(0xFFB0531E), // copper
    Color(0xFF6A4FB3), // violet
    Color(0xFF00707F), // petrol
  ];

  static Color personalColorFor(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return personalPalette[hash % personalPalette.length];
  }

  // --- Consultant disciplines (task groups and consultant dashboards) ---
  // One accent each for Legal and Accounting (no multi-colour palettes
  // there); Marketing gets the lively palette below. Text in these
  // colours is >= 4.5:1 on white and on its own tint.
  static const legalTeal = Color(0xFF0F6E6A);
  static const legalTealDeep = Color(0xFF094B48);
  static const legalTealTint = Color(0xFFE3F2F0);
  static const accountingAmber = Color(0xFF9A5B00);
  static const accountingAmberBright = Color(0xFFE59A1C);
  static const accountingAmberTint = Color(0xFFFFF3DD);
  static const marketingViolet = Color(0xFF6A3FC1);
  static const marketingVioletTint = Color(0xFFF0EAFB);

  /// Marketing dashboard: a deliberately lively palette (it doesn't have
  /// to follow AJW colours). White text on each is >= 4.5:1.
  static const marketingPalette = <Color>[
    Color(0xFF6A3FC1), // violet
    Color(0xFFC2185B), // magenta
    Color(0xFF00796B), // teal
    Color(0xFFBF360C), // tangerine
    Color(0xFF1565C0), // blue
  ];

  // --- Chart series (multi-line/bar data only: not brand/status colors) ---
  // AJW's brand palette only has one identity hue (brandRed) plus the
  // status triad above, so it can't supply two CVD-safe, mutually
  // distinguishable series for a 2-line trend chart on its own. These are
  // slots 1–2 of the dataviz skill's validated default categorical palette
  // (worst adjacent CVD ΔE 9.1 light-mode, normal-vision ΔE 19.6).
  static const chartSeriesOne = Color(0xFF2A78D6); // blue
  static const chartSeriesTwo = Color(0xFFEB6834); // orange
}
