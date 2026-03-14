import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/message.dart';
import '../../../shared/widgets/images/full_screen_image_viewer.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final TranslationService translationService;
  final String targetLanguage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.translationService,
    required this.targetLanguage,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String? _translatedText;
  bool _showTranslation = false;
  bool _isLoadingTranslation = false;

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.content != widget.message.content) {
      _translatedText = widget.message.translatedContent;
      _showTranslation = false;
      _isLoadingTranslation = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _translatedText = widget.message.translatedContent;
    if (_translatedText != null && !widget.isMe) {
      _showTranslation = true;
    }
  }

  Future<void> _translate() async {
    if (_translatedText != null) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }

    setState(() => _isLoadingTranslation = true);
    try {
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
          _showTranslation = true;
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
    final bool canTranslate = widget.message.content.isNotEmpty &&
        (!widget.isMe || widget.message.translatedContent != null);
    return RepaintBoundary(
      child: Align(
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
                              child: widget.message.imageUrl!
                                          .startsWith('blob:') ||
                                      !widget.message.imageUrl!.startsWith('http')
                                  ? (kIsWeb
                                      ? Image.network(widget.message.imageUrl!)
                                      : Image.file(
                                          File(widget.message.imageUrl!)))
                                  : Image.network(
                                      widget.message.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 200,
                                      cacheWidth: 400,
                                      filterQuality: FilterQuality.low,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          height: 200,
                                          width: double.infinity,
                                          color: AppColors.surfaceLight,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        Log.e('Image Load Error: $error', error,
                                            stackTrace);
                                        return Container(
                                          height: 200,
                                          width: double.infinity,
                                          color: AppColors.surfaceLight,
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image,
                                                  color: AppColors.error,
                                                  size: 40),
                                              SizedBox(height: 8),
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
                                : (widget.isMe
                                    ? 'See sent translation'
                                    : 'See translation'),
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
      ),
    );
  }
}
