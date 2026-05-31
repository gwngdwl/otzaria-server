# מפרט שרת API לגישה אונליין למאגר הספרים (Otzaria)

> **סטטוס:** מסמך תכנון / מפרט דרישות. טרם מומש בקוד.
> **מטרה:** לאפשר לאפליקציית האנדרואיד (ובהמשך כל פלטפורמה) לגשת למאגר הספרים מרחוק דרך שרת API דינמי, במקום להוריד ולאחסן את כל המאגר מקומית.
> **Stack שנבחר:** שרת **Dart** (לא Flutter) עם ליבה משותפת לאפליקציה. ראה סעיף 7.
> **עיקרון מנחה:** מה שהמשתמש מקבל בספר במצב אונליין הוא **בדיוק** מה שנטען לו היום מהספרייה המקומית — אותו טקסט, אותו ניקוד, אותם מפרשים, אותו תוכן עניינים, אותו חיפוש.

---

## 1. רקע: איך המאגר עובד היום

- **אין שרת API.** כל ההפצה מתבצעת כקבצים סטטיים ב‑GitHub Releases (ריפו `Otzaria/SeforimLibrary`).
- **המאגר כולו הוא קובץ SQLite אחד** — `seforim.db` (הערכה: ~500MB–1GB; דחוס ב‑zstd לכ‑100–150MB). באתחול ראשון מורידים אותו במלואו, ולאחר מכן עדכוני DIFF הדרגתיים (`lib/file_sync/repository/file_sync_repository.dart`).
- **הטקסט שמור שורה‑שורה** בטבלת `line`; קישורים/מפרשים בטבלת `link`; קטגוריות, תוכן עניינים, ראשי תיבות ומבני TOC חלופיים — באותו DB.
- **החיפוש (Tantivy) נבנה מקומית** מתוך ה‑DB באמצעות fork ב‑Rust: `Y-PLONI/otzaria_search_engine` (גישה דרך flutter_rust_bridge / FFI). אין כיום חיפוש בצד שרת.
- כל הגישה לנתונים עוברת דרך חוזה אחיד: `LibraryProvider` (`lib/data/data_providers/library_provider.dart`), עם שני מימושים — `DatabaseLibraryProvider` ו‑`FileSystemLibraryProvider`, מתואמים ע"י `LibraryProviderManager`.

### המשמעות לשרת
אין צורך לבנות נתונים מאפס, **וגם לא לבנות לוגיקה מאפס.** הבדיקה בקוד הראתה שכל שכבת הליבה היא Dart נייד:
- גישה ל‑DB דרך `package:sqlite3` (FFI טהור) — **לא** `sqflite` (שהוא Flutter plugin).
- קוד מנוע החיפוש נקי (`dart:ffi` + `flutter_rust_bridge` runtime; אפס Flutter UI).
- המודלים, הנורמליזציה ולוגיקת ה‑DAO — Dart טהור.

לכן השרת ייכתב ב‑Dart, יחלוק את אותה ליבה עם האפליקציה, ויעטוף את `seforim.db` + אינדקס Tantivy בשכבת HTTP.

---

## 2. ארכיטקטורה כללית

```
┌──────────────────────────┐                            ┌──────────────────────────────────────┐
│   אפליקציית Otzaria       │      HTTPS / JSON          │            שרת Dart (API)              │
│   (Flutter UI)           │ ─────────────────────────▶ │  ┌────────────────────────────────┐    │
│        │                 │ ◀───────────────────────── │  │  שכבת HTTP (shelf / dart_frog)  │    │
│        ▼                 │                            │  └───────────────┬────────────────┘    │
│  ┌─────────────────┐     │                            │                  ▼                     │
│  │  otzaria_core    │◀────┼──── package Dart משותף ───▶│         ┌─────────────────┐            │
│  │ data / models /  │     │                            │         │  otzaria_core   │            │
│  │ search / indexing│     │                            │         └──┬───────────┬──┘            │
│  └─────────────────┘     │                            │            ▼           ▼               │
└──────────────────────────┘                            │     ┌──────────┐  ┌────────────────┐   │
                                                         │     │seforim.db│  │ Tantivy (FFI    │  │
                                                         │     │(sqlite3  │  │ ישיר, אותו crate)│ │
                                                         │     │ read-only)│ └────────────────┘   │
                                                         │     └──────────┘                       │
                                                         └──────────────────────────────────────┘
                                                                  ▲
                                                                  │ Cloudflare CDN (cache לפי גרסה)
```

