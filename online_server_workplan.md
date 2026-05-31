# תוכנית עבודה — הקמת שרת ה‑API האונליין (Dart)

> **מסמך מלווה:** המפרט המלא ב‑[online_server_spec.md](online_server_spec.md).
> **Stack:** שרת Dart עם ליבה משותפת · חיפוש FFI ישיר · MVP טקסט בלבד · VPS + Cloudflare.

## עקרונות מנחים
- **Parity‑first:** בכל שלב, היעד הוא שהפלט יהיה זהה למה שהלקוח מקבל מהספרייה המקומית. נבדוק מול ה‑DB המקומי לאורך הדרך.
- **שיתוף קוד:** הליבה (`otzaria_core`) משותפת לאפליקציה ולשרת — כותבים פעם אחת.
- **השרת קורא בלבד:** `seforim.db` ואינדקס Tantivy נבנים מראש; השרת לעולם לא כותב אליהם.
- **POC לפני התחייבות:** הסיכון הטכני היחיד (חיפוש pure‑Dart) נבדק בשלב 0 לפני שאר העבודה.

## מפת השלבים והתלויות

```
שלב 0 (POC + הכנה)  ← שער החלטה: האם חיפוש רץ ב-Dart טהור?
   │
   ▼
שלב 1 (otzaria_core — הפרדה מ-Flutter)   ← הבסיס לכל השאר
   │
   ├───────────────┬────────────────────────┐
   ▼               ▼                         ▼
שלב 2           שלב 4 (במקביל)            (אפשר להתחיל
scaffold+DB     חיפוש FFI ישיר            parity harness)
קטלוג+תוכן      + גימטריה
   │               │
   ▼               │
שלב 3              │
קישורים+עמוד⭐     │
   │               │
   └──────┬────────┘
          ▼
       שלב 5 (caching, אבטחה, גרסאות, concurrency)
          ▼
       שלב 6 (Deployment: VPS + Cloudflare)
          ▼
       שלב 7 (Parity validation מקצה לקצה)
          ▼
       שלב עתידי (צד לקוח: ApiLibraryProvider + מעבר ל-core)
```

---

## שלב 0 — POC חיפוש pure‑Dart + הכנה ⚠️ שער החלטה
**מטרה:** להוכיח את ההנחה הקריטית לפני השקעה רחבה.
1. fork של `Y-PLONI/otzaria_search_engine`: להסיר `flutter: sdk: flutter` מה‑pubspec ולהפוך לחבילת Dart רגילה (הקוד עצמו כבר נקי מ‑Flutter).
2. בניית ה‑native של Rust ידנית: `cargo build --release` → `.dll`/`.so`/`.dylib`.
3. תוכנית Dart console (`dart run`, ללא Flutter) שטוענת את ה‑library דרך `RustLib.init(externalLibrary: ExternalLibrary.open(path))`, פותחת אינדקס קיים ומריצה חיפוש.
4. אימות: התוצאות זהות לחיפוש באפליקציה על אותן שאילתות.
5. במקביל: מדידת גדלים בפועל (`seforim.db` + אינדקס) והקמת מבנה ה‑repo (monorepo: `packages/otzaria_core/` + `server/`).

**שער החלטה:** אם החיפוש רץ ב‑Dart טהור → ממשיכים כמתוכנן. אם לא → fallback לשירות Rust קטן ל‑חיפוש בלבד (שאר השרת נשאר Dart), ועדכון המפרט.
**Done:** הוכחת היתכנות לחיפוש pure‑Dart (או הכרעת fallback), + גדלים ידועים.

---

## שלב 1 — חילוץ `otzaria_core` (הפרדה מ‑Flutter)
**מטרה:** package Dart נקי, משותף ללקוח ולשרת. זהו הבסיס לכל השאר.
1. ליצור package `otzaria_core` ולהעביר אליו: `models/`, `data/data_providers/` (ה‑DAO/SQLite), `migration/` (סכמה/DAOs), `search/` (לוגיקה, לא UI), `indexing/` (כולל הנורמליזציה).
2. להחליף תלויות Flutter בליבה:
   - `package:flutter/foundation.dart` (בעיקר `debugPrint`) → `package:logging`.
   - `path_provider` / `flutter_settings_screens` → abstraction של קונפיג (הזרקת נתיבים/הגדרות מבחוץ).
3. לוודא שהליבה מתקמפלת ועוברת `dart analyze` **ללא** תלות ב‑Flutter SDK.
4. להריץ את מבחני היחידה הקיימים של השכבות שהועברו מול ה‑package החדש.

**Done:** `otzaria_core` עומד בפני עצמו, נבנה ונבדק ב‑Dart טהור.
**סיכון:** היקף ההפרדה — ייתכנו תלויות Flutter סמויות. למפות מוקדם (אפשר כבר בשלב 0).

---

