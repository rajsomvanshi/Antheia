import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'reflection_pipeline.dart';
import 'package:uuid/uuid.dart';

// ═══════════════════════════════════════════════════════════════
// Antheia — Journal Processing Service
//
// FIX: Added per-step 15-second timeout to every _router.execute()
// call. Previously, any stalled network request (no internet,
// Groq quota, Gemini unavailable) would hang the Future forever,
// leaving ProcessingScreen stuck on "Connecting this reflection..."
//
// Each step now races against a 15s TimeoutException. The outer
// try/catch in processVoiceEntry() catches it and falls back to a
// plain local entry — so the user's words are ALWAYS preserved.
// ═══════════════════════════════════════════════════════════════

/// How long each AI step may run before we give up on it.
const _kStepTimeout = Duration(seconds: 15);

/// How long the ENTIRE enrichment pipeline may run before abort.
/// (4 steps × 15s + margin)
const _kPipelineTimeout = Duration(seconds: 30);

class MemoryEnrichmentService {
  final ReflectionPipeline _router = ReflectionPipeline();
  final Uuid _uuid = const Uuid();

  /// Callback for progress updates (0.0 → 1.0 and step label).
  void Function(double progress, String step)? onProgress;

  /// Full pipeline: transcribed text → structured JournalEntry.
  ///
  /// Throws if pipeline takes > [_kPipelineTimeout] or if any
  /// individual step exceeds [_kStepTimeout].
  Future<JournalEntry> processEntry({
    required String rawText,
    double? latitude,
    double? longitude,
    String? tone,
    String? formatting,
  }) async {
    // Hard outer timeout: entire pipeline must complete in 30s.
    return Future<JournalEntry>(() async {
      // ─── Step 1: Restructure text (0% → 35%) ───────────────
      _reportProgress(0.0, 'Restructuring your story…');
      final restructured = await _router
          .execute(
            Feature.textRestructure,
            {
              'rawText': rawText,
              'tone': tone,
              'formatting': formatting,
            },
          )
          .timeout(
            _kStepTimeout,
            onTimeout: () => throw TimeoutException(
              'Text restructure timed out after 15s',
              _kStepTimeout,
            ),
          );

      // ─── Step 1b: Generate Personalized Reflection (35% → 50%) ───
      _reportProgress(0.35, 'Reflecting on your words…');
      String reflectionText = '';
      try {
        final reflectionResult = await _router
            .execute(
              Feature.reflect,
              {
                'transcript': rawText,
                'tone': tone,
              },
            )
            .timeout(
              _kStepTimeout,
              onTimeout: () => throw TimeoutException(
                'Personalized reflection timed out after 15s',
                _kStepTimeout,
              ),
            );
        reflectionText = reflectionResult.data['reflection'] as String? ?? '';
      } catch (e) {
        debugPrint('[MemoryEnrichmentService] Reflection failed (best effort): $e');
      }

      _reportProgress(0.5, 'Detecting emotions…');

      // ─── Step 2: Emotion analysis (50% → 65%) ──────────────
      final emotionResult = await _router
          .execute(Feature.emotionDetect, {'text': rawText})
          .timeout(
            _kStepTimeout,
            onTimeout: () => throw TimeoutException(
              'Emotion detection timed out after 15s',
              _kStepTimeout,
            ),
          );
      _reportProgress(0.65, 'Fetching weather…');

      // ─── Step 3: Weather (65% → 75%) — optional ────────────
      Map<String, dynamic>? weatherData;
      if (latitude != null && longitude != null) {
        try {
          final weatherResult = await _router
              .execute(Feature.weather, {'lat': latitude, 'lon': longitude})
              .timeout(_kStepTimeout);
          weatherData = weatherResult.data;
        } catch (_) {
          // Weather is optional — skip on failure or timeout.
        }
      }
      _reportProgress(0.75, 'Finding your location…');

      // ─── Step 4: Geocoding (75% → 90%) — optional ──────────
      String? locationName;
      if (latitude != null && longitude != null) {
        try {
          final geoResult = await _router
              .execute(
                  Feature.geocoding, {'lat': latitude, 'lon': longitude})
              .timeout(_kStepTimeout);
          locationName = geoResult.data['city'] as String? ??
              geoResult.data['placeName'] as String?;
        } catch (_) {
          // Location is optional — skip on failure or timeout.
        }
      }
      _reportProgress(0.9, 'Designing your layout…');

      // ─── Step 5: Assemble JournalEntry (90% → 100%) ────────
      final data = restructured.data;
      final now = DateTime.now();

      final sectionsRaw = data['sections'] as List? ?? [];
      final sections = sectionsRaw.map((s) {
        final m = s as Map<String, dynamic>;
        return EntrySection(
          type: m['type'] as String? ?? 'paragraph',
          content: m['content'] as String? ?? '',
          headingLevel: m['headingLevel'] as int?,
        );
      }).toList();

      if (reflectionText.isNotEmpty) {
        sections.add(EntrySection(
          type: 'reflection',
          content: reflectionText,
        ));
      }

      final moodStr = (data['mood'] as String? ??
              emotionResult.data['mood'] as String? ??
              'neutral')
          .toLowerCase();
      final mood = _parseMood(moodStr);

      final tagsRaw = data['tags'] as List? ?? [];
      final tags = tagsRaw.map((t) => t.toString()).toList();

      final contentBuffer = StringBuffer();
      for (final section in sections) {
        if (section.type == 'heading') {
          contentBuffer.writeln('\n${section.content}\n');
        } else if (section.type == 'bullet') {
          contentBuffer.writeln('• ${section.content}');
        } else if (section.type == 'quote') {
          contentBuffer.writeln('> ${section.content}');
        } else {
          contentBuffer.writeln(section.content);
        }
      }

      final entry = JournalEntry(
        id: _uuid.v4(),
        title: data['title'] as String? ?? 'Untitled Entry',
        content: contentBuffer.toString().trim(),
        createdAt: now,
        updatedAt: now,
        mood: mood,
        location: locationName,
        temperature: weatherData?['temperature'] is num
            ? (weatherData!['temperature'] as num).toDouble()
            : null,
        weatherIcon: weatherData?['icon'] as String?,
        tags: tags,
        durationMinutes: 0,
        isVoiceEntry: true,
        sections: sections,
      );

      _reportProgress(1.0, 'Finalizing…');
      return entry;
    }).timeout(
      _kPipelineTimeout,
      onTimeout: () => throw TimeoutException(
        'Full enrichment pipeline timed out after 30s',
        _kPipelineTimeout,
      ),
    );
  }

