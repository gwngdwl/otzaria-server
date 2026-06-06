# Otzaria Online Server — מדריך ביצוע (Next Steps)

מדריך מעשי, צעד‑צעד, להקמת שרת ה‑API האונליין של Otzaria.
מתעדכן תוך כדי. מתחיל מהמצב הנוכחי וממשיך עד production.

> **מסמכי תכנון מלווים** (בריפו `otzaria`):
> - `docs/online_server_spec.md` — המפרט המלא (ארכיטקטורה, סכמה, כל ה‑endpoints).
> - `docs/online_server_workplan.md` — תוכנית העבודה ברמת שלבים.
> מסמך זה הוא ה‑hands‑on: מה בדיוק לעשות, עם פקודות וקוד.

---

## תובנות מפתח (כבר אומתו אמפירית)

1. **לא צריך fork של מנוע החיפוש.** ה‑`dart` שמגיע עם Flutter SDK פותר את התלות `flutter: sdk: flutter` של ה‑package, כך ש‑`dart pub get` עובד כמו שהוא. (אומת — `dart pub get` עבר.)
2. **ה‑native — אין צורך לקמפל, יש בינאריים מוכנים ב‑GitHub release.** הבהרה חשובה (תוקנה):
   - **לפיתוח מקומי (Windows)** השתמשנו ב‑`.dll` שכבר נבנה ע"י האפליקציה (`C:\Users\user\otzaria\build\windows\x64\runner\Release\search_engine.dll`) — נוחות בלבד.
   - **טעינה אוטומטית מהקוד? לא.** ה‑package הוא Flutter FFI plugin (`ffiPlugin: true`); המנגנון שמביא את ה‑native אוטומטית הוא **cargokit**, והוא רץ **רק ב‑`flutter build`**. בשרת Dart טהור אין flutter‑build ואין `hook/build.dart` (native‑assets), וה‑loader הדיפולטי של FRB מחפש ב‑`rust/target/release/` — לכן **חובה להעביר נתיב מפורש** ל‑`RustLib.init(externalLibrary: ExternalLibrary.open(path))`.
   - **לשרת לינוקס:** GitHub release מסוג `precompiled_<hash>` ב‑`Y-PLONI/otzaria_search_engine` מכיל בינאריים מוכנים לכל הפלטפורמות, כולל **`x86_64-unknown-linux-gnu_libsearch_engine.so`** (~9.9MB) ו‑`aarch64-unknown-linux-gnu_libsearch_engine.so`. מורידים את ה‑`.so` המתאים, מבאנדלים ל‑Docker image, והשרת פותח אותו לפי env var `SEARCH_ENGINE_LIB` (ראה `resolveSearchEngineLibPath` ב‑POC). **אפס קומפילציה בשרת.**
   - **⚠️ קיבוע גרסה (קריטי):** תגי ה‑release הם content‑hash של מקורות ה‑Rust (סכמת cargokit), **לא** commit. שלושה חייבים לבוא מאותה גרסת מנוע אחרת מקבלים `SchemaError` (תובנה 7): (א) ה‑Dart bindings (`search_engine` git ref — כרגע `use-regex` @ `3ab8422c`), (ב) ה‑`.so` שמורידים, (ג) המנוע שבנה את אינדקס Tantivy מ‑`seforim.db`. שני ה‑precompiled releases הקיימים (`f835d99c`, `c9e92bbc`) אינם ה‑commit של `use-regex` — צריך לאמת/לבנות release תואם לפני production.
3. **`flutter_rust_bridge` runtime הוא pure‑Dart** (תלויות: args/async/meta/path/web — אפס Flutter). לכן מנוע החיפוש רץ בשרת Dart.
4. **גישת ה‑DB כבר portable** — הפרויקט משתמש ב‑`package:sqlite3` (FFI טהור), לא ב‑`sqflite`. כל ה‑DAOs ב‑`lib/migration/` הם Dart טהור.
5. **שיתוף קוד מבטל את סיכון הנורמליזציה** — אותו קוד `removeVolwels`/`sanitizeQuery` ירוץ בלקוח ובשרת.
6. **החיפוש רץ ב‑Dart טהור — אומת מקצה לקצה** (POC, שלב 0). שלוש מלכודות שהתגלו בדרך והתיקון שלהן:
   - **import של `ExternalLibrary`:** מגיע מ‑`package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart` — **לא** מה‑barrel הראשי `flutter_rust_bridge.dart`.
   - **`facets` ב‑`search()` הוא `Occur::Must` במנוע, ו‑`TermSet` ריק לא תופס כלום** → רשימת facets ריקה מחזירה **0 תוצאות**. לחיפוש בכל המאגר מעבירים את ה‑facet השורש `['/']` (זו גם ברירת המחדל באפליקציה, `currentFacets: ["/"]`). Tantivy מאנדקס כל נתיב‑אב, כך ש‑`/` תופס הכל.
   - **`topics` ב‑`DocumentInput` הוא Tantivy facet** — חייב להתחיל ב‑`/` (פורמט `/קטגוריה/.../id:<bookId>`, ראה `BookFacet.buildFacetPath`), אחרת `Facet::from_text` זורק.
