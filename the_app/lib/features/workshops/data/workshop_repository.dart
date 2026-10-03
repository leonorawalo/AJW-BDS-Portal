import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workshop.dart';

/// Workshops and their registration lists. RLS: the BDS team (Admins and
/// consultants) only.
class WorkshopRepository {
  WorkshopRepository(this._client);

  final SupabaseClient _client;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Workshop>> fetchAll() async {
    final rows = await _client.from('workshops').select('*, workshop_attendees(count)').order('held_on', ascending: false);
    return (rows as List).map((r) => Workshop.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Workshop?> fetchOne(String id) async {
    final row = await _client.from('workshops').select('*, workshop_attendees(count)').eq('id', id).maybeSingle();
    return row == null ? null : Workshop.fromMap(row);
  }

  Future<String> create({
    required String title,
    required String kind,
    required DateTime heldOn,
    String? location,
    String? notes,
  }) async {
    final row = await _client
        .from('workshops')
        .insert({
          'title': title,
          'kind': kind,
          'held_on': _date(heldOn),
          'location': (location ?? '').trim().isEmpty ? null : location!.trim(),
          'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> delete(String id) => _client.from('workshops').delete().eq('id', id);

  Future<void> setRegistrationSent(String id, bool sent) =>
      _client.from('workshops').update({'registration_sent_at': sent ? DateTime.now().toUtc().toIso8601String() : null}).eq('id', id);

  Future<List<WorkshopAttendee>> fetchAttendees(String workshopId) async {
    final rows = await _client.from('workshop_attendees').select().eq('workshop_id', workshopId).order('created_at');
    return (rows as List).map((r) => WorkshopAttendee.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addAttendee(String workshopId, {required String fullName, String? phone, String? businessName}) =>
      _client.from('workshop_attendees').insert({
        'workshop_id': workshopId,
        'full_name': fullName.trim(),
        'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
        'business_name': (businessName ?? '').trim().isEmpty ? null : businessName!.trim(),
      });

  Future<void> removeAttendee(String attendeeId) => _client.from('workshop_attendees').delete().eq('id', attendeeId);
}
