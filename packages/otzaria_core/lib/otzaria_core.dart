/// otzaria_core — הליבה המשותפת ללקוח (Flutter) ולשרת (Dart).
///
/// כוללת את שכבת הגישה ל‑`seforim.db` (sqlite3 FFI טהור), ה‑DAOs,
/// מודלי ה‑DB, וטעינת שאילתות ה‑`.sq` (מוטמעות כקבוע, ללא IO בזמן ריצה).
/// אפס תלות ב‑Flutter SDK.
library;

// ── Text normalization (parity‑critical, shared client/server) ────────────
export 'src/text/text_normalization.dart';

// ── Database access ──────────────────────────────────────────────────────
export 'src/database/daos/database.dart';
export 'src/database/repository/seforim_repository.dart';
export 'src/database/sql/query_loader.dart';
export 'src/database/sql/sqlite3_utils.dart';

// ── DAOs ───────────────────────────────────────────────────────────────────
export 'src/database/daos/author_dao.dart';
export 'src/database/daos/book_acronym_dao.dart';
export 'src/database/daos/book_dao.dart';
export 'src/database/daos/book_has_links_dao.dart';
export 'src/database/daos/category_dao.dart';
export 'src/database/daos/connection_type_dao.dart';
export 'src/database/daos/generation_dao.dart';
export 'src/database/daos/line_dao.dart';
export 'src/database/daos/link_dao.dart';
export 'src/database/daos/pdf_outline_cache_dao.dart';
export 'src/database/daos/pub_date_dao.dart';
export 'src/database/daos/pub_place_dao.dart';
export 'src/database/daos/search_dao.dart';
export 'src/database/daos/toc_dao.dart';
export 'src/database/daos/toc_text_dao.dart';
export 'src/database/daos/topic_dao.dart';

// ── Models ───────────────────────────────────────────────────────────────
export 'src/models/alt_toc_entry.dart';
export 'src/models/alt_toc_structure.dart';
export 'src/models/author.dart';
export 'src/models/book.dart';
export 'src/models/category.dart';
export 'src/models/generation.dart';
export 'src/models/line.dart';
export 'src/models/link.dart';
export 'src/models/pdf_outline_cache_entry.dart';
export 'src/models/pub_date.dart';
export 'src/models/pub_place.dart';
export 'src/models/search_result.dart';
export 'src/models/source.dart';
export 'src/models/toc_entry.dart';
export 'src/models/toc_text.dart';
export 'src/models/topic.dart';
export 'src/models/types_helper.dart';
