import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' SIL Open Font Licence texts to Flutter's
/// licence page (Settings and privacy -> Credits and licences). The
/// package licences are added by Flutter itself. Loaded only when the
/// page opens. List of every asset and its licence: LICENSES_AND_CREDITS.md.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Poppins (font)', 'assets/fonts/OFL-Poppins.txt'),
      ('Livvic (font)', 'assets/fonts/OFL-Livvic.txt'),
      ('Work Sans (font)', 'assets/fonts/OFL-WorkSans.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(file));
    }
  });
}