7. **סנכרון סכמה DLL↔index (⚠️ לדפלוי):** ה‑`.dll` והאינדקס חייבים להיבנות מאותה גרסת מנוע. האינדקס המקומי במכונה זו (`%APPDATA%\otzaria\index`) נבנה ע"י גרסת אפליקציה אחרת ולכן נכשל מול ה‑DLL מענף `use-regex` (`SchemaError: schema does not match`). זה **אינו** כשל היתכנות — בשרת האינדקס ייבנה מ‑`seforim.db` עם אותה גרסת מנוע, כמתואר בשלב 0 של תוכנית העבודה ובסעיף 5.3 של המפרט. ה‑POC הוכח לכן מול אינדקס טרי שנבנה ע"י אותו DLL (`mode=self`).

---

## מצב נוכחי ✅

- [x] scaffold monorepo: `packages/otzaria_core`, `apps/server` (shelf + Dockerfile), `tools/search_engine_poc`.
- [x] `pubspec` מותאמים: `otzaria_core` עם sqlite3/logging/collection; `server` תלוי ב‑`otzaria_core` (path) + sqlite3.
- [x] השרת עולה (`dart run` → `Hello, World!`), wiring של ה‑monorepo תקין.
- [x] `git init` + commit ראשון.
- [x] **שלב 0 (POC חיפוש pure‑Dart) — ✅ עבר, שער ההחלטה ירוק.** הגישה מאושרת סופית.
- [x] **שלב 1 (חילוץ `otzaria_core`) — ✅ הושלם.** package Dart טהור (DAOs+models+נורמליזציה+`.sq` מוטמעים), `dart test` ירוק, אפס Flutter.
- [x] **שלב 2 (חיבור DB + `/version`) — ✅ הושלם.** `MyDatabase.readOnly`, `/health`, `/version` (מ‑`db_meta`), Dockerfile + compose.
- [x] **שלב 3 (קטלוג ותוכן ספר) — ✅ הושלם.** `/library`, `/books`, `/books/{id}`, `/exists`, `/text`, `/text/range`, `/toc`. 14 טסטים ירוקים + smoke‑test מול DB אמיתי (ראה למטה).
- [x] **שלב 4 (קישורים + עמוד מאוחד ⭐) — ✅ הושלם.** `/links`, `/links/range`, `POST /links/content`, ו‑`/page` המאוחד. 24 טסטים ירוקים + smoke‑test מול ה‑DB האמיתי (בראשית → 4 שורות + 3005 קישורים + 2935 תוכני מפרשים בקריאה אחת). תוקן באג ב‑otzaria_core (`LinkQueries.sq`: `IN ?`→`IN (?)`).

---

## שלב 0 — POC חיפוש pure‑Dart ✅ (הושלם — שער החלטה ירוק)

**מטרה:** להוכיח שמנוע החיפוש רץ ב‑Dart טהור מעל ה‑`.dll` הקיים. עד שזה ירוק — לא משקיעים בחילוץ.

> **✅ תוצאה:** `dart run bin/search_engine_poc.dart` (מצב `self`) הדפיס: init של `RustLib` ב‑Dart טהור, בניית אינדקס + commit (3 מסמכים), וחיפוש שמחזיר תוצאות נכונות (`אלהים`→2, `בראשית`→1). הקוד ב‑`tools/search_engine_poc/bin/search_engine_poc.dart`. ראה תובנות 6–7 למעלה למלכודות שהתגלו.
>
> **שני מצבי הרצה:**
> - `dart run bin/search_engine_poc.dart` — מצב `self`: בונה אינדקס טרי עם ה‑DLL הזה, מוסיף מסמכים, commit, ומחפש. הוכחה עצמאית מקצה לקצה (לא תלוי בגרסת אינדקס מקומי).
> - `dart run bin/search_engine_poc.dart real "<indexPath>" "<query>"` — פותח אינדקס קיים. דורש סכמה תואמת ל‑DLL (ראה תובנה 7).

