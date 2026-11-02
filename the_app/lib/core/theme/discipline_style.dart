import 'package:flutter/material.dart';

import '../../shared/models/user_profile.dart';
import 'app_colors.dart';

/// How each consultant discipline looks wherever the app shows it (task
/// groups, consultant dashboards). Colours come from [AppColors].
extension DisciplineStyle on ConsultantSpecialization {
  IconData get icon => switch (this) {
        ConsultantSpecialization.legal => Icons.gavel_rounded,
        ConsultantSpecialization.accounting => Icons.calculate_rounded,
        ConsultantSpecialization.marketing => Icons.campaign_rounded,
      };

  /// The discipline's single accent colour.
  Color get accent => switch (this) {
        ConsultantSpecialization.legal => AppColors.legalTeal,
        ConsultantSpecialization.accounting => AppColors.accountingAmber,
        ConsultantSpecialization.marketing => AppColors.marketingViolet,
      };

  /// A pale wash of [accent] for backgrounds and tab headers.
  Color get tint => switch (this) {
        ConsultantSpecialization.legal => AppColors.legalTealTint,
        ConsultantSpecialization.accounting => AppColors.accountingAmberTint,
        ConsultantSpecialization.marketing => AppColors.marketingVioletTint,
      };
}
