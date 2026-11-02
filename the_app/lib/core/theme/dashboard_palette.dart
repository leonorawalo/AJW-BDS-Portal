import 'package:flutter/material.dart';

import '../../shared/models/user_profile.dart';
import 'app_colors.dart';

/// The colours of one role's dashboard: the greeting banner's gradient,
/// the stat cards' accents and whether the banner's decorative shapes
/// drift. Every value comes from [AppColors]; change a dashboard's look
/// here, nowhere else.
///
/// - Admin and Owner: AJW brand (red into charcoal).
/// - Legal: one accent, deep teal. Accounting: one accent, warm amber.
/// - Marketing: a lively multi-colour palette (doesn't have to be AJW's).
class DashboardPalette {
  const DashboardPalette({
    required this.gradient,
    required this.accents,
    required this.shapeColors,
  });

  /// Banner background, top-left to bottom-right. White text sits on it
  /// at >= 4.5:1 throughout.
  final List<Color> gradient;

  /// Stat card accents, used in turn. One colour = a single-accent
  /// dashboard.
  final List<Color> accents;

  /// The banner's floating shapes (drawn translucent).
  final List<Color> shapeColors;

  Color accentAt(int i) => accents[i % accents.length];

  static const brand = DashboardPalette(
    gradient: [AppColors.brandRedDeep, AppColors.brandRed, AppColors.charcoal],
    accents: [AppColors.brandRed, AppColors.charcoal, AppColors.successGreen, AppColors.brandRedDeep],
    shapeColors: [Colors.white, AppColors.brandRedTint],
  );

  static const legal = DashboardPalette(
    gradient: [AppColors.legalTealDeep, AppColors.legalTeal],
    accents: [AppColors.legalTeal],
    shapeColors: [Colors.white, AppColors.legalTealTint],
  );

  static const accounting = DashboardPalette(
    gradient: [Color(0xFF6B3F00), AppColors.accountingAmber],
    accents: [AppColors.accountingAmber],
    shapeColors: [AppColors.accountingAmberBright, AppColors.accountingAmberTint],
  );

  static const marketing = DashboardPalette(
    gradient: [Color(0xFF4A2C91), AppColors.marketingViolet, Color(0xFFC2185B)],
    accents: AppColors.marketingPalette,
    shapeColors: [Color(0xFFFFC857), Color(0xFF4DD0E1), Color(0xFFFF8A80), Colors.white],
  );

  static DashboardPalette forProfile(UserProfile? profile) {
    if (profile?.role != UserRole.consultant) return brand;
    return switch (profile?.specialization) {
      ConsultantSpecialization.legal => legal,
      ConsultantSpecialization.accounting => accounting,
      ConsultantSpecialization.marketing => marketing,
      null => brand,
    };
  }
}
