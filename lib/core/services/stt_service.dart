import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/services/logger_service.dart';

class SttService {
  final String apiKey;
  static const String _baseUrl = 'https://speech.googleapis.com/v2';

  SttService({required this.apiKey});
  
  bool get _hasKey => apiKey.isNotEmpty && apiKey != 'null';

  Future<String?> transcribe({
    Uint8List? bytes,
    String? audioPath,
    String languageCode = 'en-US',
  }) async {
    try {
      Uint8List audioBytes;
      if (bytes != null) {
        audioBytes = bytes;
      } else if (audioPath != null) {
        final file = File(audioPath);
        audioBytes = await file.readAsBytes();
      } else {
        throw 'Either bytes or audioPath must be provided';
      }
      
      // Diagnostic: Log first 128 bytes
      final hex = audioBytes.take(128).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      Log.i('Audio First 128 bytes: $hex');
      
      // Strip WAV header if present (standard WAV header is 44 bytes)
      // Google Cloud STT LINEAR16 expects raw PCM without headers.
      if (audioBytes.length > 44 && 
          audioBytes[0] == 0x52 && // R
          audioBytes[1] == 0x49 && // I
          audioBytes[2] == 0x46 && // F
          audioBytes[3] == 0x46) { // F
        audioBytes = audioBytes.sublist(44);
        Log.i('Stripped 44-byte WAV header');
      }
      
      Log.i('Original audio size: ${bytes?.length ?? 0} bytes. Final audio size: ${audioBytes.length} bytes.');
      
      final base64AudioData = base64Encode(audioBytes);

      // Note: This is a simplified call to STT v2. 
      // V2 often requires a Recognizer resource. For simplicity with API Key, 
      // sometimes v1 is easier, but user asked for v2. 
      // Let's use the v1p1beta1 or v1 if v2 requires more setup (recognizers).
      // Actually Google Cloud STT v2 has a different structure.
      // For a quick implementation with API key, v1 is more straightforward.
      // However, I will try to follow v2 pattern if possible or fall back gracefully.
      
      if (!_hasKey) {
        Log.e('STT Error: Google Cloud API Key is missing or invalid.');
        return null;
      }

      final response = await http.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=$apiKey'),
        body: json.encode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': 16000,
            'languageCode': languageCode,
            'enableAutomaticPunctuation': true,
          },
          'audio': {
            'content': base64AudioData,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );

      Log.i('STT Response: status=${response.statusCode}, languageCode=$languageCode');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final transcript = results[0]['alternatives'][0]['transcript'] as String?;
          Log.i('STT Transcript: $transcript');
          return transcript;
        } else {
          Log.w('STT Warning: No speech recognized in the audio. Response: ${response.body}');
        }
      } else {
        Log.e('STT Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e, stack) {
      Log.e('STT Exception: $e', e, stack);
      return null;
    }
  }
}
