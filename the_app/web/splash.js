// Hides the loading screen (#ajw-splash in web/index.html) on Flutter's
// first frame. A file, not an inline script: see web/boot.js.
(function () {
  var splash = document.getElementById('ajw-splash');
  var slow = setTimeout(function () {
    document.getElementById('ajw-splash-slow').style.visibility = 'visible';
  }, 15000);
  window.addEventListener('flutter-first-frame', function () {
    clearTimeout(slow);
    splash.classList.add('hide');
    setTimeout(function () { splash.remove(); }, 400);
  }, { once: true });
})();
