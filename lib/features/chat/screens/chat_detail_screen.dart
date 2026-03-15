import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/message.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/components/chat_input.dart';
import '../widgets/components/message_list_view.dart';
import '../controllers/chat_controller.dart';


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
  
  bool _isUploading = false;
  String? _recipientCountry;
  String _recipientLanguage = 'en';
  String? _recipientId;
  String? _recipientAvatarUrl;
  String? _recipientInitials;
  bool _isTranslating = false;
  final FocusNode _focusNode = FocusNode();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'me';
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Me';

  bool _isDisposed = false;
  bool _isRecording = false;

  bool _lastTypingStatus = false;
  void _updateTypingStatus(bool isTyping) {
    if (_isDisposed || isTyping == _lastTypingStatus) return;
    _lastTypingStatus = isTyping;
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
      // Use ValueListenableBuilder in the UI instead of setState here for performance
      final isNotEmpty = _controller.text.isNotEmpty;
      _updateTypingStatus(isNotEmpty);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _updateTypingStatus(false);
    _focusNode.dispose();
    super.dispose();
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
              _recipientId = recipientId;
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

  Future<void> _sendMessage({
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    MessageType? forcedType,
    Uint8List? fileBytes,
    Map<String, String>? transcriptions,
    String? sourceLanguage,
  }) async {
    if ((text == null || text.trim().isEmpty) && 
        imageUrl == null && 
        fileUrl == null &&
        fileBytes == null) return;

    String? finalImageUrl = imageUrl;
    String? finalFileUrl = fileUrl;

    // Handle upload if it's a local path or bytes
    if (fileBytes != null || (imageUrl != null && !imageUrl.startsWith('http')) || 
        (fileUrl != null && !fileUrl.startsWith('http'))) {
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to upload files.')),
          );
        }
        return;
      }

      setState(() => _isUploading = true);
      try {
        final storageService = ref.read(storageLocatorProvider);
        
        Uint8List bytes;
        String name;
        String? contentType;

        if (fileBytes != null) {
          bytes = fileBytes;
          name = fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          final String uploadPath = imageUrl ?? fileUrl!;
          if (uploadPath.startsWith('data:')) {
            final base64String = uploadPath.split(',').last;
            bytes = base64Decode(base64String);
            name = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
            contentType = 'image/jpeg';
          } else if (kIsWeb) {
            // This case should be rare now as we prefer passing bytes for Web
            final response = await ref.read(httpProvider).get(Uri.parse(uploadPath));
            bytes = response.bodyBytes;
            name = fileName ?? 'web_${DateTime.now().millisecondsSinceEpoch}';
          } else {
            final file = File(uploadPath);
            name = fileName ?? p.basename(uploadPath);
            bytes = await file.readAsBytes();
          }
        }

        final String remotePath = imageUrl != null 
            ? 'chats/${widget.conversationId}/images/$name' 
            : 'chats/${widget.conversationId}/${forcedType?.name ?? 'files'}/$name';

        final uploadedUrl = await storageService.uploadFile(
          bytes: bytes,
          path: remotePath,
          contentType: contentType,
        );

        if (imageUrl != null) {
          finalImageUrl = uploadedUrl;
        } else {
          finalFileUrl = uploadedUrl;
        }
      } catch (e, stack) {
        Log.e('ChatDetail: Upload error: $e', e, stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
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

    if (content.isNotEmpty) {
      final appUser = ref.read(appUserProvider).valueOrNull;
      final senderLanguage = TranslationService.getLanguageForCountry(appUser?.country);

      if (senderLanguage != _recipientLanguage) {
        setState(() => _isTranslating = true);
        try {
          final translationService = ref.read(translationServiceProvider);
          final result = await translationService.translate(content, _recipientLanguage);
          translatedContent = result.translatedText;
          sourceLanguage = result.sourceLanguage;
        } catch (e) {
          Log.e('ChatDetail: Translation error: $e');
        }
        setState(() => _isTranslating = false);
      } else {
        Log.i('Skipping text translation: Same language ($senderLanguage -> $_recipientLanguage)');
        translatedContent = content;
        sourceLanguage = senderLanguage;
      }
    }

    MessageType type = MessageType.text;
    if (finalImageUrl != null) type = MessageType.image;
    if (finalFileUrl != null) {
      type = forcedType ?? MessageType.file;
    }

    final chatState = ref.read(chatControllerProvider(widget.conversationId));

    final newMessage = Message(
      id: '',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: type,
      content: content,
      translatedContent: translatedContent,
      sourceLanguage: sourceLanguage,
      sentAt: DateTime.now(),
      imageUrl: finalImageUrl,
      fileUrl: finalFileUrl,
      fileName: fileName,
      fileSize: fileSize,
      duration: duration,
      transcriptions: transcriptions,
      replyToId: chatState.replyToMessage?.id,
      replyToContent: chatState.replyToMessage?.content,
      replyToSenderName: chatState.replyToMessage?.senderName,
      replyToImageUrl: chatState.replyToMessage?.imageUrl ?? (chatState.replyToMessage?.type == MessageType.video ? chatState.replyToMessage?.fileUrl : null),
      replyToType: chatState.replyToMessage?.type.name,
    );

    await ref.read(chatRepositoryProvider).sendMessage(newMessage);
    ref.read(chatControllerProvider(widget.conversationId).notifier).cancelReply(); // Clear reply state after sending
    _controller.clear();
  }

  // Attachment logic moved to ChatInput component

  Future<void> _startRecording() async {
    final success = await ref.read(audioRecorderServiceProvider).startRecording();
    if (success) {
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final result = await ref.read(audioRecorderServiceProvider).stopRecording();
    setState(() => _isRecording = false);
    
    if (result != null) {
      final appUser = ref.read(appUserProvider).valueOrNull;
      final senderLanguage = TranslationService.getLanguageForCountry(appUser?.country);
      
      Map<String, String>? transcriptions;
      String? transcript;

      // 1. Always Transcribe in SENDER'S language (highest accuracy)
      Log.i('Transcribing voice message (Sender Language: $senderLanguage)');
      transcript = await ref.read(sttServiceProvider).transcribe(
        audioPath: result.path,
        languageCode: senderLanguage,
      );
      
      if (transcript != null && transcript.isNotEmpty) {
        // 2. Translate only if languages are different
        if (senderLanguage != _recipientLanguage) {
          Log.i('Different languages ($senderLanguage -> $_recipientLanguage), translating transcript...');
          try {
            final tResult = await ref.read(translationServiceProvider)
                .translate(transcript, _recipientLanguage);
            transcript = tResult.translatedText;
          } catch (e) {
            Log.e('Translation during record failed: $e');
          }
        } else {
          Log.i('Same language ($senderLanguage), skipping translation after STT to save API costs');
        }
        
        if (_recipientId != null && transcript != null) {
          transcriptions = {_recipientId!: transcript};
        }
      }
      
      _sendMessage(
        fileUrl: result.path,
        text: '', 
        forcedType: MessageType.voice,
        fileName: 'voice_msg.wav',
        duration: result.duration,
        transcriptions: transcriptions,
        sourceLanguage: senderLanguage, // Record source for lazy transcription later
      );
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: MessageListView(
                    conversationId: widget.conversationId,
                    userLanguage: userLanguage,
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
              ChatInput(
                conversationId: widget.conversationId,
                recipientLanguage: _recipientLanguage,
                recipientId: _recipientId,
                onSendMessage: _sendMessage,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
              ),
            ],
          ),
          if (_isRecording)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'Release to send',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          isUploading ? 'Uploading...' : 'Translating...',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

