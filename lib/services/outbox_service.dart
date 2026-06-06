import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'binary_upload_service.dart';

// ═══════════════════════════════════════════════════════════════
// OutboxService — Durable Sync Queue
//
// Architecture:
//   Every write that must reach Supabase is first recorded as an
//   outbox job in SQLite. The outbox worker processes jobs with
//   exponential backoff. Jobs survive app kills, reboots, and
//   network outages.
//
// Operations:
//   'upsert' — push entry to Supabase (insert or update)
//   'delete' — delete entry from Supabase
//
// States:
//   'pending'           — queued, not yet attempted
//   'syncing'           — currently being pushed
//   'done'              — confirmed by Supabase (row deleted shortly after)
//   'failed'            — last attempt failed, will retry
//   'permanently_failed' — exceeded max attempts, needs user attention
// ═══════════════════════════════════════════════════════════════

class OutboxService {
  // ── Singleton ─────────────────────────────────────────────────
  static final OutboxService _instance = OutboxService._internal();
  factory OutboxService() => _instance;
  OutboxService._internal();

  Database? _db;
  Timer? _retryTimer;
  StreamSubscription? _connectivitySub;
  bool _processing = false;

  static const _table = 'outbox';
  static const _maxAttempts = 5;

  /// Backoff durations for retry attempts
  static const _backoffDurations = [
    Duration(seconds: 0),    // Attempt 1: immediate
    Duration(seconds: 30),   // Attempt 2
    Duration(minutes: 2),    // Attempt 3
    Duration(minutes: 10),   // Attempt 4
    Duration(minutes: 30),   // Attempt 5
  ];

  // ── Observable state ──────────────────────────────────────────
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> permanentlyFailedCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isSyncLimitReachedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isProcessing = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  
  /// Fires after the outbox queue finishes processing (success or failure).
  /// The UI should listen to this and reload entries to pick up updated synced flags.
  final ValueNotifier<int> syncCompletionCounter = ValueNotifier(0);

  int get pendingCount => pendingCountNotifier.value;
  bool get hasPendingJobs => pendingCountNotifier.value > 0;

  // ── Initialise ────────────────────────────────────────────────

  /// Call after DatabaseService.init() — shares the same database.
  Future<void> init(Database db) async {
    _db = db;
    await _updatePendingCount();
    _startConnectivityListener();
    // Process any pending jobs from previous session
    unawaited(processQueue());
  }

  void dispose() {
    _retryTimer?.cancel();
    _connectivitySub?.cancel();
  }

  // ── Enqueue ───────────────────────────────────────────────────

