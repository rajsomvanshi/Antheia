import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'api_config.dart';

// ═══════════════════════════════════════════════════════════════
// ReflectionPipeline — UPGRADED & FIXED
//
// ISSUE 2 FIX: Dynamic Personalization System
//
// Previously: one generic prompt for every transcript.
//
// Now:
//   1. Classifies the transcript tone using keyword + signal scoring.
//   2. Selects one of 6 reflection modes based on detected intent.
//   3. Each mode has a distinct prompt optimized for its emotional register.
//   4. Falls back gracefully if AI is unavailable.
//
// Reflection Modes:
//   • Reflection    — thoughtful memories, stories, life observations
//   • Emotional     — grief, heartbreak, anxiety, overwhelm
//   • Gratitude     — positive experiences, appreciation, joy
//   • Growth        — lessons, learning, self-improvement
//   • Vent          — frustration, anger, venting, complaints
//   • LifeUpdate    — casual diary narration, events, life news
// ═══════════════════════════════════════════════════════════════

enum ReflectionMode {
  reflection,
  emotional,
  gratitude,
  growth,
  vent,
  lifeUpdate,
}

enum Feature {
  textRestructure,
  emotionDetect,
  weather,
  geocoding,
  speechToText,
  reflect,
  title,
  tags,
  mood,
}

class ApiResult {
  final bool success;
  final Map<String, dynamic> data;
  final String provider;
  final String? error;

  const ApiResult({
    this.success = true,
    required this.data,
    this.provider = 'unknown',
    this.error,
  });

  factory ApiResult.failure(String error, String provider) =>
      ApiResult(success: false, data: const {}, provider: provider, error: error);
}

class ReflectionPipeline {
  static final ReflectionPipeline _instance = ReflectionPipeline._internal();
  factory ReflectionPipeline() => _instance;
  ReflectionPipeline._internal();

  // ── Tone Classification ────────────────────────────────────

