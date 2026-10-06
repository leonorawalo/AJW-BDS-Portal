/// Public pages on the portal's own site (web/*.html). One place, so the
/// app and the emails/messages it builds agree. See DO_NOT_BREAK.md
/// section 1.
class SiteLinks {
  SiteLinks._();
  static const site = 'https://portal.ajwafrica.org';
  static const download = '$site/download.html';
  static const about = '$site/about.html';
  static const privacy = '$site/privacy.html';
  static const terms = '$site/terms.html';

  /// The newest released Android build (web/android-latest.json), read by
  /// the app's update notice. Changed only when a new APK is released.
  static const androidLatest = '$site/android-latest.json';
}
