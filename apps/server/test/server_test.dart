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

/// קורא ל-router ומחזיר (status, raw body, content-type) — לבדיקת text/plain.
Future<(int, String, String?)> _getRaw(Router router, String path) async {
  final res = await router.call(
    Request('GET', Uri.parse('http://localhost$path')),
  );
  return (res.statusCode, await res.readAsString(), res.headers['content-type']);
}

/// זורע DB מינימלי-אך-מלא: 2 קטגוריות (אב/בן), 2 ספרים, שורות, ו-TOC.
/// מבנה הקטגוריות: "תורה"(1) ← "בראשית"(2). ספר 1 בקטגוריה 2, ספר 2 בקטגוריה 1.
String _seedFullDb() {
  final dir = Directory.systemTemp.createTempSync('srv_full_');
  final path = '${dir.path}/seforim.db';
  final db = sqlite3.sqlite3.open(path);

  db.execute(
      'CREATE TABLE db_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  db.execute(
      "INSERT INTO db_meta (key, value) VALUES ('content_version_int', '7')");

  db.execute('''
    CREATE TABLE category (id INTEGER PRIMARY KEY, parentId INTEGER,
      title TEXT NOT NULL, level INTEGER NOT NULL DEFAULT 0,
      orderIndex INTEGER NOT NULL DEFAULT 999)''');
  db.execute(
      "INSERT INTO category VALUES (1, NULL, 'תורה', 0, 0)");
  db.execute(
      "INSERT INTO category VALUES (2, 1, 'בראשית', 1, 0)");

  db.execute('''
    CREATE TABLE book (id INTEGER PRIMARY KEY, categoryId INTEGER NOT NULL,
      sourceId INTEGER NOT NULL DEFAULT 1, title TEXT NOT NULL,
      heShortDesc TEXT, orderIndex INTEGER NOT NULL DEFAULT 999,
      totalLines INTEGER NOT NULL DEFAULT 0, isBaseBook INTEGER DEFAULT 0,
      hasTargumConnection INTEGER DEFAULT 0, hasReferenceConnection INTEGER DEFAULT 0,
      hasSourceConnection INTEGER DEFAULT 0, hasCommentaryConnection INTEGER DEFAULT 0,
      hasOtherConnection INTEGER DEFAULT 0, hasAltStructures INTEGER DEFAULT 0,
      hasTeamim INTEGER DEFAULT 0, hasNekudot INTEGER DEFAULT 0,
      isContentExternal INTEGER DEFAULT 0, externalLibraryId TEXT,
      isPersonal INTEGER DEFAULT 0, filePath TEXT, fileType TEXT DEFAULT 'txt',
      fileSize INTEGER, lastModified INTEGER, pages INTEGER, volume TEXT)''');
  db.execute(
      "INSERT INTO book (id, categoryId, title, orderIndex, totalLines, "
      "hasNekudot, hasCommentaryConnection) "
      "VALUES (1, 2, 'ספר בראשית', 0, 3, 1, 1)");
  db.execute(
      "INSERT INTO book (id, categoryId, title, orderIndex, totalLines) "
      "VALUES (2, 1, 'הקדמה', 1, 1)");

  db.execute('''
    CREATE TABLE author (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
      generationId INTEGER)''');
  db.execute("INSERT INTO author VALUES (1, 'משה רבנו', NULL)");
  db.execute(
      'CREATE TABLE book_author (bookId INTEGER, authorId INTEGER)');
  db.execute('INSERT INTO book_author VALUES (1, 1)');

  // טבלאות יחס נוספות (קיימות תמיד ב-seforim.db; כאן ריקות) — נדרשות
  // ל-JOINs של getBook/getAllBooksWithRelations.
  db.execute('CREATE TABLE topic (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
  db.execute('CREATE TABLE book_topic (bookId INTEGER, topicId INTEGER)');
  db.execute(
      'CREATE TABLE pub_place (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
  db.execute(
      'CREATE TABLE book_pub_place (bookId INTEGER, pubPlaceId INTEGER)');
  db.execute(
      'CREATE TABLE pub_date (id INTEGER PRIMARY KEY, date TEXT NOT NULL)');
  db.execute('CREATE TABLE book_pub_date (bookId INTEGER, pubDateId INTEGER)');

  db.execute('''
    CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER NOT NULL,
      lineIndex INTEGER NOT NULL, content TEXT NOT NULL, heRef TEXT,
      tocEntryId INTEGER)''');
  db.execute(
      "INSERT INTO line VALUES (10, 1, 0, 'בראשית ברא אלהים', 'בראשית א, א', NULL)");
  db.execute(
      "INSERT INTO line VALUES (11, 1, 1, 'את השמים ואת הארץ', 'בראשית א, א', NULL)");
  db.execute(
      "INSERT INTO line VALUES (12, 1, 2, 'והארץ היתה תהו ובהו', 'בראשית א, ב', NULL)");
  db.execute(
      "INSERT INTO line VALUES (20, 2, 0, 'דברי הקדמה', NULL, NULL)");

  db.execute(
      'CREATE TABLE tocText (id INTEGER PRIMARY KEY, text TEXT NOT NULL UNIQUE)');
  db.execute("INSERT INTO tocText VALUES (100, 'פרק א')");
  db.execute("INSERT INTO tocText VALUES (101, 'פסוק ב')");

  db.execute('''
    CREATE TABLE tocEntry (id INTEGER PRIMARY KEY, bookId INTEGER NOT NULL,
      parentId INTEGER, textId INTEGER NOT NULL, level INTEGER NOT NULL,
      lineId INTEGER, lineIndex INTEGER, isLastChild INTEGER DEFAULT 0,
      hasChildren INTEGER DEFAULT 0)''');
  // פרק א (root, lineIndex 0) ← פסוק ב (child, lineIndex 2)
  db.execute(
      'INSERT INTO tocEntry VALUES (1000, 1, NULL, 100, 1, 10, 0, 0, 1)');
  db.execute(
      'INSERT INTO tocEntry VALUES (1001, 1, 1000, 101, 2, 12, 2, 1, 0)');

  // ספר מפרש (רש"י, id=3) בקטגוריה 2, עם שורות יעד.
  db.execute(
      "INSERT INTO book (id, categoryId, title, orderIndex, totalLines) "
      "VALUES (3, 2, 'רשי על בראשית', 5, 2)");
  db.execute(
      "INSERT INTO line VALUES (30, 3, 0, 'פירוש על פסוק א', NULL, NULL)");
  db.execute(
      "INSERT INTO line VALUES (31, 3, 1, 'פירוש על פסוק ב', NULL, NULL)");

  db.execute('''
    CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)''');
  db.execute("INSERT INTO connection_type VALUES (1, 'COMMENTARY')");

  db.execute('''
    CREATE TABLE link (id INTEGER PRIMARY KEY, sourceBookId INTEGER NOT NULL,
      targetBookId INTEGER NOT NULL, sourceLineId INTEGER NOT NULL,
      targetLineId INTEGER NOT NULL, connectionTypeId INTEGER NOT NULL)''');
  // קישור משורה 0 בבראשית (id 10) ← רש"י שורה 0 (id 30)
  db.execute('INSERT INTO link VALUES (500, 1, 3, 10, 30, 1)');
  // קישור משורה 2 בבראשית (id 12) ← רש"י שורה 1 (id 31)
  db.execute('INSERT INTO link VALUES (501, 1, 3, 12, 31, 1)');

  db.close();
  return path;
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

  group('Stage 3 — catalog & book content', () {
    late MyDatabase db;
    late Router router;
    late String dbPath;

    setUp(() async {
      dbPath = _seedFullDb();
      db = MyDatabase.readOnly(dbPath);
      await db.database;
      router = buildApiRouter(db);
    });

    tearDown(() {
      db.close();
      Directory(dbPath).parent.deleteSync(recursive: true);
    });

    test('GET /library returns category tree with nested books', () async {
      final (status, json) = await _get(router, '/library');
      expect(status, 200);
      expect(json['contentVersion'], 7);

      final cats = json['categories'] as List;
      // קטגוריית שורש אחת ("תורה").
      expect(cats, hasLength(1));
      final torah = cats.first;
      expect(torah['title'], 'תורה');
      // ספר "הקדמה" יושב ישירות תחת השורש.
      expect((torah['books'] as List).map((b) => b['title']), contains('הקדמה'));

      // תת-קטגוריה "בראשית" עם הספרים שלה + מחרוזת author.
      final sub = (torah['subCategories'] as List)
          .firstWhere((c) => c['title'] == 'בראשית');
      final book = (sub['books'] as List)
          .firstWhere((b) => b['title'] == 'ספר בראשית');
      expect(book['author'], 'משה רבנו');
      expect(book['hasNekudot'], true);
    });

    test('GET /books?category= filters to one category', () async {
      final (status, json) = await _get(router, '/books?category=2');
      expect(status, 200);
      // קטגוריה 2 מכילה את "ספר בראשית" ואת המפרש "רשי על בראשית".
      expect((json as List).map((b) => b['title']),
          containsAll(['ספר בראשית', 'רשי על בראשית']));
    });

    test('GET /books returns full flat list', () async {
      final (status, json) = await _get(router, '/books');
      expect(status, 200);
      expect((json as List).map((b) => b['title']),
          containsAll(['ספר בראשית', 'הקדמה']));
    });

    test('GET /books?category= with bad id → 400', () async {
      final (status, _) = await _get(router, '/books?category=abc');
      expect(status, 400);
    });

    test('GET /books/{id} returns metadata + flags', () async {
      final (status, json) = await _get(router, '/books/1');
      expect(status, 200);
      expect(json['title'], 'ספר בראשית');
      expect(json['totalLines'], 3);
      expect(json['hasNekudot'], true);
      expect(json['hasCommentaryConnection'], true);
      expect(json['author'], 'משה רבנו');
    });

    test('GET /books/{id} missing → 404', () async {
      final (status, _) = await _get(router, '/books/999');
      expect(status, 404);
    });

    test('GET /books/{id}/exists', () async {
      final (s1, j1) = await _get(router, '/books/1/exists');
      expect(s1, 200);
      expect(j1['exists'], true);
      final (s2, j2) = await _get(router, '/books/999/exists');
      expect(s2, 200);
      expect(j2['exists'], false);
    });

    test('GET /books/{id}/text returns raw joined text/plain', () async {
      final (status, body, contentType) = await _getRaw(router, '/books/1/text');
      expect(status, 200);
      expect(contentType, contains('text/plain'));
      expect(body, 'בראשית ברא אלהים\nאת השמים ואת הארץ\nוהארץ היתה תהו ובהו');
    });

    test('GET /books/{id}/text/range returns structured lines', () async {
      final (status, json) = await _get(router, '/books/1/text/range?start=0&end=1');
      expect(status, 200);
      expect(json['totalLines'], 3);
      expect(json['startLine'], 0);
      expect(json['endLine'], 1);
      final lines = json['lines'] as List;
      expect(lines, hasLength(2));
      expect(lines.first['index'], 0);
      expect(lines.first['content'], 'בראשית ברא אלהים');
      expect(lines.first['heRef'], 'בראשית א, א');
    });

    test('GET /books/{id}/text/range missing params → 400', () async {
      final (status, _) = await _get(router, '/books/1/text/range?start=0');
      expect(status, 400);
    });

    test('GET /books/{id}/toc returns nested tree', () async {
      final (status, json) = await _get(router, '/books/1/toc');
      expect(status, 200);
      final toc = json['toc'] as List;
      expect(toc, hasLength(1));
      final chapter = toc.first;
      expect(chapter['text'], 'פרק א');
      expect(chapter['index'], 0);
      expect(chapter['level'], 1);
      final children = chapter['children'] as List;
      expect(children, hasLength(1));
      expect(children.first['text'], 'פסוק ב');
      expect(children.first['index'], 2);
    });
  });

  group('Stage 4 — links & unified page', () {
    late MyDatabase db;
    late Router router;
    late String dbPath;

    setUp(() async {
      dbPath = _seedFullDb();
      db = MyDatabase.readOnly(dbPath);
      await db.database;
      router = buildApiRouter(db);
    });

    tearDown(() {
      db.close();
      Directory(dbPath).parent.deleteSync(recursive: true);
    });

    test('GET /books/{id}/links returns all source links', () async {
      final (status, json) = await _get(router, '/books/1/links');
      expect(status, 200);
      expect((json as List), hasLength(2));
      expect(json.first['connectionType'], 'commentary');
      expect(json.map((l) => l['targetBookId']), everyElement(3));
    });

    test('GET /books/{id}/links/range filters by line range', () async {
      // טווח שורה 0 בלבד → רק הקישור משורה 10 (lineIndex 0).
      final (status, json) = await _get(router, '/books/1/links/range?start=0&end=0');
      expect(status, 200);
      expect((json as List), hasLength(1));
      expect(json.first['sourceLineIndex'], 0);
      expect(json.first['targetBookTitle'], 'רשי על בראשית');
    });

    test('GET /books/{id}/links/range with targets filter', () async {
      final (s1, j1) = await _get(router, '/books/1/links/range?start=0&end=2&targets=3');
      expect(s1, 200);
      expect((j1 as List), hasLength(2));
      // targetBookId 999 לא קיים → מסונן הכול.
      final (s2, j2) = await _get(router, '/books/1/links/range?start=0&end=2&targets=999');
      expect(s2, 200);
      expect((j2 as List), isEmpty);
    });

    test('GET /books/{id}/links/range missing params → 400', () async {
      final (status, _) = await _get(router, '/books/1/links/range?start=0');
      expect(status, 400);
    });

    test('POST /links/content returns target content by lineId', () async {
      final res = await router.call(Request(
        'POST',
        Uri.parse('http://localhost/links/content'),
        body: jsonEncode({'targetLineIds': [30, 31, 99999]}),
      ));
      expect(res.statusCode, 200);
      final json = jsonDecode(await res.readAsString());
      expect(json['content']['30'], 'פירוש על פסוק א');
      expect(json['content']['31'], 'פירוש על פסוק ב');
      expect(json['content'].containsKey('99999'), false);
    });

    test('POST /links/content bad body → 400', () async {
      final res = await router.call(Request(
        'POST',
        Uri.parse('http://localhost/links/content'),
        body: jsonEncode({'wrong': true}),
      ));
      expect(res.statusCode, 400);
    });

    test('GET /books/{id}/page unifies lines + links + commentary', () async {
      final (status, json) = await _get(router, '/books/1/page?start=0&end=2');
      expect(status, 200);
      expect(json['totalLines'], 3);
      expect((json['lines'] as List), hasLength(3));
      expect((json['links'] as List), hasLength(2));
      // תוכן המפרשים ממופתח כ-"targetBookId:targetLineId".
      final cc = json['commentaryContent'] as Map;
      expect(cc['3:30'], 'פירוש על פסוק א');
      expect(cc['3:31'], 'פירוש על פסוק ב');
      // הקישור הראשון מחובר לשורת מקור עם lineIndex תקין.
      final link = (json['links'] as List).firstWhere((l) => l['sourceLineIndex'] == 0);
      expect(link['targetBookTitle'], 'רשי על בראשית');
    });

    test('GET /books/{id}/page with commentators filter', () async {
      // מסנן ל-targetBookId שלא קיים → אין קישורים אבל השורות עדיין מוחזרות.
      final (status, json) = await _get(router, '/books/1/page?start=0&end=2&commentators=999');
      expect(status, 200);
      expect((json['lines'] as List), hasLength(3));
      expect((json['links'] as List), isEmpty);
      expect((json['commentaryContent'] as Map), isEmpty);
    });

    test('GET /books/{id}/page range without links', () async {
      // שורה 1 (id 11) אין עליה קישורים.
      final (status, json) = await _get(router, '/books/1/page?start=1&end=1');
      expect(status, 200);
      expect((json['lines'] as List), hasLength(1));
      expect((json['links'] as List), isEmpty);
    });

    test('GET /books/{id}/page missing book → 404', () async {
      final (status, _) = await _get(router, '/books/999/page?start=0&end=2');
      expect(status, 404);
    });
  });
}