## שלב 2 — Scaffold שרת + שכבת נתונים: קטלוג ותוכן ספר
**מטרה:** קריאת ספר מלאה (ללא קישורים/חיפוש), מעל הליבה.
1. scaffold שרת (`shelf`/`dart_frog`) שצורך את `otzaria_core`; פתיחת `seforim.db` ב‑`package:sqlite3` read‑only.
2. `GET /version` (מ‑`db_meta`).
3. `GET /library` — עץ קטגוריות + ספרים + מטא עשיר (`buildLibraryCatalog`).
4. `GET /books`, `/books/{id}`, `/books/{id}/exists`, `/books/titles`.
5. `GET /books/{id}/text` ו‑`/text/range`; `GET /books/{id}/toc` ו‑`/alt-toc`.
6. החזרת `line.content` raw (ניקוד/טעמים נשמרים).

**Done:** ספר נטען מהשרת זהה למקומי (טקסט + TOC), מאומת על 5–10 ספרים מגוונים.

---

## שלב 3 — קישורים, מפרשים, ו‑endpoint העמוד המאוחד ⭐
**מטרה:** לפתור את אתגר ה‑latency המרכזי.
1. `GET /books/{id}/links` ו‑`/links/range` (סינון לפי `targets`).
2. `POST /links/content` — תוכן יעד ל‑batch של קישורים.
3. ⭐ `GET /books/{id}/page?start=&end=&commentators=[...]` — שורות + קישורים + תוכן מפרשים בקריאה אחת.
4. מדידת latency וכוונון (יעד: גלילה חלקה).

**Done:** גלילה בספר עם מפרשים נטענת בקריאה אחת לעמוד, מתחת ל‑latency סף סביר.
**סיכון:** N+1 — חובה לאחד שאילתות; זה לב חוויית המשתמש.

---

## שלב 4 — חיפוש (FFI ישיר) + גימטריה (במקביל לשלבים 2–3)
**מטרה:** חשיפת מנוע החיפוש הקיים דרך ה‑API, ללא שירות נפרד.
1. אינטגרציית מנוע החיפוש (לפי תוצאת שלב 0) ישירות בתהליך השרת.
2. `POST /search`, `/search/count`, `/search/facets` — תרגום `SearchConfiguration` (mode/distance/order/searchOptions) לקריאת המנוע.
3. נורמליזציית ה‑query דרך אותו קוד מ‑`otzaria_core` (זהות מובטחת).
4. `POST /search/gematria` — ישירות מול SQLite (לא דרך Tantivy).
5. parity מול תוצאות החיפוש באפליקציה.

**Done:** חיפוש + facets + גימטריה עובדים מקצה לקצה, זהים למקומי.

---

## שלב 5 — Cross‑cutting: caching, אבטחה, גרסאות, concurrency
1. `Cache-Control` ארוך עם מפתח שכולל `contentVersion` (תוכן immutable לגרסה).
2. `API key` בסיסי + `rate limiting`.
3. סנכרון `contentVersion`↔`indexVersion` ב‑`/version`, וטיפול בחוסר התאמה.
4. Concurrency: connection per‑isolate + isolate pool (או כמה instances).
5. CORS, לוגים, health‑check.

**Done:** השרת מאובטח בסיסית, cache‑able, יציב תחת בקשות מקבילות, וחושף גרסה אמינה.

---

## שלב 6 — Deployment: VPS + Cloudflare
1. קומפילציית AOT (`dart compile exe`) + Dockerfile; באנדל ה‑native של מנוע החיפוש.
2. הקמת VPS, העלאת `seforim.db` + אינדקס, הרצת השירות.
3. Cloudflare מלפנים: HTTPS, caching rules לפי גרסה, rate limiting ברמת CDN.
4. ניטור בסיסי + תהליך עדכון מאגר (החלפת DB → בניית אינדקס מחדש מאותה גרסה → bump `version`).

**Done:** ה‑API חי, מאחורי Cloudflare, נגיש מהאינטרנט.

---

## שלב 7 — Parity validation מקצה לקצה
1. סקריפט השוואה: מדגם ספרים → טקסט/TOC/קישורים/מפרשים מהשרת מול ה‑DB המקומי.
2. מדגם שאילתות חיפוש → השוואת תוצאות + facet counts.
3. בדיקות עומס בסיסיות (concurrency על SQLite read‑only).

**Done:** דוח התאמה שמאשר "מה שמתקבל = מה שמקומי".

---

## שלב עתידי — צד הלקוח (כשתחליט לגעת בקוד האפליקציה)
מחוץ להיקף הנוכחי, אך המשך טבעי:
1. מעבר האפליקציה לצרוך את `otzaria_core` (במקום הקוד המוטמע) — מאחד את הבסיס.
2. `ApiLibraryProvider` חדש שמממש את `LibraryProvider` מול ה‑API ומתווסף ל‑`LibraryProviderManager`.
3. החלפת קריאת ה‑FFI בחיפוש לקריאת רשת ב‑`SearchRepository`.
4. Cache מקומי + טיפול במצב לא‑מקוון + אינדיקציית מקור (אונליין/מקומי).

---

## סדר מומלץ להתחלה
1. **שלב 0** (POC) — לפני הכל. שער ההחלטה.
2. **שלב 1** (otzaria_core) — הבסיס.
3. שלבים 2–4 (חלקם במקביל).
4. שלבים 5–7 (ייצוב והפצה).