  /// Quick emotion-only analysis (for mood picker suggestions).
  Future<String> detectMood(String text) async {
    try {
      final result = await _router
          .execute(Feature.emotionDetect, {'text': text})
          .timeout(_kStepTimeout);
      return result.data['mood'] as String? ?? 'neutral';
    } catch (_) {
      return 'neutral';
    }
  }

  /// Quick weather fetch.
  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    try {
      final result = await _router
          .execute(Feature.weather, {'latitude': lat, 'longitude': lon})
          .timeout(_kStepTimeout);
      return result.data;
    } catch (_) {
      return null;
    }
  }

  /// Quick geocode.
  Future<String?> fetchLocationName(double lat, double lon) async {
    try {
      final result = await _router
          .execute(
              Feature.geocoding, {'latitude': lat, 'longitude': lon})
          .timeout(_kStepTimeout);
      return result.data['city'] as String? ??
          result.data['placeName'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────

  void _reportProgress(double progress, String step) {
    onProgress?.call(progress, step);
  }

  Mood _parseMood(String s) {
    switch (s) {
      case 'happy':      return Mood.happy;
      case 'calm':       return Mood.calm;
      case 'nostalgic':  return Mood.nostalgic;
      case 'sad':        return Mood.sad;
      case 'energetic':  return Mood.energetic;
      case 'anxious':    return Mood.anxious;
      case 'grateful':   return Mood.grateful;
      case 'creative':   return Mood.creative;
      case 'romantic':   return Mood.romantic;
      default:           return Mood.neutral;
    }
  }
}
