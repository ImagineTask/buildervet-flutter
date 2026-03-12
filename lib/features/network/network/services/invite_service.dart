import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invite_model.dart';

class InviteService {
  final _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  static const String _baseUrl = 'https://buildervet.app/invite';

  String get _inviterName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ??
        user?.email?.split('@').first ??
        'Someone';
  }

  /// Generates a short random invite code e.g. "x4Kp2m"
  String _generateInviteCode() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates an invite in Firestore and returns the invite link.
  /// The caller can then share this link however they like.
  Future<String> createInvite() async {
    final inviteCode = _generateInviteCode();
    final inviteLink = '$_baseUrl?code=$inviteCode';

    final invite = InviteModel(
      inviteId: '',
      inviterUid: _uid,
      inviterName: _inviterName,
      inviteCode: inviteCode,
      inviteLink: inviteLink,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _db.collection('invites').add(invite.toMap());
    return inviteLink;
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

  /// Cancel / revoke a pending invite
  Future<void> cancelInvite(String inviteId) async {
    await _db.collection('invites').doc(inviteId).delete();
  }
}