  /// Detects the most appropriate reflection mode from transcript content.
  /// Uses weighted keyword scoring across 6 emotional categories.
  static ReflectionMode classifyTranscript(String transcript) {
    final lower = transcript.toLowerCase();
    final scores = <ReflectionMode, double>{
      ReflectionMode.reflection: 0,
      ReflectionMode.emotional: 0,
      ReflectionMode.gratitude: 0,
      ReflectionMode.growth: 0,
      ReflectionMode.vent: 0,
      ReflectionMode.lifeUpdate: 0,
    };

    // ── Vent signals (high weight — strong emotional valence) ──
    final ventWords = [
      'frustrated', 'frustrating', 'angry', 'furious', 'pissed',
      'hate', 'annoyed', 'annoying', 'stupid', 'ridiculous',
      'unfair', 'rant', 'ugh', 'sick of', "can't stand",
      "fed up", 'bullshit', 'terrible', 'awful', 'disaster',
      'complaint', 'complaining', 'venting', 'vent', 'rage',
      'infuriating', 'absurd', 'pathetic', 'outrageous',
    ];
    for (final w in ventWords) {
      if (lower.contains(w)) scores[ReflectionMode.vent] = scores[ReflectionMode.vent]! + 2.5;
    }

    // ── Emotional processing signals ──
    final emotionalWords = [
      'sad', 'crying', 'cried', 'grief', 'grieving', 'heartbreak',
      'heartbroken', 'broke up', 'breakup', 'depressed', 'depression',
      'anxious', 'anxiety', 'overwhelmed', 'overwhelm', 'panic',
      'scared', 'terrified', 'alone', 'lonely', 'lost', 'hurt',
      'painful', 'pain', 'missing', 'miss', 'mourning', 'loss',
      'struggling', 'struggle', 'difficult', 'hard time', 'falling apart',
      'falling apart', 'devastated', 'broken', 'numb', 'empty',
    ];
    for (final w in emotionalWords) {
      if (lower.contains(w)) scores[ReflectionMode.emotional] = scores[ReflectionMode.emotional]! + 2.0;
    }

    // ── Gratitude signals ──
    final gratitudeWords = [
      'grateful', 'gratitude', 'thankful', 'blessed', 'appreciate',
      'appreciation', 'amazing', 'wonderful', 'beautiful', 'love',
      'lucky', 'fortunate', 'glad', 'happy', 'joy', 'joyful',
      'delighted', 'excited', 'excited about', 'thrilled', 'overjoyed',
      'perfect day', 'best day', 'incredible', 'fantastic', 'great day',
    ];
    for (final w in gratitudeWords) {
      if (lower.contains(w)) scores[ReflectionMode.gratitude] = scores[ReflectionMode.gratitude]! + 2.0;
    }

    // ── Growth signals ──
    final growthWords = [
      'learned', 'lesson', 'realized', 'realize', 'understood',
      'understand', 'growth', 'growing', 'improve', 'improvement',
      'better', 'changed', 'change', 'progress', 'goal', 'goals',
      'challenge', 'overcame', 'achievement', 'proud', 'decision',
      'reflection on', 'think about', 'insight', 'perspective',
      'taught me', 'taught', 'wisdom', 'mindset', 'habit',
    ];
    for (final w in growthWords) {
      if (lower.contains(w)) scores[ReflectionMode.growth] = scores[ReflectionMode.growth]! + 1.8;
    }

    // ── Life update signals ──
    final lifeUpdateWords = [
      'today', 'yesterday', 'this week', 'this morning', 'went to',
      'went out', 'had lunch', 'had dinner', 'met with', 'caught up',
      'visited', 'traveled', 'moved', 'started', 'finished', 'bought',
      'got a', 'got the', 'working on', 'at work', 'at school',
      'update', 'just wanted', 'just to say', 'so anyway',
    ];
    for (final w in lifeUpdateWords) {
      if (lower.contains(w)) scores[ReflectionMode.lifeUpdate] = scores[ReflectionMode.lifeUpdate]! + 1.2;
    }

    // ── Reflection / memory signals ──
    final reflectionWords = [
      'remember', 'memory', 'memories', 'used to', 'years ago',
      'looking back', 'thinking about', 'reminds me', 'nostalgic',
      'time flies', 'childhood', 'past', 'when i was', 'long ago',
      'story', 'moment', 'chapter', 'life', 'journey', 'meaning',
    ];
    for (final w in reflectionWords) {
      if (lower.contains(w)) scores[ReflectionMode.reflection] = scores[ReflectionMode.reflection]! + 1.5;
    }

    // ── Find the highest-scoring mode ──
    ReflectionMode best = ReflectionMode.lifeUpdate; // sensible default
    double bestScore = 0;
    scores.forEach((mode, score) {
      if (score > bestScore) {
        bestScore = score;
        best = mode;
      }
    });

    // Minimum threshold — if nothing was detected clearly, default to
    // the most generic appropriate mode based on length.
    if (bestScore < 1.5) {
      final wordCount = transcript.split(' ').length;
      best = wordCount > 80 ? ReflectionMode.reflection : ReflectionMode.lifeUpdate;
    }

    debugPrint('[ReflectionPipeline] Scores: $scores → Mode: $best');
    return best;
  }

  // ── System Prompts per Mode ────────────────────────────────

