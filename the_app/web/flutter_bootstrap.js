{{flutter_js}}
{{flutter_build_config}}

// Loaded WITHOUT Flutter's service worker (deprecated by Flutter). It kept
// an offline copy of the app in each browser, so people could see an old
// version for a while after a deploy. index.html also removes any worker a
// browser installed before. See DO_NOT_BREAK.md section 5.
_flutter.loader.load();
