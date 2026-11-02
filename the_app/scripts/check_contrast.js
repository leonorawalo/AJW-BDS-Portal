#!/usr/bin/env node
// Colour contrast check (WCAG 2.1 AA) for the portal's theme. Reads the
// colours from lib/core/theme/app_colors.dart and lib/core/theme/
// dashboard_palette.dart, so it checks what the app really uses.
//
//   node scripts/check_contrast.js        prints every pair; exit 1 on a failure
//
// Required: 4.5:1 for normal text, 3:1 for large text (24 px, or 18.7 px
// bold) and for icons, focus rings and other meaningful graphics.
// Results are recorded in docs/security/SECURITY_CHECKLIST.md (E16).

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'lib/core/theme/app_colors.dart'), 'utf8');

const named = {};
for (const m of src.matchAll(/static const (\w+) = Color\(0x([0-9A-Fa-f]{8})\);/g)) named[m[1]] = m[2].slice(2);
const list = (name) => {
  const block = new RegExp(`static const ${name} = <Color>\\[([\\s\\S]*?)\\];`).exec(src);
  if (!block) throw new Error(`app_colors.dart: list ${name} not found`);
  return [...block[1].matchAll(/Color\(0x([0-9A-Fa-f]{8})\)/g)].map((m) => m[1].slice(2));
};

const palette = fs.readFileSync(path.join(root, 'lib/core/theme/dashboard_palette.dart'), 'utf8');
const gradients = {};
for (const m of palette.matchAll(/static const (\w+) = DashboardPalette\(\s*gradient: \[([^\]]*)\]/g)) {
  gradients[m[1]] = m[2].split(',').map((t) => t.trim()).filter(Boolean).map((t) => {
    const lit = /Color\(0x([0-9A-Fa-f]{8})\)/.exec(t);
    if (lit) return lit[1].slice(2);
    const ref = /AppColors\.(\w+)/.exec(t);
    if (ref && named[ref[1]]) return named[ref[1]];
    throw new Error(`dashboard_palette.dart: can't read colour ${t}`);
  });
}

const WHITE = 'FFFFFF';
function lum(hex) {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function ratio(a, b) {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}

const c = (n) => {
  if (!named[n]) throw new Error(`app_colors.dart: ${n} not found`);
  return named[n];
};
const checks = [];
const text = (label, fg, bg) => checks.push({ label, fg, bg, need: 4.5 });
const graphic = (label, fg, bg) => checks.push({ label, fg, bg, need: 3 });

for (const bg of ['canvas', 'surface', 'surfaceSunken']) {
  text(`charcoal text on ${bg}`, c('charcoal'), c(bg));
  text(`charcoalSoft (secondary text) on ${bg}`, c('charcoalSoft'), c(bg));
}
text('brandRedDeep text buttons on surface', c('brandRedDeep'), c('surface'));
text('brandRedDeep text buttons on canvas', c('brandRedDeep'), c('canvas'));
text('brandRed tab labels on surface', c('brandRed'), c('surface'));
text('white on brandRed (filled buttons)', WHITE, c('brandRed'));
text('brandRedDeep on brandRedTint (selected menu item)', c('brandRedDeep'), c('brandRedTint'));
text('errorRed on surface', c('errorRed'), c('surface'));
text('successGreen on surface', c('successGreen'), c('surface'));
graphic('pendingAmber icons/rings on surface', c('pendingAmber'), c('surface'));
graphic('notDoneMark (not-done ticks) on surface', c('notDoneMark'), c('surface'));
graphic('focus ring / input underline (brandRed) on surfaceSunken', c('brandRed'), c('surfaceSunken'));
for (const [d, tint] of [['legalTeal', 'legalTealTint'], ['accountingAmber', 'accountingAmberTint'], ['marketingViolet', 'marketingVioletTint']]) {
  text(`${d} on surface`, c(d), c('surface'));
  text(`${d} on ${tint}`, c(d), c(tint));
}
for (const hex of list('personalPalette')) text(`white initials on avatar #${hex}`, WHITE, hex);
for (const hex of list('marketingPalette')) text(`white on marketing card #${hex}`, WHITE, hex);
for (const [name, stops] of Object.entries(gradients)) {
  for (const hex of stops) text(`white banner text on ${name} gradient stop #${hex}`, WHITE, hex);
}
// The website's own pages (web/legal.css, web/cookie-consent.js).
text('web: links #D13B3B on white card', 'D13B3B', WHITE);
text('web: muted text #6B6B6E on page #F7F5F3', '6B6B6E', 'F7F5F3');
text('web: cookie banner links #A32B2B on white', 'A32B2B', WHITE);
text('web: cookie banner small text #5A5A5A on white', '5A5A5A', WHITE);

let failed = 0;
for (const k of checks) {
  const r = ratio(k.fg, k.bg);
  const ok = r >= k.need;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${r.toFixed(2).padStart(5)}:1 (needs ${k.need})  ${k.label}`);
}
console.log(failed ? `\n${failed} pair(s) below WCAG 2.1 AA.` : `\nAll ${checks.length} pairs meet WCAG 2.1 AA.`);
process.exit(failed ? 1 : 0);