### רכיבי הליבה

| רכיב | מקור | המלצה |
|------|------|--------|
| **שפה / Runtime** | Dart (VM/AOT) | אותה שפה כמו האפליקציה → שיתוף קוד מלא |
| **ליבה משותפת** | `otzaria_core` (חדש) | חילוץ `data/`, `models/`, `search/`, `indexing/` ל‑package Dart נקי, משותף ללקוח ולשרת |
| **מסד נתונים** | `seforim.db` הקיים | `package:sqlite3` read‑only (כבר בשימוש בלקוח). PostgreSQL רק אם נדרש scale חריג |
| **מנוע חיפוש** | crate Tantivy הקיים | טעינה ישירה דרך `dart:ffi`/FRB — **בלי שירות נפרד ובלי HTTP פנימי** |
| **שכבת API** | חדש | `shelf` (יציב) או `dart_frog` (מודרני) |

---

## 3. מבני הנתונים

### 3.1 סכמת מסד הנתונים (טבלאות רלוונטיות ל‑API)

מתוך `lib/migration/database/sql/Database.sq`:

| טבלה | תפקיד | עמודות מפתח |
|------|-------|-------------|
| `category` | עץ קטגוריות | `id, parentId, title, level, orderIndex` |
| `category_closure` | חיפוש צאצאים/אבות יעיל | `ancestorId, descendantId` |
| `book` | ספרים + דגלי תכונות | `id, categoryId, sourceId, title, totalLines, fileType, filePath, isContentExternal, externalLibraryId, isPersonal, hasNekudot, hasTeamim, hasCommentaryConnection, hasTargumConnection, hasReferenceConnection, hasAltStructures, pages, volume` |
| `line` | תוכן שורה‑שורה | `id, bookId, lineIndex, content, heRef, tocEntryId` |
| `tocEntry` / `tocText` | תוכן עניינים | `id, bookId, parentId, textId, level, lineId, lineIndex, hasChildren` |
| `line_toc` | מיפוי שורה ← כותרת TOC | `lineId, tocEntryId` |
| `alt_toc_structure` / `alt_toc_entry` / `line_alt_toc` | מבני TOC חלופיים (פרשה/עלייה) | — |
| `link` | קישורים בין ספרים | `sourceBookId, targetBookId, sourceLineId, targetLineId, connectionTypeId` |
| `connection_type` | סוגי קישור | `id, name` (commentary/targum/reference/…) |
| `book_has_links` | דגל אם לספר יש קישורים | `bookId, hasSourceLinks, hasTargetLinks` |
| `book_author` / `author` | מחברים | — |
| `book_topic` / `topic` | נושאים | — |
| `book_acronym` | ראשי תיבות / שמות חלופיים | `bookId, term` |
| `default_commentator` / `default_targum` | ברירות מחדל למפרשים/תרגום לכל ספר | `bookId, commentatorBookId/targumBookId, position` |
| `db_meta` | מטא, כולל `content_version_int` | `key, value` |
| `pdf_outline_cache` | cache של outline ל‑PDF | — |

### 3.2 מודלים שעוברים בין שרת ללקוח

> בארכיטקטורת Dart, המודלים האלה **אינם מוגדרים מחדש** בשרת — הם מיובאים מ‑`otzaria_core` (אותו `Book`/`Link`/`TocEntry`/`SearchResult`), כך שהסריאליזציה זהה משני הצדדים.

**`Book`** (`lib/models/books.dart`) — שים לב: `toJson()` מחזיר שדות **מינימליים** בלבד; המטא העשיר (מחבר, תיאור, נושאים, תאריכי הוצאה) מגיע **בנפרד** דרך `metadata: Map<String, Map<String, dynamic>>` שמועבר ל‑`loadBooks`/`buildLibraryCatalog`.

