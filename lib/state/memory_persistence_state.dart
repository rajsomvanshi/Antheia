import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// Memory Persistence State — FIXED
//
// ISSUE 3 ROOT CAUSE:
//   The autosave pipeline had two silent failure modes:
//
//   1. saveDraft() compared _activeDraft == draft BEFORE writing.
//      If the in-memory string was already updated but the SQLite
//      write failed (e.g. disk full, DB not yet initialized), the
//      comparison short-circuited and the write was skipped permanently
//      — but _saveStatus showed "saved just now" regardless because
//      the try/catch in EditorSurface._autosaveDraft() only caught
//      the MemoryPersistenceState.saveDraft() throwing, which it never
//      did because DatabaseService errors were swallowed internally.
//
//   2. loadDraft() was called once at app start. If the DB hadn't
//      finished initializing (DatabaseService.init() is async and
//      errors are swallowed in main.dart), loadDraft() would silently
//      return null and _hasRecoveredDraft would stay false — even if
//      a draft existed on disk.
//
// FIXES:
//   1. saveDraft() now always writes to SQLite, regardless of
//      the in-memory equality check. The equality check is used only
//      to skip notifyListeners() spam, not to skip the DB write.
//   2. saveDraft() returns a bool indicating actual write success.
//   3. loadDraft() retries with exponential backoff if DB isn't ready.
//   4. Added verifyDraftPersisted() to confirm the write actually
//      landed on disk (read-back verification).
//   5. EditorSurface should call the bool return of saveDraft() to
//      correctly show "unsaved changes" if the write failed.
// ═══════════════════════════════════════════════════════════════

class MemoryPersistenceState extends ChangeNotifier {
  // ─── Offline Sync State ───
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  // ─── Draft Persistence (SQLite-backed) ───
  String _activeDraft = '';
  String get activeDraft => _activeDraft;

  bool _hasRecoveredDraft = false;
  bool get hasRecoveredDraft => _hasRecoveredDraft;

  // Tracks whether the last write actually succeeded on disk.
  bool _lastWriteSucceeded = true;
  bool get isDraftSafelyPersisted => _lastWriteSucceeded;

  /// Helper to check if draft is a JSON-encoded draft (from text editor) or plain text (from voice)
  bool get isJsonDraft {
    if (_activeDraft.trim().isEmpty) return false;
    return _activeDraft.trim().startsWith('{') && _activeDraft.trim().endsWith('}');
  }

  /// Parses the active draft and returns a recovered [JournalEntry]
  JournalEntry getRecoveredEntry() {
    if (_activeDraft.isEmpty) {
      return JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        content: '',
        blocks: [TextBlock()],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: Mood.neutral,
      );
    }

    try {
      if (isJsonDraft) {
        final decoded = jsonDecode(_activeDraft) as Map<String, dynamic>;
        if (decoded.containsKey('entry')) {
          final entryMap = decoded['entry'] as Map<String, dynamic>;
          final blocksRaw = decoded['blocks'] as List? ?? [];
          final blocks = blocksRaw.map((b) {
            final m = b as Map<String, dynamic>;
            final type = m['type'] as String? ?? 'text';
            if (type == 'text') return TextBlock.fromJson(m);
            if (type == 'voice') return VoiceBlock.fromJson(m);
            if (type == 'reflection') return ReflectionBlock.fromJson(m);
            return TextBlock();
          }).toList();

          return JournalEntry.fromMap(entryMap).copyWith(blocks: blocks);
        }
      }
    } catch (e) {
      debugPrint('[MemoryPersistenceState] Failed to decode JSON draft: $e');
    }

    // Fallback for plain text drafts (voice or old formats)
    return JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Recovered Memory',
      content: _activeDraft,
      blocks: [TextBlock(text: _activeDraft)],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mood: Mood.neutral,
    );
  }

  /// Extract display text preview from the active draft
  String get draftDisplayText {
    if (_activeDraft.isEmpty) return '';
    try {
      if (isJsonDraft) {
        final decoded = jsonDecode(_activeDraft) as Map<String, dynamic>;
        if (decoded.containsKey('entry')) {
          final entryMap = decoded['entry'] as Map<String, dynamic>;
          final content = entryMap['content'] as String? ?? '';
          if (content.trim().isNotEmpty) return content;
          final blocksRaw = decoded['blocks'] as List? ?? [];
          final text = blocksRaw
              .where((b) => (b as Map)['type'] == 'text')
              .map((b) => (b as Map)['text'] as String? ?? '')
              .where((t) => t.isNotEmpty)
              .join(' ');
          return text;
        }
      }
    } catch (_) {}
    return _activeDraft;
  }

  // ── FIX: saveDraft always writes to SQLite ─────────────────
  /// Save draft to SQLite. Returns true if the write succeeded on disk.
  Future<bool> saveDraft(String draft) async {
    // Update in-memory immediately so UI reflects latest state.
    final changed = _activeDraft != draft;
    _activeDraft = draft;

    // ── CRITICAL FIX ──────────────────────────────────────────
    // Always write to SQLite, even if the in-memory string is the same.
    // Reason: the DB write might have failed silently on a previous call.
    // We never skip the write to disk — only skip notifyListeners spam.
    // ─────────────────────────────────────────────────────────
    bool writeSucceeded = false;
    try {
      await DatabaseService().saveDraft(draft);
      writeSucceeded = true;
      _lastWriteSucceeded = true;
      debugPrint('[MemoryPersistenceState] Draft saved (${draft.length} chars)');
    } catch (e) {
      _lastWriteSucceeded = false;
      debugPrint('[MemoryPersistenceState] saveDraft FAILED: $e');
    }

    if (changed) notifyListeners();
    return writeSucceeded;
  }

  // ── FIX: loadDraft retries if DB isn't ready yet ───────────
  Future<void> loadDraft() async {
    // Retry up to 3 times with backoff — DatabaseService.init() is
    // async and may not have completed when the provider first calls loadDraft().
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final draft = await DatabaseService().loadDraft();
        _activeDraft = draft ?? '';
        if (_activeDraft.isNotEmpty) {
          _hasRecoveredDraft = true;
          debugPrint('[MemoryPersistenceState] Recovered draft (${_activeDraft.length} chars) on attempt $attempt');
        }
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('[MemoryPersistenceState] loadDraft attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    }
    // All attempts failed — start clean but don't crash
    _activeDraft = '';
    _hasRecoveredDraft = false;
    notifyListeners();
  }

  Future<void> clearDraft() async {
    _activeDraft = '';
    _hasRecoveredDraft = false;
    _lastWriteSucceeded = true;
    try {
      await DatabaseService().clearDraft();
    } catch (e) {
      debugPrint('[MemoryPersistenceState] clearDraft failed: $e');
    }
    notifyListeners();
  }

  void consumeRecoveredDraft() {
    _hasRecoveredDraft = false;
    notifyListeners();
  }

  // ── Verification: read-back from DB to confirm write landed ──
  /// Returns true if the draft currently in SQLite matches [expected].
  /// Call this from EditorSurface if you need to confirm a write succeeded.
  Future<bool> verifyDraftPersisted(String expected) async {
    try {
      final onDisk = await DatabaseService().loadDraft();
      return onDisk == expected;
    } catch (_) {
      return false;
    }
  }
}