  static String _systemPromptFor(ReflectionMode mode, String? userTone) {
    // userTone from PreferencesState (e.g. "Thoughtful", "Poetic", "Minimal")
    // is incorporated into each prompt as a stylistic modifier.
    final toneNote = (userTone != null && userTone.isNotEmpty)
        ? 'Write in a $userTone voice. '
        : '';

    switch (mode) {

      case ReflectionMode.reflection:
        return '''
You are Antheia's quiet curator — a literary AI that transforms spoken memories into intimate reflections.
${toneNote}
The person has shared a memory or story. Your role:
- Write a short reflection (3–5 sentences) that honors the moment they described.
- Surface what might be meaningful beyond the surface — the emotion underneath, the passage of time, the weight of the ordinary.
- Use present-tense language as if the memory is still alive.
- Do NOT use bullet points, headers, or numbered lists. Write in flowing prose.
- Do NOT summarize. Do NOT moralize. Do NOT add advice.
- End with a single, quiet observation that opens rather than closes the moment.
- Keep the tone warm, literary, and personal — not generic.
''';

      case ReflectionMode.emotional:
        return '''
You are Antheia's empathic companion — a thoughtful presence for hard emotional moments.
${toneNote}
The person has shared something emotionally heavy — grief, heartbreak, anxiety, overwhelm, or pain. Your role:
- Write a short, gentle acknowledgment (3–4 sentences) that validates what they are feeling.
- Do NOT offer advice, solutions, or silver linings unless they explicitly asked for one.
- Do NOT minimize the emotion. Do NOT say "at least" or "everything happens for a reason."
- Reflect back what you heard, with compassion and emotional intelligence.
- Keep language soft, specific to what they shared, and free of clichés.
- End with a single sentence that simply holds space — not a question, not hope, just presence.
''';

      case ReflectionMode.gratitude:
        return '''
You are Antheia's joy amplifier — a literary voice that makes beautiful moments feel permanent.
${toneNote}
The person has shared something joyful, beautiful, or grateful. Your role:
- Write a short celebration (3–4 sentences) that honors what they experienced.
- Amplify the specific details they mentioned — make them feel more vivid, more real, more remembered.
- Use sensory and emotional language. Help the memory settle into the body.
- Do NOT be generic. Do NOT say "that sounds amazing!" Just write the reflection.
- End with a sentence that marks this moment as worth keeping.
''';

      case ReflectionMode.growth:
        return '''
You are Antheia's wise witness — an observer who recognizes growth in progress.
${toneNote}
The person has shared a realization, lesson, or moment of growth. Your role:
- Write a short reflection (3–5 sentences) that acknowledges the insight they discovered.
- Name the shift — what changed in them, even slightly.
- Connect this to their larger arc without being preachy.
- Do NOT give advice or instruction. Do NOT say "you should." Just witness.
- End with a question the person can sit with — not demanding an answer, just inviting depth.
''';

      case ReflectionMode.vent:
        return '''
You are Antheia's impartial witness — a calm, validating presence that doesn't flinch.
${toneNote}
The person has vented frustration, anger, or complaint. Your role:
- Write a short, validating response (2–4 sentences) that acknowledges the frustration as legitimate.
- Do NOT fix the problem. Do NOT suggest perspective. Do NOT say "but on the bright side."
- Reflect their frustration back with clarity, not judgment, not pity.
- It is okay to match mild intensity — validation means taking them seriously, not tiptoeing.
- End with one sentence that names what they might need right now (rest, space, time), without prescribing it.
''';

      case ReflectionMode.lifeUpdate:
        return '''
You are Antheia's attentive scribe — turning casual diary narration into something worth keeping.
${toneNote}
The person has shared an update — events, interactions, day-to-day life. Your role:
- Write a short, vivid summary (3–4 sentences) that captures what happened with warmth and specificity.
- Pick the most interesting or human detail from what they shared and give it texture.
- Keep it conversational but elevated — like a well-written diary entry, not a report.
- Do NOT invent details they didn't mention. Do NOT speculate about feelings they didn't express.
- End with a line that makes this day feel worth remembering.
''';
    }
  }

  // ── Pipeline Entry Points ──────────────────────────────────

