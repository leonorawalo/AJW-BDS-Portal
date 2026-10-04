/// What a loan would actually pay for. A bank asks this specifically
/// ("business growth" is the programme's goal, not a loan purpose), so the
/// facts card offers these choices. Stored as plain text in
/// `enterprises.loan_purpose`: one of [loanPurposes], or the owner's own
/// words when "Other" was chosen (older free-text values read as Other).
const loanPurposes = [
  'Stock or working capital',
  'Equipment or machinery',
  'Premises, renovation or expansion',
  'Vehicle or transport',
];

const loanPurposeOther = 'Other';

/// The dropdown choice for a stored value: one of [loanPurposes],
/// [loanPurposeOther] for anything else, or null when not set.
String? loanPurposeChoice(String? stored) {
  final v = stored?.trim() ?? '';
  if (v.isEmpty) return null;
  return loanPurposes.contains(v) ? v : loanPurposeOther;
}
