import 'package:flutter/material.dart';
import 'dart:convert';
import 'memory_block.dart';
export 'memory_block.dart';

// ═══════════════════════════════════════════════════════════════
// Antheia — Data Models
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
      case Mood.happy: return '😊';
      case Mood.calm: return '😌';
      case Mood.nostalgic: return '🌅';
      case Mood.sad: return '😢';
      case Mood.energetic: return '⚡';
      case Mood.anxious: return '😰';
      case Mood.grateful: return '🙏';
      case Mood.neutral: return '😐';
      case Mood.creative: return '🎨';
      case Mood.romantic: return '💖';
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
  final List<MemoryBlock> blocks;
  final bool synced;
  final String? thumbnailPath;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  JournalEntry({
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
    this.isVoiceEntry = false,
    this.sections = const [],
    List<MemoryBlock>? blocks,
    this.synced = false,
    this.thumbnailPath,
    this.latitude,
    this.longitude,
    this.locationLabel,
  }) : this.blocks = blocks ?? _mapSectionsToBlocks(sections);

  static List<MemoryBlock> _mapSectionsToBlocks(List<EntrySection> sections) {
    return sections.map<MemoryBlock>((s) {
      if (s.type == 'voice') {
        return VoiceBlock(
          id: s.blockId,
          transcript: s.content,
          audioPath: s.audioPath,
          duration: s.durationSeconds != null ? Duration(seconds: s.durationSeconds!) : null,
        );
      } else if (s.type == 'reflection') {
        return ReflectionBlock(
          id: s.blockId,
          content: s.content,
        );
      } else {
        return TextBlock(
          id: s.blockId,
          text: s.content,
        );
      }
    }).toList();
  }

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Mood? mood,
    String? location,
    double? temperature,
    String? weatherIcon,
    List<String>? tags,
    List<String>? photoUrls,
    int? durationMinutes,
    bool? isVoiceEntry,
    List<EntrySection>? sections,
    List<MemoryBlock>? blocks,
    bool? synced,
    String? thumbnailPath,
    bool clearThumbnail = false,
    bool clearLocation = false,
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) {
    List<EntrySection>? finalSections = sections;
    List<MemoryBlock>? finalBlocks = blocks;

    if (blocks != null && sections == null) {
      finalSections = blocks.map((b) {
        if (b is VoiceBlock) {
          return EntrySection(
            type: 'voice',
            content: b.transcript,
            audioPath: b.audioPath,
            durationSeconds: b.duration?.inSeconds,
            blockId: b.id,
          );
        } else if (b is ReflectionBlock) {
          return EntrySection(
            type: 'reflection',
            content: b.content,
            blockId: b.id,
          );
        } else if (b is TextBlock) {
          return EntrySection(
            type: 'paragraph',
            content: b.text,
            blockId: b.id,
          );
        } else {
          return EntrySection(
            type: 'paragraph',
            content: '',
            blockId: b.id,
          );
        }
      }).toList();
    } else if (sections != null && blocks == null) {
      finalBlocks = _mapSectionsToBlocks(sections);
    }

    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: mood ?? this.mood,
      location: location ?? this.location,
      temperature: temperature ?? this.temperature,
      weatherIcon: weatherIcon ?? this.weatherIcon,
      tags: tags ?? this.tags,
      photoUrls: photoUrls ?? this.photoUrls,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isVoiceEntry: isVoiceEntry ?? this.isVoiceEntry,
      sections: finalSections ?? this.sections,
      blocks: finalBlocks ?? this.blocks,
      synced: synced ?? this.synced,
      thumbnailPath: clearThumbnail ? null : (thumbnailPath ?? this.thumbnailPath),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationLabel: clearLocation ? null : (locationLabel ?? this.locationLabel),
    );
  }

  Map<String, dynamic> toMap() {
    final List<EntrySection> finalSections = blocks.isNotEmpty
        ? blocks.map((b) {
            if (b is VoiceBlock) {
              return EntrySection(
                type: 'voice',
                content: b.transcript,
                audioPath: b.audioPath,
                durationSeconds: b.duration?.inSeconds,
                blockId: b.id,
              );
            } else if (b is ReflectionBlock) {
              return EntrySection(
                type: 'reflection',
                content: b.content,
                blockId: b.id,
              );
            } else if (b is TextBlock) {
              return EntrySection(
                type: 'paragraph',
                content: b.text,
                blockId: b.id,
              );
            } else {
              return EntrySection(
                type: 'paragraph',
                content: '',
                blockId: b.id,
              );
            }
          }).toList()
        : sections;

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
      'sections': jsonEncode(finalSections.map((s) => s.toMap()).toList()),
      'synced': synced ? 1 : 0,
      'thumbnailPath': thumbnailPath,
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    final sections = (jsonDecode(map['sections'] as String? ?? '[]') as List)
        .map((s) => EntrySection.fromMap(s as Map<String, dynamic>))
        .toList();

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
      sections: sections,
      synced: (map['synced'] as int? ?? 0) == 1,
      thumbnailPath: map['thumbnailPath'] as String?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      locationLabel: map['locationLabel'] as String?,
    );
  }
}

class EntrySection {
  final String type; // 'heading', 'paragraph', 'quote', 'bullet', 'photo', 'voice'
  final String content;
  final int? headingLevel;
  final String? audioPath;
  final int? durationSeconds;
  final String? blockId;

  const EntrySection({
    required this.type,
    required this.content,
    this.headingLevel,
    this.audioPath,
    this.durationSeconds,
    this.blockId,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      if (headingLevel != null) 'headingLevel': headingLevel,
      if (audioPath != null) 'audioPath': audioPath,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (blockId != null) 'blockId': blockId,
    };
  }

  factory EntrySection.fromMap(Map<String, dynamic> map) {
    return EntrySection(
      type: map['type'] as String,
      content: map['content'] as String,
      headingLevel: map['headingLevel'] as int?,
      audioPath: map['audioPath'] as String?,
      durationSeconds: map['durationSeconds'] as int?,
      blockId: map['blockId'] as String?,
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