  /// Enqueue a sync job. Called after every local SQLite write.
  /// [op] must be 'upsert' or 'delete'.
  /// [payload] is the JSON-encoded entry data (null for deletes).
  Future<void> enqueue(String entryId, String op, String? payload) async {
    if (_db == null) {
      debugPrint('[Outbox] enqueue skipped: service not initialised.');
      return;
    }
    final db = _database;
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(
      _table,
      {
        'id': id,
        'entry_id': entryId,
        'op': op,
        'payload': payload,
        'status': 'pending',
        'attempts': 0,
        'last_tried': null,
        'error': null,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updatePendingCount();

    // Trigger immediate processing
    unawaited(processQueue());
  }

  // ── Process Queue ─────────────────────────────────────────────

  /// Process all pending/failed outbox jobs.
  /// Safe to call multiple times — serialised internally.
  Future<void> processQueue() async {
    if (_processing) return;
    if (_db == null) return;
    if (!ApiConfig.hasSupabase) return;

    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    // Check if cloud sync is gated by 15-entry limit for free users
    try {
      final db = _database;
      final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM journal_entries");
      final entriesCount = Sqflite.firstIntValue(result) ?? 0;
      
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('isPremium') ?? false;
      
      if (!isPremium && entriesCount >= 15) {
        debugPrint('[Outbox] Sync paused: 15 entries limit reached for free users. Upgrade to Antheia Pro.');
        isSyncLimitReachedNotifier.value = true;
        return;
      } else {
        isSyncLimitReachedNotifier.value = false;
      }
    } catch (e) {
      debugPrint('[Outbox] Error checking entry limit: $e');
    }

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _processing = true;
    isProcessing.value = true;

    try {
      final db = _database;
      final jobs = await db.query(
        _table,
        where: "status IN ('pending', 'failed')",
        orderBy: 'created_at ASC',
      );

      for (final job in jobs) {
        final jobId = job['id'] as String;
        final entryId = job['entry_id'] as String;
        final op = job['op'] as String;
        final payload = job['payload'] as String?;
        final attempts = (job['attempts'] as int?) ?? 0;

        // Skip metadata sync if binary uploads for this entry are still in progress
        if (await BinaryUploadService().hasPendingUploads(entryId)) {
          debugPrint('[Outbox] Skipping job $jobId for entry $entryId: binary uploads are still pending.');
          continue;
        }

        if (attempts >= _maxAttempts) {
          await _markPermanentlyFailed(jobId, 'Exceeded max retry attempts');
          continue;
        }

        // Check if we should wait (backoff)
        final lastTried = job['last_tried'] as String?;
        if (lastTried != null && attempts > 0) {
          final lastAttempt = DateTime.parse(lastTried);
          final backoffIndex = (attempts - 1).clamp(0, _backoffDurations.length - 1);
          final nextAllowed = lastAttempt.add(_backoffDurations[backoffIndex]);
          if (DateTime.now().toUtc().isBefore(nextAllowed)) {
            continue; // Not time to retry yet
          }
        }

        // Mark as syncing
        await db.update(
          _table,
          {
            'status': 'syncing',
            'last_tried': DateTime.now().toUtc().toIso8601String(),
            'attempts': attempts + 1,
          },
          where: 'id = ?',
          whereArgs: [jobId],
        );

        try {
          if (op == 'upsert') {
            await _pushUpsert(entryId, payload!, currentUser.id);
            // Mark the local entry as synced in SQLite so the UI sync count displays accurately.
            try {
              await db.update(
                'journal_entries',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [entryId],
              );
            } catch (e) {
              debugPrint('[Outbox] Failed to mark local entry $entryId as synced: $e');
            }
          } else if (op == 'delete') {
            await _pushDelete(entryId, currentUser.id);
          }

          // Success — remove from outbox
          await db.delete(_table, where: 'id = ?', whereArgs: [jobId]);
          debugPrint('[Outbox] Job $jobId ($op) for entry $entryId completed');
        } catch (e) {
          final newAttempts = attempts + 1;
          if (newAttempts >= _maxAttempts) {
            await _markPermanentlyFailed(jobId, e.toString());
          } else {
            await db.update(
              _table,
              {'status': 'failed', 'error': e.toString()},
              where: 'id = ?',
              whereArgs: [jobId],
            );
          }
          debugPrint('[Outbox] Job $jobId failed (attempt $newAttempts): $e');
        }
      }
    } catch (e) {
      debugPrint('[Outbox] Queue processing error: $e');
      lastError.value = e.toString();
    } finally {
      _processing = false;
      isProcessing.value = false;
      await _updatePendingCount();
      _scheduleNextRetry();
      // Notify listeners that sync round completed — UI should reload entries
      syncCompletionCounter.value++;
    }
  }

  // ── Supabase Operations ───────────────────────────────────────

  Future<void> _pushUpsert(String entryId, String payloadJson, String userId) async {
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;

    // Ensure user_id is always present
    map['user_id'] = userId;

    // Remove internal-only fields
    map.remove('synced');

    // Decode JSON-encoded arrays for Supabase (expects actual arrays)
    for (final key in ['tags', 'photoUrls', 'sections']) {
      final value = map[key];
      if (value is String) {
        try {
          map[key] = jsonDecode(value);
        } catch (_) {
          map[key] = [];
        }
      }
    }

    await AuthService().withAuth(() async {
      await Supabase.instance.client
          .from('journal_entries')
          .upsert(map, onConflict: 'id');
    });
  }

  Future<void> _pushDelete(String entryId, String userId) async {
    await AuthService().withAuth(() async {
      await Supabase.instance.client
          .from('journal_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId);
    });
  }

  // ── Internal Helpers ──────────────────────────────────────────

  Future<void> _markPermanentlyFailed(String jobId, String error) async {
    await _database.update(
      _table,
      {'status': 'permanently_failed', 'error': error},
      where: 'id = ?',
      whereArgs: [jobId],
    );
    debugPrint('[Outbox] Job $jobId permanently failed: $error');
  }

  Future<void> _updatePendingCount() async {
    if (_db == null) return;
    try {
      final result = await _database.rawQuery(
        "SELECT COUNT(*) as cnt FROM $_table WHERE status IN ('pending', 'failed', 'syncing')",
      );
      pendingCountNotifier.value = Sqflite.firstIntValue(result) ?? 0;

      final failedResult = await _database.rawQuery(
        "SELECT COUNT(*) as cnt FROM $_table WHERE status = 'permanently_failed'",
      );
      permanentlyFailedCountNotifier.value = Sqflite.firstIntValue(failedResult) ?? 0;
    } catch (_) {}
  }

  void _scheduleNextRetry() {
    _retryTimer?.cancel();
    if (pendingCount > 0) {
      _retryTimer = Timer(const Duration(seconds: 30), () {
        processQueue();
      });
    }
  }

  void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Network restored — retry all pending immediately
        processQueue();
      }
    });
  }

  Database get _database {
    if (_db == null) {
      throw StateError('OutboxService not initialised. Call init() first.');
    }
    return _db!;
  }

  // ── Query Helpers (for Settings sync status UI) ───────────────

  Future<int> get permanentlyFailedCount async {
    if (_db == null) return 0;
    final result = await _database.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_table WHERE status = 'permanently_failed'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns a human-readable sync status string.
  Future<String> getSyncStatusText() async {
    final pending = pendingCount;
    final permFailed = await permanentlyFailedCount;

    if (permFailed > 0) {
      return 'Backup failed — $permFailed entries need attention';
    }
    if (pending > 0) {
      return isProcessing.value
          ? 'Syncing… ($pending pending)'
          : 'Backup delayed ($pending pending)';
    }
    return 'All memories backed up';
  }

  /// Retry permanently failed jobs (user-initiated).
  Future<void> retryFailed() async {
    if (_db == null) return;
    await _database.update(
      _table,
      {'status': 'pending', 'attempts': 0, 'error': null},
      where: "status = 'permanently_failed'",
    );
    await _updatePendingCount();
    unawaited(processQueue());
  }
}