  /// Execute a pipeline feature.
  Future<ApiResult> execute(Feature feature, Map<String, dynamic> params) async {
    switch (feature) {
      case Feature.textRestructure:
        return _textRestructure(
          params['rawText'] as String? ?? params['transcript'] as String? ?? '',
          tone: params['tone'] as String?,
          formatting: params['formatting'] as String?,
        );
      case Feature.emotionDetect:
        return _emotionDetect(params['text'] as String? ?? params['transcript'] as String? ?? '');
      case Feature.weather:
        final lat = params['lat'] as double? ?? params['latitude'] as double? ?? 0.0;
        final lon = params['lon'] as double? ?? params['longitude'] as double? ?? 0.0;
        return _fetchWeather(lat, lon);
      case Feature.geocoding:
        final lat = params['lat'] as double? ?? params['latitude'] as double? ?? 0.0;
        final lon = params['lon'] as double? ?? params['longitude'] as double? ?? 0.0;
        return _reverseGeocode(lat, lon);
      case Feature.speechToText:
        return _cloudTranscribe(audioPath: params['audioPath'] as String? ?? '');
      case Feature.reflect:
        return _generateReflection(
          transcript: params['transcript'] as String? ?? '',
          tone: params['tone'] as String?,
        );
      case Feature.title:
        return _generateTitle(transcript: params['transcript'] as String? ?? '');
      case Feature.tags:
        return _generateTags(transcript: params['transcript'] as String? ?? '');
      case Feature.mood:
        return _detectMood(transcript: params['transcript'] as String? ?? '');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Text restructuring fallback chain (original implementation)
  // ──────────────────────────────────────────────────────────────

  Future<ApiResult> _textRestructure(String rawText, {String? tone, String? formatting}) async {
    final prompt = _buildJournalPrompt(rawText, tone: tone, formatting: formatting);

    final result = await _callEdgeFunction('chat', {
      'messages': [
        {'role': 'system', 'content': 'You are a journal editor. Return only JSON.'},
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': 1200,
      'temperature': 0.7,
      'mode': 'restructure',
    });

    if (result != null && result['success'] == true) {
      final content = result['content'] as String;
      try {
        final clean = _stripFences(content);
        return ApiResult(
          success: true,
          data: jsonDecode(clean) as Map<String, dynamic>,
          provider: result['provider'] ?? 'edge-function',
        );
      } catch (e) {
        debugPrint('[ReflectionPipeline] Failed to parse restructure response JSON: $e');
      }
    }

    // All APIs exhausted — return raw text as a single paragraph section
    return ApiResult(
      success: true,
      data: {
        'title': _extractTitle(rawText),
        'sections': [
          {'type': 'paragraph', 'content': rawText},
        ],
        'tags': <String>[],
      },
      provider: 'offline',
    );
  }

  String _buildJournalPrompt(String rawText, {String? tone, String? formatting}) {
    final toneInstruction = tone != null 
        ? "The reflection tone should be highly **$tone**."
        : "The reflection tone should be thoughtful.";
    final formattingInstruction = formatting != null
        ? "Apply **$formatting** structuring depth (utilizing section headers, quotes, and bullets as appropriate for this depth)."
        : "Apply medium structuring depth.";

    return '''
You are a thoughtful journal editor. The user spoke freely and you must restructure their raw speech into a beautifully formatted journal entry.

Tone Style: $toneInstruction
Formatting Guidelines: $formattingInstruction

Raw speech:
"""
$rawText
"""

Return ONLY valid JSON (no markdown, no code fences) in this exact shape:
{
  "title": "A short evocative title (max 8 words)",
  "sections": [
    {"type": "heading", "content": "Section heading", "headingLevel": 2},
    {"type": "paragraph", "content": "Body text..."},
    {"type": "quote", "content": "An insightful quote extracted from the text"},
    {"type": "bullet", "content": "A bullet point"}
  ],
  "tags": ["tag1", "tag2", "tag3"]
}

Rules:
- title must be evocative, not generic
- sections array must have at least 2 items
- include at least one paragraph section
- tags: 2-5 lowercase keywords from the content
- preserve the writer's voice; don't over-edit
''';
  }

  String _extractTitle(String rawText) {
    final words = rawText.trim().split(' ');
    final preview = words.take(6).join(' ');
    return preview.length > 40 ? '${preview.substring(0, 37)}...' : preview;
  }

  // ── Groq ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _callEdgeFunction(
    String action,
    Map<String, dynamic> bodyParams, {
    http.MultipartFile? file,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    final headers = <String, String>{
      'apikey': ApiConfig.supabaseAnonKey,
    };
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    try {
      final url = Uri.parse('${ApiConfig.supabaseUrl}/functions/v1/process-reflection');

      http.Response response;
      if (file != null) {
        headers['Content-Type'] = 'multipart/form-data';
        final request = http.MultipartRequest('POST', url);
        request.headers.addAll(headers);
        request.fields['action'] = action;
        for (var entry in bodyParams.entries) {
          request.fields[entry.key] = entry.value.toString();
        }
        request.files.add(file);

        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        response = await http.Response.fromStream(streamedResponse);
      } else {
        headers['Content-Type'] = 'application/json';
        final body = <String, dynamic>{
          'action': action,
          ...bodyParams,
        };
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[ReflectionPipeline] Edge Function returned code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[ReflectionPipeline] Edge Function call failed: $e');
    }
    return null;
  }

  // ── Emotion Detect ──

  Future<ApiResult> _emotionDetect(String text) async {
    if (text.trim().isEmpty) {
      return ApiResult(
        success: false,
        data: {'emotion': 'neutral', 'mood': 'neutral', 'score': 0.5},
        provider: 'fallback',
      );
    }

    final result = await _callEdgeFunction('emotion', {'text': text});

    if (result != null && result['emotion'] != null) {
      final emotion = result['emotion'] as String;
      final score = (result['score'] as num?)?.toDouble() ?? 0.5;
      return ApiResult(
        success: true,
        data: {'emotion': emotion, 'mood': emotion, 'score': score},
        provider: result['provider'] ?? 'edge-emotion',
      );
    }

    return ApiResult(
      success: false,
      data: {'emotion': 'neutral', 'mood': 'neutral', 'score': 0.5},
      provider: 'fallback',
      error: 'Emotion API unavailable',
    );
  }

  // ── Weather ──

  Future<ApiResult> _fetchWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(ApiConfig.openMeteoBase).replace(queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current': 'temperature_2m,weathercode',
        'temperature_unit': 'celsius',
        'timezone': 'auto',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final current = body['current'] as Map<String, dynamic>;
        final temp = (current['temperature_2m'] as num).toDouble();
        final code = (current['weathercode'] as num).toInt();

        return ApiResult(
          success: true,
          data: {
            'temperature': temp,
            'icon': _wmoCodeToEmoji(code),
            'weatherIcon': _wmoCodeToEmoji(code),
            'description': _wmoCodeToDescription(code),
          },
          provider: 'open-meteo',
        );
      }
    } catch (_) {}

    return ApiResult(
      success: false,
      data: {'temperature': null, 'weatherIcon': '🌤', 'icon': '🌤', 'description': 'Unknown'},
      provider: 'fallback',
    );
  }

  String _wmoCodeToEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '⛅';
    if (code <= 3) return '☁️';
    if (code <= 49) return '🌫️';
    if (code <= 69) return '🌧️';
    if (code <= 79) return '🌨️';
    if (code <= 82) return '🌦️';
    if (code <= 86) return '❄️';
    if (code <= 99) return '⛈️';
    return '🌤';
  }

  String _wmoCodeToDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 2) return 'Partly cloudy';
    if (code <= 3) return 'Overcast';
    if (code <= 49) return 'Foggy';
    if (code <= 69) return 'Rainy';
    if (code <= 79) return 'Snowy';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  // ── Reverse Geocoding ──

