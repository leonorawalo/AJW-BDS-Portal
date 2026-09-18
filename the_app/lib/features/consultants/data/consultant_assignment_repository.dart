import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consultant_assignment.dart';

class ConsultantAssignmentRepository {
  ConsultantAssignmentRepository(this._client);

  final SupabaseClient _client;

  /// Users with the Consultant role — for the Admin's assignment dropdown.
  /// RLS on `users` already lets an Admin see every row, so this is a
  /// plain filtered select, not a special-cased query. specialization
  /// is included so the dropdown can label each option (Legal /
  /// Accounting / Marketing) — the ToR "Trio" model means picking a
  /// consultant without knowing which specialization they are isn't
  /// meaningful.
  Future<List<Map<String, dynamic>>> fetchConsultants() async {
    final rows = await _client
        .from('users')
        .select('id, first_name, last_name, specialization, roles!inner(role_name)')
        .eq('roles.role_name', 'Consultant');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// The currently active assignment(s) for one enterprise — up to three
  /// (one per specialization). Used to populate "assign this task to"
  /// pickers, and to show the Admin which specializations are still
  /// unfilled.
  Future<List<ConsultantAssignment>> fetchActiveForEnterprise(String enterpriseId) async {
    final rows = await _client
        .from('consultant_assignments')
        .select('*, consultant:consultant_id(first_name, last_name)')
        .eq('enterprise_id', enterpriseId)
        .eq('assignment_status', 'active');
    return (rows as List)
        .map((row) => ConsultantAssignment.fromMap(row as Map<String, dynamic>))
        .toList();
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

  /// Assigns a consultant to an enterprise. Up to three concurrent
  /// active assignments per enterprise are allowed — one per
  /// specialization (the ToR "Trio" model). If this enterprise already
  /// has an active consultant of the *same* specialization as the one
  /// being assigned, that one is ended — handled server-side by the
  /// `consultant_assignments_before_insert` trigger, which derives
  /// specialization from the consultant's profile, so this is just a
  /// plain insert.
  Future<void> assign({
    required String consultantId,
    required String enterpriseId,
    required String assignedByUserId,
  }) async {
    await _client.from('consultant_assignments').insert({
      'consultant_id': consultantId,
      'enterprise_id': enterpriseId,
      'assigned_by': assignedByUserId,
    });
  }
}