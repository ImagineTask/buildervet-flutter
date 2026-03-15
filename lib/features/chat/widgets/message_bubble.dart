import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/translation_service.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/message.dart';
import 'components/text_content.dart';
import 'components/image_content.dart';
import 'components/video_content.dart';
import 'components/audio_content.dart';
import 'components/file_content.dart';
import '../../../core/widgets/user_avatar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final TranslationService translationService;
  final String targetLanguage;
  final VoidCallback? onReply;
  final Function(String messageId)? onJumpToMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.translationService,
    required this.targetLanguage,
    this.onReply,
    this.onJumpToMessage,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 40.0;
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              UserAvatar(
                radius: avatarSize / 2,
                initials: (message.senderName.isNotEmpty) ? message.senderName[0].toUpperCase() : '?',
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () => _showContextMenu(context),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMe ? 12 : 2),
                          topRight: Radius.circular(isMe ? 2 : 12),
                          bottomLeft: const Radius.circular(12),
                          bottomRight: const Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.replyToId != null) _buildReplyQuote(),
                          _buildContent(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              UserAvatar(
                radius: avatarSize / 2,
                initials: (message.senderName.isNotEmpty) ? message.senderName[0].toUpperCase() : '?',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyQuote() {
    return GestureDetector(
      onTap: () {
        if (message.replyToId != null) {
          onJumpToMessage?.call(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white.withOpacity(0.5) : AppColors.primary.withOpacity(0.6),
              width: 2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.replyToSenderName ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white.withOpacity(0.9) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    message.replyToContent ?? (message.replyToType != null ? '[${message.replyToType}]' : '[Media]'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (message.replyToImageUrl != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  image: DecorationImage(
                    image: NetworkImage(message.replyToImageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () async {
                Navigator.pop(context);
                final textToCopy = message.content;
                if (textToCopy.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: textToCopy));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (message.type) {
      case MessageType.text:
        return TextContent(
          message: message,
          isMe: isMe,
          translationService: translationService,
          targetLanguage: targetLanguage,
        );
      case MessageType.image:
        return ImageContent(message: message);
      case MessageType.video:
        return VideoContent(message: message);
      case MessageType.audio:
      case MessageType.voice:
        return AudioContent(message: message, isMe: isMe);
      case MessageType.file:
      case MessageType.document:
        return FileContent(message: message, isMe: isMe);
      default:
        return TextContent(
          message: message,
          isMe: isMe,
          translationService: translationService,
          targetLanguage: targetLanguage,
        );
    }
  }
}
