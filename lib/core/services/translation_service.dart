import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/countries.dart';

class TranslationService {
  final String apiKey;
  static const String _baseUrl =
      'https://translation.googleapis.com/language/translate/v2';

  TranslationService({required this.apiKey});

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

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        body: json.encode({
          'q': text,
          'target': languageCode,
          'format': 'text',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translations = data['data']['translations'] as List;
        if (translations.isNotEmpty) {
          final translatedText = translations[0]['translatedText'] as String;
          final detectedSourceLanguage =
              translations[0]['detectedSourceLanguage'] as String? ?? 'unknown';

          return TranslationResult(
            translatedText: translatedText,
            sourceLanguage: detectedSourceLanguage,
            targetLanguage: languageCode,
            isSameLanguage: detectedSourceLanguage == languageCode,
          );
        }
      }
      return TranslationResult(
          translatedText: text,
          sourceLanguage: 'unknown',
          targetLanguage: languageCode);
    } catch (e) {
      print('Translation error: $e');
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
      final response = await http.post(
        Uri.parse('$_baseUrl/detect?key=$apiKey'),
        body: json.encode({'q': text}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detections = data['data']['detections'] as List;
        if (detections.isNotEmpty && (detections[0] as List).isNotEmpty) {
          return detections[0][0]['language'] as String;
        }
      }
      return 'unknown';
    } catch (e) {
      print('Detection error: $e');
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
