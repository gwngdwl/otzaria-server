import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:search_engine/search_engine.dart';

/// POC — שלב 0: הוכחה שמנוע החיפוש (Tantivy via FFI) רץ ב‑Dart טהור,
/// ללא Flutter, מעל הספרייה ה‑native הקיימת.
///
/// שני מצבים:
///   self  (ברירת מחדל) — בונה אינדקס קטן טרי עם המנוע, מוסיף מסמכים,
///                         עושה commit ומחפש. הוכחה עצמאית מקצה לקצה.
///   real  — פותח אינדקס קיים (חייב סכמה תואמת למנוע) ומחפש בו.
///
/// **טעינת ה‑native (חשוב לשרת):** ב‑Dart טהור אין flutter‑build/cargokit
/// שמביא את הספרייה אוטומטית — חובה לתת נתיב מפורש. הנתיב נפתר לפי סדר:
///   1. ארגומנט CLI אחרון אם הוא נתיב לקובץ קיים.
///   2. env var `SEARCH_ENGINE_LIB`.
///   3. שם ברירת מחדל לפי הפלטפורמה ([defaultSearchEngineLibName]) ליד ה‑exe/CWD.
/// בשרת לינוקס: מורידים `x86_64-unknown-linux-gnu_libsearch_engine.so`
/// מ‑GitHub release (`precompiled_*`) ומבאנדלים ל‑image — אין קומפילציה.
///
/// שימוש:
///   dart run bin/search_engine_poc.dart            # מצב self
///   dart run bin/search_engine_poc.dart real "C:\\path\\to\\index" "בראשית"
Future<void> main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : 'self';
  final libPath = resolveSearchEngineLibPath();

  await RustLib.init(externalLibrary: ExternalLibrary.open(libPath));
  print('✓ RustLib initialized (pure Dart, ללא Flutter) — lib: $libPath');

  if (mode == 'real') {
    final indexPath = args.length > 1
        ? args[1]
        : r'C:\Users\user\AppData\Roaming\otzaria\index';
    final query = args.length > 2 ? args[2] : 'בראשית';
    await _searchExisting(indexPath, query);
  } else {
    await _selfContained();
  }
}

/// הוכחה עצמאית: בונה אינדקס טרי, מוסיף מסמכים, commit, ומחפש.
Future<void> _selfContained() async {
  final dir = Directory.systemTemp.createTempSync('otzaria_poc_index_');
  print('• building fresh index at ${dir.path}');

  final engine = SearchEngine(path: dir.path);

  final docs = <DocumentInput>[
    DocumentInput(
      id: BigInt.from(1),
      title: 'בראשית',
      reference: 'בראשית א, א',
      topics: '/תורה/בראשית/id:1',
      text: 'בראשית ברא אלהים את השמים ואת הארץ',
      segment: BigInt.from(0),
      isPdf: false,
      filePath: '',
    ),
    DocumentInput(
      id: BigInt.from(2),
      title: 'בראשית',
      reference: 'בראשית א, ג',
      topics: '/תורה/בראשית/id:1',
      text: 'ויאמר אלהים יהי אור ויהי אור',
      segment: BigInt.from(2),
      isPdf: false,
      filePath: '',
    ),
    DocumentInput(
      id: BigInt.from(3),
      title: 'שמות',
      reference: 'שמות א, א',
      topics: '/תורה/שמות/id:3',
      text: 'ואלה שמות בני ישראל הבאים מצרימה',
      segment: BigInt.from(0),
      isPdf: false,
      filePath: '',
    ),
  ];

  await engine.addDocumentsBatch(docs: docs);
  await engine.commit();
  print('✓ committed — ${await engine.getDocumentCount()} documents');

  await _run(engine, 'אלהים');
  await _run(engine, 'בראשית');

  try {
    dir.deleteSync(recursive: true);
  } catch (_) {/* best effort */}
}

Future<void> _searchExisting(String indexPath, String query) async {
  final engine = SearchEngine(path: indexPath);
  print('✓ index opened — ${await engine.getDocumentCount()} documents');
  await _run(engine, query);
}

Future<void> _run(SearchEngine engine, String query) async {
  // הערה: שאילתת ה‑facets במנוע היא Occur::Must, ו‑TermSet ריק לא תופס כלום.
  // לכן לחיפוש "בכל המאגר" מעבירים את ה‑facet השורש '/' (כמו ברירת המחדל באפליקציה).
  final results = await engine.search(
    regexTerms: [query],
    facets: const ['/'],
    limit: 10,
    offset: 0,
    slop: 0,
    maxExpansions: 10,
    order: ResultsOrder.relevance,
    highlight: const HighlightConfig(
      highlightPrefix: '<<',
      highlightPostfix: '>>',
      maxChars: 120,
    ),
  );
  print('✓ search("$query") → ${results.length} results:');
  for (final r in results.take(5)) {
    print('  [${r.title}] ${r.reference} (seg=${r.segment})');
    print('      ${r.text}');
  }
}

/// שם הקובץ ה‑native לפי הפלטפורמה (קונבנציית cargo/FRB).
String defaultSearchEngineLibName() {
  if (Platform.isWindows) return 'search_engine.dll';
  if (Platform.isMacOS) return 'libsearch_engine.dylib';
  return 'libsearch_engine.so'; // Linux (ושאר Unix)
}

/// פותר את נתיב ספריית המנוע: env `SEARCH_ENGINE_LIB` → שם ברירת‑מחדל לפי
/// פלטפורמה (נטען ע"י ה‑OS מ‑CWD/ליד ה‑exe/loader path). זהו ה‑hook היחיד
/// שצריך להגדיר בשרת — לא נדרשת קומפילציה, רק נתיב לספרייה שהורדה מ‑release.
String resolveSearchEngineLibPath() {
  final fromEnv = Platform.environment['SEARCH_ENGINE_LIB'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return defaultSearchEngineLibName();
}
