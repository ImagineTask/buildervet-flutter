import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/message.dart';
import '../../../../shared/widgets/images/full_screen_image_viewer.dart';

class ImageContent extends StatelessWidget {
  final Message message;

  const ImageContent({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (message.imageUrl == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(
                imageUrl: message.imageUrl!,
                title: message.senderName,
              ),
            ),
          );
        },
        child: Hero(
          tag: message.imageUrl!,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 250,
              maxHeight: 400,
            ),
            child: _buildImageWidget(),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    final imageUrl = message.imageUrl!;
    final bool isLocal = imageUrl.startsWith('blob:') || !imageUrl.startsWith('http');

    if (isLocal) {
      if (kIsWeb) {
        return Image.network(imageUrl, fit: BoxFit.contain);
      } else {
        return Image.file(io.File(imageUrl), fit: BoxFit.contain);
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        width: 250,
        height: 200,
        color: AppColors.surfaceLight,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) {
        Log.e('Image Load Error: $error');
        return Container(
          width: 250,
          height: 200,
          color: AppColors.surfaceLight,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: AppColors.error, size: 40),
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
    );
  }
}
