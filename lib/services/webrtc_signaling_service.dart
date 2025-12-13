import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebRTCSignalingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription? _offerSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _iceCandidateSubscription;

  Future<void> createCallDocument(
      String callId, Map<String, dynamic> data) async {
    await _supabase.from('calls').insert({
      'id': callId,
      'caller_id': data['callerId'],
      'caller_name': data['callerName'],
      'call_type': data['callType'],
      'participants': data['participants'],
      'group_id': data['groupId'],
      'offer': null,
      'answer': null,
      'ice_candidates': [],
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setAnswer(String callId, Map<String, dynamic> answer) async {
    await _supabase.from('calls').update({
      'answer': answer,
    }).eq('id', callId);
  }

  Future<void> setOffer(String callId, Map<String, dynamic> offer) async {
    await _supabase.from('calls').update({
      'offer': offer,
    }).eq('id', callId);
  }

  Future<void> addIceCandidate(
      String callId, Map<String, dynamic> candidate) async {
    // Get current ice candidates
    final callData = await _supabase
        .from('calls')
        .select('ice_candidates')
        .eq('id', callId)
        .single();

    final currentCandidates = List<Map<String, dynamic>>.from(callData['ice_candidates'] ?? []);
    currentCandidates.add(candidate);

    await _supabase.from('calls').update({
      'ice_candidates': currentCandidates,
    }).eq('id', callId);
  }

  Stream<Map<String, dynamic>?> subscribeToCall(String callId) {
    return _supabase
        .from('calls')
        .select()
        .eq('id', callId)
        .asStream()
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  Future<void> deleteCall(String callId) async {
    await _supabase.from('calls').delete().eq('id', callId);
  }
}
