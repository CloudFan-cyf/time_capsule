import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'time_capsule.db';
  static const _dbVersion = 1;

  static Future<Database> open() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE capsules (
          id TEXT PRIMARY KEY,
          title TEXT,
          orig_filename TEXT,
          mime TEXT,
          created_at_utc_ms INTEGER,
          unlock_at_utc_ms INTEGER,
          orig_size INTEGER,
          enc_path TEXT,
          manifest_path TEXT,
          status INTEGER,
          last_time_check_utc_ms INTEGER,
          last_time_source TEXT
        );
      ''');
      },
    );
  }
}
