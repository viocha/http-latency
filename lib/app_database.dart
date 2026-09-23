import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'platform_services.dart';

class SavedConfiguration {
  const SavedConfiguration({
    required this.targets,
    required this.repetitions,
    required this.warmUpCount,
    required this.timeoutSeconds,
  });

  final List<TestTarget> targets;
  final int repetitions;
  final int warmUpCount;
  final int timeoutSeconds;
}

class AppDatabase {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      await databaseFilePath(),
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE history (id TEXT PRIMARY KEY, started_at INTEGER NOT NULL, payload TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.delete('history');
        }
      },
    );
    return _database!;
  }

  Future<SavedConfiguration> loadConfiguration() async {
    final db = await _db;
    final rows = await db.query('settings');
    final settings = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };

    final selectedIds = settings['selected_ids'] == null
        ? builtInTargets
              .where((target) => target.selected)
              .map((target) => target.id)
              .toSet()
        : (jsonDecode(settings['selected_ids']!) as List)
              .cast<String>()
              .toSet();
    final customTargets = settings['custom_targets'] == null
        ? <TestTarget>[]
        : (jsonDecode(settings['custom_targets']!) as List)
              .map(
                (item) =>
                    TestTarget.fromJson(Map<String, Object?>.from(item as Map)),
              )
              .toList();
    final targets = [
      ...builtInTargets.map(
        (target) => target.copyWith(selected: selectedIds.contains(target.id)),
      ),
      ...customTargets.map(
        (target) => target.copyWith(selected: selectedIds.contains(target.id)),
      ),
    ];

    return SavedConfiguration(
      targets: targets,
      repetitions:
          int.tryParse(settings['repetitions'] ?? '')?.clamp(1, 5) ?? 3,
      warmUpCount:
          int.tryParse(settings['warm_up_count'] ?? '')?.clamp(0, 5) ?? 1,
      timeoutSeconds: _supportedTimeout(settings['timeout_seconds']),
    );
  }

  int _supportedTimeout(String? savedValue) {
    final value = int.tryParse(savedValue ?? '');
    return const {3, 5, 10, 15}.contains(value) ? value! : 10;
  }

  Future<void> saveConfiguration(SavedConfiguration configuration) async {
    final db = await _db;
    final selectedIds = configuration.targets
        .where((target) => target.selected)
        .map((target) => target.id)
        .toList();
    final customTargets = configuration.targets
        .where((target) => !target.isBuiltIn)
        .map((target) => target.toJson())
        .toList();
    final batch = db.batch();
    void put(String key, String value) => batch.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    put('selected_ids', jsonEncode(selectedIds));
    put('custom_targets', jsonEncode(customTargets));
    put('repetitions', configuration.repetitions.toString());
    put('warm_up_count', configuration.warmUpCount.toString());
    put('timeout_seconds', configuration.timeoutSeconds.toString());
    await batch.commit(noResult: true);
  }

  Future<List<TestRun>> loadHistory() async {
    final db = await _db;
    final rows = await db.query(
      'history',
      orderBy: 'started_at DESC',
      limit: 20,
    );
    final result = <TestRun>[];
    for (final row in rows) {
      try {
        result.add(TestRun.decode(row['payload']! as String));
      } on FormatException {
        // Ignore a corrupt local entry while keeping the rest of the history usable.
      }
    }
    return result;
  }

  Future<void> saveRun(TestRun run) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('history', {
        'id': run.id,
        'started_at': run.startedAt.millisecondsSinceEpoch,
        'payload': run.encode(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawDelete(
        'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY started_at DESC LIMIT 20)',
      );
    });
  }

  Future<void> deleteRun(String id) async {
    final db = await _db;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await _db;
    await db.delete('history');
  }
}
