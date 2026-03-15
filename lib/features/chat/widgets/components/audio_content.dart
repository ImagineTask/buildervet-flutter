import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../../models/message.dart';
import '../../../../models/enums/message_type.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../providers/auth_provider.dart';

class AudioContent extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;

  const AudioContent({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends ConsumerState<AudioContent> {
  // Use a shared player to save resources and ensure only one audio plays at a time
  static final AudioPlayer _sharedPlayer = AudioPlayer();
  
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isTranscribing = false;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() {
    _subscriptions.add(_sharedPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      if (_isCurrentPlayer) {
        setState(() => _duration = d);
      }
    }));
    
    _subscriptions.add(_sharedPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      if (_isCurrentPlayer) {
        setState(() => _position = p);
      }
    }));
    
    _subscriptions.add(_sharedPlayer.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      // If we are the current player, show our state. 
      // If someone else started playing, we should reset to stopped.
      setState(() {
        _playerState = _isCurrentPlayer ? s : PlayerState.stopped;
      });
    }));
  }

  bool get _isCurrentPlayer {
    final source = _sharedPlayer.source;
    if (source is UrlSource) {
      return source.url == widget.message.fileUrl;
    }
    return false;
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final url = widget.message.fileUrl;
    if (url == null) return;

    try {
      if (_isCurrentPlayer && _playerState == PlayerState.playing) {
        await _sharedPlayer.pause();
      } else {
        // If playing something else, stop it first (optional, play often replaces)
        await _sharedPlayer.play(UrlSource(url));
      }
    } catch (e, stack) {
      Log.e('Playback error: $e', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _transcribeVoice() async {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (currentUserId == null) return;
    
    // Check if we already have a transcription for this specific user
    if (_isTranscribing || (widget.message.transcriptions != null && widget.message.transcriptions!.containsKey(currentUserId))) {
      return;
    }

    final url = widget.message.fileUrl;
    if (url == null) return;

    setState(() => _isTranscribing = true);

    try {
      // 1. Get audio bytes
      final response = await http.get(Uri.parse(url));
      final audioBytes = response.bodyBytes;

      final sttService = ref.read(sttServiceProvider);
      final repository = ref.read(chatRepositoryProvider);
      
      // 2. Identify SENDER'S language (source of audio)
      // Use cached sourceLanguage if available in the message model
      String? sourceLanguageCode = widget.message.sourceLanguage;
      if (sourceLanguageCode == null) {
        final sender = await repository.getParticipant(widget.message.senderId);
        sourceLanguageCode = TranslationService.getLanguageForCountry(sender?.country);
      }
      
      // 3. Identify CURRENT USER'S language (target for display)
      final appUser = ref.read(appUserProvider).valueOrNull;
      final targetLanguageCode = TranslationService.getLanguageForCountry(appUser?.country);

      Log.i('Transcribing voice message (Lazy). Source($sourceLanguageCode) -> Target($targetLanguageCode)');

      // 4. Transcribe in SOURCE language
      String? transcript = await sttService.transcribe(
        bytes: audioBytes,
        languageCode: sourceLanguageCode,
      );

      if (transcript != null && transcript.isNotEmpty) {
        // 5. Translate if target language is different
        if (sourceLanguageCode != targetLanguageCode && targetLanguageCode != 'en') {
          try {
            final translationService = ref.read(translationServiceProvider);
            final tResult = await translationService.translate(transcript, targetLanguageCode);
            transcript = tResult.translatedText;
          } catch (e) {
            Log.e('Translation during on-demand transcribe failed: $e');
          }
        }

        // 6. Update Firestore with user-specific transcription
        if (transcript != null) {
          await repository.updateMessageTranscription(
            widget.message.conversationId,
            widget.message.id,
            currentUserId,
            transcript,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not recognize speech')),
          );
        }
      }
    } catch (e, stack) {
      Log.e('Transcription error: $e', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return "";
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final bool isVoice = widget.message.type == MessageType.voice;
    final contentColor = widget.isMe ? Colors.white : Colors.black87;
    
    if (!isVoice) {
      return _buildStandardPlayer();
    }

    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
    // Get transcription for THIS user. Fallback to 'legacy' for old messages.
    final transcription = widget.message.transcriptions?[currentUserId] 
        ?? widget.message.transcriptions?['legacy'];

    // WeChat style voice message
    final int durationSeconds = widget.message.duration ?? 0;
    final double minWidth = 70.0;
    final double maxWidth = 220.0;
    // Wider as it gets longer up to 60s
    final double width = minWidth + (durationSeconds > 60 ? 60 : durationSeconds) * (maxWidth - minWidth) / 60;
    
    final displayDuration = durationSeconds > 0 
        ? _formatDuration(Duration(seconds: durationSeconds))
        : "";

    return Column(
      crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.isMe) 
              _buildTranscriptionButton(contentColor, currentUserId),
            InkWell(
              onTap: _togglePlayback,
              child: Container(
                width: width,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!widget.isMe) 
                      Icon(
                        _playerState == PlayerState.playing ? Icons.pause : Icons.waves,
                        size: 18,
                        color: contentColor.withOpacity(0.7),
                      ),
                    const Spacer(),
                    Text(
                      displayDuration,
                      style: TextStyle(fontSize: 13, color: contentColor, fontWeight: FontWeight.w500),
                    ),
                    if (widget.isMe) ...[
                      const Spacer(),
                      Icon(
                        _playerState == PlayerState.playing ? Icons.pause : Icons.waves,
                        size: 18,
                        color: contentColor.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!widget.isMe)
              _buildTranscriptionButton(contentColor, currentUserId),
          ],
        ),
        if (_isTranscribing)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: contentColor.withOpacity(0.5),
              ),
            ),
          )
        else if (transcription != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: contentColor.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              transcription,
              style: TextStyle(
                fontSize: 13,
                color: contentColor.withOpacity(0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptionButton(Color color, String? userId) {
    // If THIS specific user already has a transcription, don't show the button
    if (userId == null || (widget.message.transcriptions != null && 
        (widget.message.transcriptions!.containsKey(userId) || widget.message.transcriptions!.containsKey('legacy')))) {
      return const SizedBox.shrink();
    }
    
    return IconButton(
      icon: Icon(
        Icons.subtitles_outlined,
        size: 16,
        color: color.withOpacity(0.4),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _transcribeVoice,
      tooltip: 'Convert to text',
    );
  }

  Widget _buildStandardPlayer() {
    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final textColor = widget.isMe ? Colors.white70 : AppColors.textSecondary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _playerState == PlayerState.playing
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: iconColor,
            size: 32,
          ),
          onPressed: _togglePlayback,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _isCurrentPlayer ? _position.inMilliseconds.toDouble() : 0,
                  max: _duration.inMilliseconds.toDouble() > 0 
                      ? _duration.inMilliseconds.toDouble() 
                      : (widget.message.duration?.toDouble() ?? 100),
                  onChanged: (value) {
                    if (_isCurrentPlayer) {
                      _sharedPlayer.seek(Duration(milliseconds: value.toInt()));
                    }
                  },
                  activeColor: iconColor,
                  inactiveColor: iconColor.withOpacity(0.3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _isCurrentPlayer ? _formatDuration(_position) : "00:00",
                style: TextStyle(color: textColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
