#!/usr/bin/env node
// Builds the portal's public legal pages and the app/server copies of the
// business details from ONE editable place: the legal/ folder.
//
//   legal/business.json   AJW's registered name, address, contacts...
//   legal/*.md            one page each (front matter: title, page,
//                         version, last_updated, effective_date)
//
// Writes:
//   web/<page>                                    the public pages
//   web/cookie-consent.js                         (POLICY_VERSION line only)
//   lib/core/legal/legal_documents.dart           versions + links for the app
//   supabase/functions/_shared/business.ts        email footers
//
// Run after editing anything in legal/:   node scripts/build_legal.js
// The hosting predeploy runs it with --check, which fails (and writes
// nothing) if a generated file is out of date. See DO_NOT_BREAK.md 1.

const fs = require('fs');
const path = require('path');

let marked;
try {
  ({ marked } = require('marked'));
} catch {
  console.error('build_legal: the "marked" package is missing. Run "npm install" in the_app/ first.');
  process.exit(1);
}

const root = path.join(__dirname, '..');
const check = process.argv.includes('--check');
const SITE = 'https://portal.ajwafrica.org';

const business = JSON.parse(fs.readFileSync(path.join(root, 'legal', 'business.json'), 'utf8'));
delete business._comment;

// The payments switch (legal/payments.json). See its _comment.
const payments = JSON.parse(fs.readFileSync(path.join(root, 'legal', 'payments.json'), 'utf8'));
if (typeof payments.takesPayments !== 'boolean') throw new Error('legal/payments.json: "takesPayments" must be true or false');

const escapeHtml = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/// {{key}} -> the business detail. Unknown keys fail loudly.
function fillBusiness(text, file) {
  return text.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    if (!(key in business)) throw new Error(`${file}: unknown placeholder {{${key}}}`);
    return business[key];
  });
}

function parse(file) {
  const raw = fs.readFileSync(path.join(root, 'legal', file), 'utf8').replace(/\r\n/g, '\n');
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error(`${file}: missing front matter`);
  const meta = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^(\w+):\s*(.*)$/);
    if (kv) meta[kv[1]] = kv[2].replace(/^"(.*)"$/, '$1');
  }
  for (const key of ['title', 'page', 'version', 'last_updated']) {
    if (!meta[key]) throw new Error(`${file}: front matter needs "${key}"`);
  }
  return { file, meta, body: m[2] };
}

const longDate = (iso) =>
  new Date(`${iso}T00:00:00Z`).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });

const docs = fs
  .readdirSync(path.join(root, 'legal'))
  .filter((f) => f.endsWith('.md'))
  .sort()
  .map(parse);
const byPage = Object.fromEntries(docs.map((d) => [d.meta.page, d]));
for (const page of ['about.html', 'privacy.html', 'terms.html', 'cookies.html', 'refund.html', 'data-protection.html']) {
  if (!byPage[page]) throw new Error(`legal/: no document for ${page}`);
}

// Payments can't be switched on without a Refund Policy written for them,
// and the Refund Policy can't claim payments that don't exist.
{
  const covers = byPage['refund.html'].meta.covers_payments === 'true';
  if (covers !== payments.takesPayments) {
    throw new Error(
      payments.takesPayments
        ? 'legal/payments.json says the portal takes payments, but legal/refund-policy.md is not written for them '
          + '(covers_payments: "true"). Complete docs/compliance/COMPLIANCE_REGISTER.md section B first.'
        : 'legal/refund-policy.md says covers_payments: "true", but legal/payments.json says the portal takes no payments.',
    );
  }
}

const NAV = [
  ['about.html', 'About'],
  ['privacy.html', 'Privacy'],
  ['terms.html', 'Terms'],
];

