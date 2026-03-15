import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/message.dart';
import '../../../../core/utils/web_helper.dart';

class FileContent extends StatefulWidget {
  final Message message;
  final bool isMe;

  const FileContent({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<FileContent> createState() => _FileContentState();
}

class _FileContentState extends State<FileContent> {
  bool _isDownloading = false;

  Future<void> _openFile() async {
    final url = widget.message.fileUrl;
    if (url == null) return;

    if (kIsWeb) {
      final url = widget.message.fileUrl;
      if (url != null) {
        try {
          // Attempt standard way first
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('UrlLauncher failed, using robust fallback: $e');
          // Fallback to direct window.open via conditional import
          openUrlWeb(url);
        }
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final fileName = widget.message.fileName ?? 'document';
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = io.File(filePath);

      if (!await file.exists()) {
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
      }

      await OpenFile.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : AppColors.textPrimary;
    final secondaryColor = widget.isMe ? Colors.white70 : AppColors.textTertiary;

    return InkWell(
      onTap: _isDownloading ? null : _openFile,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.white.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.insert_drive_file, 
                    color: widget.isMe ? Colors.white : AppColors.primary, 
                    size: 40),
                if (_isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.fileName ?? 'Document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    _formatSize(widget.message.fileSize),
                    style: TextStyle(color: secondaryColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
