import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's typefaces, by role. THE ONLY PLACE (with pubspec.yaml) that
/// names font families or font weights.
///
/// The AJW Brand Guideline's typefaces (Henderson Sans headers, Jeko
/// sub-headers, Ambit body) have no confirmed web/app licence, so the app
/// uses the designer's approved free substitutes from the brand folder
/// ("Fonts available on Google", SIL Open Font License):
///   Henderson Sans -> Poppins, Jeko -> Livvic, Ambit -> Work Sans.
/// To switch back once AJW holds web/app licences: change the families,
/// weights and [headerTracking] below and the `fonts:` block in
/// pubspec.yaml. See DO_NOT_BREAK.md section 8.
class AppFonts {
  AppFonts._();

  static const header = 'Poppins';
  static const subheader = 'Livvic';
  static const body = 'WorkSans';

  static const headerWeight = FontWeight.w700;
  static const subheaderWeight = FontWeight.w500;
  static const bodyRegular = FontWeight.w400;
  static const bodyStrong = FontWeight.w500;

  /// Extra letter spacing for headers. Henderson Sans is an extended face;
  /// Poppins is narrower, so a little tracking keeps the wide, open feel.
  static const headerTracking = 0.4;

  /// Work Sans runs wider than Ambit; slightly tighter tracking keeps text
  /// lines the same length as before.
  static const bodyTracking = -0.15;
}

/// Spacing scale. Use these instead of one-off numbers so gaps line up
/// across screens.
class Space {
  Space._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

class Radii {
  Radii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

const _colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.brandRed,
  onPrimary: Colors.white,
  primaryContainer: AppColors.brandRedTint,
  onPrimaryContainer: AppColors.brandRedDeep,
  secondary: AppColors.charcoal,
  onSecondary: Colors.white,
  secondaryContainer: AppColors.surfaceSunken,
  onSecondaryContainer: AppColors.charcoal,
  tertiary: Color(0xFF1F7A6D),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFDDF0EC),
  onTertiaryContainer: Color(0xFF0F4A42),
  error: AppColors.errorRed,
  onError: Colors.white,
  errorContainer: Color(0xFFFDECEA),
  onErrorContainer: Color(0xFF7A1A10),
  surface: AppColors.surface,
  onSurface: AppColors.charcoal,
  onSurfaceVariant: AppColors.charcoalSoft,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFBFAF9),
  surfaceContainer: AppColors.canvas,
  surfaceContainerHigh: AppColors.surfaceSunken,
  surfaceContainerHighest: Color(0xFFE9E5E1),
  outline: Color(0xFFCFC8C2),
  outlineVariant: AppColors.hairline,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF2F2D2C),
  onInverseSurface: Colors.white,
  inversePrimary: Color(0xFFF2A6A0),
  // No pink wash on raised surfaces: elevation is shown with shadow only.
  surfaceTint: Colors.transparent,
);

TextStyle _t(String family, double size, FontWeight weight, {double? height, double spacing = 0, Color? color}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: family == AppFonts.body ? spacing + AppFonts.bodyTracking : spacing,
      color: color ?? AppColors.charcoal,
    );

final _textTheme = TextTheme(
  // Henderson Sans is wide, so its sizes sit a step below Material's.
  displayLarge: _t(AppFonts.header, 44, AppFonts.headerWeight, height: 1.1, spacing: AppFonts.headerTracking),
  displayMedium: _t(AppFonts.header, 36, AppFonts.headerWeight, height: 1.1, spacing: AppFonts.headerTracking),
  displaySmall: _t(AppFonts.header, 30, AppFonts.headerWeight, height: 1.15, spacing: AppFonts.headerTracking),
  headlineLarge: _t(AppFonts.header, 26, AppFonts.headerWeight, height: 1.2, spacing: AppFonts.headerTracking),
  headlineMedium: _t(AppFonts.header, 22, AppFonts.headerWeight, height: 1.25, spacing: AppFonts.headerTracking),
  headlineSmall: _t(AppFonts.header, 19, AppFonts.headerWeight, height: 1.3, spacing: AppFonts.headerTracking),
  titleLarge: _t(AppFonts.subheader, 20, AppFonts.subheaderWeight, height: 1.3),
  titleMedium: _t(AppFonts.subheader, 16, AppFonts.subheaderWeight, height: 1.35),
  titleSmall: _t(AppFonts.subheader, 14, AppFonts.subheaderWeight, height: 1.35),
  bodyLarge: _t(AppFonts.body, 16, AppFonts.bodyRegular, height: 1.5),
  bodyMedium: _t(AppFonts.body, 14, AppFonts.bodyRegular, height: 1.45),
  bodySmall: _t(AppFonts.body, 12.5, AppFonts.bodyRegular, height: 1.4, color: AppColors.charcoalSoft),
  labelLarge: _t(AppFonts.body, 14, AppFonts.bodyStrong, height: 1.3, spacing: 0.1),
  labelMedium: _t(AppFonts.body, 12.5, AppFonts.bodyStrong, height: 1.3, spacing: 0.2),
  labelSmall: _t(AppFonts.body, 11, AppFonts.bodyStrong, height: 1.3, spacing: 0.4, color: AppColors.charcoalSoft),
);

final _roundedMd = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
const _buttonSize = Size(64, 48);
const _buttonPadding = EdgeInsets.symmetric(horizontal: Space.xl);

