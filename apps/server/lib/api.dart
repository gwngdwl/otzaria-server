import 'dart:convert';

import 'package:otzaria_core/otzaria_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// בונה את ה-Router של ה-API מעל חיבור read-only ל-seforim.db.
///
/// כרגע (שלב 2): `/health` ו-`/version`. שלבים 3–5 יוסיפו קטלוג/תוכן/חיפוש.
Router buildApiRouter(MyDatabase db) {
  final router = Router();

  router.get('/health', (Request req) => _json({'status': 'ok'}));

  router.get('/version', (Request req) async {
    final raw = await db.database;
    return _json({
      'contentVersion': _readContentVersion(raw),
      // אין כיום מקור ל-indexVersion/builtAt ב-DB (ראה הערה למטה) — מוחזר null
      // עד שנסנכרן עם בניית האינדקס (שלב 5/6, מפרט §5.3).
      'indexVersion': null,
      'builtAt': null,
    });
  });

  return router;
}

/// קורא את גרסת התוכן מ-`db_meta` (כמו האפליקציה:
/// `SELECT value FROM db_meta WHERE key='content_version_int'`).
///
/// **הגנתי:** טבלת `db_meta` עשויה להיעדר ב-exports ישנים של seforim.db —
/// במקרה כזה מוחזר `null` במקום לזרוק.
int? _readContentVersion(sqlite3.Database raw) {
  final hasMeta = raw.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='db_meta'",
  ).isNotEmpty;
  if (!hasMeta) return null;

  final rows = raw.select(
    "SELECT value FROM db_meta WHERE key = ? LIMIT 1",
    ['content_version_int'],
  );
  if (rows.isEmpty) return null;
  return int.tryParse(rows.first['value'].toString());
}

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
