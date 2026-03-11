import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/inputs/app_search_bar.dart';
import '../../models/message.dart';
import '../../models/enums/message_type.dart';
import '../../core/di/service_locator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String _searchQuery = '';
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: StreamBuilder<List<Conversation>>(
        stream: ref.watch(chatRepositoryProvider).getConversations(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final conversations = snapshot.data ?? [];
          final filtered = conversations.where((c) {
            final query = _searchQuery.toLowerCase();
            return c.title.toLowerCase().contains(query) ||
                   (c.lastMessage?.content.toLowerCase().contains(query) ?? false);
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                title: Text(
                  'Chat',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_square),
                    onPressed: () {
                      // TODO: New conversation
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    AppSearchBar(
                      hintText: 'Search conversations...',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              filtered.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: AppColors.textTertiary.withOpacity(0.5)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No conversations found',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ConversationTile(
                          conversation: filtered[index],
                          currentUserId: _currentUserId,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

// Mocking data removed

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat.Hm().format(date);
    }
    return DateFormat.MMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final String lastMsgText = lastMessage?.type == MessageType.image
        ? 'Sent an image'
        : (lastMessage?.content ?? 'No messages');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          conversation.title.isNotEmpty ? conversation.title[0] : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.title,
              style: TextStyle(
                fontWeight: unreadCount > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            _formatTime(lastMessage?.sentAt),
            style: TextStyle(
              fontSize: 12,
              color: unreadCount > 0
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMsgText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        context.push('/chat/${conversation.id}', extra: {
          'title': conversation.title,
        });
      },
    );
  }
}
