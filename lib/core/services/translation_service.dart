import 'dart:convert';

import 'package:http/http.dart' as http;

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
      return TranslationResult(translatedText: text, sourceLanguage: 'unknown');
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
            isSameLanguage: detectedSourceLanguage == languageCode,
          );
        }
      }
      return TranslationResult(translatedText: text, sourceLanguage: 'unknown');
    } catch (e) {
      print('Translation error: $e');
      return TranslationResult(translatedText: text, sourceLanguage: 'unknown');
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
  static final Map<String, String> countryToLanguage = {
    // --- A ---
    'AE': 'ar', // United Arab Emirates (Arabic)
    'AR': 'es', // Argentina (Spanish)
    'AT': 'de', // Austria (German)
    'AU': 'en', // Australia (English)

    // --- B ---
    'BD': 'bn', // Bangladesh (Bengali)
    'BE': 'nl', // Belgium (Dutch is majority, French is 'fr')
    'BR': 'pt', // Brazil (Portuguese)

    // --- C ---
    'CA': 'en', // Canada (English, French is 'fr')
    'CH': 'de', // Switzerland (German is majority, also 'fr', 'it')
    'CL': 'es', // Chile (Spanish)
    'CN': 'zh-CN', // China (Simplified Chinese - API prefers zh-CN)
    'CO': 'es', // Colombia (Spanish)
    'CZ': 'cs', // Czech Republic (Czech)

    // --- D ---
    'DE': 'de', // Germany (German)
    'DK': 'da', // Denmark (Danish)

    // --- E ---
    'EG': 'ar', // Egypt (Arabic)
    'ES': 'es', // Spain (Spanish)

    // --- F ---
    'FI': 'fi', // Finland (Finnish)
    'FR': 'fr', // France (French)

    // --- G ---
    'GB': 'en', // United Kingdom (English)
    'GR': 'el', // Greece (Greek)

    // --- H ---
    'HK': 'zh-TW', // Hong Kong (Traditional Chinese)
    'HU': 'hu', // Hungary (Hungarian)

    // --- I ---
    'ID': 'id', // Indonesia (Indonesian)
    'IE': 'en', // Ireland (English)
    'IL': 'he', // Israel (Hebrew - API also accepts 'iw')
    'IN': 'hi', // India (Hindi, though heavily multi-lingual)
    'IR': 'fa', // Iran (Persian/Farsi)
    'IT': 'it', // Italy (Italian)

    // --- J ---
    'JP': 'ja', // Japan (Japanese)

    // --- K ---
    'KR': 'ko', // South Korea (Korean)

    // --- M ---
    'MX': 'es', // Mexico (Spanish)
    'MY': 'ms', // Malaysia (Malay)

    // --- N ---
    'NL': 'nl', // Netherlands (Dutch)
    'NO': 'no', // Norway (Norwegian)
    'NZ': 'en', // New Zealand (English)

    // --- P ---
    'PE': 'es', // Peru (Spanish)
    'PH': 'tl', // Philippines (Tagalog - API uses 'tl' for Filipino)
    'PK': 'ur', // Pakistan (Urdu)
    'PL': 'pl', // Poland (Polish)
    'PT': 'pt', // Portugal (Portuguese)

    // --- R ---
    'RO': 'ro', // Romania (Romanian)
    'RU': 'ru', // Russia (Russian)

    // --- S ---
    'SA': 'ar', // Saudi Arabia (Arabic)
    'SE': 'sv', // Sweden (Swedish)
    'SG': 'en', // Singapore (English/Chinese)

    // --- T ---
    'TH': 'th', // Thailand (Thai)
    'TR': 'tr', // Turkey (Turkish)
    'TW': 'zh-TW', // Taiwan (Traditional Chinese)

    // --- U ---
    'UA': 'uk', // Ukraine (Ukrainian)
    'US': 'en', // United States (English)

    // --- V ---
    'VE': 'es', // Venezuela (Spanish)
    'VN': 'vi', // Vietnam (Vietnamese)

    // --- Z ---
    'ZA': 'en', // South Africa (English is common lingua franca)
  };

  /// Gets the language code for a given country code.
  static String getLanguageForCountry(String? countryCode) {
    if (countryCode == null) return 'en'; // Default to English
    return countryToLanguage[countryCode.toUpperCase()] ?? 'en';
  }
}

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final bool isSameLanguage;

  TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    this.isSameLanguage = false,
  });
}
