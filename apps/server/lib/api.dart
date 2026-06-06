import 'dart:convert';

import 'package:otzaria_core/otzaria_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// בונה את ה-Router של ה-API מעל חיבור read-only ל-seforim.db.
///
/// שלב 2: `/health`, `/version`.
/// שלב 3 (זה): קטלוג ותוכן ספר — `/library`, `/books`, `/books/{id}`,
/// `/books/{id}/exists`, `/books/{id}/text`, `/books/{id}/text/range`,
/// `/books/{id}/toc`. הכול נבנה ישירות מעל ה-DAOs/Repository של otzaria_core,
/// כך שהפלט זהה למה שהאפליקציה טוענת מקומית (parity).
Router buildApiRouter(MyDatabase db) {
  final router = Router();
  // Repository נטען עם אותו DB — קריאות בלבד, ללא ensureInitialized()
  // (שמריץ PRAGMA/INSERT של connection types ולא מתאים ל-DB קריאה-בלבד).
  final repo = SeforimRepository(db);

  // ── שלב 2 ────────────────────────────────────────────────────────────────
  router.get('/health', (Request req) => _json({'status': 'ok'}));

  router.get('/version', (Request req) async {
    final raw = await db.database;
    return _json({
      'contentVersion': _readContentVersion(raw),
      // אין כיום מקור ל-indexVersion/builtAt ב-DB — מוחזר null עד שנסנכרן
      // עם בניית האינדקס (שלב 5/6, מפרט §5.3).
      'indexVersion': null,
      'builtAt': null,
    });
  });

  // ── שלב 3: קטלוג ────────────────────────────────────────────────────────

  /// עץ קטגוריות מלא + ספרים + מטא. קריאה אחת לכל הספרייה.
  router.get('/library', (Request req) async {
    final raw = await db.database;
    final categories = await db.categoryDao.getAllCategories();
    final bookRows = await db.bookDao.getAllBooksWithRelations();
    final books = bookRows.map((r) => Book.fromJson(r)).toList();

    // קיבוץ ספרים לפי קטגוריה, ממוין לפי order ואז כותרת.
    final booksByCategory = <int, List<Book>>{};
    for (final b in books) {
      (booksByCategory[b.categoryId] ??= []).add(b);
    }
    for (final list in booksByCategory.values) {
      list.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
      });
    }

    // בניית עץ הקטגוריות מהרשימה השטוחה (כבר ממוינת ב-orderIndex,title).
    final nodes = <int, Map<String, dynamic>>{};
    for (final c in categories) {
      nodes[c.id] = {
        'id': c.id,
        'parentId': c.parentId,
        'title': c.title,
        'level': c.level,
        'order': c.orderIndex,
        'subCategories': <Map<String, dynamic>>[],
        'books': [for (final b in booksByCategory[c.id] ?? const []) _bookJson(b)],
      };
    }
    final roots = <Map<String, dynamic>>[];
    for (final c in categories) {
      final node = nodes[c.id]!;
      final parent = c.parentId == null ? null : nodes[c.parentId];
      if (parent == null) {
        roots.add(node);
      } else {
        (parent['subCategories'] as List).add(node);
      }
    }

    return _json({
      'contentVersion': _readContentVersion(raw),
      'categories': roots,
    });
  });

  /// רשימת ספרים שטוחה. `?category=<id>` מסנן לקטגוריה אחת.
  router.get('/books', (Request req) async {
    final categoryParam = req.url.queryParameters['category'];
    if (categoryParam != null) {
      final categoryId = int.tryParse(categoryParam);
      if (categoryId == null) {
        return _json({'error': 'invalid category id'}, status: 400);
      }
      final books = await repo.getBooksByCategory(categoryId);
      return _json([for (final b in books) _bookJson(b)]);
    }
    final rows = await db.bookDao.getAllBooksWithRelations();
    return _json([for (final r in rows) _bookJson(Book.fromJson(r))]);
  });

  /// מטא מלא של ספר + דגלים (hasNekudot, hasCommentaryConnection…).
  router.get('/books/<id|[0-9]+>', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await repo.getBook(bookId);
    if (book == null) return _notFound('book', bookId);
    return _json(_bookJson(book));
  });

  router.get('/books/<id|[0-9]+>/exists', (Request req, String id) async {
    final book = await db.bookDao.getBookById(int.parse(id));
    return _json({'exists': book != null});
  });

  // ── שלב 3: תוכן ספר ───────────────────────────────────────────────────────

  /// תוכן מלא של הספר כמחרוזת אחת (raw — ניקוד/טעמים נשמרים), שורות
  /// מחוברות ב-`\n` כמו `getBookText()` באפליקציה. מוחזר כ-text/plain.
  router.get('/books/<id|[0-9]+>/text', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);
    final lines = await db.lineDao.selectByBookId(bookId);
    return Response.ok(
      lines.map((l) => l.content).join('\n'),
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
  });

  /// טווח שורות לפי lineIndex (כולל קצוות). מבנה: startLine/endLine/
  /// totalLines + מערך שורות (index/content/heRef).
  router.get('/books/<id|[0-9]+>/text/range', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);

    final q = req.url.queryParameters;
    final start = int.tryParse(q['start'] ?? '');
    final end = int.tryParse(q['end'] ?? '');
    if (start == null || end == null) {
      return _json(
          {'error': 'start and end (lineIndex) query params are required'},
          status: 400);
    }
    if (end < start) {
      return _json({'error': 'end must be >= start'}, status: 400);
    }

    final lines = await db.lineDao.selectByBookIdRange(bookId, start, end);
    return _json({
      'bookId': bookId,
      'startLine': start,
      'endLine': end,
      'totalLines': book.totalLines,
      'lines': [
        for (final l in lines)
          {'index': l.lineIndex, 'content': l.content, 'heRef': l.heRef}
      ],
    });
  });

  /// עץ תוכן עניינים. כל צומת: text / index (=lineIndex 0-based) / level /
  /// children. נבנה מהרשימה השטוחה דרך parentId.
  router.get('/books/<id|[0-9]+>/toc', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);
    final entries = await repo.getBookToc(bookId);
    return _json({'bookId': bookId, 'toc': _buildTocTree(entries)});
  });

  // ── שלב 4: קישורים + עמוד מאוחד ⭐ ────────────────────────────────────────

  /// כל הקישורים שבהם הספר הוא המקור.
  router.get('/books/<id|[0-9]+>/links', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);
    final rows = await db.linkDao.selectLinksBySourceBook(bookId);
    return _json([for (final r in rows) _linkJson(r)]);
  });

  /// קישורים בטווח שורות (לפי lineIndex, כולל קצוות). `?targets=12,34` מסנן
  /// ל-targetBookId נבחרים. כולל `sourceLineIndex` (ממופה מ-id) לחיבור בלקוח.
  router.get('/books/<id|[0-9]+>/links/range', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);

    final q = req.url.queryParameters;
    final start = int.tryParse(q['start'] ?? '');
    final end = int.tryParse(q['end'] ?? '');
    if (start == null || end == null) {
      return _json(
          {'error': 'start and end (lineIndex) query params are required'},
          status: 400);
    }
    if (end < start) return _json({'error': 'end must be >= start'}, status: 400);
    final targets = _parseIntCsv(q['targets']);

    final lines = await db.lineDao.selectByBookIdRange(bookId, start, end);
    final indexById = {for (final l in lines) l.id: l.lineIndex};
    final rows = await _linksForSourceLineIds(db, indexById.keys.toList());
    final filtered = targets.isEmpty
        ? rows
        : rows.where((r) => targets.contains(r['targetBookId'] as int)).toList();
    return _json([
      for (final r in filtered)
        {
          ..._linkJson(r),
          'sourceLineIndex': indexById[r['sourceLineId']],
          'targetBookTitle': r['targetBookTitle'],
        }
    ]);
  });

  /// תוכן יעד ל-batch קישורים. גוף: `{ "targetLineIds": [int, ...] }`.
  /// מחזיר `{ "content": { "<lineId>": "<text>" } }`.
  router.post('/links/content', (Request req) async {
    final body = await _readJsonBody(req);
    if (body is! Map || body['targetLineIds'] is! List) {
      return _json({'error': 'body must be { "targetLineIds": [int, ...] }'},
          status: 400);
    }
    final ids = [for (final v in body['targetLineIds'] as List) if (v is int) v];
    final content = <String, String>{};
    for (final lineId in ids) {
      final line = await db.lineDao.getLineById(lineId);
      if (line != null) content['$lineId'] = line.content;
    }
    return _json({'content': content});
  });

  /// ⭐ עמוד מאוחד: שורות בטווח + הקישורים בטווח + תוכן המפרשים, בקריאה אחת.
  /// `?commentators=12,34` מסנן את הקישורים ל-targetBookId נבחרים (ריק = הכול).
  /// פותר את אתגר ה-latency (מפרט §5.1) — מונע round-trip לכל גלילה.
  router.get('/books/<id|[0-9]+>/page', (Request req, String id) async {
    final bookId = int.parse(id);
    final book = await db.bookDao.getBookById(bookId);
    if (book == null) return _notFound('book', bookId);

    final q = req.url.queryParameters;
    final start = int.tryParse(q['start'] ?? '');
    final end = int.tryParse(q['end'] ?? '');
    if (start == null || end == null) {
      return _json(
          {'error': 'start and end (lineIndex) query params are required'},
          status: 400);
    }
    if (end < start) return _json({'error': 'end must be >= start'}, status: 400);
    final commentators = _parseIntCsv(q['commentators']);

    final lines = await db.lineDao.selectByBookIdRange(bookId, start, end);
    final indexById = {for (final l in lines) l.id: l.lineIndex};
    final rows = await _linksForSourceLineIds(db, indexById.keys.toList());
    final selected = commentators.isEmpty
        ? rows
        : rows
            .where((r) => commentators.contains(r['targetBookId'] as int))
            .toList();

    final links = <Map<String, dynamic>>[];
    final commentaryContent = <String, String>{};
    for (final r in selected) {
      final targetBookId = r['targetBookId'] as int;
      final targetLineId = r['targetLineId'] as int;
      links.add({
        ..._linkJson(r),
        'sourceLineIndex': indexById[r['sourceLineId']],
        'targetBookTitle': r['targetBookTitle'],
      });
      commentaryContent['$targetBookId:$targetLineId'] =
          (r['targetText'] as String?) ?? '';
    }

    return _json({
      'bookId': bookId,
      'startLine': start,
      'endLine': end,
      'totalLines': book.totalLines,
      'lines': [
        for (final l in lines)
          {'index': l.lineIndex, 'content': l.content, 'heRef': l.heRef}
      ],
      'links': links,
      'commentaryContent': commentaryContent,
    });
  });

  return router;
}

