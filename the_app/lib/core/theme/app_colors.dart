import 'package:flutter/material.dart';

/// AJW brand palette — sampled directly from the pixel data of the
/// official AJW Africa logo file (not estimated from a screenshot).
/// If the logo is ever re-exported, re-sample and update here; every
/// other file in the app reads colors from this one.
///
/// Deliberate design rule (locked decision, see project ERD notes):
/// [brandRed] is reserved for identity — logo, primary buttons, active
/// nav states. [errorRed] is a distinctly different red — brighter and
/// more orange-leaning — reserved strictly for errors and "Overdue"
/// status, so a user never mistakes a branded element for a warning.
class AppColors {
  AppColors._();

  // --- Brand identity ---
  // charcoal/lightGray are exact logo pixel values. brandRed is
  // deliberately deepened from the logo's flat red (#D13B3B) into a
  // wine/maroon tone for UI use — richer, more "classy operations tool,"
  // and puts real distance between it and errorRed so the two never
  // read as the same color doing different jobs. The logo image itself
  // still shows its original flat red; this only affects buttons/links.
  static const brandRed = Color(0xFF7A1F2B);
  static const charcoal = Color(0xFF494949);
  static const lightGray = Color(0xFFB2B2B2);

  // --- Semantic (deliberately distinct from brandRed — see note above) ---
  static const errorRed = Color(0xFFFF3B30);
  static const successGreen = Color(0xFF2E7D32);
  static const pendingAmber = Color(0xFFF9A825);

  // --- Neutrals derived from the charcoal/gray pair, for surfaces/text ---
  static const surfaceLight = Color(0xFFF7F7F7);
  static const textOnLight = charcoal;
  static const textMuted = Color(0xFF6B6B6E);

  // --- Chart series (multi-line/bar data only — not brand/status colors) ---
  // AJW's brand palette only has one identity hue (brandRed) plus the
  // status triad above, so it can't supply two CVD-safe, mutually
  // distinguishable series for a 2-line trend chart on its own — a
  // brandRed/charcoal pairing was tried and failed automated CVD
  // validation (deutan ΔE 4.9, normal-vision ΔE 12.5, both below the
  // ≥15 floor). These are slots 1–2 of the dataviz skill's validated
  // default categorical palette instead (worst adjacent CVD ΔE 9.1
  // light-mode, normal-vision ΔE 19.6 — both clear their floors).
  static const chartSeriesOne = Color(0xFF2A78D6); // blue
  static const chartSeriesTwo = Color(0xFFEB6834); // orange
}