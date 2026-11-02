import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get available => globalContext.has('ajwCookieConsent');

void open() => globalContext.getProperty<JSObject?>('ajwCookieConsent'.toJS)?.callMethod('open'.toJS);
