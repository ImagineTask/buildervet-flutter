import 'enums/message_type.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final String? imageUrl;
  final String? taskId; // for invite messages

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.sentAt,
    this.isRead = false,
    this.imageUrl,
    this.taskId,
  });
}

class Conversation {
  final String id;
  final String title;
  final List<String> participantIds;
  final List<String> participantNames;
  final Message? lastMessage;
  final int unreadCount;
  final String? taskId; // linked task/project

  const Conversation({
    required this.id,
    required this.title,
    this.participantIds = const [],
    this.participantNames = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.taskId,
  });
}
