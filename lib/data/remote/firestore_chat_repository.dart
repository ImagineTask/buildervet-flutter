import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/logger_service.dart';

import '../../models/enums/participant_role.dart';
import '../../models/message.dart';
import '../../models/participant.dart';

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

  Future<Conversation?> getConversation(String conversationId) async {
    final doc =
        await _firestore.collection('conversations').doc(conversationId).get();
    if (doc.exists) {
      return Conversation.fromFirestore(doc);
    }
    return null;
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    final docRef = _firestore.collection('conversations').doc(conversationId);
    await docRef.update({
      'unreadCounts.$userId': 0,
    });
  }

  Stream<List<Message>> getMessages(String conversationId,
      {int limit = 20, DocumentSnapshot? lastDocument}) {
    // Ensure limit is always positive
    final safeLimit = limit > 0 ? limit : 1;
    Query query = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(safeLimit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  /// Returns snapshots of messages along with the last document for pagination
  Stream<MessagePaginationResult> getMessagesPaginated(String conversationId,
      {int limit = 20, DocumentSnapshot? lastDocument}) {
    final safeLimit = limit > 0 ? limit : 1;
    Query query = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(safeLimit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      final messages =
          snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
      return MessagePaginationResult(
        messages: messages,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length >= safeLimit,
      );
    });
  }

  Future<void> sendMessage(Message message) async {
    final messageMap = message.toMap();

    // Add message to sub-collection
    final conversationDoc = _firestore.collection('conversations').doc(message.conversationId);
    final conversationSnapshot = await conversationDoc.get();
    
    Map<String, int> updatedUnreadCounts = {};
    if (conversationSnapshot.exists) {
      final data = conversationSnapshot.data() as Map<String, dynamic>;
      updatedUnreadCounts = Map<String, int>.from(data['unreadCounts'] ?? {});
    }

    // Increment count for everyone except the sender
    final participantIds = List<String>.from(conversationSnapshot.data()?['participantIds'] ?? []);
    for (final id in participantIds) {
      if (id != message.senderId) {
        updatedUnreadCounts[id] = (updatedUnreadCounts[id] ?? 0) + 1;
      }
    }

    // Update message and conversation metadata
    final batch = _firestore.batch();
    
    final newMessageRef = conversationDoc.collection('messages').doc();
    batch.set(newMessageRef, messageMap);
    
    batch.update(conversationDoc, {
      'lastMessage': messageMap,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': updatedUnreadCounts,
    });

    await batch.commit();
  }

  Future<String> createConversation(String title, List<String> participantIds,
      {String? customId}) async {
    final data = {
      'title': title,
      'participantIds': participantIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': {for (var id in participantIds) id: 0},
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

  Future<Participant?> getParticipant(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return Participant(
          userId: doc.id,
          name: data['name'] ?? '',
          role: ParticipantRole.fromString(data['role'] ?? 'homeowner'),
          email: data['email'] ?? '',
          avatarUrl: data['avatarUrl'],
          phone: data['phone'],
          country: data['country'],
        );
      }
    } catch (e, stack) {
      Log.e('Error fetching participant: $e', e, stack);
    }
    return null;
  }
  Stream<Map<String, bool>> getTypingStatus(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return {};
      final data = snapshot.data() as Map<String, dynamic>;
      final typing = data['typing'] as Map<String, dynamic>? ?? {};
      return typing.map((key, value) => MapEntry(key, value as bool));
    });
  }

  Future<void> updateMessageTranscription(
      String conversationId, String messageId, String userId, String transcription) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'transcriptions.$userId': transcription});
    } catch (e, stack) {
      Log.e('Error updating transcription: $e', e, stack);
      rethrow;
    }
  }

  Future<void> setTypingStatus(
      String conversationId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'typing.$userId': isTyping,
      });
    } catch (e) {
      // If document doesn't have 'typing' field yet, we might need to use SetOptions
      await _firestore.collection('conversations').doc(conversationId).set({
        'typing': {userId: isTyping}
      }, SetOptions(merge: true));
    }
  }
}

class MessagePaginationResult {
  final List<Message> messages;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  MessagePaginationResult({
    required this.messages,
    this.lastDocument,
    required this.hasMore,
  });
}