OutlineInputBorder _inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: color, width: width),
    );

final ThemeData ajwLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _colorScheme,
  fontFamily: AppFonts.body,
  textTheme: _textTheme,
  scaffoldBackgroundColor: AppColors.canvas,
  canvasColor: AppColors.canvas,
  dividerColor: AppColors.hairline,
  splashFactory: InkSparkle.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    },
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.charcoal,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    toolbarHeight: 64,
    titleSpacing: Space.lg,
    shape: const Border(bottom: BorderSide(color: AppColors.hairline)),
    titleTextStyle: _t(AppFonts.subheader, 18, AppFonts.subheaderWeight),
    iconTheme: const IconThemeData(color: AppColors.charcoal),
    actionsIconTheme: const IconThemeData(color: AppColors.charcoal),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: const BorderSide(color: AppColors.hairline),
    ),
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
    minVerticalPadding: Space.md,
    iconColor: AppColors.charcoalSoft,
    titleTextStyle: _t(AppFonts.body, 15, AppFonts.bodyStrong, height: 1.35),
    subtitleTextStyle: _t(AppFonts.body, 13, AppFonts.bodyRegular, height: 1.4, color: AppColors.charcoalSoft),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceSunken,
    contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
    border: _inputBorder(Colors.transparent),
    enabledBorder: _inputBorder(Colors.transparent),
    focusedBorder: _inputBorder(AppColors.brandRed, 1.6),
    errorBorder: _inputBorder(AppColors.errorRed),
    focusedErrorBorder: _inputBorder(AppColors.errorRed, 1.6),
    disabledBorder: _inputBorder(Colors.transparent),
    labelStyle: _t(AppFonts.body, 14, AppFonts.bodyRegular, color: AppColors.charcoalSoft),
    floatingLabelStyle: _t(AppFonts.body, 14, AppFonts.bodyStrong, color: AppColors.charcoal),
    hintStyle: _t(AppFonts.body, 14, AppFonts.bodyRegular, color: AppColors.charcoalSoft),
    helperStyle: _t(AppFonts.body, 12, AppFonts.bodyRegular, color: AppColors.charcoalSoft),
    errorStyle: _t(AppFonts.body, 12, AppFonts.bodyStrong, color: AppColors.errorRed),
    prefixIconColor: AppColors.charcoalSoft,
    suffixIconColor: AppColors.charcoalSoft,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.brandRed,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.surfaceSunken,
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: _roundedMd,
      textStyle: _t(AppFonts.body, 15, AppFonts.bodyStrong),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.brandRed,
      elevation: 1,
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: _roundedMd,
      textStyle: _t(AppFonts.body, 15, AppFonts.bodyStrong),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.charcoal,
      side: const BorderSide(color: Color(0xFFCFC8C2)),
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: _roundedMd,
      textStyle: _t(AppFonts.body, 15, AppFonts.bodyStrong),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brandRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      textStyle: _t(AppFonts.body, 14, AppFonts.bodyStrong),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.brandRed,
    foregroundColor: Colors.white,
    elevation: 2,
    highlightElevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    extendedTextStyle: _t(AppFonts.body, 15, AppFonts.bodyStrong),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceSunken,
    selectedColor: AppColors.brandRedTint,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    labelStyle: _t(AppFonts.body, 12.5, AppFonts.bodyStrong),
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
    titleTextStyle: _t(AppFonts.subheader, 20, AppFonts.subheaderWeight, height: 1.3),
    contentTextStyle: _t(AppFonts.body, 14.5, AppFonts.bodyRegular, height: 1.5),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF2F2D2C),
    contentTextStyle: _t(AppFonts.body, 14, AppFonts.bodyRegular, color: Colors.white),
    actionTextColor: const Color(0xFFF2A6A0),
    shape: _roundedMd,
    width: 480,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    textStyle: _t(AppFonts.body, 14, AppFonts.bodyRegular),
  ),
  menuTheme: const MenuThemeData(
    style: MenuStyle(surfaceTintColor: WidgetStatePropertyAll(Colors.transparent)),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(color: const Color(0xFF2F2D2C), borderRadius: BorderRadius.circular(Radii.sm)),
    textStyle: _t(AppFonts.body, 12.5, AppFonts.bodyRegular, color: Colors.white),
    waitDuration: const Duration(milliseconds: 400),
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: AppColors.brandRed,
    unselectedLabelColor: AppColors.charcoalSoft,
    indicatorColor: AppColors.brandRed,
    dividerColor: AppColors.hairline,
    labelStyle: _t(AppFonts.body, 14, AppFonts.bodyStrong),
    unselectedLabelStyle: _t(AppFonts.body, 14, AppFonts.bodyStrong),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
  drawerTheme: const DrawerThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.brandRed,
    linearTrackColor: AppColors.brandRedTint,
    circularTrackColor: Colors.transparent,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.charcoalSoft,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? AppColors.brandRed : AppColors.surfaceSunken,
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(_roundedMd),
      textStyle: WidgetStatePropertyAll(_t(AppFonts.body, 13.5, AppFonts.bodyStrong)),
    ),
  ),
  badgeTheme: const BadgeThemeData(backgroundColor: AppColors.brandRed, textColor: Colors.white),
);
