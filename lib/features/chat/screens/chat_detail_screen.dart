import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/service_locator.dart';
import '../../../data/remote/firestore_chat_repository.dart';
import '../../../core/services/image_picker_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/message.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/message_bubble.dart';


class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String title;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTranslating = false;
  bool _isUploading = false;
  String? _recipientCountry;
  String _recipientLanguage = 'en';
  int _messageLimit = 10;
  String? _recipientAvatarUrl;
  String? _recipientInitials;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showEmoji = false;
  final FocusNode _focusNode = FocusNode();
  DocumentSnapshot? _lastDocument;
  List<Message> _allMessages = [];


  final ImagePickerService _imagePickerService = ImagePickerService();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'me';
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Me';

  bool _isDisposed = false;

  void _updateTypingStatus(bool isTyping) {
    if (_isDisposed) return;
    ref.read(chatRepositoryProvider).setTypingStatus(
          widget.conversationId,
          _currentUserId,
          isTyping,
        );
  }

  @override
  void initState() {
    super.initState();
    _fetchRecipientInfo();
    _markAsRead();
    _controller.addListener(() {
      if (_controller.text.isNotEmpty) {
        _updateTypingStatus(true);
      } else {
        _updateTypingStatus(false);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _updateTypingStatus(false);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadMoreMessages(int currentCount) {
    if (!_hasMore || _isLoadingMore) return;

    // If we have fewer messages than the limit, we've reached the end
    if (currentCount < _messageLimit) {
      setState(() => _hasMore = false);
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _messageLimit += 10;
    });

    // Reset loading state after a small delay to allow stream to update
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    });
  }

  Future<void> _markAsRead() async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .markAsRead(widget.conversationId, _currentUserId);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _fetchRecipientInfo() async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      final conversation =
          await repository.getConversation(widget.conversationId);

      if (conversation != null) {
        // In a 1-to-1 chat, the recipient is the other participant
        final recipientId = conversation.participantIds
            .firstWhere((id) => id != _currentUserId, orElse: () => '');

        if (recipientId.isNotEmpty) {
          final recipient = await repository.getParticipant(recipientId);
          if (mounted && recipient != null) {
            setState(() {
              _recipientCountry = recipient.country;
              _recipientLanguage =
                  TranslationService.getLanguageForCountry(_recipientCountry);
              _recipientAvatarUrl = recipient.avatarUrl;
              _recipientInitials = recipient.initials;
            });
            Log.i(
                'Recipient country: $_recipientCountry, target language: $_recipientLanguage');
          }
        }
      }
    } catch (e, stack) {
      Log.e('Error fetching recipient info: $e', e, stack);
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null) return;

    String? finalImageUrl;
    if (imageUrl != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to upload images.')),
          );
        }
        return;
      }

      setState(() => _isUploading = true);
      try {
        Log.i('ChatDetail: Starting upload for $imageUrl by user ${user.uid}');
        final storageService = ref.read(storageLocatorProvider);
        Uint8List bytes;
        String fileName;

        if (imageUrl.startsWith('data:image')) {
          Log.i('ChatDetail: Handling data URL');
          final base64String = imageUrl.split(',').last;
          bytes = base64Decode(base64String);
          fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else if (kIsWeb) {
          Log.i('ChatDetail: Handling Web path/blob');
          final response =
              await ref.read(httpProvider).get(Uri.parse(imageUrl));
          bytes = response.bodyBytes;
          fileName = 'web_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          Log.i('ChatDetail: Handling local file');
          final file = File(imageUrl);
          fileName = p.basename(imageUrl);
          bytes = await file.readAsBytes();
        }

        finalImageUrl = await storageService.uploadFile(
          bytes: bytes,
          path: 'chat_images/$fileName',
          contentType: 'image/jpeg',
        );
        Log.i('ChatDetail: Upload successful: $finalImageUrl');
      } catch (e, stack) {
        String errorMessage = e.toString();
        if (errorMessage.contains('unauthorized')) {
          errorMessage =
              'Upload failed: Unauthorized. Please check Firebase Storage rules.';
        }
        Log.e('ChatDetail: Upload error: $errorMessage', e, stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
      setState(() => _isUploading = false);
    }

    final String content = text ?? '';
    String? translatedContent;
    String? sourceLanguage;
    String? targetLanguage;

    if (content.isNotEmpty) {
      setState(() => _isTranslating = true);
      try {
        // Translate to the recipient's language based on their country
        Log.i('ChatDetail: Translating to recipient language: $_recipientLanguage');
        final translationService = ref.read(translationServiceProvider);
        final result =
            await translationService.translate(content, _recipientLanguage);
        translatedContent = result.translatedText;
        sourceLanguage = result.sourceLanguage;
        targetLanguage = result.targetLanguage;
        Log.i('ChatDetail: Translation success: $translatedContent ($sourceLanguage -> $targetLanguage)');
      } catch (e) {
        Log.e('ChatDetail: Translation error: $e');
      }
      setState(() => _isTranslating = false);
    }

    final newMessage = Message(
      id: '',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: finalImageUrl != null ? MessageType.image : MessageType.text,
      content: content,
      translatedContent: translatedContent,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      sentAt: DateTime.now(),
      imageUrl: finalImageUrl,
    );

    await ref.read(chatRepositoryProvider).sendMessage(newMessage);
    _controller.clear();
    // With reverse: true, 0 is the bottom.
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _pickImage() async {
    final String? imagePath =
        await _imagePickerService.pickAndEditImage(context);
    if (imagePath != null) {
      _sendMessage(imageUrl: imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final userLanguage =
        TranslationService.getLanguageForCountry(appUser?.country);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              radius: 18,
              avatarUrl: _recipientAvatarUrl,
              initials: _recipientInitials ?? widget.title[0].toUpperCase(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(widget.title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: StreamBuilder<MessagePaginationResult>(
                stream: ref.watch(chatRepositoryProvider).getMessagesPaginated(
                    widget.conversationId,
                    limit: _messageLimit > 0 ? _messageLimit : 10),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final messages = data?.messages ?? [];
                  _lastDocument = data?.lastDocument;
                  _hasMore = data?.hasMore ?? true;
  
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (messages.isEmpty) {
                    return const Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: AppColors.textTertiary)));
                  }
  
                  return NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 200 &&
                          !_isLoadingMore) {
                        _loadMoreMessages(messages.length);
                      }
                      return true;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                      reverse: true,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
  
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;
                        return MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isMe: isMe,
                          translationService: ref.watch(translationServiceProvider),
                          targetLanguage: userLanguage,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          StreamBuilder<Map<String, bool>>(
            stream: ref.watch(chatRepositoryProvider).getTypingStatus(widget.conversationId),
            builder: (context, snapshot) {
              final typingMap = snapshot.data ?? {};
              // Find if anyone else is typing
              final othersTyping = typingMap.entries
                  .where((e) => e.key != _currentUserId && e.value)
                  .isNotEmpty;

              if (!othersTyping) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.title} is typing...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _ChatStatusIndicator(
            isTranslating: _isTranslating,
            isUploading: _isUploading,
          ),
          _buildInput(),
          if (_showEmoji)
            RepaintBoundary(
              child: SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    setState(() {
                      _controller.text = _controller.text + emoji.emoji;
                    });
                  },
                  config: Config(
                    height: 256,
                    checkPlatformCompatibility: true,
                    viewOrderConfig: const ViewOrderConfig(),
                    emojiViewConfig: EmojiViewConfig(
                      columns: 7,
                      emojiSizeMax: 32,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFFF2F2F2),
                      loadingIndicator: const SizedBox.shrink(),
                      buttonMode: ButtonMode.MATERIAL,
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      indicatorColor: AppColors.primary,
                      iconColorSelected: AppColors.primary,
                      backspaceColor: AppColors.primary,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Color(0xFFF2F2F2),
                      buttonColor: Color(0xFFF2F2F2),
                      buttonIconColor: Colors.grey,
                    ),
                    searchViewConfig: const SearchViewConfig(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() {
                  _showEmoji = !_showEmoji;
                  if (_showEmoji) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              onPressed: _pickImage,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onTap: () {
                  if (_showEmoji) {
                    setState(() => _showEmoji = false);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppColors.surfaceLight,
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: () => _sendMessage(text: _controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStatusIndicator extends StatelessWidget {
  final bool isTranslating;
  final bool isUploading;

  const _ChatStatusIndicator({
    required this.isTranslating,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTranslating && !isUploading) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          isUploading ? 'Uploading image...' : 'Translating...',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