/// שולף קישורים לפי source lineIds (עם תוכן היעד), עם הגנה מפני `IN ()` ריק.
Future<List<Map<String, dynamic>>> _linksForSourceLineIds(
    MyDatabase db, List<int> lineIds) async {
  if (lineIds.isEmpty) return const [];
  return db.linkDao.selectLinksBySourceLineIds(lineIds);
}

/// סריאליזציה אחידה של שורת קישור (תוצאת JOIN ל-connection_type).
Map<String, dynamic> _linkJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'sourceBookId': row['sourceBookId'],
      'targetBookId': row['targetBookId'],
      'sourceLineId': row['sourceLineId'],
      'targetLineId': row['targetLineId'],
      'connectionType':
          ConnectionType.fromString((row['connectionType'] ?? 'OTHER').toString())
              .toJson(),
    };

/// פירוק רשימת מספרים מופרדת בפסיקים (`"12,34"`). ריק/null → רשימה ריקה.
List<int> _parseIntCsv(String? csv) {
  if (csv == null || csv.trim().isEmpty) return const [];
  return [
    for (final p in csv.split(','))
      if (int.tryParse(p.trim()) != null) int.parse(p.trim())
  ];
}

/// קורא גוף בקשה כ-JSON; מחזיר null אם ריק/לא תקין.
Future<Object?> _readJsonBody(Request req) async {
  final s = await req.readAsString();
  if (s.isEmpty) return null;
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

/// בונה עץ TOC מרשימה שטוחה (ממוינת ב-lineIndex) באמצעות parentId.
List<Map<String, dynamic>> _buildTocTree(List<TocEntry> entries) {
  final nodes = <int, Map<String, dynamic>>{};
  for (final e in entries) {
    nodes[e.id] = {
      'text': e.text,
      'index': e.lineIndex,
      'level': e.level,
      'children': <Map<String, dynamic>>[],
    };
  }
  final roots = <Map<String, dynamic>>[];
  for (final e in entries) {
    final node = nodes[e.id]!;
    final parent = e.parentId == null ? null : nodes[e.parentId];
    if (parent == null) {
      roots.add(node);
    } else {
      (parent['children'] as List).add(node);
    }
  }
  return roots;
}

/// סריאליזציה של ספר: כל שדות [Book.toJson] + מחרוזת `author` נוחה
/// (שמות המחברים מחוברים בפסיק) לצריכה קלה בלקוח.
Map<String, dynamic> _bookJson(Book book) {
  return {
    ...book.toJson(),
    'author': book.authors.map((a) => a.name).join(', '),
  };
}

/// קורא את גרסת התוכן מ-`db_meta`.
/// **הגנתי:** טבלת `db_meta` עשויה להיעדר ב-exports ישנים — מוחזר null.
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

Response _notFound(String kind, int id) =>
    _json({'error': '$kind $id not found'}, status: 404);

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
