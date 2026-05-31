import 'dart:io';

import 'package:otzaria_core/otzaria_core.dart';
import 'package:server/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

void main(List<String> args) async {
  // נתיב ל-seforim.db מ-env (חובה ל-production). ברירת מחדל לפיתוח מקומי.
  final dbPath = Platform.environment['SEFORIM_DB_PATH'] ??
      r'C:\ProgramData\otzaria\books\seforim.db';

  if (!File(dbPath).existsSync()) {
    stderr.writeln('FATAL: seforim.db not found at "$dbPath" '
        '(set SEFORIM_DB_PATH).');
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
