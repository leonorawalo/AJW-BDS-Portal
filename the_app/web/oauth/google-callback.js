// Google's OAuth redirect lands here, on AJW's own verified domain (Google
// verification requires redirect URIs on domains the developer owns, and
// supabase.co isn't one). Pass Google's result (code + state, or error)
// straight on to the google-oauth Edge Function, which validates the
// state and exchanges the code server-side. Nothing is stored or read here.
window.location.replace(
  'https://cgnmnqjyvlgyndhmicjl.supabase.co/functions/v1/google-oauth' + window.location.search
);
