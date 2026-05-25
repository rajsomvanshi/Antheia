import 'package:flutter/material.dart';
import 'dart:convert';

// ═══════════════════════════════════════════════════════════════
// FlowJournal Data Models
// ═══════════════════════════════════════════════════════════════

enum Mood {
  happy('Happy', Icons.sentiment_very_satisfied_rounded, Color(0xFF00B894)),
  calm('Calm', Icons.self_improvement_rounded, Color(0xFF74B9FF)),
  nostalgic('Nostalgic', Icons.hourglass_top_rounded, Color(0xFFFDCB6E)),
  sad('Sad', Icons.sentiment_dissatisfied_rounded, Color(0xFF636E72)),
  energetic('Energetic', Icons.bolt_rounded, Color(0xFFE17055)),
  anxious('Anxious', Icons.psychology_alt_rounded, Color(0xFFFF7675)),
  grateful('Grateful', Icons.favorite_rounded, Color(0xFF00B894)),
  neutral('Neutral', Icons.sentiment_neutral_rounded, Color(0xFFDFE6E9)),
  creative('Creative', Icons.palette_rounded, Color(0xFF6C5CE7)),
  romantic('Romantic', Icons.favorite_border_rounded, Color(0xFFFD79A8));

  const Mood(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  String get emoji {
    switch (this) {
      case Mood.happy: return '';
      case Mood.calm: return '';
      case Mood.nostalgic: return '';
      case Mood.sad: return '';
      case Mood.energetic: return '';
      case Mood.anxious: return '';
      case Mood.grateful: return '';
      case Mood.neutral: return '';
      case Mood.creative: return '';
      case Mood.romantic: return '';
    }
  }
}

class MoodIcon extends StatelessWidget {
  final Mood mood;
  final double size;
  final Color? colorOverride;

  const MoodIcon({
    super.key,
    required this.mood,
    this.size = 20,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      mood.icon,
      size: size,
      color: colorOverride ?? mood.color,
    );
  }
}

class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Mood mood;
  final String? location;
  final double? temperature;
  final String? weatherIcon;
  final List<String> tags;
  final List<String> photoUrls;
  final int durationMinutes;
  final bool isVoiceEntry;
  final List<EntrySection> sections;

  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.mood,
    this.location,
    this.temperature,
    this.weatherIcon,
    this.tags = const [],
    this.photoUrls = const [],
    this.durationMinutes = 0,
    this.isVoiceEntry = true,
    this.sections = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mood': mood.name,
      'location': location,
      'temperature': temperature,
      'weatherIcon': weatherIcon,
      'tags': jsonEncode(tags),
      'photoUrls': jsonEncode(photoUrls),
      'durationMinutes': durationMinutes,
      'isVoiceEntry': isVoiceEntry ? 1 : 0,
      'sections': jsonEncode(sections.map((s) => s.toMap()).toList()),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      mood: Mood.values.firstWhere(
        (m) => m.name == map['mood'],
        orElse: () => Mood.neutral,
      ),
      location: map['location'] as String?,
      temperature: map['temperature'] as double?,
      weatherIcon: map['weatherIcon'] as String?,
      tags: List<String>.from(jsonDecode(map['tags'] as String? ?? '[]')),
      photoUrls: List<String>.from(
          jsonDecode(map['photoUrls'] as String? ?? '[]')),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      isVoiceEntry: (map['isVoiceEntry'] as int? ?? 1) == 1,
      sections: (jsonDecode(map['sections'] as String? ?? '[]') as List)
          .map((s) => EntrySection.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EntrySection {
  final String type; // 'heading', 'paragraph', 'quote', 'bullet', 'photo'
  final String content;
  final int? headingLevel;

  const EntrySection({
    required this.type,
    required this.content,
    this.headingLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'headingLevel': headingLevel,
    };
  }

  factory EntrySection.fromMap(Map<String, dynamic> map) {
    return EntrySection(
      type: map['type'] as String,
      content: map['content'] as String,
      headingLevel: map['headingLevel'] as int?,
    );
  }
}

class PersonMention {
  final String name;
  final String initial;
  final int entryCount;
  final double emotionalScore;
  final IconData emotionalIcon;

  const PersonMention({
    required this.name,
    required this.initial,
    required this.entryCount,
    required this.emotionalScore,
    required this.emotionalIcon,
  });
}

class LocationMemory {
  final String name;
  final IconData icon;
  final int entryCount;
  final String latestEntry;
  final double latitude;
  final double longitude;

  const LocationMemory({
    required this.name,
    required this.icon,
    required this.entryCount,
    required this.latestEntry,
    required this.latitude,
    required this.longitude,
  });
}

enum JournalFontPreset {
  journal('Journal', 'Serif body, sans headings'),
  professional('Professional', 'All sans-serif'),
  creative('Creative', 'Handwriting titles, sans body'),
  minimal('Minimal', 'Monospace, no bold'),
  romantic('Romantic', 'All script'),
  editorial('Editorial', 'Display titles, serif body');

  const JournalFontPreset(this.label, this.description);
  final String label;
  final String description;
}

enum JournalThemePreset {
  pureWhite('Pure White', 'Minimal'),
  creamPaper('Cream Paper', 'Minimal'),
  slateDark('Slate Dark', 'Minimal'),
  forestMist('Forest Mist', 'Nature'),
  oceanBreeze('Ocean Breeze', 'Nature'),
  sunsetGlow('Sunset Glow', 'Nature'),
  cottagecore('Cottagecore', 'Aesthetic'),
  darkAcademia('Dark Academia', 'Aesthetic'),
  vaporwave('Vaporwave', 'Aesthetic'),
  springBloom('Spring Bloom', 'Seasonal'),
  autumnLeaves('Autumn Leaves', 'Seasonal'),
  calmBlue('Calm Blue', 'Mood'),
  energeticOrange('Energetic Orange', 'Mood'),
  melancholyGray('Melancholy Gray', 'Mood');

  const JournalThemePreset(this.label, this.category);
  final String label;
  final String category;
}

enum PersonalityStyle {
  calm('Calm', Icons.spa_outlined, Color(0xFF74B9FF)),
  energetic('Energetic', Icons.bolt_outlined, Color(0xFFE17055)),
  nostalgic('Nostalgic', Icons.auto_awesome_outlined, Color(0xFFFDCB6E)),
  minimal('Minimal', Icons.crop_square_outlined, Color(0xFF636E72)),
  creative('Creative', Icons.palette_outlined, Color(0xFF6C5CE7)),
  romantic('Romantic', Icons.favorite_outline, Color(0xFFFD79A8));

  const PersonalityStyle(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