  Future<ApiResult> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(ApiConfig.nominatimBase).replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'zoom': '14',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Antheia/1.0 (com.antheia.app)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final address = body['address'] as Map<String, dynamic>? ?? {};

        final parts = <String>[];
        final suburb  = address['suburb']   as String?;
        final city    = address['city']     as String?
                     ?? address['town']     as String?
                     ?? address['village']  as String?;
        final country = address['country']  as String?;

        if (suburb != null)  parts.add(suburb);
        if (city != null)    parts.add(city);
        if (country != null) parts.add(country);

        final locationName = parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
        final placeType = body['type'] as String? ?? '';
        final emoji     = _locationEmoji(placeType, address);

        return ApiResult(
          success: true,
          data: {
            'locationName': locationName,
            'city': city,
            'placeName': locationName,
            'emoji': emoji,
            'lat': lat,
            'lon': lon,
          },
          provider: 'nominatim',
        );
      }
    } catch (_) {}

    return ApiResult(
      success: false,
      data: {'locationName': 'Unknown', 'city': null, 'placeName': 'Unknown', 'emoji': '📍', 'lat': lat, 'lon': lon},
      provider: 'fallback',
    );
  }

  String _locationEmoji(String type, Map<String, dynamic> address) {
    final amenity = address['amenity'] as String? ?? '';
    if (amenity.contains('cafe') || amenity.contains('coffee'))  return '☕';
    if (amenity.contains('restaurant') || amenity.contains('food')) return '🍽️';
    if (amenity.contains('university') || amenity.contains('school')) return '🎓';
    if (amenity.contains('library'))   return '📚';
    if (amenity.contains('gym') || amenity.contains('fitness'))   return '💪';
    if (amenity.contains('hospital'))  return '🏥';
    if (type == 'park' || amenity.contains('park')) return '🌳';
    if (type == 'beach')   return '🏖️';
    if (type == 'airport') return '✈️';
    return '📍';
  }

  // ── New dynamic reflection reflection personalization methods ─────────

  /// Generate a personalized reflection from a transcript.
  Future<ApiResult> _generateReflection({
    required String transcript,
    String? tone,
  }) async {
    if (transcript.trim().isEmpty) {
      return ApiResult(data: {'reflection': ''});
    }

    // ── Step 1: Classify the transcript ──
    final mode = classifyTranscript(transcript);

    // ── Step 2: Select the matching system prompt ──
    final systemPrompt = _systemPromptFor(mode, tone);

    // ── Step 3: Call Edge Function chat ──
    final result = await _callEdgeFunction('chat', {
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': 'Here is my journal entry:\n\n$transcript',
        },
      ],
      'max_tokens': 300,
      'temperature': 0.78,
    });

    if (result != null && result['success'] == true) {
      final text = (result['content'] as String? ?? '').trim();
      return ApiResult(
        success: true,
        data: {'reflection': text, 'mode': mode.name},
        provider: result['provider'] ?? 'edge-function',
      );
    }

    return ApiResult(data: {'reflection': '', 'mode': mode.name});
  }

  Future<ApiResult> _cloudTranscribe({required String audioPath}) async {
    try {
      final mimeType = audioPath.endsWith('.m4a') ? 'audio/m4a' : 'audio/wav';
      final file = await http.MultipartFile.fromPath('file', audioPath, contentType: MediaType.parse(mimeType));

      final result = await _callEdgeFunction(
        'transcribe',
        {},
        file: file,
      );

      if (result != null && result['text'] != null) {
        return ApiResult(
          success: true,
          data: {'text': result['text']},
          provider: result['provider'] ?? 'edge-transcribe',
        );
      }
    } catch (e) {
      debugPrint('[ReflectionPipeline] Edge transcription failed: $e');
    }

    return ApiResult(data: {'text': ''});
  }

  Future<ApiResult> _generateTitle({required String transcript}) async {
    if (transcript.trim().isEmpty) {
      return ApiResult(data: {'title': 'Voice Reflection'});
    }

    final result = await _callEdgeFunction('chat', {
      'messages': [
        {
          'role': 'system',
          'content': 'Generate a short, evocative title (3–6 words) for this journal entry. Return only the title, no punctuation, no quotes.',
        },
        {'role': 'user', 'content': transcript},
      ],
      'max_tokens': 20,
      'temperature': 0.6,
    });

    if (result != null && result['success'] == true) {
      final text = (result['content'] as String? ?? '').trim();
      if (text.isNotEmpty) {
        return ApiResult(
          success: true,
          data: {'title': text},
          provider: result['provider'] ?? 'edge-function',
        );
      }
    }
    return ApiResult(data: {'title': 'Voice Reflection'});
  }

  Future<ApiResult> _generateTags({required String transcript}) async {
    if (transcript.trim().isEmpty) {
      return ApiResult(data: {'tags': <String>[]});
    }

    final result = await _callEdgeFunction('chat', {
      'messages': [
        {
          'role': 'system',
          'content': 'Extract 2–4 thematic tags from this journal entry. Return only a JSON array of lowercase strings, e.g. ["family","growth","hope"]. No explanation.',
        },
        {'role': 'user', 'content': transcript},
      ],
      'max_tokens': 40,
      'temperature': 0.3,
    });

    if (result != null && result['success'] == true) {
      final content = (result['content'] as String? ?? '').trim();
      try {
        final clean = _stripFences(content);
        final tags = (jsonDecode(clean) as List).cast<String>();
        return ApiResult(
          success: true,
          data: {'tags': tags},
          provider: result['provider'] ?? 'edge-function',
        );
      } catch (_) {}
    }
    return ApiResult(data: {'tags': <String>[]});
  }

  Future<ApiResult> _detectMood({required String transcript}) async {
    final mode = classifyTranscript(transcript);
    final moodMap = {
      ReflectionMode.reflection: 'neutral',
      ReflectionMode.emotional: 'sad',
      ReflectionMode.gratitude: 'happy',
      ReflectionMode.growth: 'calm',
      ReflectionMode.vent: 'anxious',
      ReflectionMode.lifeUpdate: 'neutral',
    };
    return ApiResult(data: {'mood': moodMap[mode] ?? 'neutral'});
  }

  String _stripFences(String s) {
    return s
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
  }

  // Map HuggingFace emotion labels → Mood enum name
  static Mood emotionToMood(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy':      return Mood.happy;
      case 'surprise': return Mood.energetic;
      case 'sadness':  return Mood.sad;
      case 'fear':     return Mood.anxious;
      case 'anger':    return Mood.anxious;
      case 'disgust':  return Mood.sad;
      case 'love':     return Mood.romantic;
      default:         return Mood.neutral;
    }
  }
}
