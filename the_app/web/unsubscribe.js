// web/unsubscribe.html: the link in an optional portal email. Unsubscribes
// at once (one click) through the email-unsubscribe Edge Function, then
// says so. Link checkers that only fetch the page don't run this, so they
// can't unsubscribe anyone.
(function () {
  var out = document.getElementById('result');
  var token = new URLSearchParams(window.location.search).get('token') || '';
  if (!token) {
    out.textContent = 'This unsubscribe link is incomplete. Open the link from the email again, or change your email preferences in the portal under Settings and privacy.';
    return;
  }
  fetch('https://cgnmnqjyvlgyndhmicjl.supabase.co/functions/v1/email-unsubscribe?token=' + encodeURIComponent(token), {
    method: 'POST',
  }).then(function (r) { return r.json(); }).then(function (res) {
    out.textContent = res.ok
      ? 'You are unsubscribed. You will no longer get programme news and updates by email. Emails about your account and security still arrive. You can subscribe again in the portal under Settings and privacy.'
      : (res.error || 'This unsubscribe link is not valid any more. You can change your email preferences in the portal under Settings and privacy.');
  }).catch(function () {
    out.textContent = 'We could not reach the portal. Check your connection and open the link again.';
  });
})();
