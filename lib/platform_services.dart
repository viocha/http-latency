import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initializePlatformServices() async {
  if (!Platform.isWindows) return;
  sqfliteFfiInit();
  sqflite.databaseFactory = databaseFactoryFfi;
}

Future<String> databaseFilePath() async {
  if (!Platform.isWindows) {
    return p.join(await sqflite.getDatabasesPath(), 'http_latency.db');
  }

  final supportDirectory = await getApplicationSupportDirectory();
  final databaseDirectory = Directory(
    p.join(supportDirectory.path, 'databases'),
  );
  await databaseDirectory.create(recursive: true);
  return p.join(databaseDirectory.path, 'http_latency.db');
}
