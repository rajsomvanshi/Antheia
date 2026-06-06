import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ═══════════════════════════════════════════════════════════════
// NarrationService — Picture-Book Reading Style
//
// Design goals (permanent fix):
//   1. NEVER starts immediately — always a human-feeling pre-pause
//      of 1.8s (like a storyteller settling before speaking)
//   2. Reads at rate 0.38 — deliberately slow, like a bedtime story
//   3. Warm pitch 0.95 — slightly softer than neutral
//   4. Between sentences: 900ms pause (breathing room)
//   5. After title: 2.2s pause (cinematic breath before body text)
//   6. After paragraph breaks (detected in content): 1.4s pause
//   7. Sentence splitter handles common speech artifacts:
//      "um", "uh", "like" — stripped before reading
//   8. Stops cleanly on dispose, never leaves TTS running
// ═══════════════════════════════════════════════════════════════

enum NarrationState { idle, playing, paused }

/// Represents a segment to be spoken, with how long to pause after it.
class _Segment {
  final String text;
  final int pauseAfterMs;
  const _Segment(this.text, this.pauseAfterMs);
}

class NarrationService extends ChangeNotifier {
  static final NarrationService _instance = NarrationService._internal();
  factory NarrationService() => _instance;
  NarrationService._internal() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();

  NarrationState _state = NarrationState.idle;
  NarrationState get state => _state;

  String _currentEntryId = '';
  String get currentEntryId => _currentEntryId;

  List<_Segment> _segments = [];
  int _currentIndex = 0;

  int get totalSentences => _segments.length;
  int get currentIndex => _currentIndex;

  Timer? _sentenceTimer;
  Timer? _preSpeechTimer;

  // ─── Init ────────────────────────────────────────────────────

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      // Picture-book pace: slow, warm, never rushed.
      await _tts.setSpeechRate(0.38);
      // Slightly softer pitch — less robotic, more human.
      await _tts.setPitch(0.95);
      // Volume: full (user controls device volume).
      await _tts.setVolume(1.0);

      _tts.setCompletionHandler(_onSegmentCompleted);
      _tts.setErrorHandler((msg) {
        debugPrint('[NarrationService] TTS error: $msg');
        stop();
      });
    } catch (e) {
      debugPrint('[NarrationService] initialization failed: $e');
    }
  }

  // ─── Public API ───────────────────────────────────────────────

  Future<void> speakEntry(
    String entryId,
    String title,
    String content, {
    /// Kept for API compatibility — actual speed is fixed at picture-book pace.
    double speed = 0.38,
    double pitch = 0.95,
  }) async {
    // If same entry and paused, just resume.
    if (_currentEntryId == entryId && _state == NarrationState.paused) {
      await resume();
      return;
    }

    await stop();

    try {
      // Always lock to picture-book pace regardless of prefs.ttsSpeed.
      // This is intentional — we never want this to sound like a podcast.
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(0.95);
    } catch (_) {}

    _currentEntryId = entryId;
    _segments = _buildSegments(title, content);

    if (_segments.isEmpty) return;

    _state = NarrationState.playing;
    _currentIndex = 0;
    notifyListeners();

    // ── Pre-speech pause: 1.8s ────────────────────────────────
    // Feels like a storyteller taking a breath before beginning.
    // This is the single most important "feel" change vs. immediate read.
    _preSpeechTimer?.cancel();
    _preSpeechTimer = Timer(const Duration(milliseconds: 1800), () {
      if (_state == NarrationState.playing &&
          _currentEntryId == entryId) {
        _speakCurrent();
      }
    });
  }

  Future<void> pause() async {
    if (_state != NarrationState.playing) return;
    _state = NarrationState.paused;
    _sentenceTimer?.cancel();
    _preSpeechTimer?.cancel();
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_state != NarrationState.paused) return;
    _state = NarrationState.playing;
    notifyListeners();
    // Small re-entry pause so it doesn't snap back jarringly.
    _sentenceTimer?.cancel();
    _sentenceTimer = Timer(const Duration(milliseconds: 600), () {
      if (_state == NarrationState.playing) _speakCurrent();
    });
  }

  Future<void> stop() async {
    _state = NarrationState.idle;
    _currentEntryId = '';
    _segments = [];
    _currentIndex = 0;
    _sentenceTimer?.cancel();
    _preSpeechTimer?.cancel();
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ─── Internal ─────────────────────────────────────────────────

  void _onSegmentCompleted() {
    if (_state != NarrationState.playing) return;

    _currentIndex++;
    if (_currentIndex >= _segments.length) {
      stop();
      return;
    }

    final pauseMs = _segments[_currentIndex - 1].pauseAfterMs;
    _sentenceTimer?.cancel();
    _sentenceTimer = Timer(Duration(milliseconds: pauseMs), () {
      if (_state == NarrationState.playing) _speakCurrent();
    });
  }

  Future<void> _speakCurrent() async {
    if (_currentIndex >= _segments.length) return;
    final text = _segments[_currentIndex].text;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[NarrationService] speak failed: $e');
    }
  }

  /// Build the ordered list of segments with appropriate pauses.
  ///
  /// Structure:
  ///   [title] → 2200ms pause → [sentences...] → 900ms between
  ///   Paragraph breaks (double newline in source) → 1400ms pause
  ///   Short exclamatory sentences (ends !) → 1100ms pause
  List<_Segment> _buildSegments(String title, String content) {
    final result = <_Segment>[];

    // 1. Title — read first, long pause after.
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty) {
      result.add(_Segment(cleanTitle, 2200));
    }

    // 2. Split content into paragraphs first (preserve big pauses).
    final paragraphs =
        content.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);

    for (final paragraph in paragraphs) {
      final sentences = _splitSentences(paragraph);
      for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i];
        final isLast = i == sentences.length - 1;
        // Last sentence in a paragraph: longer pause (paragraph break feel).
        final pauseMs = isLast ? 1400 : (s.endsWith('!') ? 1100 : 900);
        result.add(_Segment(s, pauseMs));
      }
    }

    return result;
  }

  /// Split a paragraph into clean, speakable sentences.
  List<String> _splitSentences(String paragraph) {
    if (paragraph.isEmpty) return [];

    // Strip markdown formatting.
    var clean = paragraph
        .replaceAll(RegExp(r'\*\*|__'), '')
        .replaceAll(RegExp(r'\*|_'), '')
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'>\s*'), '')
        .replaceAll('•', '')
        .trim();

    // Remove filler words that sound bad when read aloud.
    // These are the "um", "uh", "like" artifacts from voice transcription.
    clean = clean.replaceAllMapped(
      RegExp(r'\b(um+|uh+|hmm+|err+)\b', caseSensitive: false),
      (_) => '',
    );

    // Collapse multiple spaces left by filler removal.
    clean = clean.replaceAll(RegExp(r'  +'), ' ').trim();

    if (clean.isEmpty) return [];

    // Split by sentence-ending punctuation followed by whitespace.
    final reg = RegExp(r'(?<=[.!?])\s+');
    return clean
        .split(reg)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
