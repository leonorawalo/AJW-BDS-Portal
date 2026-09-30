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

if (problems.length > 0) {
  console.error('\nDO_NOT_BREAK check FAILED, deploy stopped:');
  for (const p of problems) console.error(`  - ${p}`);
  console.error('See DO_NOT_BREAK.md sections 1 and 5.\n');
  process.exit(1);
}

console.log('DO_NOT_BREAK check passed.');
