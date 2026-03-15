import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/remote/firestore_chat_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../message_bubble.dart';
import '../../controllers/chat_controller.dart';

class MessageListView extends ConsumerStatefulWidget {
  final String conversationId;
  final String userLanguage;

  const MessageListView({
    super.key,
    required this.conversationId,
    required this.userLanguage,
  });

  @override
  ConsumerState<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends ConsumerState<MessageListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch only necessary pagination state to avoid unneeded rebuilds of the entire stream list
    final isLoadingMore = ref.watch(chatControllerProvider(widget.conversationId).select((s) => s.isLoadingMore));
    final messageLimit = ref.watch(chatControllerProvider(widget.conversationId).select((s) => s.messageLimit));
    final hasMore = ref.watch(chatControllerProvider(widget.conversationId).select((s) => s.hasMore));
    
    final controller = ref.read(chatControllerProvider(widget.conversationId).notifier);

    // Listen to jump events
    ref.listen(chatControllerProvider(widget.conversationId).select((s) => s.jumpToMessageId), (prev, next) {
      if (next != null) {
        final key = _messageKeys[next];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return StreamBuilder<MessagePaginationResult>(
      stream: ref.watch(chatRepositoryProvider).getMessagesPaginated(
          widget.conversationId,
          limit: messageLimit > 0 ? messageLimit : 20),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final messages = data?.messages ?? [];

        if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          );
        }

        // Update hasMore state if needed, though usually managed well enough for the view
        if (!isLoadingMore && messages.length < messageLimit && hasMore) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             controller.setHasMore(false);
           });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
               controller.loadMore();
            }
            return true;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: messages.length + (isLoadingMore ? 1 : 0),
            reverse: true,
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final message = messages[index];
              final isMe = message.senderId == FirebaseAuth.instance.currentUser?.uid;
              
              final messageKey = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

              return MessageBubble(
                key: messageKey,
                message: message,
                isMe: isMe,
                translationService: ref.watch(translationServiceProvider),
                targetLanguage: widget.userLanguage,
                onReply: () {
                  controller.setReplyToMessage(message);
                },
                onJumpToMessage: (targetId) {
                  controller.jumpToMessage(targetId);
                },
              );
            },
          ),
        );
      },
    );
  }
}
