import 'package:flutter/material.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/message.dart';

class TextContent extends StatefulWidget {
  final Message message;
  final bool isMe;
  final TranslationService translationService;
  final String targetLanguage;

  const TextContent({
    super.key,
    required this.message,
    required this.isMe,
    required this.translationService,
    required this.targetLanguage,
  });

  @override
  State<TextContent> createState() => _TextContentState();
}

class _TextContentState extends State<TextContent> {
  String? _translatedText;
  bool _showTranslation = false;
  bool _isLoadingTranslation = false;

  @override
  void initState() {
    super.initState();
    _translatedText = widget.message.translatedContent;
    if (_translatedText != null && !widget.isMe) {
      _showTranslation = true;
    }
  }

  @override
  void didUpdateWidget(TextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.content != widget.message.content) {
      _translatedText = widget.message.translatedContent;
      _showTranslation = false;
      _isLoadingTranslation = false;
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

    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (widget.message.content.isNotEmpty)
          Text(
            widget.message.content,
            style: TextStyle(
              color: widget.isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
        if (canTranslate)
          GestureDetector(
            onTap: _translate,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
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
                      style: TextStyle(
                          fontSize: 12,
                          color: widget.isMe ? Colors.white.withOpacity(0.7) : AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        if (canTranslate && _showTranslation && _translatedText != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white.withOpacity(0.1) : AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _translatedText!,
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: widget.isMe ? Colors.white70 : AppColors.textPrimary),
            ),
          ),
      ],
    );
  }
}
