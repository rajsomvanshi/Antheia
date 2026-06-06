import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import 'outbox_service.dart';
import 'auth_service.dart';

class BinaryUploadService {
  static final BinaryUploadService _instance = BinaryUploadService._internal();
  factory BinaryUploadService() => _instance;
  BinaryUploadService._internal();

  Database? _db;
  bool _processing = false;
  static const _table = 'binary_upload_queue';

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isProcessing = ValueNotifier(false);

  Future<void> init(Database db) async {
    _db = db;
    await _updatePendingCount();
    unawaited(processQueue());
  }

  Database get _database {
    if (_db == null) {
      throw StateError('BinaryUploadService not initialised. Call init() first.');
    }
    return _db!;
  }

  Future<void> enqueue(String entryId, String localPath, String bucket) async {
    if (_db == null) {
      debugPrint('[BinaryUpload] enqueue skipped: service not initialised.');
      return;
    }
    final db = _database;
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // Check if this path is already queued
    final existing = await db.query(
      _table,
      where: 'local_path = ? AND entry_id = ? AND status != \'done\'',
      whereArgs: [localPath, entryId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await db.insert(
      _table,
      {
        'id': id,
        'entry_id': entryId,
        'local_path': localPath,
        'bucket': bucket,
        'status': 'pending',
        'public_url': null,
        'error': null,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updatePendingCount();
    unawaited(processQueue());
  }

  Future<void> processQueue() async {
    if (_processing) return;
    if (_db == null) return;
    _processing = true;
    isProcessing.value = true;

    try {
      final db = _database;
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        debugPrint('[BinaryUpload] Sync skipped: User is not authenticated.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('isPremium') ?? false;

      // Scan jobs
      final jobs = await db.query(
        _table,
        where: "status IN ('pending', 'failed')",
        orderBy: 'created_at ASC',
      );

      for (final job in jobs) {
        final jobId = job['id'] as String;
        final entryId = job['entry_id'] as String;
        final localPath = job['local_path'] as String;
        final bucket = job['bucket'] as String;

        // Pro-only Gate Check
        if (!isPremium) {
          await _markFailed(jobId, 'Cloud sync is a Pro-only feature.');
          continue;
        }

        final file = File(localPath);
        if (!await file.exists()) {
          // File deleted locally — complete job with warning
          await db.update(
            _table,
            {
              'status': 'done',
              'error': 'File not found locally, skipped upload.',
            },
            where: 'id = ?',
            whereArgs: [jobId],
          );
          continue;
        }

        final fileSize = await file.length();

        // Storage Quota Enforcement (500MB max for Pro)
        try {
          final cloudUsage = await _getUserCloudUsage(currentUser.id);
          if (cloudUsage + fileSize > 500 * 1024 * 1024) {
            await _markFailed(jobId, 'Cloud storage quota exceeded (500MB max).');
            continue;
          }
        } catch (e) {
          debugPrint('[BinaryUpload] Quota check failed: $e');
        }

        // Set status to uploading
        await db.update(
          _table,
          {'status': 'uploading'},
          where: 'id = ?',
          whereArgs: [jobId],
        );

        try {
          final bytes = await file.readAsBytes();
          final extension = p.extension(localPath).toLowerCase();
          final extStr = extension.isEmpty
              ? (bucket == 'entry-photos' ? '.jpg' : '.m4a')
              : extension;
          
          // Folder structure: {user_id}/{entry_id}/{uuid}.{ext}
          final uuid = const Uuid().v4();
          final fileName = '${currentUser.id}/$entryId/$uuid$extStr';

          final contentType = bucket == 'entry-photos'
              ? 'image/jpeg'
              : 'audio/m4a';

          // Upload to Supabase Storage
          await Supabase.instance.client.storage
              .from(bucket)
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(contentType: contentType),
              );

          final publicUrl = Supabase.instance.client.storage
              .from(bucket)
              .getPublicUrl(fileName);

          // 1. Update SQLite journal_entries
          await _updateJournalEntryLocalPath(entryId, localPath, publicUrl, bucket);

          // 2. Update Outbox JSON payload in SQLite
          await _updateOutboxPayloadPath(entryId, localPath, publicUrl, bucket);

          // 3. Mark job as done
          await db.update(
            _table,
            {
              'status': 'done',
              'public_url': publicUrl,
              'error': null,
            },
            where: 'id = ?',
            whereArgs: [jobId],
          );

          debugPrint('[BinaryUpload] Completed upload for entry $entryId: $publicUrl');

          // 4. Update Supabase User Storage Quota
          await _incrementUserCloudUsage(currentUser.id, fileSize, bucket);

          // 5. Wake up Outbox sync to push updated metadata
          unawaited(OutboxService().processQueue());
        } catch (e) {
          await _markFailed(jobId, e.toString());
          debugPrint('[BinaryUpload] Job $jobId failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[BinaryUpload] Process queue error: $e');
    } finally {
      _processing = false;
      isProcessing.value = false;
      await _updatePendingCount();
    }
  }

  Future<int> _getUserCloudUsage(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_storage')
          .select('total_bytes_used')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['total_bytes_used'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _incrementUserCloudUsage(String userId, int size, String bucket) async {
    try {
      final db = Supabase.instance.client;
      // Fetch current storage row
      final row = await db.from('user_storage').select().eq('user_id', userId).maybeSingle();
      final isImage = bucket == 'entry-photos';

      if (row == null) {
        await db.from('user_storage').insert({
          'user_id': userId,
          'total_bytes_used': size,
          'image_count': isImage ? 1 : 0,
          'audio_count': isImage ? 0 : 1,
        });
      } else {
        final currentBytes = row['total_bytes_used'] as int? ?? 0;
        final currentImg = row['image_count'] as int? ?? 0;
        final currentAud = row['audio_count'] as int? ?? 0;

        await db.from('user_storage').update({
          'total_bytes_used': currentBytes + size,
          'image_count': isImage ? currentImg + 1 : currentImg,
          'audio_count': isImage ? currentAud : currentAud + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('[BinaryUpload] Failed to update user quota metadata in Supabase: $e');
    }
  }

  Future<void> _updateJournalEntryLocalPath(
      String entryId, String localPath, String remoteUrl, String bucket) async {
    final db = _database;
    final rows = await db.query('journal_entries', where: 'id = ?', whereArgs: [entryId], limit: 1);
    if (rows.isEmpty) return;

    final entryMap = Map<String, dynamic>.from(rows.first);
    bool changed = false;

    if (bucket == 'entry-photos') {
      if (entryMap['thumbnailPath'] == localPath) {
        entryMap['thumbnailPath'] = remoteUrl;
        changed = true;
      }
      final photoUrlsRaw = entryMap['photoUrls'] as String? ?? '[]';
      try {
        final List<dynamic> urls = jsonDecode(photoUrlsRaw);
        final List<String> updated = urls.map((u) => u == localPath ? remoteUrl : u as String).toList();
        if (photoUrlsRaw != jsonEncode(updated)) {
          entryMap['photoUrls'] = jsonEncode(updated);
          changed = true;
        }
      } catch (_) {}
    } else if (bucket == 'entry-voices') {
      final sectionsRaw = entryMap['sections'] as String? ?? '[]';
      try {
        final List<dynamic> sections = jsonDecode(sectionsRaw);
        bool sectionChanged = false;
        for (final sec in sections) {
          if (sec is Map && sec['type'] == 'voice' && sec['audioPath'] == localPath) {
            sec['audioPath'] = remoteUrl;
            sectionChanged = true;
          }
        }
        if (sectionChanged) {
          entryMap['sections'] = jsonEncode(sections);
          changed = true;
        }
      } catch (_) {}
    }

    if (changed) {
      entryMap['synced'] = 0; // Mark metadata unsynced so Outbox pushes it
      await db.update(
        'journal_entries',
        entryMap,
        where: 'id = ?',
        whereArgs: [entryId],
      );
    }
  }

  Future<void> _updateOutboxPayloadPath(
      String entryId, String localPath, String remoteUrl, String bucket) async {
    final db = _database;
    final jobs = await db.query(
      'outbox',
      where: "entry_id = ? AND status IN ('pending', 'failed')",
      whereArgs: [entryId],
    );

    for (final job in jobs) {
      final payloadJson = job['payload'] as String?;
      if (payloadJson == null) continue;

      try {
        final Map<String, dynamic> payload = jsonDecode(payloadJson);
        bool changed = false;

        if (bucket == 'entry-photos') {
          if (payload['thumbnailPath'] == localPath) {
            payload['thumbnailPath'] = remoteUrl;
            changed = true;
          }
          final photoUrls = payload['photoUrls'];
          if (photoUrls is List) {
            for (int i = 0; i < photoUrls.length; i++) {
              if (photoUrls[i] == localPath) {
                photoUrls[i] = remoteUrl;
                changed = true;
              }
            }
          } else if (photoUrls is String) {
            try {
              final List<dynamic> urls = jsonDecode(photoUrls);
              final List<String> updated = urls.map((u) => u == localPath ? remoteUrl : u as String).toList();
              if (photoUrls != jsonEncode(updated)) {
                payload['photoUrls'] = jsonEncode(updated);
                changed = true;
              }
            } catch (_) {}
          }
        } else if (bucket == 'entry-voices') {
          final sections = payload['sections'];
          if (sections is List) {
            for (final sec in sections) {
              if (sec is Map && sec['type'] == 'voice' && sec['audioPath'] == localPath) {
                sec['audioPath'] = remoteUrl;
                changed = true;
              }
            }
          } else if (sections is String) {
            try {
              final List<dynamic> secs = jsonDecode(sections);
              bool secChanged = false;
              for (final sec in secs) {
                if (sec is Map && sec['type'] == 'voice' && sec['audioPath'] == localPath) {
                  sec['audioPath'] = remoteUrl;
                  secChanged = true;
                }
              }
              if (secChanged) {
                payload['sections'] = jsonEncode(secs);
                changed = true;
              }
            } catch (_) {}
          }
        }

        if (changed) {
          await db.update(
            'outbox',
            {'payload': jsonEncode(payload)},
            where: 'id = ?',
            whereArgs: [job['id']],
          );
        }
      } catch (e) {
        debugPrint('[BinaryUpload] Outbox payload update failed for job ${job['id']}: $e');
      }
    }
  }

  Future<void> _markFailed(String jobId, String error) async {
    await _database.update(
      _table,
      {'status': 'failed', 'error': error},
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<void> _updatePendingCount() async {
    if (_db == null) return;
    try {
      final result = await _database.rawQuery(
        "SELECT COUNT(*) as cnt FROM $_table WHERE status IN ('pending', 'failed', 'uploading')",
      );
      pendingCountNotifier.value = Sqflite.firstIntValue(result) ?? 0;
    } catch (_) {}
  }

  /// Check if the entry has any pending binary uploads in the queue.
  Future<bool> hasPendingUploads(String entryId) async {
    if (_db == null) return false;
    try {
      final result = await _database.rawQuery(
        "SELECT COUNT(*) as cnt FROM $_table WHERE entry_id = ? AND status IN ('pending', 'failed', 'uploading')",
        [entryId],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      return count > 0;
    } catch (_) {
      return false;
    }
  }
}
