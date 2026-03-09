import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message.dart';
import '../../models/participant.dart';
import '../../models/enums/participant_role.dart';

class FirestoreChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Conversation>> getConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        // .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc))
            .toList());
  }

  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList());
  }

  Future<void> sendMessage(Message message) async {
    final messageMap = message.toMap();
    
    // Add message to sub-collection
    await _firestore
        .collection('conversations')
        .doc(message.conversationId)
        .collection('messages')
        .add(messageMap);

    // Update last message in conversation document
    await _firestore
        .collection('conversations')
        .doc(message.conversationId)
        .update({
      'lastMessage': messageMap,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<String> createConversation(String title, List<String> participantIds, {String? customId}) async {
    final data = {
      'title': title,
      'participantIds': participantIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': 0,
    };

    if (customId != null) {
      await _firestore.collection('conversations').doc(customId).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return customId;
    } else {
      final docRef = await _firestore.collection('conversations').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }
  }

  String getDeterministicConversationId(List<String> participantIds) {
    final sortedIds = List<String>.from(participantIds)..sort();
    return 'chat_1to1_${sortedIds.join('_')}';
  }

  Stream<List<Participant>> getUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Participant(
          userId: doc.id,
          name: data['name'] ?? '',
          role: ParticipantRole.fromString(data['role'] ?? 'homeowner'),
          email: data['email'] ?? '',
          avatarUrl: data['avatarUrl'],
          phone: data['phone'],
          country: data['country'],
        );
      }).toList();
    });
  }
}
