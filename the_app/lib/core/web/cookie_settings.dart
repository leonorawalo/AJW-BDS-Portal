import 'cookie_settings_stub.dart' if (dart.library.js_interop) 'cookie_settings_web.dart' as impl;

/// The website's cookie banner (web/cookie-consent.js) can be reopened
/// from the app. False on Android, which has no cookie banner.
bool get cookieSettingsAvailable => impl.available;

/// Reopens the cookie banner's "Customise" panel (web only).
void openCookieSettings() => impl.open();
