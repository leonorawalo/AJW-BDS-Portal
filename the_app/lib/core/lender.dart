/// The bank the programme prepares enterprises for. THE ONE PLACE to name
/// a specific bank: leave [bankName] empty for generic wording ("the
/// bank", "Bank lending checklist"), or set it (e.g. 'Equity Bank') and
/// every screen, report, sheet and deck uses that name instead.
class Lender {
  Lender._();

  static const String bankName = '';

  /// Mid-sentence: "the bank" / "Equity Bank".
  static const String inSentence = bankName == '' ? 'the bank' : bankName;

  /// At the start of a heading or label: "Bank" / "Equity Bank".
  static const String inHeading = bankName == '' ? 'Bank' : bankName;

  static const String checklist = '$inHeading lending checklist';
  static const String checklistInSentence = bankName == '' ? 'bank lending checklist' : '$bankName lending checklist';
  static const String requirements = '$inHeading lending requirements';
}
