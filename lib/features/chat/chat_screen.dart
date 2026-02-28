import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/inputs/app_search_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
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
          const SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: AppSpacing.sm),
                AppSearchBar(hintText: 'Search conversations...'),
                SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          // Mock conversations
          SliverList(
            delegate: SliverChildListDelegate(
              _mockConversations
                  .map((c) => _ConversationTile(conversation: c))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockConversation {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String role;

  const _MockConversation({
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
    required this.role,
  });
}

const _mockConversations = [
  _MockConversation(
    name: 'James Smith',
    lastMessage: 'Cabinet delivery confirmed for Monday',
    time: '10:32',
    unread: 2,
    role: 'Contractor',
  ),
  _MockConversation(
    name: 'Maria Lopez',
    lastMessage: 'Here are the updated floor plans 📎',
    time: '09:15',
    unread: 1,
    role: 'Designer',
  ),
  _MockConversation(
    name: 'Dave Wilson',
    lastMessage: 'Rewiring is 80% complete',
    time: 'Yesterday',
    role: 'Electrician',
  ),
  _MockConversation(
    name: 'Kitchen Renovation Group',
    lastMessage: 'Maria: Timeline looks good to me',
    time: 'Yesterday',
    role: 'Group',
  ),
  _MockConversation(
    name: 'Sarah Green',
    lastMessage: 'Patio samples ready for review',
    time: 'Mon',
    role: 'Landscape Designer',
  ),
  _MockConversation(
    name: 'Mike Turner',
    lastMessage: 'Boiler part ordered, arriving Wed',
    time: 'Mon',
    role: 'Gas Engineer',
  ),
];

class _ConversationTile extends StatelessWidget {
  final _MockConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          conversation.name[0],
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
              conversation.name,
              style: TextStyle(
                fontWeight: conversation.unread > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            conversation.time,
            style: TextStyle(
              fontSize: 12,
              color: conversation.unread > 0
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
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conversation.unread > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (conversation.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.unread}',
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
        // TODO: Navigate to conversation screen
      },
    );
  }
}
