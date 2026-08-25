import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enterprise.dart';

class EnterpriseRepository {
  EnterpriseRepository(this._client);

  final SupabaseClient _client;

  Future<List<Enterprise>> fetchAll() async {
    final rows = await _client
        .from('enterprises')
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Enterprise.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Enterprise?> fetchById(String id) async {
    final row = await _client.from('enterprises').select().eq('id', id).maybeSingle();
    return row == null ? null : Enterprise.fromMap(row);
  }

  /// Admin-only per FR-009 — enterprises are registered by AJW Africa staff,
  /// never self-registered by an Owner. RLS backs this up independently:
  /// there's no insert policy for non-admins, so this call fails safely
  /// even if a non-admin somehow reaches this code path.
  Future<Enterprise> create({
    required String businessName,
    required String ownerName,
    String? ownerUserId,
    String? phoneNumber,
    String? email,
    String? county,
    String? industry,
    String? registrationNumber,
    String? kraPin,
  }) async {
    final row = await _client
        .from('enterprises')
        .insert({
          'business_name': businessName,
          'owner_name': ownerName,
          'owner_user_id': ownerUserId,
          'phone_number': phoneNumber,
          'email': email,
          'county': county,
          'industry': industry,
          'registration_number': registrationNumber,
          'kra_pin': kraPin,
        })
        .select()
        .single();
    return Enterprise.fromMap(row);
  }

  Future<Enterprise> updateLifecycleStatus({
    required String enterpriseId,
    required LifecycleStatus status,
  }) async {
    final row = await _client
        .from('enterprises')
        .update({'lifecycle_status': status.dbValue})
        .eq('id', enterpriseId)
        .select()
        .single();
    return Enterprise.fromMap(row);
  }

  Future<Enterprise> updateGoingConcernStatus({
    required String enterpriseId,
    required GoingConcernStatus status,
  }) async {
    // going_concern_achieved_at is set/cleared automatically by the
    // check_going_concern_consistency trigger — never set it from here.
    final row = await _client
        .from('enterprises')
        .update({'going_concern_status': status.dbValue})
        .eq('id', enterpriseId)
        .select()
        .single();
    return Enterprise.fromMap(row);
  }
}