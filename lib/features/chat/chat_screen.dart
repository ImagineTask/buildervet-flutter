import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _chats.length,
                itemBuilder: (context, index) => _ChatTile(chat: _chats[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chat {
  final String name;
  final String lastMessage;
  final String time;
  final String initials;
  final Color avatarColor;
  final int unread;
  final bool isOnline;

  const _Chat({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.initials,
    required this.avatarColor,
    this.unread = 0,
    this.isOnline = false,
  });
}

const _chats = [
  _Chat(name: 'Sarah Connor', lastMessage: 'See you at the meeting! 👋', time: '2m', initials: 'SC', avatarColor: Color(0xFFFF6B6B), unread: 3, isOnline: true),
  _Chat(name: 'Mike Reynolds', lastMessage: 'The PR is ready for review.', time: '15m', initials: 'MR', avatarColor: Color(0xFF43C59E), unread: 1, isOnline: true),
  _Chat(name: 'Design Team', lastMessage: 'Emma: New mockups are up!', time: '1h', initials: 'DT', avatarColor: Color(0xFF6C63FF), unread: 7, isOnline: false),
  _Chat(name: 'David Park', lastMessage: 'Thanks for the help 🙏', time: '3h', initials: 'DP', avatarColor: Color(0xFFFFB347), unread: 0, isOnline: false),
  _Chat(name: 'Lisa Chen', lastMessage: 'Can we reschedule the call?', time: 'Yesterday', initials: 'LC', avatarColor: Color(0xFF4ECDC4), unread: 0, isOnline: true),
  _Chat(name: 'James Martins', lastMessage: 'Great work on the launch!', time: 'Yesterday', initials: 'JM', avatarColor: Color(0xFFE056A0), unread: 0, isOnline: false),
  _Chat(name: 'Dev Team', lastMessage: 'Alex: Build passed ✅', time: 'Mon', initials: 'DV', avatarColor: Color(0xFF5C6BC0), unread: 0, isOnline: false),
];

class _ChatTile extends StatelessWidget {
  final _Chat chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: chat.avatarColor,
                child: Text(
                  chat.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (chat.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43C59E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.name,
                  style: TextStyle(
                    fontWeight: chat.unread > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: chat.unread > 0 ? const Color(0xFF1A1A2E) : Colors.grey[500],
                    fontWeight: chat.unread > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                chat.time,
                style: TextStyle(
                  fontSize: 11,
                  color: chat.unread > 0 ? const Color(0xFF6C63FF) : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 4),
              if (chat.unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${chat.unread}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}
