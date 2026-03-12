import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String inviterUid;
  final String inviterName;
  final String inviteCode;
  final String inviteLink;
  final String status; // "pending" | "accepted"
  final DateTime createdAt;

  InviteModel({
    required this.inviteId,
    required this.inviterUid,
    required this.inviterName,
    required this.inviteCode,
    required this.inviteLink,
    required this.status,
    required this.createdAt,
  });

  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InviteModel(
      inviteId: doc.id,
      inviterUid: d['inviterUid'] ?? '',
      inviterName: d['inviterName'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      inviteLink: d['inviteLink'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviteCode': inviteCode,
        'inviteLink': inviteLink,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
