import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/features/workshops/models/registration_list.dart';
import 'package:the_app/features/workshops/models/workshop.dart';

/// The workshop registration list saved for AJW's admins (ToR: "an excel
/// copy ... 5 days after each workshop") opens cleanly in Excel and can't
/// carry a spreadsheet formula.
void main() {
  final workshop = Workshop(
    id: 'w1',
    title: 'Onboarding: Kisumu, cohort 3',
    kind: 'Onboarding & induction',
    heldOn: DateTime(2026, 10, 5),
    createdBy: 'u1',
    attendeeCount: 3,
    location: 'AJW office, Kisumu',
  );
  const attendees = [
    WorkshopAttendee(id: 'a1', fullName: 'Achieng "Acha" Otieno', phone: '+254 712 345 678', businessName: 'Blue Farm'),
    WorkshopAttendee(id: 'a2', fullName: '=HYPERLINK("http://evil")', businessName: 'Café Zawadi'),
    WorkshopAttendee(id: 'a3', fullName: 'Juma Mwangi'),
  ];
  final list = RegistrationList(workshop, attendees);

  test('starts with a UTF-8 byte-order mark so Excel reads accents', () {
    final bytes = list.toBytes();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.skip(3).toList()), contains('Café Zawadi'));
  });

  test('a header row plus one row per attendee, CRLF line ends', () {
    final lines = list.toCsv().split('\r\n');
    expect(lines, hasLength(4));
    expect(lines.first, startsWith('"#","Full name","Phone","Business"'));
    expect(lines[3], '"3","Juma Mwangi","","","Onboarding: Kisumu, cohort 3","Onboarding & induction","2026-10-05","AJW office, Kisumu"');
  });

  test('quotes are doubled and commas stay inside their cell', () {
    expect(list.toCsv(), contains('"Achieng ""Acha"" Otieno"'));
    expect(list.toCsv(), contains('"AJW office, Kisumu"'));
  });

  test('a formula is kept as text; a phone number is left alone', () {
    final csv = list.toCsv();
    expect(csv, contains('"\'=HYPERLINK(""http://evil"")"'));
    expect(csv, contains('"+254 712 345 678"'));
  });

  test('file name is safe and dated', () {
    expect(list.fileName, 'Registration list - Onboarding Kisumu cohort 3 - 2026-10-05.csv');
  });
}
