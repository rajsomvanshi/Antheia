import 'dart:async';
import '../models/models.dart';
import 'api_router.dart';
import 'package:uuid/uuid.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal — Journal Processing Service
// ═══════════════════════════════════════════════════════════════
// High-level service that orchestrates the full pipeline:
//   Raw voice text → AI restructure → Emotion detect → Weather
//   → Geocode → Create JournalEntry
//
// This is what the Processing Screen calls.
// ═══════════════════════════════════════════════════════════════

class ProcessingService {
  final ApiRouter _router = ApiRouter();
  final Uuid _uuid = const Uuid();

  // Callback for progress updates (0.0 → 1.0 and step label)
  void Function(double progress, String step)? onProgress;

  /// Full pipeline: transcribed text → structured JournalEntry
  Future<JournalEntry> processEntry({
    required String rawText,
    double? latitude,
    double? longitude,
  }) async {
    // ─── Step 1: Restructure text (0% → 40%) ───
    _reportProgress(0.0, 'Restructuring your story…');
    final restructured = await _router.execute(
      Feature.textRestructure,
      {'rawText': rawText},
    );
    _reportProgress(0.4, 'Detecting emotions…');

    // ─── Step 2: Emotion analysis (40% → 60%) ───
    final emotionResult = await _router.execute(
      Feature.emotionDetect,
      {'text': rawText},
    );
    _reportProgress(0.6, 'Fetching weather…');

    // ─── Step 3: Weather (60% → 75%) ───
    Map<String, dynamic>? weatherData;
    if (latitude != null && longitude != null) {
      try {
        final weatherResult = await _router.execute(
          Feature.weather,
          {'lat': latitude, 'lon': longitude},
        );
        weatherData = weatherResult.data;
      } catch (_) {
        // Weather is optional — skip on failure
      }
    }
    _reportProgress(0.75, 'Finding your location…');

    // ─── Step 4: Geocoding (75% → 90%) ───
    String? locationName;
    if (latitude != null && longitude != null) {
      try {
        final geoResult = await _router.execute(
          Feature.geocoding,
          {'lat': latitude, 'lon': longitude},
        );
        locationName = geoResult.data['city'] as String? ??
            geoResult.data['placeName'] as String?;
      } catch (_) {
        // Location is optional — skip on failure
      }
    }
    _reportProgress(0.9, 'Designing your layout…');

    // ─── Step 5: Assemble JournalEntry (90% → 100%) ───
    final data = restructured.data;
    final now = DateTime.now();

    // Parse sections from AI response
    final sectionsRaw = data['sections'] as List? ?? [];
    final sections = sectionsRaw.map((s) {
      final m = s as Map<String, dynamic>;
      return EntrySection(
        type: m['type'] as String? ?? 'paragraph',
        content: m['content'] as String? ?? '',
        headingLevel: m['headingLevel'] as int?,
      );
    }).toList();

    // Parse mood
    final moodStr = (data['mood'] as String? ??
        emotionResult.data['mood'] as String? ??
        'neutral')
        .toLowerCase();
    final mood = _parseMood(moodStr);

    // Parse tags
    final tagsRaw = data['tags'] as List? ?? [];
    final tags = tagsRaw.map((t) => t.toString()).toList();

    // Build the full entry content from sections
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
      durationMinutes: 0, // caller can set this
      isVoiceEntry: true,
      sections: sections,
    );

    _reportProgress(1.0, 'Finalizing…');
    return entry;
  }

  /// Quick emotion-only analysis (for mood picker suggestions)
  Future<String> detectMood(String text) async {
    try {
      final result = await _router.execute(
        Feature.emotionDetect,
        {'text': text},
      );
      return result.data['mood'] as String? ?? 'neutral';
    } catch (_) {
      return 'neutral';
    }
  }

  /// Quick weather fetch
  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    try {
      final result = await _router.execute(
        Feature.weather,
        {'latitude': lat, 'longitude': lon},
      );
      return result.data;
    } catch (_) {
      return null;
    }
  }

  /// Quick geocode
  Future<String?> fetchLocationName(double lat, double lon) async {
    try {
      final result = await _router.execute(
        Feature.geocoding,
        {'latitude': lat, 'longitude': lon},
      );
      return result.data['city'] as String? ??
          result.data['placeName'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ───

  void _reportProgress(double progress, String step) {
    onProgress?.call(progress, step);
  }

  Mood _parseMood(String s) {
    switch (s) {
      case 'happy':
        return Mood.happy;
      case 'calm':
        return Mood.calm;
      case 'nostalgic':
        return Mood.nostalgic;
      case 'sad':
        return Mood.sad;
      case 'energetic':
        return Mood.energetic;
      case 'anxious':
        return Mood.anxious;
      case 'grateful':
        return Mood.grateful;
      case 'creative':
        return Mood.creative;
      case 'romantic':
        return Mood.romantic;
      default:
        return Mood.neutral;
    }
  }
}
