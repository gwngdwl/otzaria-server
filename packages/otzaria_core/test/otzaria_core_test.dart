import 'package:otzaria_core/otzaria_core.dart';
import 'package:test/test.dart';

void main() {
  group('text normalization (parity)', () {
    test('removeVolwels strips nikud and cantillation', () {
      expect(removeVolwels('בְּרֵאשִׁית'), 'בראשית');
    });

    test('normalizeForFindRefMatch removes gershayim and lowercases', () {
      expect(normalizeForFindRefMatch('שו"ע'), 'שוע');
      expect(normalizeForFindRefMatch('בְּרֵאשִׁית'), 'בראשית');
    });

    test('stripHtmlIfNeeded removes tags but keeps word spacing', () {
      expect(stripHtmlIfNeeded('<b>לאמר</b>&nbsp;שירה'), 'לאמר שירה');
    });
  });

  group('QueryLoader (embedded .sq)', () {
    test('initialize then load embedded queries', () async {
      await QueryLoader.initialize();
      final q = QueryLoader.loadQueries('BookQueries.sq');
      expect(q, isNotEmpty);
      expect(QueryLoader.getQuery('BookQueries.sq', 'selectById'),
          contains('FROM book'));
    });
  });

  group('DAO layer over in-memory sqlite3 (pure Dart, no Flutter)', () {
    late MyDatabase db;

    setUp(() async {
      db = MyDatabase.withPath(':memory:');
      await db.database; // creates schema + initializes DAOs
    });

    tearDown(() => db.close());

    test('insert + read a category through CategoryDao', () async {
      final id = await db.categoryDao.insertCategory(null, 'תנ"ך', 0);
      final cat = await db.categoryDao.getCategoryById(id);
      expect(cat, isNotNull);
      expect(cat!.title, 'תנ"ך');

      final roots = await db.categoryDao.getRootCategories();
      expect(roots.map((c) => c.title), contains('תנ"ך'));
    });

    test('book inserted via raw SQL is read back through BookDao', () async {
      final raw = await db.database;
      final catId = await db.categoryDao.insertCategory(null, 'תורה', 0);
      raw.execute("INSERT INTO source (id, name) VALUES (1, 'test')");
      raw.execute(
        'INSERT INTO book (categoryId, sourceId, title, totalLines) '
        'VALUES (?, 1, ?, 0)',
        [catId, 'בראשית'],
      );
      final book = await db.bookDao.getBookByTitle('בראשית');
      expect(book, isNotNull);
      expect(book!.title, 'בראשית');
    });
  });
}
