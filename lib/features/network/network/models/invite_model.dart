import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String inviterUid;
  final String inviteePhone;
  final String inviteCode;
  final String status; // "pending" | "accepted"
  final DateTime createdAt;

  InviteModel({
    required this.inviteId,
    required this.inviterUid,
    required this.inviteePhone,
    required this.inviteCode,
    required this.status,
    required this.createdAt,
  });

  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InviteModel(
      inviteId: doc.id,
      inviterUid: d['inviterUid'] ?? '',
      inviteePhone: d['inviteePhone'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'inviterUid': inviterUid,
        'inviteePhone': inviteePhone,
        'inviteCode': inviteCode,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
