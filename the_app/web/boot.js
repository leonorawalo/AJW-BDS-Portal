// Runs first on the app page (web/index.html), as a file rather than an
// inline script so the Content-Security-Policy can forbid inline scripts
// (firebase.json, docs/security/SECURITY.md).

// Old-style links (/#/set-password?..., /#/admin/users) become clean
// addresses (/set-password?..., /admin/users) before the app starts,
// so invite and reset emails keep working. The emails keep the #/ form
// on purpose: what follows # is never sent to any server, which is the
// safe place for a one-time token. See DO_NOT_BREAK.md section 3.
(function () {
  var h = window.location.hash;
  if (h.indexOf('#/') === 0) {
    window.history.replaceState(null, '', h.slice(1));
  }
})();

// Remove the old Flutter service worker that kept a stale copy of the
// app in the browser. If this page was served by it, reload once so
// the current version loads (no loop: after unregistering there is no
// controller any more). See DO_NOT_BREAK.md section 5.
(function () {
  if (!('serviceWorker' in navigator)) return;
  var servedByWorker = !!navigator.serviceWorker.controller;
  navigator.serviceWorker.getRegistrations().then(function (regs) {
    return Promise.all(regs.map(function (r) { return r.unregister(); }));
  }).then(function () {
    if (!window.caches) return;
    return caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k.indexOf('flutter') === 0; })
        .map(function (k) { return caches.delete(k); }));
    });
  }).then(function () {
    if (servedByWorker) window.location.reload();
  });
})();
