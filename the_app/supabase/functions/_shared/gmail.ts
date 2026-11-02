// Plain-text Gmail messages, sent as the signed-in user through their
// own Google connection (gmail.send scope). Used by gmail-send and by
// manage-users (deletion confirmations).

export function base64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

const utf8 = (s: string) => new TextEncoder().encode(s);
export const base64Url = (s: string) => base64(utf8(s)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/// A plain-text RFC 2822 message. Subject is RFC 2047 encoded and the body
/// base64 so any language / emoji survives. No From header: Gmail sets it
/// to the sender's own address.
export function buildMessage(to: string[], subject: string, body: string): string {
  const encodedBody = base64(utf8(body)).replace(/.{76}/g, '$&\r\n');
  return [
    `To: ${to.join(', ')}`,
    `Subject: =?UTF-8?B?${base64(utf8(subject))}?=`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset="UTF-8"',
    'Content-Transfer-Encoding: base64',
    '',
    encodedBody,
  ].join('\r\n');
}

/// Sends [body] as the user whose Google [token] this is. Throws on failure.
export async function sendGmail(token: string, to: string[], subject: string, body: string): Promise<string> {
  const res = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ raw: base64Url(buildMessage(to, subject, body)) }),
  });
  const result = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`Gmail send failed: ${res.status} ${result.error?.message ?? res.statusText}`);
  return result.id as string;
}
