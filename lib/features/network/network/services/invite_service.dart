import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/invite_model.dart';

class InviteService {
  final _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  // Your Cloud Run base URL
  static const String _baseUrl =
      'https://imaginetask-engine-v1-268920641222.europe-west2.run.app';

  /// Generates a short random invite code e.g. "x4Kp2m"
  String _generateInviteCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Check if a pending invite already exists for this phone number
  Future<bool> inviteAlreadySent(String phone) async {
    final snap = await _db
        .collection('invites')
        .where('inviterUid', isEqualTo: _uid)
        .where('inviteePhone', isEqualTo: phone)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Stream all pending invites sent by the current user
  Stream<List<InviteModel>> streamSentInvites() {
    return _db
        .collection('invites')
        .where('inviterUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(InviteModel.fromFirestore).toList());
  }

  /// Send an SMS invite:
  /// 1. Writes invite doc to Firestore
  /// 2. Calls Cloud Run → Twilio sends SMS
  Future<void> sendInvite({
    required String phone,
    required String inviterName,
  }) async {
    // Check for duplicate
    if (await inviteAlreadySent(phone)) {
      throw Exception('You have already sent an invite to $phone.');
    }

    final inviteCode = _generateInviteCode();
    final inviteLink = 'https://buildervet.app/invite?code=$inviteCode';

    // 1. Write to Firestore
    final invite = InviteModel(
      inviteId: '',
      inviterUid: _uid,
      inviteePhone: phone,
      inviteCode: inviteCode,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _db.collection('invites').add(invite.toMap());

    // 2. Call Cloud Run to send SMS via Twilio
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/invites/send-sms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'inviterName': inviterName,
        'inviteLink': inviteLink,
      }),
    );

    if (response.statusCode != 200) {
      // If SMS fails, remove the Firestore doc to keep state consistent
      final snap = await _db
          .collection('invites')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      throw Exception('Failed to send SMS. Please try again.');
    }
  }

  /// Cancel / revoke a pending invite
  Future<void> cancelInvite(String inviteId) async {
    await _db.collection('invites').doc(inviteId).delete();
  }
}
