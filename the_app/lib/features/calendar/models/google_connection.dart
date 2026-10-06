/// The signed-in user's Google connection, as exposed by the
/// get_my_google_connection() RPC: deliberately without the token,
/// which never leaves the Edge Functions.
class GoogleConnection {
  const GoogleConnection({required this.connectedAt, this.googleEmail, this.scope});

  factory GoogleConnection.fromMap(Map<String, dynamic> map) => GoogleConnection(
        googleEmail: map['google_email'] as String?,
        connectedAt: DateTime.parse(map['connected_at'] as String),
        scope: map['scope'] as String?,
      );

  static const _freeBusyScope = 'https://www.googleapis.com/auth/calendar.freebusy';
  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const _gmailSendScope = 'https://www.googleapis.com/auth/gmail.send';

  final String? googleEmail;
  final DateTime connectedAt;

  /// Space-separated scopes Google granted at connect time.
  final String? scope;

  bool _has(String s) => (scope ?? '').split(' ').contains(s);

  bool get canCheckAvailability => _has(_freeBusyScope);
  bool get canExport => _has(_driveFileScope);
  bool get canSendEmail => _has(_gmailSendScope);

  /// Connected before availability checks / exports / email were added:
  /// needs to reconnect once to grant the newer permissions.
  bool get needsReconnect => !canCheckAvailability || !canExport || !canSendEmail;
}
