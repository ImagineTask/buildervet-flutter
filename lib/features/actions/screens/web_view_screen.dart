import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Generic web view screen for web-based actions.
///
/// TODO: Replace with real WebView using webview_flutter package.
/// For now shows a placeholder with the URL and an "Open in Browser" option.
/// To enable real WebView:
///   1. Add to pubspec.yaml: webview_flutter: ^4.4.0
///   2. Replace the body with WebViewWidget
class WebViewScreen extends StatelessWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Open in external browser
              // url_launcher: launchUrl(Uri.parse(url))
            },
            icon: const Icon(Icons.open_in_browser),
          ),
          IconButton(
            onPressed: () {
              // TODO: Refresh WebView
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.language,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  url,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'WebView will load here.\nAdd webview_flutter to pubspec.yaml to enable.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Launch URL externally
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open in Browser'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
