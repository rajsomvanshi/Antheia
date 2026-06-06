import 'dart:math';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// Resurfacing Engine (Memory Gravity)
//
// Calculates the "gravity" or "resonance" of a memory relative to
// the current moment. Instead of a chronological feed, we resurface
// memories that feel emotionally relevant.
// ═══════════════════════════════════════════════════════════════

class ResurfacingEngine {
  
  /// Given a list of entries, returns a list of highly resonant entries
  /// for today's "Serendipity" or "Reflection" surface.
  static List<JournalEntry> getResonantMemories(List<JournalEntry> allEntries, {int limit = 3}) {
    if (allEntries.isEmpty) return [];

    final now = DateTime.now();
    
    // Calculate gravity for each entry
    final scoredEntries = allEntries.map((entry) {
      return MapEntry(entry, _calculateGravity(entry, now));
    }).toList();

    // Sort by highest gravity descending
    scoredEntries.sort((a, b) => b.value.compareTo(a.value));

    // Return the top N
    return scoredEntries.take(limit).map((e) => e.key).toList();
  }

  /// Calculates the "Gravity Score" (0.0 to 100.0+) of an entry.
  static double _calculateGravity(JournalEntry entry, DateTime now) {
    double score = 10.0; // Base score

    final ageInDays = now.difference(entry.createdAt).inDays;

    // 1. Anniversary Bonus (1 month, 6 months, exactly N years)
    if (ageInDays > 25 && ageInDays < 35) score += 20; // ~1 month
    if (ageInDays > 175 && ageInDays < 190) score += 30; // ~6 months
    
    // Yearly anniversary (within a 3 day window)
    if (ageInDays > 300) {
      final remainder = ageInDays % 365;
      if (remainder <= 3 || remainder >= 362) {
        score += 50; // Exact anniversary
      }
    }

    // 2. Emotional Resonance Bonus
    // High intensity emotions (happy, sad, romantic) have stronger lasting gravity
    // than neutral/calm ones when looking back.
    switch (entry.mood) {
      case Mood.happy:
      case Mood.sad:
      case Mood.romantic:
        score += 15;
        break;
      case Mood.anxious:
      case Mood.energetic:
        score += 10;
        break;
      default:
        score += 5;
    }

    // 3. Richness Bonus (photos, voice, long text)
    if (entry.photoUrls.isNotEmpty) score += 15;
    if (entry.isVoiceEntry || entry.durationMinutes > 0) score += 20;
    if (entry.content.length > 500 || entry.blocks.length > 2) score += 10;

    // 4. Random Serendipity (add some slight noise so the same memories don't always win)
    final randomNoise = Random(entry.id.hashCode + now.day).nextDouble() * 10;
    score += randomNoise;

    return score;
  }
}