**מה בוצע בפועל (כל הצעדים אומתו):**
1. ה‑`.dll` הועתק לתיקיית ה‑POC (`build/` נמחק ב‑`flutter clean`, לכן עותק יציב):
   ```powershell
   Copy-Item 'C:\Users\user\otzaria\build\windows\x64\runner\Release\search_engine.dll' `
             'C:\Users\user\otzaria-server\tools\search_engine_poc\search_engine.dll'
   ```
2. ב‑`tools/search_engine_poc/pubspec.yaml` נוסף ה‑dependency (אין צורך ב‑`flutter_rust_bridge` מפורש — מגיע transitively מ‑`search_engine`):
   ```yaml
   search_engine:
     git:
       url: https://github.com/Y-PLONI/otzaria_search_engine
       ref: use-regex
   ```
   ואז `dart pub get`.
3. `bin/search_engine_poc.dart` — נכתב עם **שני מצבים** (`self` הוכחה עצמאית / `real` אינדקס קיים). נקודות קריטיות שתוקנו מול הסקיצה המקורית (ראה תובנות 6–7):
   ```dart
   // import נכון ל-ExternalLibrary:
   import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
   import 'package:search_engine/search_engine.dart';

   await RustLib.init(externalLibrary: ExternalLibrary.open('search_engine.dll'));

   // topics חייב להיות facet חוקי שמתחיל ב-'/'
   final engine = SearchEngine(path: indexDir);
   await engine.addDocumentsBatch(docs: [
     DocumentInput(id: BigInt.from(1), title: 'בראשית', reference: 'בראשית א, א',
       topics: '/תורה/בראשית/id:1', text: 'בראשית ברא אלהים את השמים ואת הארץ',
       segment: BigInt.from(0), isPdf: false, filePath: ''),
   ]);
   await engine.commit();

   final results = await engine.search(
     regexTerms: ['אלהים'],
     facets: const ['/'],          // ⚠️ חובה! ריק => 0 תוצאות (Occur::Must)
     limit: 10, offset: 0, slop: 0, maxExpansions: 10,
     order: ResultsOrder.relevance,
     highlight: const HighlightConfig(
         highlightPrefix: '<<', highlightPostfix: '>>', maxChars: 120),
   );
   ```
   (הקובץ המלא בריפו — אל תשכתב, רק הרץ.)
4. נתיב האינדקס המקומי (מצב `real`): `%APPDATA%\otzaria\index` (כאן `C:\Users\user\AppData\Roaming\otzaria\index`, ~4.5GB). מיקום ברירת המחדל לפי `AppPaths.getIndexPath()` = ליד הספרייה.
5. הרצה:
   ```powershell
   cd C:\Users\user\otzaria-server\tools\search_engine_poc
   dart run bin/search_engine_poc.dart            # self — הוכחה עצמאית (ירוק)
   dart run bin/search_engine_poc.dart real "C:\Users\user\AppData\Roaming\otzaria\index" "בראשית"
   ```

**✅ Done — עבר:** הודפסו תוצאות חיפוש נכונות (מצב `self`). → הגישה מאושרת סופית, ממשיכים לשלב 1.
(מצב `real` מול האינדקס המקומי נכשל ב‑`SchemaError` בגלל אי‑התאמת גרסת מנוע↔אינדקס — תובנה 7; לא חוסם.)

---

## שלב 1 — חילוץ `otzaria_core` (גל נקי בלבד) ✅ הושלם

**מטרה:** להעביר את שכבת ה‑DB והמודלים ל‑package המשותף — רק מה שנקי, בלי abstractions עדיין.

> **קיצור דרך חשוב:** לא צריך לחלץ את `database_library_provider.dart` המלא (שתלוי ב‑Settings/Sentry/pdfrx). אפשר לבנות את ה‑endpoints **ישירות מעל ה‑DAOs הנקיים** של `lib/migration/`. זה מפשט דרמטית.

> **✅ תוצאה:** `otzaria_core` עומד בפני עצמו ב‑Dart טהור — קומפילציה נקייה (`dart run` של ה‑example) + `dart test` ירוק (6/6, כולל DAO אמיתי מול sqlite3 in‑memory), ו‑**אפס Flutter ב‑`pubspec.lock`**. (הערה: `dart analyze` קורס במכונה זו בגלל באג perf‑witness ב‑shutdown — errno 1920 על קובץ נעול, ככל הנראה מול ה‑analysis‑server של ה‑IDE — לא קשור לקוד; הקומפילציה+טסטים מאמתים חזק יותר.)

**מה בוצע בפועל:**
1. הועתק התת‑עץ `migration/database/{daos,repository,sql}` ו‑`migration/models/*` (פרט ל‑`model_adapters.dart` — bridge ללקוח בלבד) אל `packages/otzaria_core/lib/src/`. ה‑imports שם **יחסיים** (`../sql/`, `../../models/`), לכן שמירת מבנה התיקיות = הם ממשיכים לעבוד as‑is. (תת‑העצים `sync/`+`generator/` **לא** הועתקו — לא נדרשים לשרת.)
2. **נורמליזציה:** במקום לחלץ את `lib/utils/text/text_manipulation.dart` המלא (1191 שורות, צמוד ל‑Flutter/אפליקציה), חולצו רק הפונקציות הנקיות הנדרשות אל `lib/src/text/text_normalization.dart`: `removeVolwels`, `removeTeamim`, `stripHtmlIfNeeded`, `normalizeForFindRefMatch` (+ ה‑regexes שלהן inline). `seforim_repository` משתמש רק ב‑`normalizeForFindRefMatch`. (`sanitizeQuery` יושב ב‑`SearchQueryBuilder` של שכבת החיפוש — לשלב 4.)
3. **`.sq` הוטמעו כקבוע Dart** (`lib/src/database/sql/sql_queries_data.dart`, נוצר ע"י `tool/gen_sql_data.dart`). `query_loader.dart` כבר **לא** משתמש ב‑`rootBundle` אלא seed מהמפה המוטמעת → אפס IO בזמן ריצה, עובד גם תחת AOT (`dart compile exe`).
4. `kDebugMode` ב‑`category_dao.dart` → `const bool kDebugMode = !bool.fromEnvironment('dart.vm.product')` (שקילות pure‑Dart נאמנה: שקרי תחת AOT product, אמת תחת `dart run`).
5. `pubspec`: נוסף `equatable` (לצד `sqlite3`/`logging`/`collection`). barrel ב‑`lib/otzaria_core.dart` מייצא DAOs+repository+models+normalization+query_loader.

**מלכודות שהתגלו (לשימוש בשלבים הבאים):**
- היחידות שצמודות ל‑Flutter/אפליקציה בתוך ה‑scope היו: `query_loader.dart` (`rootBundle`), `category_dao.dart` (`kDebugMode`), ו‑`model_adapters.dart` (`package:otzaria/models/books.dart`). הכול טופל/הוחרג.
- `database.dart` עדיין מריץ `PRAGMA journal_mode=WAL` + `CREATE TABLE IF NOT EXISTS` בפתיחה — שלב 2 צריך לפתוח read‑only; ה‑CREATE‑IF‑NOT‑EXISTS על DB קיים הם no‑op, וה‑WAL עטוף ב‑try/catch, אבל לאמת מול `seforim.db` אמיתי בפתיחת read‑only.

**Done:** ✅ `otzaria_core` נבנה ונבדק ב‑Dart טהור, אפס תלות ב‑Flutter SDK.

---

## שלב 2 — חיבור DB בשרת + `/version`

**מטרה:** השרת קורא מ‑`seforim.db` אמיתי.

1. הכן `sqlite3.dll` לסביבת השרת (ב‑Windows: ליד ה‑exe / ב‑PATH; ב‑Linux: `libsqlite3` מותקן).
2. בשרת: קבל נתיב ל‑`seforim.db` מ‑env var (`SEFORIM_DB_PATH`), פתח אותו read‑only דרך `otzaria_core`.
3. ממש `GET /version` → קרא `content_version_int` מטבלת `db_meta`.

**Done:** `curl /version` מחזיר את גרסת המאגר האמיתית מה‑DB.

---

## שלב 3 — Endpoints: קטלוג ותוכן ספר ✅ הושלם

**מטרה:** קריאת ספר מלאה (טקסט + TOC), ישירות מעל ה‑DAOs.
(חתימות ה‑JSON המדויקות: ראה `online_server_spec.md §4.1–4.2`.)

**מה בוצע בפועל** (הכול ב‑[apps/server/lib/api.dart](apps/server/lib/api.dart), בנוי מעל DAOs/`SeforimRepository` בלבד — **בלי** `ensureInitialized()` שמריץ INSERT ולא מתאים ל‑read‑only):
- `GET /library` — עץ קטגוריות מלא + ספרים מקוננים + `contentVersion`. נבנה מ‑`getAllCategories()` + `getAllBooksWithRelations()` (קריאה אחת, ללא N+1), עץ לפי `parentId`, ספרים ממוינים `order,title`.
- `GET /books` — רשימה שטוחה; `?category=<id>` מסנן (400 על id לא תקין).
- `GET /books/{id}` — מטא מלא + דגלים; כולל מחרוזת `author` נוחה (404 אם חסר).
- `GET /books/{id}/exists` — `{ exists }`.
- `GET /books/{id}/text` — טקסט raw מלא כ‑`text/plain` (שורות מחוברות ב‑`\n`, ניקוד/טעמים נשמרים).
- `GET /books/{id}/text/range?start=&end=` — `{ bookId, startLine, endLine, totalLines, lines[] }` לפי `lineIndex` (כולל קצוות; 400 אם חסרים פרמטרים / `end<start`).
- `GET /books/{id}/toc` — עץ TOC `{ text, index, level, children[] }` (נבנה מהרשימה השטוחה דרך `parentId`; `index` = `lineIndex` שמחושב ב‑`TocQueries.selectByBookId` דרך `COALESCE`).

**אימות:**
- **14 טסטים ירוקים** ([apps/server/test/server_test.dart](apps/server/test/server_test.dart)): seed של DB עם סכמת `otzaria_core` המדויקת (קטגוריות אב/בן, ספרים, שורות, TOC מקונן) → כל endpoint נבדק כולל מקרי 400/404.
- **Smoke‑test מול ה‑DB האמיתי** (`C:\ProgramData\otzaria\books\seforim.db`, 6.3GB): `/version`=1, `/library`=17 קטגוריות שורש (תלמוד בבלי/תנ"ך/משנה/ירושלמי/מדרש/הלכה…), `/books/1`=בראשית (txt, 1584 שורות, ניקוד), `/toc`=שורש "בראשית" עם 50 ילדים. **כל ה‑endpoints עובדים מול הסכמה האמיתית.**

> **📍 מיקום ה‑DB האמיתי:** `C:\ProgramData\otzaria\books\seforim.db` (סכמת Otzaria מלאה: יש `fileType`, `tocEntry.lineIndex`, `db_meta`). **שים לב — לא לבלבל** עם `...\io.github.kdroidfilter.seforimapp\databases\seforim.db`, שהוא גרסת סכמה upstream שונה (חסר `fileType`/`lineIndex`) ו‑`/library`/`/toc`/`/books` נכשלים מולה.

---

## שלב 4 — קישורים + endpoint עמוד מאוחד ⭐ ✅ הושלם

**מטרה:** לפתור את אתגר ה‑latency (כל גלילה = round‑trip).

**מה בוצע בפועל** (ב‑[apps/server/lib/api.dart](apps/server/lib/api.dart)):
- `GET /books/{id}/links` — כל הקישורים שבהם הספר הוא המקור (`LinkDao.selectLinksBySourceBook`).
- `GET /books/{id}/links/range?start=&end=&targets=` — קישורים בטווח שורות (לפי `lineIndex`), `targets`=רשימת `targetBookId` מופרדת בפסיקים לסינון. כולל `sourceLineIndex` (ממופה מ‑`lineId`) ו‑`targetBookTitle`.
- `POST /links/content` — גוף `{ "targetLineIds": [int,…] }` → `{ "content": { "<lineId>": "<text>" } }`.
- ⭐ `GET /books/{id}/page?start=&end=&commentators=` — שורות + קישורים + תוכן מפרשים **בקריאה אחת**. תוכן המפרשים ממופתח `"targetBookId:targetLineId"`. `commentators` ריק = כל הקישורים בטווח.

**אימות:**
- **24 טסטים ירוקים** — seed הורחב עם `connection_type`, `link`, וספר מפרש (רש"י) עם שורות יעד; כל endpoint נבדק כולל סינון/400/404.
- **Smoke‑test מול ה‑DB האמיתי:** `/books/1/page?start=0&end=3` החזיר 4 שורות + **3005 קישורים + 2935 תוכני מפרשים בקריאה אחת**, עם `sourceLineIndex`/`targetBookTitle` תקינים → אתגר ה‑latency נפתר.

> **🐞 באג ב‑otzaria_core — ✅ תוקן:** `LinkDao.selectLinksBySourceLineIds` היה שבור — ה‑`.sq` הכיל `WHERE l.sourceLineId IN ?` (**ללא סוגריים**), וה‑DAO מחליף את ה‑`?` ב‑`?,?` ⇒ `IN ?,?` (תחביר SQL שגוי). **התיקון:** `LinkQueries.sq` שונה ל‑`IN (?)` ו‑`sql_queries_data.dart` נוצר מחדש (`dart run tool/gen_sql_data.dart`); כעת ה‑DAO מייצר `IN (?,?,…)` תקין. השרת חזר להשתמש ב‑DAO ישירות (אין יותר עוקף). ⚠️ אם ה‑`.sq` באפליקציית Otzaria עדיין מכיל `IN ?` — צריך תיקון מקביל שם.

**Done:** ✅ גלילה בספר עם מפרשים נטענת בקריאה אחת.

---

## שלב 5 — חיפוש (FFI ישיר) + גימטריה

**מטרה:** חשיפת מנוע החיפוש (מ‑POC) דרך ה‑API.

- הוסף את `search_engine` ל‑`otzaria_core`/`server` (כמו ב‑POC), טען את ה‑`.dll`.
- `POST /search`, `/search/count`, `/search/facets` — תרגום פרמטרים → `engine.search/count/getFacetCounts`.
- נרמל את ה‑query דרך אותו קוד מ‑`otzaria_core` (זהות מובטחת).
- `POST /search/gematria` — ישירות מול SQLite.

**Done:** חיפוש + facets + גימטריה זהים למקומי.

---

## שלב 6 — Cross‑cutting

- `Cache-Control` ארוך עם מפתח שכולל `contentVersion`.
- `API key` בסיסי + `rate limiting`.
- סנכרון `contentVersion`↔`indexVersion` ב‑`/version`.
- Concurrency: connection per‑isolate + isolate pool / כמה instances.
- CORS, לוגים, health‑check.

---

## שלב 7 — Deployment (VPS + Cloudflare)

- `dart compile exe` + ה‑Dockerfile שכבר נוצר ע"י `server-shelf`.
- **native של מנוע החיפוש (לינוקס):** ב‑Dockerfile להוריד מ‑GitHub release את `x86_64-unknown-linux-gnu_libsearch_engine.so` (או aarch64 ל‑ARM) לנתיב קבוע (למשל `/app/lib/libsearch_engine.so`), ולהגדיר `ENV SEARCH_ENGINE_LIB=/app/lib/libsearch_engine.so`. אין קומפילציה. **חובה לקבע ל‑release התואם לגרסת ה‑bindings ולגרסת האינדקס** (תובנה 2, ⚠️ קיבוע גרסה).
- **sqlite3 native:** ב‑Linux להתקין `libsqlite3` (או לבאנדל). ב‑Windows `sqlite3.dll` ליד ה‑exe.
- VPS: העלאת `seforim.db` + אינדקס Tantivy, הרצת השירות.
- Cloudflare מלפנים: HTTPS, caching לפי גרסה, rate limiting ב‑CDN.
- תהליך עדכון מאגר: החלפת DB → בניית אינדקס מחדש מאותה גרסה → bump version.

---

## שלב 8 — Parity validation

- סקריפט השוואה: מדגם ספרים → טקסט/TOC/קישורים מהשרת מול ה‑DB המקומי.
- מדגם שאילתות חיפוש → תוצאות + facet counts זהים.
- בדיקות עומס בסיסיות (concurrency על SQLite read‑only).

**Done:** דוח התאמה שמאשר "מה שמתקבל = מה שמקומי".

---

## עתידי (מחוץ להיקף הנוכחי — צד הלקוח)

כשתחליט לגעת בקוד האפליקציה: מעבר לצרוך את `otzaria_core`, הוספת `ApiLibraryProvider` ל‑`LibraryProviderManager`, החלפת FFI מקומי בקריאת רשת, ו‑cache מקומי.

---

## נקודות פתוחות

1. מזהה ספר ב‑API: `bookId` בלבד, או גם `(title, categoryId, fileType)`?
2. מודל גרסאות: נעילת לקוח לגרסת שרת לכל סשן, או טיפול בעדכון תוך כדי?
3. PDF: מחוץ ל‑MVP (טקסט בלבד) — מתי להוסיף?
