import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consultant_assignment.dart';

class ConsultantAssignmentRepository {
  ConsultantAssignmentRepository(this._client);

  final SupabaseClient _client;

  /// Users with the Consultant role — for the Admin's assignment dropdown.
  /// RLS on `users` already lets an Admin see every row, so this is a
  /// plain filtered select, not a special-cased query.
  Future<List<Map<String, dynamic>>> fetchConsultants() async {
    final rows = await _client
        .from('users')
        .select('id, first_name, last_name, roles!inner(role_name)')
        .eq('roles.role_name', 'Consultant');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// All assignments, with the consultant and enterprise names joined in
  /// — this is what Admin's assignment list screen displays. A
  /// Consultant calling this would only get their own rows back (RLS),
  /// but this method is intended for the Admin view specifically.
  Future<List<ConsultantAssignment>> fetchAll() async {
    final rows = await _client
        .from('consultant_assignments')
        .select('''
          *,
          consultant:consultant_id(first_name, last_name),
          enterprise:enterprise_id(business_name)
        ''')
        .order('assigned_date', ascending: false);
    return (rows as List)
        .map((row) => ConsultantAssignment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Assigns a consultant to an enterprise. If that enterprise already
  /// has an active assignment (to any consultant), it's ended first —
  /// MVP scope is one active Legal consultant per enterprise at a time,
  /// not tracking multiple concurrent consultant "types" yet.
  Future<void> assign({
    required String consultantId,
    required String enterpriseId,
    required String assignedByUserId,
  }) async {
    await _client
        .from('consultant_assignments')
        .update({'assignment_status': 'ended'})
        .eq('enterprise_id', enterpriseId)
        .eq('assignment_status', 'active');

    await _client.from('consultant_assignments').insert({
      'consultant_id': consultantId,
      'enterprise_id': enterpriseId,
      'assigned_by': assignedByUserId,
    });
  }
}