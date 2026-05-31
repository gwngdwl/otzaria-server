import 'dart:convert';
import 'dart:io';

import 'package:otzaria_core/otzaria_core.dart';
import 'package:server/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:test/test.dart';

/// קורא ל-router ישירות (ללא socket) ומחזיר (status, decoded JSON).
Future<(int, dynamic)> _get(Router router, String path) async {
  final res = await router.call(
    Request('GET', Uri.parse('http://localhost$path')),
  );
  final body = await res.readAsString();
  return (res.statusCode, body.isEmpty ? null : jsonDecode(body));
}

void main() {
  group('GET /version', () {
    test('returns contentVersion from db_meta when present', () async {
      // בונים DB זמני עם db_meta + content_version_int, סוגרים, ואז פותחים
      // ל-קריאה-בלבד דרך MyDatabase.readOnly (כמו השרת).
      final dir = Directory.systemTemp.createTempSync('srv_ver_');
      final path = '${dir.path}/seforim.db';
      final seed = sqlite3.sqlite3.open(path);
      seed.execute(
          'CREATE TABLE db_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      seed.execute(
          "INSERT INTO db_meta (key, value) VALUES ('content_version_int', '142')");
      seed.close();

      final db = MyDatabase.readOnly(path);
      await db.database;
      final router = buildApiRouter(db);

      final (status, json) = await _get(router, '/version');
      expect(status, 200);
      expect(json['contentVersion'], 142);

      db.close();
      dir.deleteSync(recursive: true);
    });

    test('returns null contentVersion when db_meta is absent', () async {
      final dir = Directory.systemTemp.createTempSync('srv_nover_');
      final path = '${dir.path}/seforim.db';
      // DB ללא db_meta — export ישן.
      sqlite3.sqlite3.open(path)
        ..execute('CREATE TABLE book (id INTEGER PRIMARY KEY)')
        ..close();

      final db = MyDatabase.readOnly(path);
      await db.database;
      final router = buildApiRouter(db);

      final (status, json) = await _get(router, '/version');
      expect(status, 200);
      expect(json['contentVersion'], isNull);

      db.close();
      dir.deleteSync(recursive: true);
    });
  });

  test('GET /health returns ok', () async {
    final dir = Directory.systemTemp.createTempSync('srv_health_');
    final path = '${dir.path}/seforim.db';
    sqlite3.sqlite3.open(path)
      ..execute('CREATE TABLE x (id INTEGER)')
      ..close();

    final db = MyDatabase.readOnly(path);
    await db.database;
    final router = buildApiRouter(db);

    final (status, json) = await _get(router, '/health');
    expect(status, 200);
    expect(json['status'], 'ok');

    db.close();
    dir.deleteSync(recursive: true);
  });
}
