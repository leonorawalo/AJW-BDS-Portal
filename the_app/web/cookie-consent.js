// Cookie banner for the portal's website (the Flutter app page and the
// public pages). Policy: legal/cookie-policy.md (web/cookies.html).
//
// Today the portal stores only strictly necessary items, so the choice
// changes nothing that loads. The banner is still shown so people know,
// and so anything non-essential added later can only start through
// ajwCookieConsent.whenAllowed('functional' | 'analytics', fn).
//
// - Shown on the first visit, and again whenever POLICY_VERSION changes
//   (scripts/build_legal.js keeps it equal to the cookie policy's version).
// - "Accept all", "Reject non-essential" and "Customise" look the same.
// - Reopened from any element with data-cookie-settings, or from the
//   app's sign-in screen (ajwCookieConsent.open()).
(function () {
  'use strict';
  var POLICY_VERSION = '1.0';
  var KEY = 'ajw-cookie-consent';
  var CATEGORIES = [
    { id: 'necessary', label: 'Strictly necessary', locked: true,
      text: 'Keeps you signed in and remembers this choice. Always on.' },
    { id: 'functional', label: 'Functional',
      text: 'Would remember optional preferences. None are used today.' },
    { id: 'analytics', label: 'Analytics',
      text: 'Would measure how the portal is used. None are used today.' },
  ];
  var waiting = [];
  var root = null;

  function read() {
    try {
      var v = JSON.parse(window.localStorage.getItem(KEY) || 'null');
      return v && v.version === POLICY_VERSION ? v : null;
    } catch (e) {
      return null;
    }
  }

  function save(choice) {
    var record = {
      version: POLICY_VERSION,
      functional: !!choice.functional,
      analytics: !!choice.analytics,
      at: new Date().toISOString(),
    };
    try {
      window.localStorage.setItem(KEY, JSON.stringify(record));
    } catch (e) { /* private mode: ask again next visit */ }
    close();
    var still = [];
    waiting.forEach(function (w) {
      if (record[w.category]) w.fn(); else still.push(w);
    });
    waiting = still;
    try {
      window.dispatchEvent(new CustomEvent('ajw-cookie-consent', { detail: record }));
    } catch (e) { /* old browser */ }
  }

  function allows(category) {
    if (category === 'necessary') return true;
    var v = read();
    return !!(v && v[category]);
  }

  function whenAllowed(category, fn) {
    if (allows(category)) fn(); else waiting.push({ category: category, fn: fn });
  }

  function style() {
    if (document.getElementById('ajw-cc-style')) return;
    var s = document.createElement('style');
    s.id = 'ajw-cc-style';
    s.textContent =
      '#ajw-cc{position:fixed;left:16px;right:16px;bottom:16px;z-index:10000;max-width:640px;margin:0 auto;' +
      'background:#fff;color:#2b2b2b;border:1px solid #b2b2b2;border-radius:12px;box-shadow:0 8px 28px rgba(0,0,0,.18);' +
      'padding:16px 18px;font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}' +
      '#ajw-cc h2{font-size:17px;margin:0 0 6px}#ajw-cc p{margin:0 0 12px}#ajw-cc a{color:#a32b2b}' +
      '#ajw-cc .row{display:flex;flex-wrap:wrap;gap:8px}' +
      '#ajw-cc button{flex:1 1 160px;min-height:44px;padding:8px 14px;border-radius:10px;border:2px solid #494949;' +
      'background:#fff;color:#2b2b2b;font:600 15px/1.2 inherit;cursor:pointer}' +
      '#ajw-cc button:hover{background:#f2f2f2}' +
      '#ajw-cc button:focus-visible,#ajw-cc input:focus-visible{outline:3px solid #1a5fb4;outline-offset:2px}' +
      '#ajw-cc fieldset{border:0;margin:0 0 12px;padding:0}#ajw-cc label{display:flex;gap:10px;align-items:flex-start;margin:8px 0}' +
      '#ajw-cc input{width:20px;height:20px;margin-top:2px;flex:none}#ajw-cc small{display:block;color:#5a5a5a}' +
      '#ajw-cc .visually-hidden{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}';
    document.head.appendChild(s);
  }

  function el(tag, attrs, text) {
    var e = document.createElement(tag);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (text) e.textContent = text;
    return e;
  }

  function button(label, onClick) {
    var b = el('button', { type: 'button' }, label);
    b.addEventListener('click', onClick);
    return b;
  }

  function close() {
    if (root) root.remove();
    root = null;
  }

  function open(customise) {
    style();
    close();
    var current = read() || { functional: false, analytics: false };
    root = el('section', { id: 'ajw-cc', role: 'dialog', 'aria-modal': 'false', 'aria-labelledby': 'ajw-cc-title' });
    root.appendChild(el('h2', { id: 'ajw-cc-title' }, 'Cookies and browser storage'));
    var p = el('p', {});
    p.appendChild(document.createTextNode(
      'The portal sets no cookies and uses no analytics or advertising. It only keeps what it needs to sign you in. '));
    var link = el('a', { href: '/cookies.html' }, 'Read the Cookie Policy');
    p.appendChild(link);
    p.appendChild(document.createTextNode('.'));
    root.appendChild(p);

    if (customise) {
      var fs = el('fieldset', {});
      fs.appendChild(el('legend', { class: 'visually-hidden' }, 'Choose what the portal may store'));
      var boxes = {};
      CATEGORIES.forEach(function (c) {
        var label = el('label', {});
        var box = el('input', { type: 'checkbox', name: c.id });
        box.checked = c.locked ? true : !!current[c.id];
        if (c.locked) box.disabled = true;
        boxes[c.id] = box;
        var span = el('span', {}, c.label);
        span.appendChild(el('small', {}, c.text));
        label.appendChild(box);
        label.appendChild(span);
        fs.appendChild(label);
      });
      root.appendChild(fs);
      var row = el('div', { class: 'row' });
      row.appendChild(button('Save my choices', function () {
        save({ functional: boxes.functional.checked, analytics: boxes.analytics.checked });
      }));
      row.appendChild(button('Reject non-essential', function () { save({}); }));
      root.appendChild(row);
    } else {
      var actions = el('div', { class: 'row' });
      actions.appendChild(button('Accept all', function () { save({ functional: true, analytics: true }); }));
      actions.appendChild(button('Reject non-essential', function () { save({}); }));
      actions.appendChild(button('Customise', function () { open(true); }));
      root.appendChild(actions);
    }
    document.body.appendChild(root);
    root.addEventListener('keydown', function (e) {
      // Escape closes only a reopened panel; a first-visit banner stays
      // until a choice is made (it never blocks the page behind it).
      if (e.key === 'Escape' && read()) close();
    });
    if (customise) {
      var first = root.querySelector('input:not([disabled]), button');
      if (first) first.focus();
    }
  }

  window.ajwCookieConsent = { allows: allows, whenAllowed: whenAllowed, open: function () { open(true); } };

  function start() {
    document.addEventListener('click', function (e) {
      var t = e.target && e.target.closest ? e.target.closest('[data-cookie-settings]') : null;
      if (t) {
        e.preventDefault();
        open(true);
      }
    });
    if (!read()) open(false);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
