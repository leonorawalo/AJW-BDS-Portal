/// The signed-in user's Google Calendar connection, as exposed by the
/// get_my_google_connection() RPC — deliberately without the token,
/// which never leaves the Edge Functions.
class GoogleConnection {
  const GoogleConnection({required this.connectedAt, this.googleEmail});

  factory GoogleConnection.fromMap(Map<String, dynamic> map) => GoogleConnection(
        googleEmail: map['google_email'] as String?,
        connectedAt: DateTime.parse(map['connected_at'] as String),
      );

  final String? googleEmail;
  final DateTime connectedAt;
}