```json
// Book.toJson() — מבנה מינימלי
{
  "id": 1234, "title": "בראשית", "type": "TextBook",
  "filePath": null, "fileType": "txt",
  "categoryPath": "תנ\"ך/תורה", "categoryId": 5,
  "heCategories": "תנ\"ך", "isUserBook": false, "externalLibraryId": null
}
```
סוגי `type`: `TextBook` | `PdfBook` | `DocxBook` | `ExternalLibraryBook`.
מטא נוסף שיש להחזיר לצד הלקוח: `author, heShortDesc, heDesc, topics, heEra, compDateStringHe, compPlaceStringHe, pubDateStringHe, pubPlaceStringHe`.

**`TocEntry`** (`lib/models/books.dart:496`):
```json
{ "text": "פרק א", "index": 50, "level": 2, "children": [ ... ] }
```
(`parent` נגזר מההיררכיה; `index` = מספר שורה 0‑based בספר.)

**`Link`** (`lib/models/links.dart`) — מבנה ה‑JSON ההיסטורי שה‑`fromJson` הנוכחי מצפה לו (כולל שמות מפתח לא־סטנדרטיים, ושגיאת הכתיב `Conection Type` כפי שהיא בקוד):
```json
{
  "heRef_2": "רש\"י על בראשית א, א",
  "line_index_1": 12,        // שורה בספר המקור (1-based)
  "path_2": "רש\"י על בראשית",// שם/נתיב ספר היעד
  "line_index_2": 8,         // שורה בספר היעד (1-based)
  "Conection Type": "commentary",
  "category_id_2": 7,        // אופטימיזציה
  "file_type_2": "txt",      // אופטימיזציה
  "start": null, "end": null // לקישורים מבוססי תווים
}
```
> **המלצה:** ה‑API יחזיר פורמט נקי וברור, וה‑`ApiLibraryProvider` החדש יבנה ממנו `Link` ישירות (לא דרך ה‑`fromJson` הישן). יש לתעד את המיפוי בין השמות.

**`SearchResult`** (`lib/migration/models/search_result.dart`):
```json
{ "bookId": 1234, "bookTitle": "בראשית", "lineId": 99001,
  "lineIndex": 50, "snippet": "בראשית <b>ברא</b> אלהים", "rank": 8.42 }
```

---

## 4. מפרט ה‑API

מיפוי אחד‑לאחד מחוזה `LibraryProvider`. כל ספר מזוהה היום במפתח מורכב `(title, categoryId, fileType)`.
> **המלצה:** לעבור ב‑API ל‑`bookId` (ה‑primary key הקיים בטבלת `book`) כמזהה ראשי — נקי ויציב יותר. אפשר לחשוף גם resolve מ‑`(title, categoryId, fileType)` ל‑`bookId` לצורכי תאימות.

### 4.1 קטלוג ומטא

