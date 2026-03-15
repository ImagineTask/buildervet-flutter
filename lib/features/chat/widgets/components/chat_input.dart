import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/theme/app_colors.dart';
import '../../../../models/enums/message_type.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../controllers/chat_controller.dart';

class ChatInput extends ConsumerStatefulWidget {
  final String conversationId;
  final String recipientLanguage;
  final String? recipientId;
  
  final Future<void> Function({
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    MessageType? forcedType,
  }) onSendMessage;

  final VoidCallback onStartRecording;
  final Future<void> Function() onStopRecording;

  const ChatInput({
    super.key,
    required this.conversationId,
    required this.recipientLanguage,
    this.recipientId,
    required this.onSendMessage,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePickerService _imagePickerService = ImagePickerService();
  bool _lastTypingStatus = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final isNotEmpty = _controller.text.isNotEmpty;
    if (isNotEmpty != _lastTypingStatus) {
      _lastTypingStatus = isNotEmpty;
      // You can implement typing status here or via a passed callback
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage({String? text}) {
    if (text != null && text.isNotEmpty) {
      widget.onSendMessage(text: text);
      _controller.clear();
    }
  }

  Future<void> _pickImage() async {
    final String? imagePath = await _imagePickerService.pickAndEditImage(context);
    if (imagePath != null) {
      widget.onSendMessage(imageUrl: imagePath);
    }
  }

  Future<void> _pickFile(MessageType type) async {
    try {
      FileType fileType = FileType.any;
      if (type == MessageType.video) fileType = FileType.video;
      if (type == MessageType.audio) fileType = FileType.audio;

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        widget.onSendMessage(
            fileUrl: kIsWeb ? null : pickedFile.path,
            fileName: pickedFile.name,
            fileSize: pickedFile.size,
            forcedType: type,
        );
      }
    } catch (e, stack) {
      Log.e('Error picking file: $e', e, stack);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: SafeArea(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            shrinkWrap: true,
            children: [
              _buildAttachmentItem(
                icon: Icons.image,
                label: 'Photo',
                color: Colors.white,
                iconColor: Colors.black87,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              _buildAttachmentItem(
                icon: Icons.videocam,
                label: 'Video',
                color: Colors.white,
                iconColor: Colors.black87,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(MessageType.video);
                },
              ),
              _buildAttachmentItem(
                icon: Icons.insert_drive_file,
                label: 'Document',
                color: Colors.white,
                iconColor: Colors.black87,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(MessageType.document);
                },
              ),
              _buildAttachmentItem(
                icon: Icons.audiotrack,
                label: 'Audio',
                color: Colors.white,
                iconColor: Colors.black87,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(MessageType.audio);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(ChatState state) {
    final message = state.replyToMessage;
    if (message == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          if (message.imageUrl != null || (message.type == MessageType.video && message.fileUrl != null))
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: NetworkImage(message.imageUrl ?? message.fileUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content.isEmpty ? '[Media]' : message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
            onPressed: () {
              ref.read(chatControllerProvider(widget.conversationId).notifier).cancelReply();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    final controller = ref.read(chatControllerProvider(widget.conversationId).notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyPreview(state),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      state.isVoiceMode ? Icons.keyboard : Icons.mic_none,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      controller.setVoiceMode(!state.isVoiceMode);
                      if (state.isVoiceMode) {
                        _focusNode.requestFocus();
                      } else {
                        _focusNode.unfocus();
                        controller.setShowEmoji(false);
                      }
                    },
                  ),
                  Expanded(
                    child: state.isVoiceMode
                        ? GestureDetector(
                            onLongPressStart: (_) => widget.onStartRecording(),
                            onLongPressEnd: (_) => widget.onStopRecording(),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                               decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Text(
                                state.isRecording ? 'Release to Send' : 'Hold to Talk',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          )
                        : TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onTap: () {
                              if (state.showEmoji) {
                                controller.setShowEmoji(false);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: '',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            maxLines: 5,
                            minLines: 1,
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      state.showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      controller.toggleEmoji();
                      if (state.showEmoji) {
                        _focusNode.requestFocus();
                      } else {
                        _focusNode.unfocus();
                        controller.setVoiceMode(false);
                      }
                    },
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: _showAttachmentMenu,
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => _sendMessage(text: _controller.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Send'),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (state.showEmoji)
            RepaintBoundary(
              child: SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _controller.text = _controller.text + emoji.emoji;
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
}
