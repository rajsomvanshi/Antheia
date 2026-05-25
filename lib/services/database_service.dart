import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'api_config.dart';

// ═══════════════════════════════════════════════════════════════
// DatabaseService — SQLite (source of truth) + Supabase (sync)
// ═══════════════════════════════════════════════════════════════

class DatabaseService {
  // ── Singleton ─────────────────────────────────────────────────
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  static const _dbName    = 'flowjournal.db';
  static const _dbVersion = 2;
  static const _table     = 'journal_entries';

  // ──────────────────────────────────────────────────────────────
  // Initialise
  // ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = p.join(await getDatabasesPath(), _dbName);

    _db = await openDatabase(
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
            synced        INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add synced column for Supabase sync tracking
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialised. Call init() first.');
    return _db!;
  }

  // ──────────────────────────────────────────────────────────────
  // CRUD
  // ──────────────────────────────────────────────────────────────

  Future<List<JournalEntry>> loadEntries() async {
    final rows = await _database.query(
      _table,
      orderBy: 'createdAt DESC',
    );
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<void> insertEntry(JournalEntry entry) async {
    final map = entry.toMap();
    map['synced'] = 0;
    await _database.insert(
      _table,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _trySyncToSupabase();
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final map = entry.toMap();
    map['synced'] = 0;
    await _database.update(
      _table,
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    _trySyncToSupabase();
  }

  Future<void> deleteEntry(String id) async {
    await _database.delete(_table, where: 'id = ?', whereArgs: [id]);
    if (ApiConfig.hasSupabase) {
      try {
        await Supabase.instance.client.from('entries').delete().eq('id', id);
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Image upload (Supabase Storage)
  // ──────────────────────────────────────────────────────────────

  Future<String?> uploadImage(String localPath, String fileName) async {
    if (!ApiConfig.hasSupabase) {
      debugPrint('DatabaseService: Supabase not configured, cannot upload image.');
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
  // Supabase Sync — push unsynced entries
  // ──────────────────────────────────────────────────────────────

  Future<void> _trySyncToSupabase() async {
    if (!ApiConfig.hasSupabase) return;

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    isSyncing.value = true;
    try {
      final unsynced = await _database.query(
        _table,
        where: 'synced = 0',
      );

      for (final row in unsynced) {
        final map = Map<String, dynamic>.from(row);
        map.remove('synced'); // don't push internal field
        // Supabase expects lists as actual arrays, not JSON strings
        map['tags']      = jsonDecode(row['tags'] as String? ?? '[]');
        map['photoUrls'] = jsonDecode(row['photoUrls'] as String? ?? '[]');
        map['sections']  = jsonDecode(row['sections'] as String? ?? '[]');

        await Supabase.instance.client
            .from('entries')
            .upsert(map, onConflict: 'id');

        await _database.update(
          _table,
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    } catch (e) {
      debugPrint('DatabaseService sync error: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Call this explicitly when the app comes online or the user taps "sync"
  Future<void> syncNow() => _trySyncToSupabase();
}
