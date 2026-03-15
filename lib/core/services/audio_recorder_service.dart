import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/services/logger_service.dart';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentPath;
  Stopwatch? _stopwatch;

  Future<bool> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        if (kIsWeb) {
          _currentPath = null; // Record package handles this on web
        } else {
          final tempDir = await getTemporaryDirectory();
          _currentPath = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        }
        
        final config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );
        await _audioRecorder.start(config, path: _currentPath ?? '');
        _stopwatch = Stopwatch()..start();
        Log.i('Recording started: ${_currentPath ?? "web_blob"}');
        return true;
      }
      return false;
    } catch (e, stack) {
      Log.e('Error starting recording: $e', e, stack);
      return false;
    }
  }

  Future<RecordResult?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _stopwatch?.stop();
      final duration = _stopwatch?.elapsed.inSeconds ?? 0;
      _stopwatch = null;
      
      Log.i('Recording stopped: $path, duration: $duration s');
      if (path == null) return null;
      return RecordResult(path: path, duration: duration);
    } catch (e, stack) {
      Log.e('Error stopping recording: $e', e, stack);
      return null;
    }
  }

  Future<bool> isRecording() => _audioRecorder.isRecording();

  void dispose() {
    _audioRecorder.dispose();
  }
}

class RecordResult {
  final String path;
  final int duration;

  RecordResult({required this.path, required this.duration});
}
