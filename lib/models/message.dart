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
  final String? sourceLanguage;
  final String? targetLanguage;
  final DateTime sentAt;
  final bool isRead;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final String? mimeType;
  final String? taskId;
  final Map<String, String>? transcriptions;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final String? replyToImageUrl;
  final String? replyToType;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.translatedContent,
    this.sourceLanguage,
    this.targetLanguage,
    required this.sentAt,
    this.isRead = false,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.mimeType,
    this.taskId,
    this.transcriptions,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.replyToImageUrl,
    this.replyToType,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    return Message.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    // Backward compatibility: handle old 'transcription' field
    Map<String, String>? transcriptions;
    if (data['transcriptions'] != null) {
      transcriptions = Map<String, String>.from(data['transcriptions']);
    } else if (data['transcription'] != null) {
      // If old single field exists, we don't know who it was for, 
      // but we'll assume it's a global one for now.
      transcriptions = {'legacy': data['transcription'] as String};
    }

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
      sourceLanguage: data['sourceLanguage'],
      targetLanguage: data['targetLanguage'],
      sentAt: data['sentAt'] is Timestamp 
          ? (data['sentAt'] as Timestamp).toDate() 
          : DateTime.tryParse(data['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      duration: data['duration'],
      mimeType: data['mimeType'],
      taskId: data['taskId'],
      transcriptions: transcriptions,
      replyToId: data['replyToId'],
      replyToContent: data['replyToContent'],
      replyToSenderName: data['replyToSenderName'],
      replyToImageUrl: data['replyToImageUrl'],
      replyToType: data['replyToType'],
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
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration,
      'mimeType': mimeType,
      'taskId': taskId,
      'transcriptions': transcriptions,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'replyToImageUrl': replyToImageUrl,
      'replyToType': replyToType,
    };
  }
}

class Conversation {
  final String id;
  final String title;
  final List<String> participantIds;
  final List<String> participantNames;
  final Message? lastMessage;
  final Map<String, int> unreadCounts;
  final String? taskId;

  const Conversation({
    required this.id,
    required this.title,
    this.participantIds = const [],
    this.participantNames = const [],
    this.lastMessage,
    this.unreadCounts = const {},
    this.taskId,
  });

  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastMessageData = data['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      id: doc.id,
      title: data['title'] ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: List<String>.from(data['participantNames'] ?? []),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      taskId: data['taskId'],
      lastMessage: lastMessageData != null ? Message.fromMap(lastMessageData, '') : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'unreadCounts': unreadCounts,
      'taskId': taskId,
    };
  }
}
