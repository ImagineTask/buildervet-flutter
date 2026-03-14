import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/countries.dart';
import 'logger_service.dart';

class TranslationService {
  final String apiKey;
  static const String _baseUrl =
      'https://translation.googleapis.com/language/translate/v2';

  TranslationService({required this.apiKey});

  final Map<String, TranslationResult> _cache = {};

  /// Translates text to the target language.
  /// Returns the translated text, or the original text if translation fails.
  /// Also returns the detected source language if available.
  Future<TranslationResult> translate(
      String text, String targetLanguage) async {
    if (text.isEmpty || targetLanguage.isEmpty) {
      return TranslationResult(
          translatedText: text,
          sourceLanguage: 'unknown',
          targetLanguage: targetLanguage);
    }

    final languageCode = targetLanguage.split('-').first.toLowerCase();
    final cacheKey = '${languageCode}_$text';

    if (_cache.containsKey(cacheKey)) {
      Log.i('Translation Cache Hit: key="$cacheKey"');
      return _cache[cacheKey]!;
    }

    try {
      Log.i('Translation Request: text="$text", target="$languageCode"');
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        body: json.encode({
          'q': text,
          'target': languageCode,
          'format': 'text',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      Log.i('Translation Response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translations = data['data']['translations'] as List;
        if (translations.isNotEmpty) {
          final translatedText = translations[0]['translatedText'] as String;
          final detectedSourceLanguage =
              translations[0]['detectedSourceLanguage'] as String? ?? 'unknown';

          Log.i('Translation Result: translated="$translatedText", detected="$detectedSourceLanguage"');

          final result = TranslationResult(
            translatedText: translatedText,
            sourceLanguage: detectedSourceLanguage,
            targetLanguage: languageCode,
            isSameLanguage: detectedSourceLanguage == languageCode,
          );
          
          _cache[cacheKey] = result;
          return result;
        }
      }
      return TranslationResult(
          translatedText: text,
          sourceLanguage: 'unknown',
          targetLanguage: languageCode);
    } catch (e, stack) {
      Log.e('Translation error: $e', e, stack);
      return TranslationResult(
          translatedText: text,
          sourceLanguage: 'unknown',
          targetLanguage: languageCode);
    }
  }

  /// Detects the language of the given text.
  Future<String> detectLanguage(String text) async {
    if (text.isEmpty) return 'unknown';

    try {
      Log.i('Detection Request: text="$text"');
      final response = await http.post(
        Uri.parse('$_baseUrl/detect?key=$apiKey'),
        body: json.encode({'q': text}),
        headers: {'Content-Type': 'application/json'},
      );

      Log.i('Detection Response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detections = data['data']['detections'] as List;
        if (detections.isNotEmpty && (detections[0] as List).isNotEmpty) {
          final language = detections[0][0]['language'] as String;
          Log.i('Detection Result: language="$language"');
          return language;
        }
      }
      return 'unknown';
    } catch (e, stack) {
      Log.e('Detection error: $e', e, stack);
      return 'unknown';
    }
  }

  /// Map of country codes (ISO 3166-1 alpha-2) to language codes (ISO 639-1).
  /// Based on major languages for each country.
  static final Map<String, String> countryToLanguage =
      Countries.countryToLanguageMap;

  /// Gets the language code for a given country code.
  static String getLanguageForCountry(String? countryCode) {
    final code = countryCode ?? 'GB';
    return countryToLanguage[code.toUpperCase()] ?? 'en';
  }
}

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final bool isSameLanguage;

  TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isSameLanguage = false,
  });
}
