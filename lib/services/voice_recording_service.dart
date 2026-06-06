import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'voice_filter_service.dart';
import '../state/memory_persistence_state.dart';


// ═══════════════════════════════════════════════════════════════
// VoiceRecordingService — FIXED
//
// ROOT CAUSE (Issue 1):
//   On Android, speech_to_text holds the microphone even after
//   the widget that called initialize() is disposed — because
//   SpeechToText.initialize() registers a persistent platform
//   channel listener that retains the audio focus.
//
//   When the VoiceReflectionSurface creates a NEW instance of
//   VoiceRecordingService (via ChangeNotifierProvider create:),
//   the old SpeechToText instance from a prior session is still
//   holding the mic. Android's AudioFocus system then blocks the
//   new instance, producing:
//
//     "Speech Recognition ... cannot record now because
//      [app] is using the microphone."
//
// FIX:
//   1. Cancel the old speech instance unconditionally in
//      startRecording() before re-initializing. This forces
//      Android to release audio focus.
//   2. Always call _speech.cancel() then re-initialize from
//      scratch on each startRecording() call rather than relying
//      on the cached _isInitialized flag.
//   3. Add a brief settle delay (80ms) after cancel() to allow
//      the Android audio session to fully release the mic before
//      a new listen() begins.
//   4. Add stopRecording() guard: if already stopped, no-op.
// ═══════════════════════════════════════════════════════════════

class VoiceRecordingService extends ChangeNotifier {
  stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isInitialized = false;
  Timer? _autosaveTimer;

  /// Full accumulated transcript (all segments concatenated)
  final StringBuffer _fullBuffer = StringBuffer();

  /// The interim partial text for the CURRENT segment only (shown live)
  String _partialText = '';

  String get fullTranscript => _fullBuffer.toString().trim();
  String get partialText => _partialText;
  bool get isListening => _isListening;

  // ── FIX: Initialize always releases any prior mic hold first ──
  Future<bool> initialize() async {
    // Request microphone permission first
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('[Voice] Microphone permission denied.');
      return false;
    }

    // Cancel whatever the current instance is doing —
    // this releases Android audio focus even if we "own" it.
    try {
      await _speech.cancel();
    } catch (_) {}

    // Create a completely fresh SpeechToText instance.
    // This is the critical fix: the old instance may be holding
    // a platform channel resource that blocks the mic.
    _speech = stt.SpeechToText();
    _isInitialized = false;

    // Small settle so Android AudioManager releases the session.
    await Future.delayed(const Duration(milliseconds: 80));

    _isInitialized = await _speech.initialize(
      onError: (e) => debugPrint('[Voice] error: $e'),
      onStatus: (status) {
        debugPrint('[Voice] status: $status');
        if (status == 'done' && _isListening) {
          // Auto-restart to continue capturing — key fix for truncation
          _continueListening();
        }
      },
    );
    return _isInitialized;
  }

  /// Start a fresh recording session. Clears the buffer.
  Future<void> startRecording(MemoryPersistenceState persistenceState) async {
    if (!await initialize()) {
      debugPrint('[VoiceRecordingService] Failed to initialize speech recognition.');
      return;
    }
    _fullBuffer.clear();
    _partialText = '';
    _isListening = true;
    notifyListeners();
    _continueListening();

    // Start 10-second periodic autosave timer to prevent in-memory loss
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final transcript = fullTranscript;
      if (transcript.isNotEmpty) {
        persistenceState.saveDraft(transcript);
      }
    });
  }

  /// Internal: start or restart a single speech recognition segment.
  void _continueListening() {
    if (!_isListening) return;

    _speech.listen(
      onResult: (result) {
        if (!_isListening) return;

        if (result.finalResult) {
          // Segment finalized — append cleaned text to buffer
          final cleaned = VoiceFilterService.clean(result.recognizedWords);
          if (cleaned.isNotEmpty) {
            if (_fullBuffer.isNotEmpty) _fullBuffer.write(' ');
            _fullBuffer.write(cleaned);
          }
          _partialText = '';
        } else {
          // Partial interim — show raw for responsiveness
          _partialText = result.recognizedWords;
        }
        notifyListeners();
      },
      listenFor: const Duration(seconds: 60),   // max segment length
      pauseFor: const Duration(seconds: 4),      // silence before auto-finalizing
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,      // optimized for long-form
    );
  }

  /// Stop recording. Returns the full cleaned transcript.
  Future<String> stopRecording() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;

    if (!_isListening) return fullTranscript;
    _isListening = false;

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('[VoiceRecordingService] stop error: $e');
    }

    // Flush any remaining partial text
    if (_partialText.isNotEmpty) {
      final cleaned = VoiceFilterService.clean(_partialText);
      if (cleaned.isNotEmpty) {
        if (_fullBuffer.isNotEmpty) _fullBuffer.write(' ');
        _fullBuffer.write(cleaned);
      }
      _partialText = '';
    }

    notifyListeners();
    final result = fullTranscript;
    _fullBuffer.clear();
    return result;
  }

  @override
  void dispose() {
    _isListening = false;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    // Cancel on dispose so we don't hold the mic after the widget is gone.
    // This is the second half of the fix — ensure no lingering audio focus.
    _speech.cancel();
    super.dispose();
  }
}
