/// Phone numbers people type in many ways ("0712 345 678", "+254 712-345-678",
/// "254712345678"). The portal stores one form, +254712345678, so the same
/// number is never saved twice in different shapes (users.phone_number is
/// unique) and every number can be dialled from abroad.
class PhoneNumber {
  PhoneNumber._();

  /// Kenyan default: a local number starting with 0 gets +254.
  static const defaultCountryCode = '254';

  /// The stored form, or null if [input] isn't a plausible phone number.
  /// Empty input also gives null; callers treat that as "no number".
  static String? normalise(String input) {
    var s = input.replaceAll(RegExp(r'[\s\-().]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (s.startsWith('0')) {
      s = '+$defaultCountryCode${s.substring(1)}';
    } else if (s.startsWith(defaultCountryCode) && !s.startsWith('+')) {
      s = '+$s';
    } else if (!s.startsWith('+')) {
      return null;
    }
    // Same rule as the database (users_phone_number_format).
    if (!RegExp(r'^\+[0-9]{9,15}$').hasMatch(s)) return null;
    // Kenyan numbers are always +254 followed by 9 digits.
    if (s.startsWith('+$defaultCountryCode') && s.length != 13) return null;
    return s;
  }

  /// For display: "+254 712 345 678" for Kenyan numbers, otherwise as stored.
  static String display(String stored) {
    if (stored.startsWith('+$defaultCountryCode') && stored.length == 13) {
      final n = stored.substring(4);
      return '+$defaultCountryCode ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
    }
    return stored;
  }
}
