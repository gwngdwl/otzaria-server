import 'dart:io';

import 'package:otzaria_core/otzaria_core.dart';
import 'package:server/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

void main(List<String> args) async {
  // נתיב ל-seforim.db מגיע אך ורק מ-env var SEFORIM_DB_PATH — ללא נתיב מוטמע,
  // כך שזה עובד זהה ב-Linux VPS, ב-Docker וב-Windows.
  // לפיתוח מקומי: `SEFORIM_DB_PATH=/path/to/seforim.db dart run bin/server.dart`.
  final dbPath = Platform.environment['SEFORIM_DB_PATH'];
  if (dbPath == null || dbPath.isEmpty) {
    stderr.writeln('FATAL: SEFORIM_DB_PATH is not set. '
        'Set it to the absolute path of seforim.db, e.g. '
        '(Linux) SEFORIM_DB_PATH=/srv/otzaria/seforim.db');
    exitCode = 1;
    return;
  }

  if (!File(dbPath).existsSync()) {
    stderr.writeln('FATAL: seforim.db not found at "$dbPath".');
    exitCode = 1;
    return;
  }

  // פתיחה ל-קריאה-בלבד — השרת לעולם לא כותב למאגר.
  final db = MyDatabase.readOnly(dbPath);
  // פתיחה מוקדמת כדי לכשול מהר אם ה-DB לא תקין.
  await db.database;
  print('Opened seforim.db (read-only): $dbPath');

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildApiRouter(db).call);

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on http://${server.address.host}:${server.port}');
}