function footerHtml() {
  const b = Object.fromEntries(Object.entries(business).map(([k, v]) => [k, escapeHtml(v)]));
  return `  <footer>
    <p>
      © ${b.tradingName} · <a href="about.html">About and contact</a> · <a href="privacy.html">Privacy Policy</a> ·
      <a href="terms.html">Terms of Service</a> · <a href="cookies.html">Cookie Policy</a> ·
      <a href="refund.html">Payments and Refund Policy</a> · <a href="data-protection.html">Data Protection Notice</a> ·
      <a href="#" data-cookie-settings>Cookie settings</a>
    </p>
    <p>${b.registeredName} · ${b.physicalAddress} ·
      <a href="mailto:${b.email}">${b.email}</a> · ${b.phone}</p>
  </footer>`;
}

function pageHtml(doc) {
  const { meta } = doc;
  const body = marked.parse(fillBusiness(doc.body, doc.file), { gfm: true });
  const nav = NAV.filter(([href]) => href !== meta.page)
    .map(([href, label]) => `        <a href="${href}">${label}</a>`)
    .join('\n');
  const subtitle = meta.subtitle
    ? `<p class="muted">${escapeHtml(meta.subtitle)}</p>`
    : `<p class="muted">Version ${escapeHtml(meta.version)} · Last updated: ${longDate(meta.last_updated)}` +
      (meta.effective_date ? ` · Effective: ${escapeHtml(meta.effective_date)}` : '') +
      '</p>';
  const browserTitle = meta.browser_title ?? meta.title;
  return `<!DOCTYPE html>
<!-- GENERATED from legal/${doc.file} by scripts/build_legal.js. Edit that file, not this one.${
    meta.draft === 'true' ? '\n     DRAFT: awaiting review by AJW\'s lawyer.' : ''
  } -->
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AJW BAGS Portal · ${escapeHtml(browserTitle)}</title>
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="stylesheet" href="legal.css">
  <script src="cookie-consent.js" defer></script>
</head>
<body>
  <a class="skip-link" href="#main">Skip to main content</a>
  <header>
    <div class="bar">
      <img src="assets/assets/images/ajw_logo.webp" alt="AJW Africa logo">
      <a class="name" href="about.html">AJW BAGS Portal</a>
      <nav aria-label="Site">
${nav}
        <a href="/">Sign in</a>
      </nav>
    </div>
  </header>
  <main id="main">
    <div class="card">
      <h1>${escapeHtml(meta.title)}</h1>
      ${subtitle}
${body.trim().replace(/^/gm, '      ')}
    </div>
  </main>
${footerHtml()}
</body>
</html>
`;
}

