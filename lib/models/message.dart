import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums/message_type.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final String? translatedContent;
  final DateTime sentAt;
  final bool isRead;
  final String? imageUrl;
  final String? taskId;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.translatedContent,
    required this.sentAt,
    this.isRead = false,
    this.imageUrl,
    this.taskId,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    return Message.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      content: data['content'] ?? '',
      translatedContent: data['translatedContent'],
      sentAt: data['sentAt'] is Timestamp 
          ? (data['sentAt'] as Timestamp).toDate() 
          : DateTime.tryParse(data['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      taskId: data['taskId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'translatedContent': translatedContent,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'taskId': taskId,
    };
  }
}

class Conversation {
  final String id;
  final String title;
  final List<String> participantIds;
  final List<String> participantNames;
  final Message? lastMessage;
  final int unreadCount;
  final String? taskId;

  const Conversation({
    required this.id,
    required this.title,
    this.participantIds = const [],
    this.participantNames = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.taskId,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastMessageData = data['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      id: doc.id,
      title: data['title'] ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: List<String>.from(data['participantNames'] ?? []),
      unreadCount: data['unreadCount'] ?? 0,
      taskId: data['taskId'],
      lastMessage: lastMessageData != null ? Message.fromMap(lastMessageData, '') : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'unreadCount': unreadCount,
      'taskId': taskId,
    };
  }
}
