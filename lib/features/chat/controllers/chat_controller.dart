import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/message.dart';
import '../../../models/enums/message_type.dart';
import '../../../core/di/service_locator.dart';

class ChatState {
  final Message? replyToMessage;
  final bool isTranslating;
  final bool isUploading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool showEmoji;
  final bool isRecording;
  final bool isVoiceMode;
  final int messageLimit;
  final String? jumpToMessageId;

  ChatState({
    this.replyToMessage,
    this.isTranslating = false,
    this.isUploading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.showEmoji = false,
    this.isRecording = false,
    this.isVoiceMode = false,
    this.messageLimit = 20,
    this.jumpToMessageId,
  });

  ChatState copyWith({
    Message? replyToMessage,
    bool? clearReplyToMessage,
    bool? isTranslating,
    bool? isUploading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? showEmoji,
    bool? isRecording,
    bool? isVoiceMode,
    int? messageLimit,
    String? jumpToMessageId,
    bool? clearJumpToMessageId,
  }) {
    return ChatState(
      replyToMessage: clearReplyToMessage == true ? null : (replyToMessage ?? this.replyToMessage),
      isTranslating: isTranslating ?? this.isTranslating,
      isUploading: isUploading ?? this.isUploading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      showEmoji: showEmoji ?? this.showEmoji,
      isRecording: isRecording ?? this.isRecording,
      isVoiceMode: isVoiceMode ?? this.isVoiceMode,
      messageLimit: messageLimit ?? this.messageLimit,
      jumpToMessageId: clearJumpToMessageId == true ? null : (jumpToMessageId ?? this.jumpToMessageId),
    );
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, conversationId) {
  return ChatController(ref, conversationId);
});

class ChatController extends StateNotifier<ChatState> {
  final Ref ref;
  final String conversationId;

  ChatController(this.ref, this.conversationId) : super(ChatState());

  void setReplyToMessage(Message? message) {
    state = state.copyWith(replyToMessage: message, isVoiceMode: false);
  }

  void cancelReply() {
    state = state.copyWith(clearReplyToMessage: true);
  }

  void setVoiceMode(bool isVoice) {
    state = state.copyWith(isVoiceMode: isVoice);
  }

  void setRecording(bool isRecording) {
    state = state.copyWith(isRecording: isRecording);
  }

  void toggleEmoji() {
    state = state.copyWith(showEmoji: !state.showEmoji);
  }

  void setShowEmoji(bool show) {
    state = state.copyWith(showEmoji: show);
  }

  void updateTypingStatus(bool isTyping) {
    // Logic for typing status can be here
  }

  Future<void> sendMessage({
    String? text,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    String? mimeType,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final newMessage = Message(
      id: '', // Will be set by Firestore
      conversationId: conversationId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName ?? 'User',
      type: type,
      content: text ?? '',
      sentAt: DateTime.now(),
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      duration: duration,
      mimeType: mimeType,
      replyToId: state.replyToMessage?.id,
      replyToContent: state.replyToMessage?.content,
      replyToSenderName: state.replyToMessage?.senderName,
      replyToImageUrl: state.replyToMessage?.imageUrl ?? (state.replyToMessage?.type == MessageType.video ? state.replyToMessage?.fileUrl : null),
      replyToType: state.replyToMessage?.type.name,
    );

    try {
      if (type == MessageType.text) {
        state = state.copyWith(isTranslating: true);
      }
      
      await ref.read(chatRepositoryProvider).sendMessage(newMessage);
      cancelReply();
    } finally {
      state = state.copyWith(isTranslating: false);
    }
  }

  void jumpToMessage(String messageId) {
    state = state.copyWith(jumpToMessageId: messageId);
    Future.delayed(const Duration(milliseconds: 100), () {
      state = state.copyWith(clearJumpToMessageId: true);
    });
  }

  void loadMore() {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(
      isLoadingMore: true,
      messageLimit: state.messageLimit + 20,
    );
    Future.delayed(const Duration(milliseconds: 1000), () {
      state = state.copyWith(isLoadingMore: false);
    });
  }

  void setHasMore(bool hasMore) {
    state = state.copyWith(hasMore: hasMore);
  }
}
