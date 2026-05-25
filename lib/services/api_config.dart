// ═══════════════════════════════════════════════════════════════
// FlowJournal — API Configuration
//
// Keys are injected at build-time via --dart-define, e.g.:
//   flutter run \
//     --dart-define=GROQ_API_KEY=gsk_xxx \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJxxx
//
// Create a local `.env.sh` (gitignored) and source it before
// building. Never commit actual keys to source control.
// ═══════════════════════════════════════════════════════════════

class ApiConfig {
  ApiConfig._();

  // ── AI text processing (fallback chain: Groq → Gemini → OpenRouter → OpenAI) ──
  static const groqApiKey       = String.fromEnvironment('GROQ_API_KEY',        defaultValue: '');
  static const groqApiKeysRaw   = String.fromEnvironment('GROQ_API_KEYS',       defaultValue: '');

  static List<String> get groqKeys {
    final keys = <String>[];
    if (groqApiKey.isNotEmpty) keys.add(groqApiKey);
    if (groqApiKeysRaw.isNotEmpty) {
      keys.addAll(groqApiKeysRaw.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty));
    }
    return keys.toSet().toList();
  }
  static const geminiApiKey     = String.fromEnvironment('GEMINI_API_KEY',      defaultValue: '');
  static const openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY',  defaultValue: '');
  static const openAiApiKey     = String.fromEnvironment('OPENAI_API_KEY',      defaultValue: '');

  // ── Speech-to-text cloud fallback ──
  static const deepgramApiKey   = String.fromEnvironment('DEEPGRAM_API_KEY',    defaultValue: '');
  static const assemblyAiApiKey = String.fromEnvironment('ASSEMBLY_AI_API_KEY', defaultValue: '');

  // ── Supabase ──
  // URL must be https://xxx.supabase.co  (NOT .../rest/v1/)
  // Key must be the anon/service JWT (eyJ...)
  static const supabaseUrl      = String.fromEnvironment('SUPABASE_URL',        defaultValue: '');
  static const supabaseAnonKey  = String.fromEnvironment('SUPABASE_ANON_KEY',   defaultValue: '');

  // ── Reserved (not yet wired) ──
  static const unsplashKey      = String.fromEnvironment('UNSPLASH_KEY',        defaultValue: '');
  static const mapboxToken      = String.fromEnvironment('MAPBOX_TOKEN',        defaultValue: '');

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
      supabaseAnonKey.startsWith('eyJ');

  static bool get hasAnyTextAi =>
      hasGroq || hasGemini || hasOpenRouter || hasOpenAi;
}