| Method | Path | פרמטרים | מחזיר | מקור בחוזה |
|--------|------|---------|--------|-----------|
| `GET` | `/version` | — | `{ contentVersion, indexVersion, builtAt }` | `db_meta.content_version_int` |
| `GET` | `/library` | — | עץ קטגוריות מלא + ספרים + מטא | `buildLibraryCatalog()` |
| `GET` | `/books` | `?category=` (אופ') | רשימת ספרים שטוחה | `loadBooks()` |
| `GET` | `/books/{id}` | — | מטא מלא של הספר + דגלים (`hasNekudot`, `hasCommentaryConnection`…) | metadata של `Book` |
| `GET` | `/books/titles` | — | קבוצת מזהי ספרים זמינים | `getAvailableBookTitles()` |
| `GET` | `/books/{id}/exists` | — | `{ exists: bool }` | `hasBook()` |

**`GET /library`** — תגובה (סקיצה):
```json
{
  "contentVersion": 142,
  "categories": [
    { "id": 1, "title": "תנ\"ך", "level": 0, "order": 0,
      "subCategories": [ /* Category רקורסיבי */ ],
      "books": [ /* Book + metadata */ ] }
  ]
}
```

### 4.2 תוכן ספר

| Method | Path | פרמטרים | מחזיר | מקור |
|--------|------|---------|--------|------|
| `GET` | `/books/{id}/text` | — | תוכן מלא (string) | `getBookText()` |
| `GET` | `/books/{id}/text/range` | `?start=&end=` | `{ startLine, endLine, totalLines, lines[] }` | `getBookTextRangeFromDb()` |
| `GET` | `/books/{id}/toc` | — | עץ `TocEntry` | `getBookToc()` |
| `GET` | `/books/{id}/alt-toc` | `?key=` (אופ') | מבני TOC חלופיים | `alt_toc_*` |

> הטקסט ב‑`line.content` כולל **כבר** ניקוד וטעמים. ההחלטה אם להציגם נשארת בצד הלקוח, ולכן ה‑API מחזיר raw — כך מובטחת זהות לחוויה המקומית.

### 4.3 קישורים ומפרשים

| Method | Path | פרמטרים | מחזיר | מקור |
|--------|------|---------|--------|------|
| `GET` | `/books/{id}/links` | — | כל הקישורים של הספר | `getAllLinksForBook()` |
| `GET` | `/books/{id}/links/range` | `?start=&end=&targets=` | קישורים בטווח שורות, מסונן למפרשים נבחרים | `getLinksForBookRange()` |
| `POST` | `/links/content` | `{ links: [{path2, index2, targetCategoryId, targetFileType}] }` | תוכן יעד לכל קישור (batch) | `getLinkContent()` |

`targets` = רשימת שמות מפרשים לסינון (commentary/targum). אם ריק — מוחזרים גם קישורי reference/source.

### 4.4 ⭐ endpoint עמוד מאוחד (קריטי — ראה סעיף 5.1)

| Method | Path | פרמטרים | מחזיר |
|--------|------|---------|--------|
| `GET` | `/books/{id}/page` | `?start=&end=&commentators=[...]` | `{ lines[], totalLines, links[], commentaryContent{ "path2:index2": "..." } }` |

מאחד בקריאה אחת: טווח שורות + הקישורים בטווח + תוכן המפרשים המקושרים. זה ה‑endpoint שמונע מאות round‑trips בעת גלילה.

### 4.5 חיפוש

מבוסס על `lib/search/search_repository.dart` (`searchTexts` / `searchTextsAndCount`).

```
POST /search
{
  "query": "ברא אלהים",
  "facets": ["/תנ\"ך/תורה"],          // טווח חיפוש (ספרים/קטגוריות)
  "limit": 100, "offset": 0,
  "order": "relevance",                 // relevance | catalogue
  "searchMode": "exact",                // exact | fuzzy | advanced
  "distance": 0,                        // slop (מרחק מילים)
  "fuzzy": false,
  "customSpacing": null,
  "alternativeWords": null,             // Map<int, List<String>>
  "searchOptions": {                    // למצב advanced/regex
    "regex": false, "caseSensitive": false,
    "multiline": false, "dotAll": false, "unicode": true
  }
}
→ { "results": [SearchResult, ...], "totalCount": 1234 }
```

endpoints נלווים לספירת facets (לעץ הסינון):

| Method | Path | מחזיר | מקור |
|--------|------|--------|------|
| `POST` | `/search/count` | `{ totalCount }` | `countTexts()` |
| `POST` | `/search/facets` | `{ "<facet>": count, ... }` | `countByBook()` / `getFacetCounts()` (batch) |

מבנה ה‑facet: `/קטגוריה1/קטגוריה2/<מפתח-ספר>` (ראה `lib/search/book_facet.dart`).

### 4.6 גימטריה

חיפוש הגימטריה (`lib/tools/gematria/gematria_search.dart`) **אינו** עובר דרך Tantivy אלא ישירות מול ה‑DB. נדרש endpoint נפרד:

```
POST /search/gematria
{ "value": 86, "method": "regular",  // regular | small | finalLetters
  "maxPhraseWords": 4, "wholeVerseOnly": false, "kolel": false, "facets": [...] }
→ { "results": [SearchResult, ...] }
```

---

## 5. אתגרים קריטיים והחלטות תכן

### 5.1 ⚠️ Latency של מפרשים — הנקודה החשובה ביותר
מקומית, בכל טווח גלילה האפליקציה טוענת את הקישורים של השורות הנראות ואז את תוכן המפרשים — קריאות DB של מילישניות. אונליין, **כל גלילה הופכת ל‑round‑trip רשת**. ללא טיפול, הגלילה בספר עם מפרשים תהיה איטית ומקרטעת.
**פתרון:** עיצוב ה‑API סביב "עמוד" (`/books/{id}/page`, סעיף 4.4) — טווח שורות + קישורים + תוכן מפרשים בקריאה אחת. כן לשמור prefetch של העמוד הבא ו‑cache מקומי.

### 5.2 ✅ נורמליזציית טקסט בחיפוש — נפתר ע"י שיתוף קוד
האינדקס נבנה מטקסט מנוקה מניקוד (`lib/indexing/services/indexing_isolate_service.dart` — `removeVolwels`, `stripHtmlIfNeeded`, `sanitizeQuery`), וה‑query חייב לעבור את אותה נורמליזציה בדיוק. **בארכיטקטורת Dart זה מובטח by construction:** אותו קוד נורמליזציה מ‑`otzaria_core` רץ גם בבניית האינדקס וגם בשאילתות השרת. זה היה הסיכון הגבוה ביותר אילו השרת היה ב‑Node — וכאן הוא נעלם.

### 5.3 ⚠️ סנכרון גרסאות DB ↔ אינדקס
תוצאת חיפוש מצביעה על `lineIndex`/`lineId`. אם ה‑DB עודכן אך האינדקס לא נבנה מחדש (או להפך) — התוצאות יצביעו על שורות שזזו. **חובה:** לבנות מחדש את אינדקס Tantivy מאותה גרסת DB, ולחשוף `contentVersion` + `indexVersion` תואמים ב‑`/version`. הלקוח צריך לטפל בחוסר התאמה (למשל לבטל cache).

### 5.4 ספרי PDF (מחוץ ל‑MVP)
`getBookText()` מחזיר `null` ל‑PDF; ב‑PDF הטקסט מחולץ בצד הלקוח (`pdfrx`) וה‑TOC מ‑outline. בשלב ה‑MVP (טקסט בלבד) PDF מוחרג. בשלב הבא: להחליט אם להגיש קובצי PDF דרך השרת (streaming/Range), ולחלץ טקסט בצד השרת לצורך אינדוקס.

### 5.5 ספרים אישיים ותיקיות מותאמות
`user_books.db` והתיקיות המקומיות הם **תוכן של המשתמש**, לא של השרת. הם נשארים מקומיים. ה‑`ApiLibraryProvider` יתווסף לצד המקומיים ב‑`LibraryProviderManager` (ולא יחליף אותם), כך שספרים אישיים ימשיכו לעבוד.

---

## 6. אבטחה, Caching ועומס

- **תוכן ציבורי** — אין משתמשים/אימות בתוכן עצמו (כמו היום). מומלץ בכל זאת **API key בסיסי** + **rate limiting** למניעת ניצול לרעה.
- **Caching אגרסיבי:** התוכן immutable לכל גרסה. אפשר `Cache-Control` ארוך כשמפתח ה‑cache כולל את `contentVersion`, ולהציב CDN (Cloudflare) מול ה‑API. זה מוריד דרמטית את העומס על ה‑DB ועל החיפוש.
- **HTTPS** חובה.
- **Concurrency:** Dart הוא single‑threaded עם isolates. ל‑read‑only SQLite, פתיחת חיבור per‑isolate + isolate pool, או הרצת כמה instances מאחורי Cloudflare/load balancer.
- **גודל (לאימות):** `seforim.db` ~500MB–1GB; אינדקס Tantivy עשרות–מאות MB. זניח לשרת יחיד; משמעותי רק לחישוב רוחב‑פס מול CDN.

---

## 7. Stack: שרת Dart (הוכרע)

השרת ייכתב ב‑**Dart** — אותה שפה כמו האפליקציה — כדי לאפשר שיתוף קוד מלא. הבהרה: זה **לא** "שרת ב‑Flutter" (Flutter הוא שכבת ה‑UI בלבד, תלוית מסך); זה Dart standalone הרץ על VM/AOT.

**למה Dart כאן (ולא Node/Rust) — מבוסס בדיקת קוד:**
- שכבת הגישה ל‑DB כבר portable — `package:sqlite3` (FFI טהור), לא `sqflite`.
- קוד מנוע החיפוש נקי — ה‑imports היחידים הם `dart:ffi`/`dart:async`/`dart:convert` + `flutter_rust_bridge` runtime, **אפס** `package:flutter/` UI → ניתן להרצה ב‑Dart טהור.
- שיתוף מלא של מודלים, סריאליזציה, נורמליזציה ולוגיקת DAO → **ביטול סיכון הנורמליזציה** וחוזה DTO זהה.

**רכיבים:**
- **HTTP framework:** `shelf` (יציב, low‑level, פחות "קסם") או `dart_frog` (מודרני, file‑based routing).
- **DB:** `package:sqlite3` read‑only.
- **חיפוש:** fork pure‑Dart של `search_engine` — הסרת `flutter: sdk: flutter` מה‑pubspec (הקוד כבר נקי), בניית ה‑Rust ב‑`cargo build --release`, וטעינה דרך `RustLib.init(externalLibrary: ...)`.
- **Concurrency:** isolate pool / כמה instances מאחורי Cloudflare.

**תנאי מקדים קריטי:** POC שמאמת ש‑`search_engine` נטען ומחזיר תוצאות ב‑Dart טהור (ראה שלב 0 בתוכנית העבודה). אם ה‑POC נכשל — fallback: שירות Rust קטן ל‑חיפוש בלבד, בעוד שאר השרת נשאר Dart.

---

## 8. השלכות על צד הלקוח (לידיעה — לא חלק מעבודת השרת הנוכחית)

חילוץ `otzaria_core` (שלב 1 בתוכנית) משרת **גם את הלקוח**: האפליקציה תצרוך את אותו package, כך שאין כפילות קוד והתחזוקה אחת. בהמשך, צד הלקוח יצטרך:
1. **`ApiLibraryProvider`** חדש שמממש את חוזה `LibraryProvider` מול ה‑API, ומתווסף ל‑`LibraryProviderManager` לצד המקומיים.
2. **שכבת חיפוש** שמחליפה את קריאת ה‑FFI המקומית בקריאת רשת (`SearchRepository`).
3. **Cache מקומי** (עמודים/טווחים/תוצאות) ל‑UX סביר ולעבודה לסירוגין בלי רשת.
4. טיפול בכשלי רשת, מצב לא־מקוון, ואינדיקציית מקור (אונליין/מקומי).

---

## 9. הכרעות שהתקבלו ונקודות פתוחות

**הוכרע:**
- **Stack:** שרת Dart עם ליבה משותפת (`otzaria_core`).
- **חיפוש:** FFI ישיר למנוע הקיים (לא שירות נפרד).
- **היקף MVP:** טקסט בלבד; PDF בשלב הבא.
- **Hosting:** VPS + Cloudflare.

**נותר פתוח:**
1. מזהה ספר ב‑API: `bookId` בלבד, או גם תאימות ל‑`(title, categoryId, fileType)`?
2. מודל גרסאות: האם הלקוח ננעל לגרסת שרת בודדה לכל סשן, או מתמודד עם עדכון תוך כדי?
3. גודל מאגר מדויק (DB + אינדקס) — לאימות, לתכנון רוחב‑פס ועלויות.
4. **POC חיפוש pure‑Dart** — האימות הקריטי לפני התחייבות מלאה (שלב 0 בתוכנית העבודה).

---

> תוכנית העבודה המפורטת: ראה [online_server_workplan.md](online_server_workplan.md).
