import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'outbox_service.dart';
import 'binary_upload_service.dart';

// ═══════════════════════════════════════════════════════════════
// DatabaseService — SQLite (source of truth) + Outbox (sync)
//
// Architecture:
//   SQLite in WAL mode is the canonical source of truth.
//   All Supabase writes go through OutboxService (see Section 1+2
//   of the Permanent Architecture document).
//
// Tables:
//   journal_entries — user memories
//   outbox          — pending sync jobs (managed by OutboxService)
//   drafts          — crash-safe voice recording drafts
// ═══════════════════════════════════════════════════════════════

class DatabaseService {
  // ── Singleton ─────────────────────────────────────────────────
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  bool _supabaseReady = false;
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  static const _dbName    = 'antheia.db';
  static const _dbVersion = 4;
  static const _table     = 'journal_entries';
  static const _draftsTable = 'drafts';

  // ──────────────────────────────────────────────────────────────
  // Initialise
  // ──────────────────────────────────────────────────────────────

  /// Call this if init() previously failed and you want to retry.
  /// Safe to call — clears the null _db so init() won't early-return.
  void resetForRetry() {
    if (_db == null) {
      debugPrint('[DB] resetForRetry called — will reattempt init()');
      // _db is already null, so init() will retry naturally.
    }
  }

  Future<void> init() async {
    if (_db != null) return;

    try {
      await _initSupabaseIfConfigured();
    } catch (e) {
      debugPrint('[DB] Supabase pre-init failed (non-fatal): $e');
    }

    // Load last sync time (non-critical)
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_sync_timestamp');
      if (lastSyncStr != null) {
        lastSyncNotifier.value = DateTime.tryParse(lastSyncStr);
      }
    } catch (_) {}

    // ── CRITICAL: Open the database ──────────────────────────────
    // This section MUST succeed or the app is non-functional.
    // Each step is individually wrapped so one failure doesn't
    // prevent the database from opening.
    final dbPath = p.join(await getDatabasesPath(), _dbName);

    try {
      await _copyLegacyDatabaseIfNeeded(dbPath);
    } catch (e) {
      debugPrint('[DB] Legacy copy failed (non-fatal): $e');
    }

    try {
      _db = await _openDatabaseConn(dbPath);
    } catch (e) {
      debugPrint('[SQLite Recovery] Database initialization failed: $e. Attempting forensic quarantine.');
      try {
        final corruptBackupPath = p.join(
          await getDatabasesPath(),
          'antheia_corrupt_${DateTime.now().millisecondsSinceEpoch}.db',
        );
        final corruptFile = File(dbPath);
        if (await corruptFile.exists()) {
          await corruptFile.rename(corruptBackupPath);
          debugPrint('[SQLite Recovery] Successfully quarantined failed db to: $corruptBackupPath');
        }
      } catch (quarantineError) {
        debugPrint('[SQLite Recovery] Failed database quarantine: $quarantineError');
      }
      // Attempt fresh reconstruction
      try {
        _db = await _openDatabaseConn(dbPath);
      } catch (e2) {
        debugPrint('[SQLite Recovery] FATAL: Fresh database also failed: $e2');
      }
    }

    // If _db is STILL null, nothing else can proceed
    if (_db == null) {
      debugPrint('[DB] CRITICAL: Database could not be opened. All persistence is disabled.');
      throw StateError('SQLite Database could not be opened after recovery attempts.');
    }

    // Run migration checks (non-critical — individual statements are try-caught inside)
    try {
      await _runMigrations(_db!);
    } catch (e) {
      debugPrint('[DB] Migrations failed (non-fatal): $e');
    }

    // Merge legacy database entries (non-critical)
    try {
      await _mergeLegacyDatabaseIfNeeded();
    } catch (e) {
      debugPrint('[DB] Legacy merge failed (non-fatal): $e');
    }

    // Initialise OutboxService (non-critical for core app function)
    try {
      await OutboxService().init(_db!);
    } catch (e) {
      debugPrint('[DB] OutboxService init failed (non-fatal): $e');
    }

    // Initialise BinaryUploadService (non-critical)
    try {
      await BinaryUploadService().init(_db!);
    } catch (e) {
      debugPrint('[DB] BinaryUploadService init failed (non-fatal): $e');
    }

