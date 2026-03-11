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
import '../../models/enums/message_type.dart';
import '../../models/message.dart';
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

  final TranslationService _translationService =
      TranslationService(apiKey: 'your_api_key');
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
        final storageService = ref.read(storageServiceProvider);
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

        finalImageUrl = await storageService.uploadImage(bytes, fileName);
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

    if (content.isNotEmpty) {
      setState(() => _isTranslating = true);
      try {
        // Translate to the recipient's language based on their country
        final result =
            await _translationService.translate(content, _recipientLanguage);
        translatedContent = result.translatedText;
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
      sentAt: DateTime.now(),
      imageUrl: finalImageUrl,
    );

    await ref.read(chatRepositoryProvider).sendMessage(newMessage);
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final String? imagePath =
        await _imagePickerService.pickAndEditImage(context);
    if (imagePath != null) {
      _sendMessage(imageUrl: imagePath);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(widget.title[0],
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.primary)),
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
                  .getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                      child: Text('No messages yet',
                          style: TextStyle(color: AppColors.textTertiary)));
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      translationService: _translationService,
                    );
                  },
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

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.translationService,
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
  void initState() {
    super.initState();
    _translatedText = widget.message.translatedContent;
    _checkLanguage();
  }

  Future<void> _checkLanguage() async {
    if (widget.isMe || widget.message.content.isEmpty) return;

    // Assume current user's language is English ('en') for this demo
    const currentUserLang = 'en';

    try {
      final detectedLang = await widget.translationService
          .detectLanguage(widget.message.content);
      if (mounted) {
        setState(() {
          _isSameLanguage = detectedLang == currentUserLang;
          _hasCheckedLanguage = true;
          // If we already have a translation and languages differ, show it
          if (_translatedText != null && !_isSameLanguage) {
            _showTranslation = false;
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
      final result = await widget.translationService
          .translate(widget.message.content, 'en');
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
    final bool canTranslate = !widget.isMe &&
        widget.message.content.isNotEmpty &&
        _hasCheckedLanguage &&
        !_isSameLanguage;
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
                              : 'See translation',
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
