import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/memory_enrichment_service.dart';
import '../services/resurfacing_engine.dart';

class MemoryState extends ChangeNotifier {
  final _db = DatabaseService();
  final _enrichment = MemoryEnrichmentService();

  List<JournalEntry> _entries = [];
  List<JournalEntry> get entries => List.unmodifiable(_entries);

  // ── Track database loading state ──
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  JournalEntry? _currentEntry;
  JournalEntry? get currentEntry => _currentEntry;

  JournalEntry? get safeCurrentEntry =>
      _currentEntry ?? (_entries.isNotEmpty ? _entries.first : null);

  String? _pendingRawText;
  String? get pendingDraft => _pendingRawText;

  Future<void> loadEntries({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _entries = await _db.loadEntries();
    } catch (e) {
      debugPrint('[MemoryState] loadEntries failed: $e');
      _entries = [];
    }
    if (!quiet) {
      _isLoading = false;
    }
    notifyListeners();
  }

  void setCurrentEntry(JournalEntry? entry) {
    _currentEntry = entry;
    notifyListeners();
  }

  Future<void> addEntry(JournalEntry entry) async {
    _entries.insert(0, entry);
    notifyListeners();
    
    // ── Track event in PostHog ──
    try {
      Posthog().capture(
        eventName: 'editor_entry_saved',
        properties: {
          'is_voice': entry.isVoiceEntry,
          'mood': entry.mood.toString().split('.').last,
          'has_photos': entry.photoUrls.isNotEmpty,
          'has_location': entry.latitude != null,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] PostHog tracking failed: $e');
    }

    // ── FIX: Surface DB errors instead of swallowing them ──────
    try {
      await _db.insertEntry(entry);
      debugPrint('[MemoryState] Entry ${entry.id} persisted to SQLite ✓');
    } catch (e) {
      debugPrint('[MemoryState] CRITICAL: insertEntry failed: $e');
      // Rethrow so _saveAndExit can show the user a "save failed" snackbar
      // and stay in the editor rather than silently losing the entry.
      rethrow;
    }
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) _entries[idx] = entry;
    if (_currentEntry?.id == entry.id) _currentEntry = entry;
    notifyListeners();
    // ── FIX: Surface DB errors instead of swallowing them ──────
    try {
      await _db.updateEntry(entry);
      debugPrint('[MemoryState] Entry ${entry.id} updated in SQLite ✓');
    } catch (e) {
      debugPrint('[MemoryState] CRITICAL: updateEntry failed: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    final entryIdx = _entries.indexWhere((e) => e.id == id);
    if (entryIdx != -1) {
      final entry = _entries[entryIdx];
      for (final sec in entry.sections) {
        if (sec.type == 'voice' && sec.audioPath != null) {
          try {
            final file = File(sec.audioPath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('[MemoryState] Failed to delete audio file: $e');
          }
        }
      }
    }
    _entries.removeWhere((e) => e.id == id);
    if (_currentEntry?.id == id) _currentEntry = null;
    notifyListeners();
    await _db.deleteEntry(id);
  }

  void clearMemory() {
    _entries.clear();
    _currentEntry = null;
    notifyListeners();
  }

  Future<void> replaceAllEntries(List<JournalEntry> incoming) async {
    // ── SAFETY GUARD: Never wipe a populated list with an empty one ──
    // If the incoming list is empty but we have existing entries, this is
    // almost certainly a sync failure — not a legitimate "delete all".
    if (incoming.isEmpty && _entries.isNotEmpty) {
      debugPrint('[MemoryState] ⚠️ GUARD: replaceAllEntries() blocked — '
          'refusing to wipe ${_entries.length} entries with an empty list. '
          'Use deleteAllData() for intentional deletion.');
      return;
    }
    _entries
      ..clear()
      ..addAll(incoming);
    notifyListeners();
    await _db.replaceAllEntries(incoming);
  }

  Future<JournalEntry?> processVoiceEntry({
    required String rawText,
    double? latitude,
    double? longitude,
    int durationMinutes = 0,
    required dynamic voiceState,
    String? tone,
    String? formatting,
    String? audioPath,
  }) async {
    final text = rawText.trim().isEmpty ? 'A quiet moment.' : rawText.trim();
    _pendingRawText = text;

    try {
      _enrichment.onProgress = (progress, step) {
        try {
          voiceState.setProcessingState(
            isProcessing: true,
            progress: progress,
            step: step,
          );
        } catch (_) {}
      };

      final entry = await _enrichment.processEntry(
        rawText: text,
        latitude: latitude,
        longitude: longitude,
        tone: tone,
        formatting: formatting,
      );

      final enrichedSections = [
        EntrySection(
          type: 'voice',
          content: text,
          audioPath: audioPath,
          durationSeconds: durationMinutes * 60,
        ),
        ...entry.sections,
      ];

      final stamped = entry.copyWith(
        durationMinutes: durationMinutes,
        sections: enrichedSections,
      );
      await addEntry(stamped);
      setCurrentEntry(stamped);
      _pendingRawText = null;
      return stamped;
    } catch (e) {
      debugPrint('[MemoryState] processVoiceEntry failed: $e. Falling back to local-only preservation.');
      
      // Fallback! Construct a valid local-only entry using the raw transcript
      final now = DateTime.now();
      final stamped = JournalEntry(
        id: const Uuid().v4(),
        title: 'Voice Reflection (${DateFormat('MMM d, yyyy').format(now)})',
        content: text,
        createdAt: now,
        updatedAt: now,
        mood: Mood.neutral,
        durationMinutes: durationMinutes,
        isVoiceEntry: true,
        sections: [
          EntrySection(
            type: 'voice',
            content: text,
            audioPath: audioPath,
            durationSeconds: durationMinutes * 60,
          )
        ],
      );

      await addEntry(stamped);
      setCurrentEntry(stamped);
      _pendingRawText = null;
      return stamped;
    } finally {
      unawaited(Future<void>.microtask(() {
        try {
          voiceState.setProcessingState(isProcessing: false);
        } catch (_) {}
      }));
    }
  }

  String? consumePendingDraft() {
    final draft = _pendingRawText;
    _pendingRawText = null;
    return draft;
  }

  Future<void> deleteAllData() async {
    for (final entry in _entries) {
      for (final sec in entry.sections) {
        if (sec.type == 'voice' && sec.audioPath != null) {
          try {
            final file = File(sec.audioPath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('[MemoryState] Failed to delete audio file: $e');
          }
        }
      }
    }
    clearMemory();
    await _db.deleteAllEntries();
  }

  List<JournalEntry> get resonantMemories =>
      ResurfacingEngine.getResonantMemories(_entries, limit: 3);

  int get mediaCount => _entries.fold(0, (sum, e) => sum + e.photoUrls.length);

  int get voiceEntryCount => _entries.where((e) => e.isVoiceEntry).length;

  DateTime? get journalStartDate => _entries.isEmpty
      ? null
      : _entries
          .reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b)
          .createdAt;

  int get uniqueDaysJournaled => _entries
      .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day)
          .toIso8601String())
      .toSet()
      .length;

  int get currentStreak {
    if (_entries.isEmpty) return 0;
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final normalized = DateTime(day.year, day.month, day.day);
      final hasEntry = _entries.any((e) =>
          e.createdAt.year == normalized.year &&
          e.createdAt.month == normalized.month &&
          e.createdAt.day == normalized.day);
      if (hasEntry) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  int get bestStreak {
    if (_entries.isEmpty) return 0;
    final days = _entries
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .toList()
      ..sort();

    int best = 1;
    int current = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  List<PersonMention> get people => const [];

  List<LocationMemory> get locations {
    final Map<String, List<JournalEntry>> clusters = {};
    for (final entry in _entries) {
      double? lat = entry.latitude;
      double? lng = entry.longitude;

      if (lat == null || lng == null) {
        final loc = entry.location;
        if (loc != null && loc.contains(',')) {
          final parts = loc.split(',');
          if (parts.length >= 2) {
            lat = double.tryParse(parts[0].trim());
            lng = double.tryParse(parts[1].trim());
          }
        }
      }

      if (lat == null || lng == null) continue;
      final key = '${(lat * 100).round() / 100},${(lng * 100).round() / 100}';
      clusters.putIfAbsent(key, () => []).add(entry);
    }

    return clusters.entries.map((cluster) {
      final clusterEntries = cluster.value;
      final parts = cluster.key.split(',');
      final lat = double.parse(parts[0]);
      final lng = double.parse(parts[1]);
      final latest = clusterEntries
          .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      
      String name = 'Journal Location';
      if (latest.locationLabel != null && latest.locationLabel!.isNotEmpty) {
        name = latest.locationLabel!;
      } else if (latest.location != null && !latest.location!.contains(',')) {
        name = latest.location!;
      }

      return LocationMemory(
        name: name,
        icon: Icons.place_rounded,
        entryCount: clusterEntries.length,
        latestEntry: latest.title,
        latitude: lat,
        longitude: lng,
      );
    }).toList();
  }
}
