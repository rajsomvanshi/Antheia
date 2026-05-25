import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';

// ═══════════════════════════════════════════════════════════════
// FlowJournal — API Router
//
// Text restructuring:  Groq → Gemini → OpenRouter → OpenAI
// Emotion detection:   HuggingFace (free, no key)
// Weather:             Open-Meteo  (free, no key)
// Geocoding:           Nominatim   (free, no key)
// Cloud STT:           Deepgram    (key required)
// ═══════════════════════════════════════════════════════════════

enum Feature { textRestructure, emotionDetect, weather, geocoding, speechToText }

class ApiResult {
  final bool success;
  final Map<String, dynamic> data;
  final String provider;
  final String? error;

  const ApiResult({
    required this.success,
    required this.data,
    required this.provider,
    this.error,
  });

  factory ApiResult.failure(String error, String provider) =>
      ApiResult(success: false, data: const {}, provider: provider, error: error);
}

class ApiRouter {
  static final ApiRouter _instance = ApiRouter._();
  factory ApiRouter() => _instance;
  ApiRouter._();

  // ──────────────────────────────────────────────────────────────
  // Public entry point
  // ──────────────────────────────────────────────────────────────

  Future<ApiResult> execute(Feature feature, Map<String, dynamic> params) async {
    switch (feature) {
      case Feature.textRestructure:
        return _textRestructure(params['rawText'] as String);
      case Feature.emotionDetect:
        return _emotionDetect(params['text'] as String);
      case Feature.weather:
        return _fetchWeather(params['lat'] as double, params['lon'] as double);
      case Feature.geocoding:
        return _reverseGeocode(params['lat'] as double, params['lon'] as double);
      case Feature.speechToText:
        return _cloudStt(params['audioPath'] as String);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Text Restructuring — Groq → Gemini → OpenRouter → OpenAI
  // ──────────────────────────────────────────────────────────────

  Future<ApiResult> _textRestructure(String rawText) async {
    final prompt = _buildJournalPrompt(rawText);

    if (ApiConfig.hasGroq) {
      for (final key in ApiConfig.groqKeys) {
        final r = await _callGroq(prompt, key);
        if (r != null) return r;
      }
    }
    if (ApiConfig.hasGemini) {
      final r = await _callGemini(prompt);
      if (r != null) return r;
    }
    if (ApiConfig.hasOpenRouter) {
      final r = await _callOpenRouter(prompt);
      if (r != null) return r;
    }
    if (ApiConfig.hasOpenAi) {
      final r = await _callOpenAi(prompt);
      if (r != null) return r;
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

  String _buildJournalPrompt(String rawText) => '''
You are a thoughtful journal editor. The user spoke freely and you must restructure their raw speech into a beautifully formatted journal entry.

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

  String _extractTitle(String rawText) {
    final words = rawText.trim().split(' ');
    final preview = words.take(6).join(' ');
    return preview.length > 40 ? '${preview.substring(0, 37)}...' : preview;
  }

  // ── Groq ─────────────────────────────────────────────────────

  Future<ApiResult?> _callGroq(String prompt, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': 'You are a journal editor. Return only JSON.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1200,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      // Auth errors (401/403) → skip to next provider, don't throw
      if (response.statusCode == 401 || response.statusCode == 403) {
        return null;
      }
      // Quota errors (429) → skip
      if (response.statusCode == 429) return null;

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices'][0]['message']['content'] as String;
      return ApiResult(
        success: true,
        data: jsonDecode(_stripFences(content)) as Map<String, dynamic>,
        provider: 'groq',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Gemini ────────────────────────────────────────────────────

  Future<ApiResult?> _callGemini(String prompt) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${ApiConfig.geminiApiKey}',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'maxOutputTokens': 1200, 'temperature': 0.7},
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) return null;
      if (response.statusCode == 429) return null;
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          body['candidates'][0]['content']['parts'][0]['text'] as String;
      return ApiResult(
        success: true,
        data: jsonDecode(_stripFences(content)) as Map<String, dynamic>,
        provider: 'gemini',
      );
    } catch (_) {
      return null;
    }
  }

  // ── OpenRouter ────────────────────────────────────────────────

  Future<ApiResult?> _callOpenRouter(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.openRouterApiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'com.flowjournal.app',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3-8b-instruct:free',
          'messages': [
            {'role': 'system', 'content': 'You are a journal editor. Return only JSON.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1200,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) return null;
      if (response.statusCode == 429) return null;
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices'][0]['message']['content'] as String;
      return ApiResult(
        success: true,
        data: jsonDecode(_stripFences(content)) as Map<String, dynamic>,
        provider: 'openrouter',
      );
    } catch (_) {
      return null;
    }
  }

  // ── OpenAI ────────────────────────────────────────────────────

  Future<ApiResult?> _callOpenAi(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.openAiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a journal editor. Return only JSON.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1200,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) return null;
      if (response.statusCode == 429) return null;
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices'][0]['message']['content'] as String;
      return ApiResult(
        success: true,
        data: jsonDecode(_stripFences(content)) as Map<String, dynamic>,
        provider: 'openai',
      );
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Emotion Detection — HuggingFace (free, no key needed)
  // ──────────────────────────────────────────────────────────────

  Future<ApiResult> _emotionDetect(String text) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://api-inference.huggingface.co/models/j-hartmann/emotion-english-distilroberta-base',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'inputs': text.substring(0, text.length.clamp(0, 512))}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        // Response: [[{label, score}, ...]]
        final List items = (raw is List && raw.isNotEmpty && raw[0] is List)
            ? raw[0] as List
            : (raw is List ? raw : []);

        String topEmotion = 'neutral';
        double topScore = 0;
        for (final item in items) {
          if (item is Map) {
            final score = (item['score'] as num?)?.toDouble() ?? 0;
            if (score > topScore) {
              topScore = score;
              topEmotion = (item['label'] as String? ?? 'neutral').toLowerCase();
            }
          }
        }

        return ApiResult(
          success: true,
          data: {'emotion': topEmotion, 'score': topScore},
          provider: 'huggingface',
        );
      }
    } catch (_) {}

    return ApiResult(
      success: false,
      data: {'emotion': 'neutral', 'score': 0.5},
      provider: 'fallback',
      error: 'Emotion API unavailable',
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Weather — Open-Meteo (free, no key)
  // ──────────────────────────────────────────────────────────────

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
            'weatherIcon': _wmoCodeToEmoji(code),
            'description': _wmoCodeToDescription(code),
          },
          provider: 'open-meteo',
        );
      }
    } catch (_) {}

    return ApiResult(
      success: false,
      data: {'temperature': null, 'weatherIcon': '🌤', 'description': 'Unknown'},
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

  // ──────────────────────────────────────────────────────────────
  // Reverse Geocoding — Nominatim (free, no key)
  // ──────────────────────────────────────────────────────────────

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
        headers: {'User-Agent': 'FlowJournal/1.0 (com.flowjournal.app)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final address = body['address'] as Map<String, dynamic>? ?? {};

        // Build a short readable location string
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

        // Pick an emoji for the type of location
        final placeType = body['type'] as String? ?? '';
        final emoji     = _locationEmoji(placeType, address);

        return ApiResult(
          success: true,
          data: {
            'locationName': locationName,
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
      data: {'locationName': 'Unknown', 'emoji': '📍', 'lat': lat, 'lon': lon},
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

  // ──────────────────────────────────────────────────────────────
  // Cloud Speech-to-Text — Deepgram
  // NOTE: AssemblyAI removed (was simulated). Only Deepgram is real.
  // ──────────────────────────────────────────────────────────────

  Future<ApiResult> _cloudStt(String audioPath) async {
    if (!ApiConfig.hasDeepgram) {
      return ApiResult.failure('No cloud STT key configured', 'none');
    }

    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        return ApiResult.failure('Audio file not found: $audioPath', 'deepgram');
      }

      final bytes = await file.readAsBytes();
      final response = await http.post(
        Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true'),
        headers: {
          'Authorization': 'Token ${ApiConfig.deepgramApiKey}',
          'Content-Type': 'audio/m4a',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return ApiResult.failure('Deepgram auth error', 'deepgram');
      }
      if (response.statusCode != 200) {
        return ApiResult.failure('Deepgram error ${response.statusCode}', 'deepgram');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final transcript =
          body['results']?['channels']?[0]?['alternatives']?[0]?['transcript']
              as String? ??
          '';

      return ApiResult(
        success: transcript.isNotEmpty,
        data: {'text': transcript},
        provider: 'deepgram',
      );
    } catch (e) {
      return ApiResult.failure('Deepgram failed: $e', 'deepgram');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────

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
