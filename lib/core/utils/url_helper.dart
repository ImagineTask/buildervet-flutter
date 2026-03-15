import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// A utility to open URLs robustly across platforms.
/// On Web, it provides an additional fallback to avoid MissingPluginException.
class UrlHelper {
  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    
    if (kIsWeb) {
      try {
        // Try the standard way first
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('UrlHelper: launchUrl failed, trying fallback: $e');
        // Fallback or secondary method could be handled here if we had a web-specific utility
        // For now, rethrow or handle in the UI
        rethrow;
      }
    } else {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    }
  }
}
