// ═══════════════════════════════════════════════════════════════
// VoiceFilterService — Real-time Speech Sanitization Pipeline
// ═══════════════════════════════════════════════════════════════

class VoiceFilterService {
  VoiceFilterService._();

  // Filler words to strip
  static const _fillers = [
    r'\b(um+|uh+|ah+|ahh+|hmm+|err+|umm+|uhh+|like)\b',
    r'\b(you know|i mean|like i said|basically|literally|sort of|kind of|right\?)\b',
  ];

  // Profanity list to soften
  static const _profanity = [
    'fuck', 'fucking', 'fucker', 'shit', 'bitch', 'asshole', 'bastard', 'damn it', 'crap',
  ];

  /// Core sanitation pipeline
  static String clean(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw.trim();

    // Step 1: remove filler words (case-insensitive)
    for (final pattern in _fillers) {
      text = text.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // Step 2: soften profanity (case-insensitive)
    for (final word in _profanity) {
      text = text.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        '—',
      );
    }

    // Step 3: deduplicate immediately repeated words ("i i went" → "i went")
    text = text.replaceAllMapped(
      RegExp(r'\b(\w+)(\s+\1)+\b', caseSensitive: false),
      (m) => m.group(1)!,
    );

    // Step 4: normalize whitespace
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // Step 4.5: strip leading punctuation and whitespace (e.g. leftover commas)
    text = text.replaceAll(RegExp(r'^[,.!?\s]+'), '').trim();

    if (text.isEmpty) return '';

    // Step 5: capitalize first letter of each sentence
    text = text.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (m) => m.group(1)! + m.group(2)!.toUpperCase(),
    );

    // Step 6: capitalize the absolute first character if it was missed
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    // Step 7: ensure sentence ends with punctuation
    if (text.isNotEmpty && !'.!?'.contains(text[text.length - 1])) {
      text += '.';
    }

    return text;
  }
}
