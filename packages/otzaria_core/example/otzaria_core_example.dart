import 'package:otzaria_core/otzaria_core.dart';

/// דוגמה/smoke: מאתחלת את טוען השאילתות (pure Dart, ללא native sqlite3)
/// ומדפיסה כמה קבצי שאילתות וכמה שאילתות נטענו — מאמת שגרף ה‑imports
/// של ה‑package מתקמפל ורץ ללא Flutter.
Future<void> main() async {
  await QueryLoader.initialize();
  final bookQueries = QueryLoader.loadQueries('BookQueries.sq');
  print('✓ otzaria_core loaded — BookQueries has ${bookQueries.length} queries');
  print('  selectById: ${QueryLoader.getQuery('BookQueries.sq', 'selectById')}');
}
