import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A person's initials on their own colour (picked from [AppColors.personalPalette]
/// by their id, so it's stable across sessions and devices). It's what makes
/// the app feel like theirs: the same colour follows them everywhere.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.id,
    required this.firstName,
    required this.lastName,
    this.radius = 16,
  });

  final String id;
  final String firstName;
  final String lastName;
  final double radius;

  String get initials {
    final a = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final b = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final both = '$a$b'.toUpperCase();
    return both.isEmpty ? '?' : both;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.personalColorFor(id),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.subheader,
          fontWeight: AppFonts.subheaderWeight,
          fontSize: radius * 0.8,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