    // Backport legacy local paths (fire-and-forget, non-critical)
    unawaited(_scanAndEnqueueLegacyMedia());
  }

  Future<Database> _openDatabaseConn(String dbPath) async {
    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id            TEXT PRIMARY KEY,
            title         TEXT NOT NULL,
            content       TEXT NOT NULL,
            createdAt     TEXT NOT NULL,
            updatedAt     TEXT NOT NULL,
            mood          TEXT NOT NULL,
            location      TEXT,
            temperature   REAL,
            weatherIcon   TEXT,
            tags          TEXT NOT NULL DEFAULT '[]',
            photoUrls     TEXT NOT NULL DEFAULT '[]',
            durationMinutes INTEGER NOT NULL DEFAULT 0,
            isVoiceEntry  INTEGER NOT NULL DEFAULT 1,
            sections      TEXT NOT NULL DEFAULT '[]',
            synced        INTEGER NOT NULL DEFAULT 0,
            thumbnailPath TEXT,
            latitude      REAL,
            longitude     REAL,
            locationLabel TEXT
          )
        ''');
        await _createOutboxTable(db);
        await _createDraftsTable(db);
        await _createBinaryUploadQueueTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE $_table ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await _createOutboxTable(db);
          } catch (_) {}
          try {
            await _createDraftsTable(db);
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE $_table ADD COLUMN thumbnailPath TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $_table ADD COLUMN latitude REAL');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $_table ADD COLUMN longitude REAL');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $_table ADD COLUMN locationLabel TEXT');
          } catch (_) {}
        }
      },
    );

    // Enable WAL mode for crash-safe atomic writes
    try {
      await db.rawQuery('PRAGMA journal_mode=WAL');
    } catch (e) {
      debugPrint('[DB] WAL mode not supported or failed to enable (falling back): $e');
    }
    return db;
  }

  Future<void> _createOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        id          TEXT PRIMARY KEY,
        entry_id    TEXT NOT NULL,
        op          TEXT NOT NULL,
        payload     TEXT,
        status      TEXT NOT NULL DEFAULT 'pending',
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_tried  TEXT,
        error       TEXT,
        created_at  TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_draftsTable (
        id          TEXT PRIMARY KEY DEFAULT 'active_draft',
        content     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBinaryUploadQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS binary_upload_queue (
        id            TEXT PRIMARY KEY,
        entry_id      TEXT NOT NULL,
        local_path    TEXT NOT NULL,
        bucket        TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'pending',
        public_url    TEXT,
        error         TEXT,
        created_at    TEXT NOT NULL
      )
    ''');
  }

  Future<void> _initSupabaseIfConfigured() async {
    await AuthService().initialize();
    _supabaseReady = AuthService().isSupabaseReady;
  }

  Future<void> _runMigrations(Database db) async {
    final migrations = [
      "ALTER TABLE $_table ADD COLUMN thumbnailPath TEXT",
      "ALTER TABLE $_table ADD COLUMN latitude REAL",
      "ALTER TABLE $_table ADD COLUMN longitude REAL",
      "ALTER TABLE $_table ADD COLUMN locationLabel TEXT",
      "CREATE TABLE IF NOT EXISTS outbox (id TEXT PRIMARY KEY, entry_id TEXT NOT NULL, op TEXT NOT NULL, payload TEXT, status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0, last_tried TEXT, error TEXT, created_at TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS drafts (id TEXT PRIMARY KEY DEFAULT 'active_draft', content TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS binary_upload_queue (id TEXT PRIMARY KEY, entry_id TEXT NOT NULL, local_path TEXT NOT NULL, bucket TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', public_url TEXT, error TEXT, created_at TEXT NOT NULL)",
    ];
    
    for (final sql in migrations) {
      try {
        await db.execute(sql);
        debugPrint('[DB] Migration OK: $sql');
      } catch (e) {
        // Column already exists or table is locked — safe to ignore
        debugPrint('[DB] Migration skipped: $e');
      }
    }
  }

  Future<void> _copyLegacyDatabaseIfNeeded(String dbPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('legacy_db_migrated') ?? false;
      if (migrated) {
        debugPrint('[DB] Legacy database migration already marked as completed.');
        return;
      }

      final newDb = File(dbPath);
      if (await newDb.exists()) {
        await prefs.setBool('legacy_db_migrated', true);
        return;
      }

      // Check for lowercase 'flowjournal.db' first
      var legacyPath = p.join(await getDatabasesPath(), 'flowjournal.db');
      var legacyDb = File(legacyPath);
      
      // If not found, check for camelcase 'FlowJournal.db'
      if (!await legacyDb.exists()) {
        legacyPath = p.join(await getDatabasesPath(), 'FlowJournal.db');
        legacyDb = File(legacyPath);
      }

      if (!await legacyDb.exists()) {
        // No legacy DB found — mark as migrated so we don't check again
        await prefs.setBool('legacy_db_migrated', true);
        return;
      }

      await legacyDb.copy(dbPath);
      debugPrint('Successfully migrated legacy database file to $dbPath');
      await prefs.setBool('legacy_db_migrated', true);
    } catch (e) {
      debugPrint('Failed to copy legacy database: $e');
    }
  }

  Future<void> _mergeLegacyDatabaseIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('legacy_db_migrated') ?? false;
      if (migrated) return;

      // Check for lowercase 'flowjournal.db' first
      var legacyPath = p.join(await getDatabasesPath(), 'flowjournal.db');
      var legacyDb = File(legacyPath);
      
      // If not found, check for camelcase 'FlowJournal.db'
      if (!await legacyDb.exists()) {
        legacyPath = p.join(await getDatabasesPath(), 'FlowJournal.db');
        legacyDb = File(legacyPath);
      }

      if (!await legacyDb.exists()) {
        await prefs.setBool('legacy_db_migrated', true);
        return;
      }

      debugPrint('[DB Migration] Merging legacy database entries into active connection...');
      Database? legacyDbConn;
      try {
        legacyDbConn = await openDatabase(legacyPath, readOnly: true);

        // Get all entries from legacy
        final List<Map<String, dynamic>> legacyRows = await legacyDbConn.query('journal_entries');
        debugPrint('[DB Migration] Found ${legacyRows.length} legacy entries to merge.');

        // Query active schema table info to filter only known columns
        final List<Map<String, dynamic>> columnsInfo = await _database.rawQuery('PRAGMA table_info($_table)');
        final Set<String> knownColumns = columnsInfo.map((col) => col['name'] as String).toSet();

        int mergedCount = 0;
        await _database.transaction((txn) async {
          for (final row in legacyRows) {
            final map = Map<String, dynamic>.from(row);
            
            // Strip out keys that are not in the current schema to prevent crash
            map.removeWhere((key, value) => !knownColumns.contains(key));
            
            // Set defaults for required columns if they are missing in legacy DB
            if (knownColumns.contains('title')) map['title'] ??= '';
            if (knownColumns.contains('content')) map['content'] ??= '';
            if (knownColumns.contains('createdAt')) map['createdAt'] ??= DateTime.now().toUtc().toIso8601String();
            if (knownColumns.contains('updatedAt')) map['updatedAt'] ??= map['createdAt'];
            if (knownColumns.contains('mood')) map['mood'] ??= 'neutral';
            if (knownColumns.contains('tags')) map['tags'] ??= '[]';
            if (knownColumns.contains('photoUrls')) map['photoUrls'] ??= '[]';
            if (knownColumns.contains('sections')) map['sections'] ??= '[]';
            if (knownColumns.contains('durationMinutes')) map['durationMinutes'] ??= 0;
            if (knownColumns.contains('isVoiceEntry')) map['isVoiceEntry'] ??= 1;
            
            map['synced'] = 0; // force re-sync

            // Insert using the transaction (SQLite will set missing columns to default/null)
            final id = await txn.insert(
              _table,
              map,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            if (id != 0) {
              mergedCount++;
            }
          }
        });
        debugPrint('[DB Migration] Successfully merged $mergedCount legacy entries.');
      } catch (e) {
        debugPrint('[DB Migration] Failed during merge operations: $e');
      } finally {
        await legacyDbConn?.close();
      }
      await prefs.setBool('legacy_db_migrated', true);
    } catch (e) {
      debugPrint('Failed to merge legacy database: $e');
    }
  }


  Database get _database {
    if (_db == null) {
      throw StateError('DatabaseService not initialised. Call init() first.');
    }
    return _db!;
  }

  /// Whether the database has been successfully opened.
  bool get isReady => _db != null;

  // ──────────────────────────────────────────────────────────────
  // CRUD — All writes enqueue outbox jobs for Supabase sync
  // ──────────────────────────────────────────────────────────────

  Future<List<JournalEntry>> loadEntries() async {
    if (_db == null) {
      debugPrint('[DB] Cannot load entries: database not initialized.');
      return [];
    }
    final rows = await _database.query(
      _table,
      orderBy: 'createdAt DESC',
    );
    return rows.map(JournalEntry.fromMap).toList();
  }

  /// Insert or replace an entry. Enqueues an outbox upsert job.
  /// Throws on SQLite failure (e.g. storage full) — callers must handle.
  Future<void> insertEntry(JournalEntry entry) async {
    if (!isReady) {
      debugPrint('[DB] insertEntry skipped: database not ready. Attempting late init...');
      await init();
      if (!isReady) {
        throw StateError('DatabaseService not initialised. Call init() first.');
      }
    }
    try {
      final map = entry.toMap();
      map['synced'] = 0;
      await _database.insert(
        _table,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Enqueue local media uploads if user is Pro
      await _enqueueMediaIfNeeded(entry);

      // Enqueue sync job with full entry snapshot
      await OutboxService().enqueue(
        entry.id,
        'upsert',
        jsonEncode(map),
      );
    } on DatabaseException catch (e) {
      debugPrint('DatabaseService.insertEntry failed: $e');
      if (e.toString().contains('SQLITE_FULL') || e.toString().contains('database or disk is full')) {
        throw StorageFullException('Storage full. Free space to save your memory.');
      }
      rethrow;
    }
  }

  /// Update an existing entry. Enqueues an outbox upsert job.
  Future<void> updateEntry(JournalEntry entry) async {
    if (!isReady) {
      debugPrint('[DB] updateEntry skipped: database not ready. Attempting late init...');
      await init();
      if (!isReady) {
        throw StateError('DatabaseService not initialised. Call init() first.');
      }
    }
    try {
      final map = entry.toMap();
      map['synced'] = 0;
      await _database.update(
        _table,
        map,
        where: 'id = ?',
        whereArgs: [entry.id],
      );

      // Enqueue local media uploads if user is Pro
      await _enqueueMediaIfNeeded(entry);

      await OutboxService().enqueue(
        entry.id,
        'upsert',
        jsonEncode(map),
      );
    } on DatabaseException catch (e) {
      debugPrint('DatabaseService.updateEntry failed: $e');
      if (e.toString().contains('SQLITE_FULL') || e.toString().contains('database or disk is full')) {
        throw StorageFullException('Storage full. Free space to save your memory.');
      }
      rethrow;
    }
  }

  /// Delete an entry. Enqueues an outbox delete job for cloud propagation.
  Future<void> deleteEntry(String id) async {
    if (!isReady) {
      debugPrint('[DB] deleteEntry skipped: database not ready.');
      return;
    }
    await _database.delete(_table, where: 'id = ?', whereArgs: [id]);
    // Enqueue cloud delete — ensures deleted entries don't persist remotely
    try {
      await OutboxService().enqueue(id, 'delete', null);
    } catch (e) {
      debugPrint('[DB] Outbox enqueue (delete) failed: $e');
    }
  }

  /// Delete all entries. Enqueues individual delete jobs for cloud propagation.
  Future<void> deleteAllEntries() async {
    if (!isReady) {
      debugPrint('[DB] deleteAllEntries skipped: database not ready.');
      return;
    }
    // Collect all IDs before deleting locally
    final rows = await _database.query(_table, columns: ['id']);
    await _database.delete(_table);

    // Enqueue individual delete jobs for each entry
    for (final row in rows) {
      final entryId = row['id'] as String;
      try {
        await OutboxService().enqueue(entryId, 'delete', null);
      } catch (e) {
        debugPrint('[DB] Outbox enqueue (delete) failed for $entryId: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Draft Operations — Crash-safe voice recording drafts
  //
  // Uses SQLite WAL table instead of SharedPreferences.
  // Survives app kills, power loss, and OS process termination.
  // ──────────────────────────────────────────────────────────────

  /// Save or update the active recording draft. WAL-safe.
  Future<void> saveDraft(String content) async {
    if (content.trim().isEmpty) return;
    if (_db == null) {
      debugPrint('[DB] Cannot save draft: database not initialized.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _database.insert(
        _draftsTable,
        {
          'id': 'active_draft',
          'content': content,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('DatabaseService.saveDraft failed: $e');
    }
  }

  /// Load the active draft. Returns null if no draft exists.
  Future<String?> loadDraft() async {
    if (_db == null) {
      debugPrint('[DB] Cannot load draft: database not initialized.');
      return null;
    }
    try {
      final rows = await _database.query(
        _draftsTable,
        where: "id = 'active_draft'",
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final content = rows.first['content'] as String?;
      return (content != null && content.trim().isNotEmpty) ? content : null;
    } catch (e) {
      debugPrint('DatabaseService.loadDraft failed: $e');
      return null;
    }
  }

  /// Clear the active draft after recovery or discard.
  Future<void> clearDraft() async {
    if (_db == null) {
      debugPrint('[DB] Cannot clear draft: database not initialized.');
      return;
    }
    try {
      await _database.delete(_draftsTable, where: "id = 'active_draft'");
    } catch (e) {
      debugPrint('DatabaseService.clearDraft failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Image upload (Supabase Storage)
  // ──────────────────────────────────────────────────────────────

  Future<String?> uploadImage(String localPath, String fileName) async {
    if (!ApiConfig.hasSupabase || !_supabaseReady) {
      debugPrint('DatabaseService: Supabase not configured or ready, cannot upload image.');
      return null;
    }
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();

      await Supabase.instance.client.storage
          .from('entry-photos')
          .uploadBinary(fileName, bytes);

      final url = Supabase.instance.client.storage
          .from('entry-photos')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      debugPrint('DatabaseService.uploadImage error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Pull Sync — Download entries from Supabase with conflict resolution
  //
  // Conflict strategy: last-writer-wins with client-wins tiebreak.
  // - Cloud newer → apply locally
  // - Local newer → skip (already in outbox for push)
  // - Equal → keep local
  // ──────────────────────────────────────────────────────────────

  /// Sanitises a Supabase row into a map that SQLite can accept.
  /// - Strips columns not in the local schema
  /// - Converts Postgres booleans → SQLite integers
  /// - Converts numeric types safely (double → int where needed)
  /// - Converts Postgres arrays → JSON strings
  Map<String, dynamic> _sanitiseSupabaseRow(
    Map<String, dynamic> raw,
    Set<String> knownColumns,
  ) {
    final map = Map<String, dynamic>.from(raw);

    // ── 1. Convert arrays to JSON strings for SQLite ──
    for (final key in ['tags', 'photoUrls', 'sections']) {
      final val = map[key];
      if (val is List) {
        map[key] = jsonEncode(val);
      } else if (val == null) {
        map[key] = '[]';
      }
      // If already a String, keep as-is
    }

    // ── 2. Mark as synced ──
    map['synced'] = 1;

    // ── 3. Convert boolean isVoiceEntry → integer ──
    if (map['isVoiceEntry'] is bool) {
      map['isVoiceEntry'] = (map['isVoiceEntry'] as bool) ? 1 : 0;
    } else if (map['isVoiceEntry'] is num) {
      map['isVoiceEntry'] = (map['isVoiceEntry'] as num).toInt();
    } else {
      map['isVoiceEntry'] = 1; // Default
    }

    // ── 4. Normalise numeric types ──
    // durationMinutes — Supabase may return double (e.g. 0.0), SQLite needs int
    if (map['durationMinutes'] is num) {
      map['durationMinutes'] = (map['durationMinutes'] as num).toInt();
    } else {
      map['durationMinutes'] = 0;
    }

    // temperature — ensure it's a double or null
    if (map['temperature'] is num) {
      map['temperature'] = (map['temperature'] as num).toDouble();
    } else if (map['temperature'] != null) {
      map['temperature'] = null;
    }

    // latitude / longitude — ensure double or null
    for (final coord in ['latitude', 'longitude']) {
      if (map[coord] is num) {
        map[coord] = (map[coord] as num).toDouble();
      } else if (map[coord] != null) {
        map[coord] = null;
      }
    }

    // ── 5. Strip ALL columns that don't exist in local SQLite schema ──
    // Supabase may return user_id, created_at, or any RLS/trigger columns
    // that would crash the insert.
    map.removeWhere((key, _) => !knownColumns.contains(key));

    return map;
  }

  Future<void> pullSync() async {
    if (!isReady) return;
    if (!ApiConfig.hasSupabase || !_supabaseReady) return;
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ── Get known SQLite columns once ──────────────────────────────
      final columnsInfo = await _database.rawQuery('PRAGMA table_info($_table)');
      final knownColumns = columnsInfo.map((c) => c['name'] as String).toSet();
      debugPrint('[PullSync] Known SQLite columns: $knownColumns');
      
      // ── RESILIENCE FIX: Empty-DB Stale Timestamp Bypass ──────────
      // If the SQLite database is completely empty (e.g. after a clean reinstall
      // where Android restored SharedPreferences but the SQLite file was wiped),
      // we must bypass any restored last_sync_timestamp and force a full pull.
      final localCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM $_table'),
      ) ?? 0;
      
      final lastSyncStr = (localCount == 0)
          ? '1970-01-01T00:00:00.000Z'
          : (prefs.getString('last_sync_timestamp') ?? '1970-01-01T00:00:00.000Z');
      
      debugPrint('[PullSync] localCount=$localCount, lastSyncStr=$lastSyncStr, userId=${currentUser.id}');

      final response = await AuthService().withAuth(() async {
        if (lastSyncStr == '1970-01-01T00:00:00.000Z') {
          // Full pull — no timestamp filter
          return await Supabase.instance.client
              .from('journal_entries')
              .select()
              .eq('user_id', currentUser.id)
              .order('updatedAt', ascending: false);
        } else {
          // Delta pull — only entries updated after last sync
          return await Supabase.instance.client
              .from('journal_entries')
              .select()
              .eq('user_id', currentUser.id)
              .gt('updatedAt', lastSyncStr)
              .order('updatedAt', ascending: false);
        }
      });

      final List rows = response as List? ?? [];
      debugPrint('[PullSync] Received ${rows.length} rows from Supabase');
      int added = 0, updated = 0, skipped = 0, errors = 0;

      for (final row in rows) {
        // ── Per-row try/catch: one bad row must NOT kill the entire pull ──
        try {
          final rawMap = Map<String, dynamic>.from(row as Map);
          final cloudId = rawMap['id'] as String?;
          if (cloudId == null) {
            debugPrint('[PullSync] Skipping row with null id');
            errors++;
            continue;
          }

          final updatedAtStr = rawMap['updatedAt'] as String?;
          if (updatedAtStr == null) {
            debugPrint('[PullSync] Skipping row $cloudId with null updatedAt');
            errors++;
            continue;
          }
          final cloudUpdatedAt = DateTime.parse(updatedAtStr);

          // Sanitise: strip unknown columns, normalise types
          final map = _sanitiseSupabaseRow(rawMap, knownColumns);

          // Check if we have this entry locally
          final localRows = await _database.query(
            _table,
            where: 'id = ?',
            whereArgs: [cloudId],
            limit: 1,
          );

          if (localRows.isEmpty) {
            // New entry from cloud — insert locally
            await _database.insert(
              _table,
              map,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            added++;
          } else {
            // Entry exists locally — compare timestamps
            final localUpdatedAt = DateTime.parse(
              localRows.first['updatedAt'] as String,
            );

            if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
              // Cloud is newer → apply cloud version locally
              await _database.update(
                _table,
                map,
                where: 'id = ?',
                whereArgs: [cloudId],
              );
              updated++;
            } else {
              // Local is newer or equal → keep local (client-wins)
              skipped++;
            }
          }
        } catch (rowError) {
          errors++;
          debugPrint('[PullSync] Error processing row: $rowError');
          // Continue with remaining rows — don't abort
        }
      }

      debugPrint('[PullSync] Added: $added, Updated: $updated, Skipped: $skipped, Errors: $errors');
      
      // Update sync timestamp after successful pull
      final now = DateTime.now();
      lastSyncNotifier.value = now;
      await prefs.setString('last_sync_timestamp', now.toUtc().toIso8601String());
    } catch (e) {
      debugPrint('DatabaseService pull sync error: $e');
    }
  }

  /// Explicit sync: pull from cloud, then push pending outbox jobs.
  Future<void> syncNow() async {
    if (!isReady) {
      debugPrint('[DB] syncNow skipped: database not ready.');
      return;
    }
    isSyncing.value = true;
    try {
      await pullSync();
      await OutboxService().processQueue();
      
      // Update last sync time on successful sync
      final now = DateTime.now();
      lastSyncNotifier.value = now;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('last_sync_timestamp', now.toUtc().toIso8601String());
      } catch (_) {}
    } finally {
      isSyncing.value = false;
    }
  }

  /// Sweeps all local SQLite memories and enqueues them in the outbox
  /// to migrate them and push them to Supabase under the newly logged-in user.
  Future<void> migrateGuestMemories(String userId) async {
    if (!isReady) {
      debugPrint('[DB] migrateGuestMemories skipped: database not ready.');
      return;
    }
    try {
      final entries = await loadEntries();
      for (final entry in entries) {
        final map = entry.toMap();
        map['synced'] = 0;
        
        // Mark local as unsynced
        await _database.update(
          _table,
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        
        // Enqueue sync job in outbox
        await OutboxService().enqueue(
          entry.id,
          'upsert',
          jsonEncode(map),
        );
      }
      // Start processing immediately
      unawaited(OutboxService().processQueue());
    } catch (e) {
      debugPrint('Guest migration failed: $e');
    }
  }

  /// Replaces all local SQLite entries with the given list of entries safely by merging them,
  /// marking them as synced. Does not delete local unsynced entries.
  Future<void> replaceAllEntries(List<JournalEntry> incoming) async {
    if (!isReady) {
      debugPrint('[DB] replaceAllEntries skipped: database not ready.');
      return;
    }
    await _database.transaction((txn) async {
      for (final entry in incoming) {
        final map = entry.toMap();
        map['synced'] = 1;
        // Only insert/replace if cloud version is newer than what we have
        final local = await txn.query(
          _table,
          where: 'id = ?',
          whereArgs: [entry.id],
          limit: 1,
        );
        if (local.isEmpty) {
          await txn.insert(
            _table,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          final localUpdatedAt = DateTime.parse(local.first['updatedAt'] as String);
          final cloudUpdatedAt = entry.updatedAt;
          if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
            await txn.update(
              _table,
              map,
              where: 'id = ?',
              whereArgs: [entry.id],
            );
          }
        }
      }
    });
  }

  /// Cleanly wipes all local SQLite tables (memories, outbox, drafts, media queue)
  /// without enqueuing outbox items or propagating deletions to Supabase.
  /// Used for secure sign-out or account switching.
  Future<void> wipeLocalDataOnly() async {
    if (!isReady) {
      debugPrint('[DB] wipeLocalDataOnly skipped: database not ready.');
      return;
    }
    await _database.transaction((txn) async {
      await txn.delete(_table);
      await txn.delete('outbox');
      await txn.delete(_draftsTable);
      try {
        await txn.delete('binary_upload_queue');
      } catch (_) {}
    });
    debugPrint('[DB] Clean local-only database wipe completed successfully.');
  }

  /// Securely deletes the remote Supabase data and clears local SQLite data.
  /// Designed to be future-proof: supports clean cascade and manual multi-table purges.
  Future<void> deleteCloudAccount() async {
    final client = Supabase.instance.client;
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;
    
    // ═══════════════════════════════════════════════════════════════
    // REMOTE PURGE — Future-Proof Cascade Strategy
    // ═══════════════════════════════════════════════════════════════
    
    // 1. Purge core memories archive
    try {
      await client.from('journal_entries').delete().eq('user_id', currentUser.id);
    } catch (e) {
      debugPrint('Remote entries deletion failed: $e');
    }
    
    // [FUTURE EXPANSION: Add client-side purges for non-cascade tables here]
    // 2. Purge AI embeddings
    // try {
    //   await client.from('embeddings').delete().eq('user_id', currentUser.id);
    // } catch (e) { debugPrint('Remote embeddings deletion failed: $e'); }
    //
    // 3. Purge user preferences/settings
    // try {
    //   await client.from('user_settings').delete().eq('user_id', currentUser.id);
    // } catch (e) { debugPrint('Remote settings deletion failed: $e'); }
    
    // ═══════════════════════════════════════════════════════════════
    // LOCAL WIPE — Zero-Trace Clean Room Wipes
    // ═══════════════════════════════════════════════════════════════
    
    // 4. Wipe all local SQLite tables (memories, outbox, drafts, media queue)
    await wipeLocalDataOnly();

    // ═══════════════════════════════════════════════════════════════
    // AUTH PURGE
    // ═══════════════════════════════════════════════════════════════
    
    // 7. Request remote auth user deletion via Edge Function or RPC if available
    // [Note: Best practice is using a Postgres trigger in Supabase on auth.users:
    //  "CREATE TRIGGER on_auth_user_deleted AFTER DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_user_deletion()"
    //  with cascade deletes enabled in Supabase db schemas.]
    
    // 8. Sign the user out completely
    await AuthService().signOut();
  }

  Future<void> _enqueueMediaIfNeeded(JournalEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('isPremium') ?? false;
      if (!isPremium) return;

      // Enqueue thumbnail if local
      if (entry.thumbnailPath != null &&
          !entry.thumbnailPath!.startsWith('http') &&
          !entry.thumbnailPath!.startsWith('content://')) {
        await BinaryUploadService().enqueue(entry.id, entry.thumbnailPath!, 'entry-photos');
      }

      // Enqueue photoUrls if local
      for (final photo in entry.photoUrls) {
        if (!photo.startsWith('http') && !photo.startsWith('content://')) {
          await BinaryUploadService().enqueue(entry.id, photo, 'entry-photos');
        }
      }

      // Enqueue voice section audioPath if local
      for (final section in entry.sections) {
        if (section.type == 'voice' && section.audioPath != null) {
          final audio = section.audioPath!;
          if (!audio.startsWith('http') && !audio.startsWith('content://')) {
            await BinaryUploadService().enqueue(entry.id, audio, 'entry-voices');
          }
        }
      }
    } catch (e) {
      debugPrint('[DB] Failed to enqueue media: $e');
    }
  }

  Future<void> _scanAndEnqueueLegacyMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('isPremium') ?? false;
      if (!isPremium) return;

      final entries = await loadEntries();
      for (final entry in entries) {
        // Enqueue thumbnail if local path
        if (entry.thumbnailPath != null &&
            !entry.thumbnailPath!.startsWith('http') &&
            !entry.thumbnailPath!.startsWith('content://')) {
          await BinaryUploadService().enqueue(entry.id, entry.thumbnailPath!, 'entry-photos');
        }

        // Enqueue photoUrls if local paths
        for (final photo in entry.photoUrls) {
          if (!photo.startsWith('http') && !photo.startsWith('content://')) {
            await BinaryUploadService().enqueue(entry.id, photo, 'entry-photos');
          }
        }

        // Enqueue voice section audioPath if local paths
        for (final section in entry.sections) {
          if (section.type == 'voice' && section.audioPath != null) {
            final audio = section.audioPath!;
            if (!audio.startsWith('http') && !audio.startsWith('content://')) {
              await BinaryUploadService().enqueue(entry.id, audio, 'entry-voices');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DB Scan] Legacy media scan failed: $e');
    }
  }

  Future<void> pullFromSupabase(String userId) async {
    if (!isReady) {
      debugPrint('[DB] pullFromSupabase skipped: database not ready. Attempting late init...');
      await init();
      if (!isReady) return;
    }
    if (!ApiConfig.hasSupabase || !_supabaseReady) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ── Get known SQLite columns once ──────────────────────────────
      final columnsInfo = await _database.rawQuery('PRAGMA table_info($_table)');
      final knownColumns = columnsInfo.map((c) => c['name'] as String).toSet();
      
      // ── RESILIENCE FIX: Google Auto-Backup Stale Timestamp Bypass ──
      final localCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM $_table'),
      ) ?? 0;
      
      final lastSyncStr = (localCount == 0)
          ? '1970-01-01T00:00:00.000Z'
          : (prefs.getString('last_sync_timestamp') ?? '1970-01-01T00:00:00.000Z');
      
      final response = await AuthService().withAuth(() async {
        if (lastSyncStr == '1970-01-01T00:00:00.000Z') {
          return await Supabase.instance.client
              .from('journal_entries')
              .select()
              .eq('user_id', userId)
              .order('updatedAt', ascending: false);
        } else {
          return await Supabase.instance.client
              .from('journal_entries')
              .select()
              .eq('user_id', userId)
              .gt('updatedAt', lastSyncStr)
              .order('updatedAt', ascending: false);
        }
      });

      final List rows = response as List? ?? [];
      debugPrint('[DeltaPullSync] Received ${rows.length} rows from Supabase');
      int added = 0, updated = 0, skipped = 0, errors = 0;

      for (final row in rows) {
        // ── Per-row try/catch: one bad row must NOT kill the entire pull ──
        try {
          final rawMap = Map<String, dynamic>.from(row as Map);
          final cloudId = rawMap['id'] as String?;
          if (cloudId == null) {
            errors++;
            continue;
          }

          final updatedAtStr = rawMap['updatedAt'] as String?;
          if (updatedAtStr == null) {
            errors++;
            continue;
          }
          final cloudUpdatedAt = DateTime.parse(updatedAtStr);

          // Sanitise: strip unknown columns, normalise types
          final map = _sanitiseSupabaseRow(rawMap, knownColumns);

          // Check if we have this entry locally
          final localRows = await _database.query(
            _table,
            where: 'id = ?',
            whereArgs: [cloudId],
            limit: 1,
          );

          if (localRows.isEmpty) {
            await _database.insert(
              _table,
              map,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            added++;
          } else {
            final localUpdatedAt = DateTime.parse(
              localRows.first['updatedAt'] as String,
            );

            if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
              await _database.update(
                _table,
                map,
                where: 'id = ?',
                whereArgs: [cloudId],
              );
              updated++;
            } else {
              skipped++;
            }
          }
        } catch (rowError) {
          errors++;
          debugPrint('[DeltaPullSync] Error processing row: $rowError');
        }
      }

      debugPrint('[DeltaPullSync] Added: $added, Updated: $updated, Skipped: $skipped, Errors: $errors');
      
      final now = DateTime.now();
      lastSyncNotifier.value = now;
      await prefs.setString('last_sync_timestamp', now.toUtc().toIso8601String());
    } catch (e) {
      debugPrint('[DeltaPullSync] Error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// StorageFullException — surfaced to user on SQLITE_FULL
// ═══════════════════════════════════════════════════════════════

class StorageFullException implements Exception {
  final String message;
  const StorageFullException(this.message);

  @override
  String toString() => message;
}
