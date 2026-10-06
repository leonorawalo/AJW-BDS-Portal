/// This build's version, the same as `version:` in pubspec.yaml (name+build).
/// Read by the Android update notice. scripts/check_do_not_break.js fails
/// the deploy if the two ever differ, so bump both together.
const appVersionName = '1.2.1';
const appBuildNumber = 4;
