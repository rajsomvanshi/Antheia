import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;

// ═══════════════════════════════════════════════════════════════
// Antheia — API Configuration
//
// Keys can be injected at build-time via --dart-define, e.g.:
//   flutter run \
//     --dart-define=GROQ_API_KEY=gsk_xxx \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJxxx
//
// Alternatively, they can be loaded at runtime from assets/.env
// ═══════════════════════════════════════════════════════════════

class ApiConfig {
  ApiConfig._();

  // Text processing fallback chain: Groq -> Gemini -> OpenRouter -> OpenAI.
  static String groqApiKey       = const String.fromEnvironment('GROQ_API_KEY',        defaultValue: '');
  static String groqApiKeysRaw   = const String.fromEnvironment('GROQ_API_KEYS',       defaultValue: '');

  static List<String> get groqKeys {
    final keys = <String>[];
    if (groqApiKey.isNotEmpty) keys.add(groqApiKey);
    if (groqApiKeysRaw.isNotEmpty) {
      keys.addAll(groqApiKeysRaw.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty));
    }
    return keys.toSet().toList();
  }
  static String geminiApiKey     = const String.fromEnvironment('GEMINI_API_KEY',      defaultValue: '');
  static String openRouterApiKey = const String.fromEnvironment('OPENROUTER_API_KEY',  defaultValue: '');
  static String openAiApiKey     = const String.fromEnvironment('OPENAI_API_KEY',      defaultValue: '');

  // ── Speech-to-text cloud fallback ──
  static String deepgramApiKey   = const String.fromEnvironment('DEEPGRAM_API_KEY',    defaultValue: '');
  static String assemblyAiApiKey = const String.fromEnvironment('ASSEMBLY_AI_API_KEY', defaultValue: '');

  // ── Supabase ──
  // URL must be https://xxx.supabase.co  (NOT .../rest/v1/)
  // Key must be the anon/service JWT (eyJ...) or publishable key (sb_publishable_...)
  static String supabaseUrl      = const String.fromEnvironment('SUPABASE_URL',        defaultValue: 'https://rlrhwwltbalerqiwupnf.supabase.co');
  static String supabaseAnonKey  = const String.fromEnvironment('SUPABASE_ANON_KEY',   defaultValue: 'sb_publishable_7OX67S5bgNiw5fyk9FCR9w_m9UunpIT');

  // ── Reserved (not yet wired) ──
  static String unsplashKey      = const String.fromEnvironment('UNSPLASH_KEY',        defaultValue: '');
  static String mapboxToken      = const String.fromEnvironment('MAPBOX_TOKEN',        defaultValue: '');

  // ── Open APIs (no key required) ──
  static const openMeteoBase    = 'https://api.open-meteo.com/v1/forecast';
  static const nominatimBase    = 'https://nominatim.openstreetmap.org/reverse';

  // ── Availability helpers ──
  static bool get hasGroq        => groqKeys.isNotEmpty;
  static bool get hasGemini      => geminiApiKey.isNotEmpty;
  static bool get hasOpenRouter  => openRouterApiKey.isNotEmpty;
  static bool get hasOpenAi      => openAiApiKey.isNotEmpty;
  static bool get hasDeepgram    => deepgramApiKey.isNotEmpty;
  static bool get hasAssemblyAi  => assemblyAiApiKey.isNotEmpty;
  static bool get hasSupabase    =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl.startsWith('https://') &&
      supabaseUrl.contains('.supabase.co') &&
      (supabaseAnonKey.startsWith('eyJ') || supabaseAnonKey.startsWith('sb_publishable_'));

  static Map<String, dynamic> checkSupabaseDiagnostics() {
    return {
      'url_exists': supabaseUrl.isNotEmpty,
      'url_value': supabaseUrl,
      'key_exists': supabaseAnonKey.isNotEmpty,
      'key_length': supabaseAnonKey.length,
      'key_masked': supabaseAnonKey.isNotEmpty
          ? (supabaseAnonKey.length > 10
              ? '${supabaseAnonKey.substring(0, 10)}...'
              : 'too-short')
          : 'empty',
      'starts_with_https': supabaseUrl.startsWith('https://'),
      'contains_supabase_co': supabaseUrl.contains('.supabase.co'),
      'key_starts_with_eyj': supabaseAnonKey.startsWith('eyJ') || supabaseAnonKey.startsWith('sb_publishable_'),
    };
  }

  static bool get hasAnyTextAi =>
      hasGroq || hasGemini || hasOpenRouter || hasOpenAi;

  // ── Runtime Env Loader ──
  static Future<void> loadEnv() async {
    try {
      final envContent = await rootBundle.loadString('assets/.env');
      final lines = envContent.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final idx = line.indexOf('=');
        if (idx == -1) continue;

        final key = line.substring(0, idx).trim();
        var val = line.substring(idx + 1).trim();

        // Remove surrounding quotes if any
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }

        switch (key) {
          case 'GROQ_API_KEY':
            if (groqApiKey.isEmpty) groqApiKey = val;
            break;
          case 'GROQ_API_KEYS':
            if (groqApiKeysRaw.isEmpty) groqApiKeysRaw = val;
            break;
          case 'GEMINI_API_KEY':
            if (geminiApiKey.isEmpty) geminiApiKey = val;
            break;
          case 'OPENROUTER_API_KEY':
            if (openRouterApiKey.isEmpty) openRouterApiKey = val;
            break;
          case 'OPENAI_API_KEY':
            if (openAiApiKey.isEmpty) openAiApiKey = val;
            break;
          case 'DEEPGRAM_API_KEY':
            if (deepgramApiKey.isEmpty) deepgramApiKey = val;
            break;
          case 'ASSEMBLY_AI_API_KEY':
            if (assemblyAiApiKey.isEmpty) assemblyAiApiKey = val;
            break;
          case 'SUPABASE_URL':
            if (supabaseUrl.isEmpty) supabaseUrl = val;
            break;
          case 'SUPABASE_ANON_KEY':
            if (supabaseAnonKey.isEmpty) supabaseAnonKey = val;
            break;
          case 'UNSPLASH_KEY':
            if (unsplashKey.isEmpty) unsplashKey = val;
            break;
          case 'MAPBOX_TOKEN':
            if (mapboxToken.isEmpty) mapboxToken = val;
            break;
        }
      }
      debugPrint('[ApiConfig] Loaded configuration keys from assets/.env');
    } catch (e) {
      debugPrint('[ApiConfig] No assets/.env found or failed to load. Falling back to build-time environment variables.');
    }
  }
}