const dartString = (s) => `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;

function dartFile() {
  const docKey = {
    'privacy.html': 'privacyPolicy',
    'terms.html': 'termsOfService',
    'cookies.html': 'cookiePolicy',
    'refund.html': 'refundPolicy',
    'data-protection.html': 'dataProtectionNotice',
    'about.html': 'aboutAndContact',
  };
  const order = ['privacy.html', 'terms.html', 'data-protection.html', 'cookies.html', 'refund.html', 'about.html'];
  const lines = [];
  lines.push('// GENERATED by scripts/build_legal.js from legal/*.md and legal/business.json.');
  lines.push('// Do not edit: change the files in legal/ and run `node scripts/build_legal.js`.');
  lines.push('');
  lines.push('/// One public legal page on the portal\'s website.');
  lines.push('class LegalDocument {');
  lines.push('  const LegalDocument({required this.title, required this.url, required this.version, required this.lastUpdated});');
  lines.push('  final String title;');
  lines.push('  final String url;');
  lines.push('  final String version;');
  lines.push('');
  lines.push('  /// ISO date (yyyy-mm-dd).');
  lines.push('  final String lastUpdated;');
  lines.push('}');
  lines.push('');
  lines.push('class LegalDocuments {');
  lines.push('  LegalDocuments._();');
  for (const page of order) {
    const m = byPage[page].meta;
    lines.push('');
    lines.push(`  static const ${docKey[page]} = LegalDocument(`);
    lines.push(`    title: ${dartString(page === 'about.html' ? 'About and contact' : m.title)},`);
    lines.push(`    url: ${dartString(`${SITE}/${page}`)},`);
    lines.push(`    version: ${dartString(m.version)},`);
    lines.push(`    lastUpdated: ${dartString(m.last_updated)},`);
    lines.push('  );');
  }
  lines.push('');
  lines.push(`  static const all = [${order.map((p) => docKey[p]).join(', ')}];`);
  lines.push('}');
  lines.push('');
  lines.push('/// AJW Africa\'s business details (legal/business.json). Values in');
  lines.push('/// [BRACKETS] are placeholders AJW has not supplied yet.');
  lines.push('class BusinessDetails {');
  lines.push('  BusinessDetails._();');
  for (const [k, v] of Object.entries(business)) lines.push(`  static const ${k} = ${dartString(v)};`);
  lines.push('}');
  lines.push('');
  lines.push('/// Whether the portal takes, holds or pays out money (legal/payments.json).');
  lines.push('/// Any payment feature must be hidden unless this is true. It can only be');
  lines.push('/// true once the Refund Policy is written for payments (the build checks)');
  lines.push('/// and docs/compliance/COMPLIANCE_REGISTER.md section B is complete.');
  lines.push('class Payments {');
  lines.push('  Payments._();');
  lines.push(`  static const enabled = ${payments.takesPayments};`);
  lines.push('}');
  lines.push('');
  return lines.join('\n');
}

function tsFile() {
  return `// GENERATED by scripts/build_legal.js from legal/business.json.
// Do not edit: change legal/business.json and run \`node scripts/build_legal.js\`.

export const BUSINESS = ${JSON.stringify(business, null, 2)} as const;

/// Plain-text footer for every email the portal's server sends: AJW's
/// business details (required on essential emails too).
export function emailFooter(): string {
  return [
    '--',
    \`\${BUSINESS.registeredName} (\${BUSINESS.tradingName}) · \${BUSINESS.programmeName}\`,
    \`\${BUSINESS.physicalAddress}\`,
    \`\${BUSINESS.email} · \${BUSINESS.phone} · \${BUSINESS.website}\`,
  ].join('\\n');
}
`;
}

const outputs = new Map();
for (const doc of docs) outputs.set(path.join('web', doc.meta.page), pageHtml(doc));
outputs.set(path.join('lib', 'core', 'legal', 'legal_documents.dart'), dartFile());
outputs.set(path.join('supabase', 'functions', '_shared', 'business.ts'), tsFile());

const consentJsPath = path.join('web', 'cookie-consent.js');
const consentJs = fs.readFileSync(path.join(root, consentJsPath), 'utf8').replace(/\r\n/g, '\n');
const versionLine = /var POLICY_VERSION = '[^']*';/;
if (!versionLine.test(consentJs)) throw new Error(`${consentJsPath}: POLICY_VERSION line not found`);
outputs.set(consentJsPath, consentJs.replace(versionLine, `var POLICY_VERSION = '${byPage['cookies.html'].meta.version}';`));

// Hand-written pages that share the generated footer, between markers.
for (const page of ['download.html']) {
  const rel = path.join('web', page);
  const html = fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
  const block = /  <!-- legal-footer:start[^>]*-->\n[\s\S]*?  <!-- legal-footer:end -->/;
  if (!block.test(html)) throw new Error(`${rel}: legal-footer markers not found`);
  const footer = `  <!-- legal-footer:start (written by scripts/build_legal.js) -->\n${footerHtml()}\n  <!-- legal-footer:end -->`;
  outputs.set(rel, html.replace(block, () => footer));
}

const stale = [];
for (const [rel, content] of outputs) {
  const full = path.join(root, rel);
  const current = fs.existsSync(full) ? fs.readFileSync(full, 'utf8').replace(/\r\n/g, '\n') : null;
  if (current === content) continue;
  stale.push(rel);
  if (!check) {
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, content);
  }
}

if (check) {
  if (stale.length) {
    console.error('build_legal --check: out of date (run "node scripts/build_legal.js"):\n  ' + stale.join('\n  '));
    process.exit(1);
  }
  console.log('build_legal --check: legal pages and business details are up to date.');
} else {
  console.log(stale.length ? 'build_legal: wrote\n  ' + stale.join('\n  ') : 'build_legal: nothing to change.');
}
