import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/service_locator.dart';
import '../../core/services/image_picker_service.dart';
import '../../core/services/translation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/enums/message_type.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/images/full_screen_image_viewer.dart';

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

  final TranslationService _translationService =
      TranslationService(apiKey: 'AIzaSyCLFlPZU-JhUlxkKiaYM8W0ju4IPrUQxqU');
  final ImagePickerService _imagePickerService = ImagePickerService();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'me';
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Me';

  @override
  void initState() {
    super.initState();
    _fetchRecipientInfo();
    _markAsRead();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      await ref.read(chatRepositoryProvider).markAsRead(widget.conversationId, _currentUserId);
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
              final names = recipient.name.split(' ');
              if (names.length >= 2) {
                _recipientInitials = (names[0][0] + names[1][0]).toUpperCase();
              } else {
                _recipientInitials = recipient.name.isNotEmpty ? recipient.name[0].toUpperCase() : '?';
              }
            });
            debugPrint(
                'Recipient country: $_recipientCountry, target language: $_recipientLanguage');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching recipient info: $e');
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
            const SnackBar(content: Text('You must be logged in to upload images.')),
          );
        }
        return;
      }

      setState(() => _isUploading = true);
      try {
        print('ChatDetail: Starting upload for $imageUrl by user ${user.uid}');
        final storageService = ref.read(storageLocatorProvider);
        Uint8List bytes;
        String fileName;

        if (imageUrl.startsWith('data:image')) {
          print('ChatDetail: Handling data URL');
          final base64String = imageUrl.split(',').last;
          bytes = base64Decode(base64String);
          fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else if (kIsWeb) {
          print('ChatDetail: Handling Web path/blob');
          final response =
              await ref.read(httpProvider).get(Uri.parse(imageUrl));
          bytes = response.bodyBytes;
          fileName = 'web_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          print('ChatDetail: Handling local file');
          final file = File(imageUrl);
          fileName = p.basename(imageUrl);
          bytes = await file.readAsBytes();
        }

        finalImageUrl = await storageService.uploadFile(
          bytes: bytes,
          path: 'chat_images/$fileName',
          contentType: 'image/jpeg',
        );
        print('ChatDetail: Upload successful: $finalImageUrl');
      } catch (e, stack) {
        String errorMessage = e.toString();
        if (errorMessage.contains('unauthorized')) {
          errorMessage = 'Upload failed: Unauthorized. Please check Firebase Storage rules.';
        }
        print('ChatDetail: Upload error: $errorMessage');
        print(stack);
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
        final result =
            await _translationService.translate(content, _recipientLanguage);
        translatedContent = result.translatedText;
        sourceLanguage = result.sourceLanguage;
        targetLanguage = result.targetLanguage;
      } catch (e) {
        debugPrint('Translation error: $e');
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
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
    final userLanguage = TranslationService.getLanguageForCountry(appUser?.country);

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
            child: StreamBuilder<List<Message>>(
              stream: ref
                  .watch(chatRepositoryProvider)
                  .getMessages(widget.conversationId, limit: _messageLimit > 0 ? _messageLimit : 10),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

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
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;
                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isMe: isMe,
                        translationService: _translationService,
                        targetLanguage: userLanguage,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_isTranslating || _isUploading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _isUploading ? 'Uploading image...' : 'Translating...',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          _buildInput(),
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
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              onPressed: _pickImage,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
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

class _MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final TranslationService translationService;
  final String targetLanguage;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.translationService,
    required this.targetLanguage,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String? _translatedText;
  bool _showTranslation = false;
  bool _isLoadingTranslation = false;
  bool _isSameLanguage = false;
  bool _hasCheckedLanguage = false;

  @override
  void didUpdateWidget(_MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.content != widget.message.content) {
      _translatedText = widget.message.translatedContent;
      _showTranslation = false;
      _isLoadingTranslation = false;
      _isSameLanguage = false;
      _hasCheckedLanguage = false;
      _checkLanguage();
    }
  }

  @override
  void initState() {
    super.initState();
    _translatedText = widget.message.translatedContent;
    _checkLanguage();
  }

  Future<void> _checkLanguage() async {
    if (widget.isMe || widget.message.content.isEmpty) return;

    final currentUserLang = widget.targetLanguage;

    try {
      final detectedLang = await widget.translationService
          .detectLanguage(widget.message.content);
      if (mounted) {
        setState(() {
          _isSameLanguage = detectedLang == currentUserLang;
          _hasCheckedLanguage = true;
          
          // Bidirectional Logic:
          // 1. If I'm the recipient and languages differ, auto-show translation
          if (!widget.isMe && !_isSameLanguage && _translatedText != null) {
            _showTranslation = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Language detection error: $e');
    }
  }

  Future<void> _translate() async {
    if (_translatedText != null) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }

    setState(() => _isLoadingTranslation = true);
    try {
      // If we are the sender, we might want to see what we sent to the recipient
      // If the message already has a translation, just toggle it
      if (widget.isMe && widget.message.translatedContent != null) {
        setState(() {
          _translatedText = widget.message.translatedContent;
          _showTranslation = !_showTranslation;
          _isLoadingTranslation = false;
        });
        return;
      }

      final result = await widget.translationService
          .translate(widget.message.content, widget.targetLanguage);
      if (mounted) {
        setState(() {
          _translatedText = result.translatedText;
          _isSameLanguage = result.isSameLanguage;
          _showTranslation = !_isSameLanguage;
          _isLoadingTranslation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
        setState(() => _isLoadingTranslation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should even show the translation button
    final bool canTranslate = 
        widget.message.content.isNotEmpty &&
        _hasCheckedLanguage &&
        (!_isSameLanguage || (widget.isMe && widget.message.translatedContent != null));
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message.type == MessageType.image &&
                      widget.message.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageViewer(
                                  imageUrl: widget.message.imageUrl!,
                                  title: widget.message.senderName,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: widget.message.imageUrl!,
                            child: widget.message.imageUrl!.startsWith('blob:') ||
                                    !widget.message.imageUrl!.startsWith('http')
                                ? (kIsWeb
                                    ? Image.network(widget.message.imageUrl!)
                                    : Image.file(File(widget.message.imageUrl!)))
                                : Image.network(
                                    widget.message.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                    // Optimize: don't load full quality for preview
                                    cacheWidth: 400, 
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: AppColors.surfaceLight,
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Image Load Error: $error');
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: AppColors.surfaceLight,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.broken_image, 
                                                color: AppColors.error, size: 40),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Failed to load image',
                                              style: TextStyle(
                                                color: AppColors.textTertiary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.message.content.isNotEmpty)
                    Text(
                      widget.message.content,
                      style: TextStyle(
                        color:
                            widget.isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
            ),
            if (canTranslate)
              GestureDetector(
                onTap: _translate,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: _isLoadingTranslation
                      ? const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          _showTranslation
                              ? 'Hide translation'
                              : (widget.isMe ? 'See sent translation' : 'See translation'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500),
                        ),
                ),
              ),
            if (canTranslate && _showTranslation && _translatedText != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _translatedText!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
