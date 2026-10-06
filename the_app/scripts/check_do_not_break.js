// Pre-deploy guard for DO_NOT_BREAK.md. Runs automatically before every
// `firebase deploy` of hosting (see "predeploy" in firebase.json) and fails
// the deploy if a section-1 file is missing, or if firebase.json would stop
// serving dotfiles (the app reads assets/.env at startup).
//
// Keep SECTION_1_FILES in sync with DO_NOT_BREAK.md section 1 and the "!"
// lines at the end of .gitignore.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

// Source files that must exist in the repo / working tree.
const SECTION_1_FILES = [
  'web/googlec7b934ad5a1b7fa7.html',
  'web/about.html',
  'web/privacy.html',
  'web/terms.html',
  'web/legal.css',
  'web/oauth/google-callback.html',
  'web/download.html',
  '.env',
  'supabase/config.toml',
];

// What those become in the built site that actually gets uploaded.
const BUILT_FILES = [
  'build/web/googlec7b934ad5a1b7fa7.html',
  'build/web/about.html',
  'build/web/privacy.html',
  'build/web/terms.html',
  'build/web/legal.css',
  'build/web/oauth/google-callback.html',
  'build/web/download.html',
  'build/web/assets/.env',
];

const problems = [];

for (const file of SECTION_1_FILES) {
  if (!fs.existsSync(path.join(root, file))) {
    problems.push(`Missing section-1 file: ${file}`);
  }
}

const pubspec = fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8');
if (!/^\s*-\s*\.env\s*$/m.test(pubspec)) {
  problems.push('pubspec.yaml no longer lists .env under flutter: assets:');
}

const firebase = JSON.parse(fs.readFileSync(path.join(root, 'firebase.json'), 'utf8'));
const ignore = (firebase.hosting && firebase.hosting.ignore) || [];
for (const pattern of ignore) {
  // Catches the Firebase default "**/.*" and variants like ".*" or "assets/.env".
  if (/(^|\/)\.(\*|env)/.test(pattern)) {
    problems.push(`firebase.json hosting.ignore hides dotfiles: "${pattern}"`);
  }
}

for (const file of BUILT_FILES) {
  if (!fs.existsSync(path.join(root, file))) {
    problems.push(`Not in the web build: ${file} (run flutter build web --release)`);
  }
}

// Commercial brand fonts (no confirmed web/app licence) must never ship.
// DO_NOT_BREAK.md section 8.
const commercialFont = /henderson|jeko|ambit/i;
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}
for (const file of [...walk(path.join(root, 'assets/fonts')), ...walk(path.join(root, 'build/web/assets'))]) {
  if (commercialFont.test(path.basename(file))) {
    problems.push(`Commercial font would be deployed: ${path.relative(root, file)}`);
  }
}
const fontAssets = pubspec.split('\n').filter((l) => /^\s*-\s*asset:\s*assets\/fonts\//.test(l));
if (fontAssets.some((l) => commercialFont.test(l))) {
  problems.push('pubspec.yaml fonts: still lists a commercial brand font');
}

// The portal's public address is https://portal.ajwafrica.org
// (DO_NOT_BREAK.md section 0). web.app stays served as a fallback, but no
// link the app, the pages or the emails hand out may point at it.
const SITE = 'https://portal.ajwafrica.org';
const siteLinks = fs.readFileSync(path.join(root, 'lib/core/site_links.dart'), 'utf8');
if (!siteLinks.includes(`static const site = '${SITE}';`)) {
  problems.push(`lib/core/site_links.dart: SiteLinks.site must be ${SITE}`);
}
for (const file of [...walk(path.join(root, 'lib')), ...walk(path.join(root, 'web'))]) {
  if (!/\.(dart|html|js|css|json)$/.test(file)) continue;
  if (fs.readFileSync(file, 'utf8').includes('ajwafrica-bags-portal.web.app')) {
    problems.push(`Old web.app address hard-coded in ${path.relative(root, file)} (use ${SITE})`);
  }
}

// The Android update notice compares the installed build with
// web/android-latest.json (DO_NOT_BREAK.md section 5). The app's own
// version constant must equal pubspec, and the published "latest" can't
// be newer than the code that exists.
const versionLine = /^version:\s*([0-9.]+)\+([0-9]+)\s*$/m.exec(pubspec);
const appVersion = fs.readFileSync(path.join(root, 'lib/core/app_version.dart'), 'utf8');
const constName = /appVersionName = '([^']+)'/.exec(appVersion);
const constBuild = /appBuildNumber = ([0-9]+)/.exec(appVersion);
if (!versionLine || !constName || !constBuild) {
  problems.push('Could not read the version from pubspec.yaml or lib/core/app_version.dart');
} else {
  if (constName[1] !== versionLine[1] || constBuild[1] !== versionLine[2]) {
    problems.push(
      `lib/core/app_version.dart (${constName[1]}+${constBuild[1]}) differs from pubspec.yaml (${versionLine[1]}+${versionLine[2]}): bump both`,
    );
  }
  const latestPath = path.join(root, 'web/android-latest.json');
  if (!fs.existsSync(latestPath)) {
    problems.push('Missing web/android-latest.json (the Android update notice reads it)');
  } else {
    const latest = JSON.parse(fs.readFileSync(latestPath, 'utf8'));
    if (latest.build > Number(versionLine[2])) {
      problems.push(`web/android-latest.json says build ${latest.build}, newer than the code (${versionLine[2]})`);
    }
  }
}

if (problems.length > 0) {
  console.error('\nDO_NOT_BREAK check FAILED, deploy stopped:');
  for (const p of problems) console.error(`  - ${p}`);
  console.error('See DO_NOT_BREAK.md sections 1 and 5.\n');
  process.exit(1);
}

console.log('DO_NOT_BREAK check passed.');
