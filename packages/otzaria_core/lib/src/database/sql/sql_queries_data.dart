// GENERATED — do not edit by hand.
// Embeds the .sq query files so the package needs no runtime asset/file IO
// (works under AOT `dart compile exe`). Regenerate with tool/gen_sql_data.dart.

const Map<String, String> kEmbeddedSqlFiles = {
  'AcronymQueries.sq': r'''
-- Queries for book acronyms (alternate names)

selectTermsByBookId:
SELECT term FROM book_acronym
WHERE bookId = ?
ORDER BY term;

selectByBookId:
SELECT * FROM book_acronym
WHERE bookId = ?
ORDER BY term;

selectBookIdsByTerm:
SELECT bookId FROM book_acronym
WHERE term = ?
ORDER BY bookId;

selectBookIdsByTermLike:
SELECT DISTINCT bookId FROM book_acronym
WHERE term LIKE ?
ORDER BY bookId
LIMIT ?;

insert:
INSERT INTO book_acronym (bookId, term)
VALUES (?, ?)
ON CONFLICT(bookId, term) DO NOTHING;

deleteByBookId:
DELETE FROM book_acronym WHERE bookId = ?;

countByBookId:
SELECT COUNT(*) FROM book_acronym WHERE bookId = ?;
''',
  'AuthorQueries.sq': r'''
-- Queries for authors

selectAll:
SELECT * FROM author ORDER BY name;

selectById:
SELECT * FROM author WHERE id = ?;

selectByName:
SELECT * FROM author WHERE name = ? LIMIT 1;

selectByBookId:
SELECT a.* FROM author a
JOIN book_author ba ON a.id = ba.authorId
WHERE ba.bookId = ?
ORDER BY a.name;

insert:
INSERT INTO author (name)
VALUES (?)
ON CONFLICT (name) DO NOTHING;

insertAndGetId:
INSERT OR IGNORE INTO author (name)
VALUES (?);

selectIdByName:
SELECT id FROM author WHERE name = ? LIMIT 1;

delete:
DELETE FROM author WHERE id = ?;

countAll:
SELECT COUNT(*) FROM author;

lastInsertRowId:
SELECT last_insert_rowid();

-- Queries for the book_author junction table

linkBookAuthor:
INSERT INTO book_author (bookId, authorId)
VALUES (?, ?)
ON CONFLICT (bookId, authorId) DO NOTHING;

unlinkBookAuthor:
DELETE FROM book_author WHERE bookId = ? AND authorId = ?;

deleteAllBookAuthors:
DELETE FROM book_author WHERE bookId = ?;

countBookAuthors:
SELECT COUNT(*) FROM book_author WHERE bookId = ?;

selectAllBookTitleToGeneration:
SELECT b.title, GROUP_CONCAT(DISTINCT g.name) as generationName
FROM book b
JOIN book_author ba ON b.id = ba.bookId
JOIN author a ON ba.authorId = a.id
JOIN generation g ON a.generationId = g.id
WHERE g.name IS NOT NULL
GROUP BY b.title;
''',
  'BookHasLinksQueries.sq': r'''
-- Queries for the book_has_links table

-- Get link status for a book
selectByBookId:
SELECT bookId, hasSourceLinks, hasTargetLinks
FROM book_has_links
WHERE bookId = ?;

-- Get all books that have source links
selectBooksWithSourceLinks:
SELECT b.*
FROM book b
JOIN book_has_links bhl ON b.id = bhl.bookId
WHERE bhl.hasSourceLinks = 1
  AND COALESCE(b.fileType, '') NOT IN ('link', 'url');

-- Get all books that have target links
selectBooksWithTargetLinks:
SELECT b.*
FROM book b
JOIN book_has_links bhl ON b.id = bhl.bookId
WHERE bhl.hasTargetLinks = 1
  AND COALESCE(b.fileType, '') NOT IN ('link', 'url');

-- Get all books that have any links (source or target)
selectBooksWithAnyLinks:
SELECT b.*
FROM book b
JOIN book_has_links bhl ON b.id = bhl.bookId
WHERE (bhl.hasSourceLinks = 1 OR bhl.hasTargetLinks = 1)
  AND COALESCE(b.fileType, '') NOT IN ('link', 'url');

-- Count books with source links
countBooksWithSourceLinks:
SELECT COUNT(*)
FROM book_has_links
WHERE hasSourceLinks = 1;

-- Count books with target links
countBooksWithTargetLinks:
SELECT COUNT(*)
FROM book_has_links
WHERE hasTargetLinks = 1;

-- Count books with any links (source or target)
countBooksWithAnyLinks:
SELECT COUNT(*)
FROM book_has_links
WHERE hasSourceLinks = 1 OR hasTargetLinks = 1;

-- Insert or update a book's link status
upsert:
INSERT OR REPLACE INTO book_has_links (bookId, hasSourceLinks, hasTargetLinks)
VALUES (?, ?, ?);

-- Update a book's source link status
updateSourceLinks:
UPDATE book_has_links
SET hasSourceLinks = ?
WHERE bookId = ?;

-- Update a book's target link status
updateTargetLinks:
UPDATE book_has_links
SET hasTargetLinks = ?
WHERE bookId = ?;

-- Update both source and target link status
updateBothLinkTypes:
UPDATE book_has_links
SET hasSourceLinks = ?,
    hasTargetLinks = ?
WHERE bookId = ?;

-- Insert a new book link status
insert:
INSERT INTO book_has_links (bookId, hasSourceLinks, hasTargetLinks)
VALUES (?, ?, ?);

-- Delete a book's link status
delete:
DELETE FROM book_has_links
WHERE bookId = ?;

-- Get the last inserted row ID
lastInsertRowId:
SELECT last_insert_rowid();
''',
  'BookQueries.sq': r'''
-- Queries for books

selectAll:
SELECT * FROM book ORDER BY orderIndex, title;

selectAllIgnoreExternalCatalogs:
SELECT *
FROM book
WHERE COALESCE(fileType, '') NOT IN ('link', 'url')
ORDER BY orderIndex, title;



selectById:
SELECT * FROM book WHERE id = ?;

selectByCategoryId:
SELECT * FROM book WHERE categoryId = ? AND COALESCE(fileType, '') NOT IN ('link', 'url') ORDER BY orderIndex, title;

-- Select all books whose category is a descendant of the given ancestor category
selectByAncestorCategory:
SELECT b.* FROM book b
WHERE b.categoryId IN (SELECT descendantId FROM category_closure WHERE ancestorId = ?)
  AND COALESCE(b.fileType, '') NOT IN ('link', 'url')
ORDER BY b.orderIndex, b.title;

selectByTitle:
SELECT * FROM book WHERE title = ? AND COALESCE(fileType, '') NOT IN ('link', 'url') LIMIT 1;

selectByTitleAndCategory:
SELECT * FROM book WHERE title = ? AND categoryId = ? AND COALESCE(fileType, '') NOT IN ('link', 'url') LIMIT 1;

selectByTitleCategoryAndFileType:
SELECT * FROM book WHERE title = ? AND categoryId = ? AND fileType = ? LIMIT 1;

selectByTitleAndFileType:
SELECT * FROM book WHERE title = ? AND fileType = ? LIMIT 1;

selectByTitleLike:
SELECT * FROM book WHERE title LIKE ? AND COALESCE(fileType, '') NOT IN ('link', 'url') LIMIT 1;

selectManyByTitleLike:
SELECT * FROM book WHERE title LIKE ? AND COALESCE(fileType, '') NOT IN ('link', 'url') ORDER BY orderIndex, title LIMIT ?;


selectByAuthor:
SELECT b.* FROM book b
JOIN book_author ba ON b.id = ba.bookId
JOIN author a ON ba.authorId = a.id
WHERE a.name LIKE ?
  AND COALESCE(b.fileType, '') NOT IN ('link', 'url')
ORDER BY b.orderIndex, b.title;

-- Base-books helpers
selectBaseIds:
SELECT id FROM book WHERE isBaseBook = 1 ORDER BY orderIndex, title;

insert:
INSERT INTO book (categoryId, sourceId, title, heShortDesc, orderIndex, totalLines, isBaseBook,
    hasTargumConnection, hasReferenceConnection, hasSourceConnection, hasCommentaryConnection, hasOtherConnection,
    hasAltStructures, hasTeamim, hasNekudot, isPersonal, filePath, fileType, fileSize, lastModified, pages, volume)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Insert external content book (content stored externally, metadata in DB)
insertExternalContent:
INSERT INTO book (categoryId, sourceId, title, heShortDesc, orderIndex, isPersonal, filePath, fileType, fileSize, lastModified)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- Update external book metadata
updateExternalMetadata:
UPDATE book SET fileSize = ?, lastModified = ? WHERE id = ?;

-- Select external content books only
selectExternalContent:
SELECT * FROM book WHERE filePath IS NOT NULL ORDER BY orderIndex, title;

-- Select personal books only
selectPersonal:
SELECT * FROM book WHERE isPersonal = 1 ORDER BY orderIndex, title;

-- Select external book by file path
selectByFilePath:
SELECT * FROM book WHERE filePath = ? LIMIT 1;

-- Select external book by file path and file type
selectByFilePathAndType:
SELECT * FROM book WHERE filePath = ? AND fileType = ? LIMIT 1;

updateTotalLines:
UPDATE book SET totalLines = ? WHERE id = ?;

delete:
DELETE FROM book WHERE id = ?;

countByCategoryId:
SELECT COUNT(*) FROM book WHERE categoryId = ?;

countAll:
SELECT COUNT(*) FROM book WHERE COALESCE(fileType, '') NOT IN ('link', 'url');

getMaxId:
SELECT MAX(id) FROM book;

updateCategoryId:
UPDATE book SET categoryId = ? WHERE id = ?;

-- Update connection flags on book
updateConnectionFlags:
UPDATE book SET 
    hasTargumConnection = ?,
    hasReferenceConnection = ?,
    hasSourceConnection = ?,
    hasCommentaryConnection = ?,
    hasOtherConnection = ?
WHERE id = ?;

-- Update alt structures flag
updateAltStructuresFlag:
UPDATE book SET hasAltStructures = ? WHERE id = ?;

-- Update teamim flag
updateTeamimFlag:
UPDATE book SET hasTeamim = ? WHERE id = ?;

-- Update nekudot flag
updateNekudotFlag:
UPDATE book SET hasNekudot = ? WHERE id = ?;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'CategoryClosureQueries.sq': r'''
-- Queries for the category_closure table

clear:
DELETE FROM category_closure;

insert:
INSERT OR IGNORE INTO category_closure(ancestorId, descendantId) VALUES(?, ?);

selectDescendants:
SELECT descendantId FROM category_closure WHERE ancestorId = ?;

selectAncestors:
SELECT ancestorId FROM category_closure WHERE descendantId = ?;

countAncestorsByDescendant:
SELECT COUNT(*) FROM category_closure WHERE descendantId = ?;
''',
  'CategoryQueries.sq': r'''
-- Queries for categories

selectAll:
SELECT * FROM category ORDER BY orderIndex, title;

selectById:
SELECT * FROM category WHERE id = ?;

selectByParentId:
SELECT * FROM category WHERE parentId = ? ORDER BY orderIndex, title;

selectRoot:
SELECT * FROM category WHERE parentId IS NULL ORDER BY orderIndex, title;

selectByTitle:
SELECT * FROM category WHERE title = ? LIMIT 1;

selectByTitleAndParent:
SELECT * FROM category WHERE title = ? AND (parentId = ? OR (parentId IS NULL AND ? IS NULL)) LIMIT 1;

selectByTitleLike:
SELECT * FROM category WHERE title LIKE ? ORDER BY level ASC, orderIndex, title LIMIT 1;

selectManyByTitleLike:
SELECT * FROM category WHERE title LIKE ? ORDER BY level ASC, orderIndex, title LIMIT ?;

insert:
INSERT INTO category (parentId, title, level, orderIndex)
VALUES (?, ?, ?, ?);

update:
UPDATE category SET
    title = ?,
    orderIndex = ?
WHERE id = ?;

updateOrderIndex:
UPDATE category SET orderIndex = ? WHERE id = ?;

delete:
DELETE FROM category WHERE id = ?;

countAll:
SELECT COUNT(*) FROM category;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'ConnectionTypeQueries.sq': r'''
-- Queries for connection types

selectById:
SELECT * FROM connection_type WHERE id = ?;

selectByName:
SELECT * FROM connection_type WHERE name = ?;

selectAll:
SELECT * FROM connection_type ORDER BY name;

insert:
INSERT INTO connection_type (name)
VALUES (?);

update:
UPDATE connection_type
SET name = ?
WHERE id = ?;

delete:
DELETE FROM connection_type WHERE id = ?;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'Database.sq': r'''
-- Categories table
CREATE TABLE IF NOT EXISTS category (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parentId INTEGER,
    title TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 0,
    orderIndex INTEGER NOT NULL DEFAULT 999,
    FOREIGN KEY (parentId) REFERENCES category(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_category_parent ON category(parentId);
CREATE INDEX IF NOT EXISTS idx_category_order ON category(orderIndex);

-- Closure table for efficient descendant/ancestor lookups
CREATE TABLE IF NOT EXISTS category_closure (
    ancestorId INTEGER NOT NULL,
    descendantId INTEGER NOT NULL,
    PRIMARY KEY (ancestorId, descendantId),
    FOREIGN KEY (ancestorId) REFERENCES category(id) ON DELETE CASCADE,
    FOREIGN KEY (descendantId) REFERENCES category(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_category_closure_ancestor ON category_closure(ancestorId);
CREATE INDEX IF NOT EXISTS idx_category_closure_descendant ON category_closure(descendantId);

-- Generations table
CREATE TABLE IF NOT EXISTS generation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    startYear INTEGER,
    endYear INTEGER,
    parentGenerationId INTEGER,
    FOREIGN KEY (parentGenerationId) REFERENCES generation(id),
    CHECK (startYear IS NULL OR endYear IS NULL OR startYear <= endYear)
);

CREATE INDEX IF NOT EXISTS idx_generation_name ON generation(name);
CREATE INDEX IF NOT EXISTS idx_generation_start_year ON generation(startYear);
CREATE INDEX IF NOT EXISTS idx_generation_end_year ON generation(endYear);
CREATE INDEX IF NOT EXISTS idx_generation_parent ON generation(parentGenerationId);

-- Authors table
CREATE TABLE IF NOT EXISTS author (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    generationId INTEGER,
    FOREIGN KEY (generationId) REFERENCES generation(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_author_name ON author(name);
CREATE INDEX IF NOT EXISTS idx_author_generation ON author(generationId);

-- Table des topics
CREATE TABLE IF NOT EXISTS topic (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_topic_name ON topic(name);

-- Publication places table
CREATE TABLE IF NOT EXISTS pub_place (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_pub_place_name ON pub_place(name);

-- Publication dates table
CREATE TABLE IF NOT EXISTS pub_date (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_pub_date_date ON pub_date(date);

-- Sources table (origin of each book)
CREATE TABLE IF NOT EXISTS source (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_source_name ON source(name);

-- Books table
CREATE TABLE IF NOT EXISTS book (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    categoryId INTEGER NOT NULL,
    sourceId INTEGER NOT NULL,
    title TEXT NOT NULL,
    heShortDesc TEXT,
    orderIndex INTEGER NOT NULL DEFAULT 999,
    totalLines INTEGER NOT NULL DEFAULT 0,
    isBaseBook INTEGER NOT NULL DEFAULT 0,
    hasTargumConnection INTEGER NOT NULL DEFAULT 0,
    hasReferenceConnection INTEGER NOT NULL DEFAULT 0,
    hasSourceConnection INTEGER NOT NULL DEFAULT 0,
    hasCommentaryConnection INTEGER NOT NULL DEFAULT 0,
    hasOtherConnection INTEGER NOT NULL DEFAULT 0,
    hasAltStructures INTEGER NOT NULL DEFAULT 0,
    hasTeamim INTEGER NOT NULL DEFAULT 0,
    hasNekudot INTEGER NOT NULL DEFAULT 0,
    isContentExternal INTEGER DEFAULT 0,
    externalLibraryId TEXT DEFAULT NULL,
    isPersonal INTEGER DEFAULT 0,
    filePath TEXT DEFAULT NULL,
    fileType TEXT DEFAULT 'txt',
    fileSize INTEGER DEFAULT NULL,
    lastModified INTEGER DEFAULT NULL,
    pages INTEGER DEFAULT NULL,
    volume TEXT DEFAULT NULL,
    FOREIGN KEY (categoryId) REFERENCES category(id) ON DELETE CASCADE,
    FOREIGN KEY (sourceId) REFERENCES source(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_book_category ON book(categoryId);
CREATE INDEX IF NOT EXISTS idx_book_title ON book(title);
CREATE INDEX IF NOT EXISTS idx_book_order ON book(orderIndex);
CREATE INDEX IF NOT EXISTS idx_book_source ON book(sourceId);

-- Book-publication place junction table
CREATE TABLE IF NOT EXISTS book_pub_place (
    bookId INTEGER NOT NULL,
    pubPlaceId INTEGER NOT NULL,
    PRIMARY KEY (bookId, pubPlaceId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (pubPlaceId) REFERENCES pub_place(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_book_pub_place_book ON book_pub_place(bookId);
CREATE INDEX IF NOT EXISTS idx_book_pub_place_place ON book_pub_place(pubPlaceId);

-- Book-publication date junction table
CREATE TABLE IF NOT EXISTS book_pub_date (
    bookId INTEGER NOT NULL,
    pubDateId INTEGER NOT NULL,
    PRIMARY KEY (bookId, pubDateId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (pubDateId) REFERENCES pub_date(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_book_pub_date_book ON book_pub_date(bookId);
CREATE INDEX IF NOT EXISTS idx_book_pub_date_date ON book_pub_date(pubDateId);

-- Book-topic junction table
CREATE TABLE IF NOT EXISTS book_topic (
    bookId INTEGER NOT NULL,
    topicId INTEGER NOT NULL,
    PRIMARY KEY (bookId, topicId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (topicId) REFERENCES topic(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_book_topic_book ON book_topic(bookId);
CREATE INDEX IF NOT EXISTS idx_book_topic_topic ON book_topic(topicId);

-- Book-author junction table
CREATE TABLE IF NOT EXISTS book_author (
    bookId INTEGER NOT NULL,
    authorId INTEGER NOT NULL,
    PRIMARY KEY (bookId, authorId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (authorId) REFERENCES author(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_book_author_book ON book_author(bookId);
CREATE INDEX IF NOT EXISTS idx_book_author_author ON book_author(authorId);

-- Lines table
CREATE TABLE IF NOT EXISTS line (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bookId INTEGER NOT NULL,
    lineIndex INTEGER NOT NULL,
    content TEXT NOT NULL,
    heRef TEXT,
    tocEntryId INTEGER,
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (tocEntryId) REFERENCES tocEntry(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_line_book_index ON line(bookId, lineIndex);
CREATE INDEX IF NOT EXISTS idx_line_toc ON line(tocEntryId);
CREATE INDEX IF NOT EXISTS idx_line_heref ON line(heRef);

-- TOC texts table
CREATE TABLE IF NOT EXISTS tocText (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_toc_text ON tocText(text);
CREATE INDEX IF NOT EXISTS idx_toctext_text_length ON tocText(text, length(text));

-- TOC entries table
CREATE TABLE IF NOT EXISTS tocEntry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bookId INTEGER NOT NULL,
    parentId INTEGER,
    textId INTEGER NOT NULL,
    level INTEGER NOT NULL,
    lineId INTEGER,
    lineIndex INTEGER,
    isLastChild INTEGER NOT NULL DEFAULT 0,
    hasChildren INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (parentId) REFERENCES tocEntry(id) ON DELETE CASCADE,
    FOREIGN KEY (textId) REFERENCES tocText(id) ON DELETE CASCADE,
    FOREIGN KEY (lineId) REFERENCES line(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_toc_book ON tocEntry(bookId);
CREATE INDEX IF NOT EXISTS idx_toc_parent ON tocEntry(parentId);
CREATE INDEX IF NOT EXISTS idx_toc_text_id ON tocEntry(textId);
CREATE INDEX IF NOT EXISTS idx_toc_line ON tocEntry(lineId);
CREATE INDEX IF NOT EXISTS idx_tocentry_text_level ON tocEntry(textId, level);
CREATE INDEX IF NOT EXISTS idx_tocentry_level_book ON tocEntry(level, bookId);

-- Connection types table
CREATE TABLE IF NOT EXISTS connection_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

-- DB meta table
CREATE TABLE IF NOT EXISTS db_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_connection_type_name ON connection_type(name);
CREATE INDEX IF NOT EXISTS idx_db_meta_key ON db_meta(key);

CREATE TABLE IF NOT EXISTS pdf_outline_cache (
    filePath TEXT PRIMARY KEY,
    fileSize INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    outlineJson TEXT NOT NULL,
    createdAt INTEGER NOT NULL,
    accessedAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pdf_outline_cache_accessed_at ON pdf_outline_cache(accessedAt);

-- Links table
CREATE TABLE IF NOT EXISTS link (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sourceBookId INTEGER NOT NULL,
    targetBookId INTEGER NOT NULL,
    sourceLineId INTEGER NOT NULL,
    targetLineId INTEGER NOT NULL,
    connectionTypeId INTEGER NOT NULL,
    FOREIGN KEY (sourceBookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (targetBookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (sourceLineId) REFERENCES line(id) ON DELETE CASCADE,
    FOREIGN KEY (targetLineId) REFERENCES line(id) ON DELETE CASCADE,
    FOREIGN KEY (connectionTypeId) REFERENCES connection_type(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_link_source_book ON link(sourceBookId);
CREATE INDEX IF NOT EXISTS idx_link_source_line ON link(sourceLineId);
CREATE INDEX IF NOT EXISTS idx_link_target_book ON link(targetBookId);
CREATE INDEX IF NOT EXISTS idx_link_target_line ON link(targetLineId);
CREATE INDEX IF NOT EXISTS idx_link_type ON link(connectionTypeId);
CREATE INDEX IF NOT EXISTS idx_link_type_source_line ON link(connectionTypeId, sourceLineId);

-- Removed legacy FTS view/table in favor of Lucene (10.x)

-- Table to track whether books have links (as source or target)
CREATE TABLE IF NOT EXISTS book_has_links (
    bookId INTEGER PRIMARY KEY,
    hasSourceLinks INTEGER NOT NULL DEFAULT 0, -- 0 = false, 1 = true
    hasTargetLinks INTEGER NOT NULL DEFAULT 0, -- 0 = false, 1 = true
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_book_has_source_links ON book_has_links(hasSourceLinks);
CREATE INDEX IF NOT EXISTS idx_book_has_target_links ON book_has_links(hasTargetLinks);

-- Mapping table: line -> owning TOC entry
-- This denormalizes the relationship so every line can directly resolve
-- the TOC entry it belongs to (the latest heading before or at the line).
CREATE TABLE IF NOT EXISTS line_toc (
    lineId INTEGER PRIMARY KEY,
    tocEntryId INTEGER NOT NULL,
    FOREIGN KEY (lineId) REFERENCES line(id) ON DELETE CASCADE,
    FOREIGN KEY (tocEntryId) REFERENCES tocEntry(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_linetoc_toc ON line_toc(tocEntryId);

-- Alternative TOC structures (e.g., Parasha/Aliyah)
CREATE TABLE IF NOT EXISTS alt_toc_structure (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bookId INTEGER NOT NULL,
    -- Stable key for the structure (e.g., "Parasha")
    key TEXT NOT NULL,
    title TEXT,
    heTitle TEXT,
    UNIQUE (bookId, key),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_alt_toc_structure_book ON alt_toc_structure(bookId);
CREATE INDEX IF NOT EXISTS idx_alt_toc_structure_key ON alt_toc_structure(key);

CREATE TABLE IF NOT EXISTS alt_toc_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    structureId INTEGER NOT NULL,
    parentId INTEGER,
    textId INTEGER NOT NULL,
    level INTEGER NOT NULL,
    lineId INTEGER,
    isLastChild INTEGER NOT NULL DEFAULT 0,
    hasChildren INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (structureId) REFERENCES alt_toc_structure(id) ON DELETE CASCADE,
    FOREIGN KEY (parentId) REFERENCES alt_toc_entry(id) ON DELETE CASCADE,
    FOREIGN KEY (textId) REFERENCES tocText(id) ON DELETE CASCADE,
    FOREIGN KEY (lineId) REFERENCES line(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_alt_toc_entry_structure ON alt_toc_entry(structureId);
CREATE INDEX IF NOT EXISTS idx_alt_toc_entry_parent ON alt_toc_entry(parentId);
CREATE INDEX IF NOT EXISTS idx_alt_toc_entry_text ON alt_toc_entry(textId);
CREATE INDEX IF NOT EXISTS idx_alt_toc_entry_line ON alt_toc_entry(lineId);

-- Mapping table: line -> alternative TOC entry (per structure)
CREATE TABLE IF NOT EXISTS line_alt_toc (
    lineId INTEGER NOT NULL,
    structureId INTEGER NOT NULL,
    altTocEntryId INTEGER NOT NULL,
    PRIMARY KEY (lineId, structureId),
    FOREIGN KEY (lineId) REFERENCES line(id) ON DELETE CASCADE,
    FOREIGN KEY (structureId) REFERENCES alt_toc_structure(id) ON DELETE CASCADE,
    FOREIGN KEY (altTocEntryId) REFERENCES alt_toc_entry(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_line_alt_toc_entry ON line_alt_toc(altTocEntryId);
CREATE INDEX IF NOT EXISTS idx_line_alt_toc_structure ON line_alt_toc(structureId);

-- Book acronyms table: stores alternate names/abbreviations per book
-- One row per (bookId, term) pair for efficient lookup
CREATE TABLE IF NOT EXISTS book_acronym (
    bookId INTEGER NOT NULL,
    term TEXT NOT NULL,
    PRIMARY KEY (bookId, term),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE
);

-- Index to quickly find books by acronym term
CREATE INDEX IF NOT EXISTS idx_book_acronym_term ON book_acronym(term);

-- Default commentators table: stores per-book default commentator selections
CREATE TABLE IF NOT EXISTS default_commentator (
    bookId INTEGER NOT NULL,
    commentatorBookId INTEGER NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (bookId, commentatorBookId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (commentatorBookId) REFERENCES book(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_default_commentator_book ON default_commentator(bookId);
CREATE INDEX IF NOT EXISTS idx_default_commentator_commentator ON default_commentator(commentatorBookId);

-- Default targum table: stores per-book default targum selections
CREATE TABLE IF NOT EXISTS default_targum (
    bookId INTEGER NOT NULL,
    targumBookId INTEGER NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (bookId, targumBookId),
    FOREIGN KEY (bookId) REFERENCES book(id) ON DELETE CASCADE,
    FOREIGN KEY (targumBookId) REFERENCES book(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_default_targum_book ON default_targum(bookId);
CREATE INDEX IF NOT EXISTS idx_default_targum_target ON default_targum(targumBookId);
''',
  'GenerationQueries.sq': r'''
-- Queries for generation (read-only)

selectAll:
SELECT * FROM generation ORDER BY name;

selectById:
SELECT * FROM generation WHERE id = ? LIMIT 1;

selectByName:
SELECT * FROM generation WHERE name = ? LIMIT 1;

selectChildren:
SELECT * FROM generation WHERE parentGenerationId = ? ORDER BY name;
''',
  'LineQueries.sq': r'''
-- Queries for lines

selectById:
SELECT * FROM line WHERE id = ?;

selectByBookId:
SELECT * FROM line WHERE bookId = ? ORDER BY lineIndex;

selectByBookIdRange:
SELECT * FROM line
WHERE bookId = ?
AND lineIndex >= ?
AND lineIndex <= ?
ORDER BY lineIndex;

selectByBookIdAndIndex:
SELECT * FROM line WHERE bookId = ? AND lineIndex = ?;

selectByHeRef:
SELECT * FROM line WHERE heRef = ? LIMIT 1;

selectByHeRefLike:
SELECT * FROM line WHERE heRef LIKE ? ORDER BY bookId, lineIndex LIMIT ?;

insert:
INSERT INTO line (bookId, lineIndex, content, heRef, tocEntryId)
VALUES (?, ?, ?, ?, ?);

updateTocEntryId:
UPDATE line SET tocEntryId = ? WHERE id = ?;

updateHeRef:
UPDATE line SET heRef = ? WHERE id = ?;

delete:
DELETE FROM line WHERE id = ?;

deleteByBookId:
DELETE FROM line WHERE bookId = ?;

countByBookId:
SELECT COUNT(*) FROM line WHERE bookId = ?;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'LineTocQueries.sq': r'''
-- Queries for mapping lines to their owning TOC entries

selectByLineId:
SELECT * FROM line_toc WHERE lineId = ?;

selectTocEntryIdByLineId:
SELECT tocEntryId FROM line_toc WHERE lineId = ?;

selectByBookId:
SELECT lt.lineId, lt.tocEntryId
FROM line_toc lt
JOIN line l ON l.id = lt.lineId
WHERE l.bookId = ?
ORDER BY l.lineIndex;

selectLineIdsByTocEntryId:
SELECT l.id
FROM line l
JOIN line_toc lt ON lt.lineId = l.id
WHERE lt.tocEntryId = ?
ORDER BY l.lineIndex;

insert:
INSERT INTO line_toc (lineId, tocEntryId)
VALUES (?, ?);

upsert:
INSERT INTO line_toc (lineId, tocEntryId)
VALUES (?, ?)
ON CONFLICT(lineId) DO UPDATE SET tocEntryId = excluded.tocEntryId;

deleteByLineId:
DELETE FROM line_toc WHERE lineId = ?;

deleteByBookId:
DELETE FROM line_toc WHERE lineId IN (
    SELECT l.id FROM line l WHERE l.bookId = ?
);
''',
  'LinkQueries.sq': r'''
-- Queries for links

selectLinkById:
SELECT l.*, ct.name AS connectionType
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
WHERE l.id = ?;

countAllLinks:
SELECT COUNT(*) FROM link;

selectLinksBySourceLineIds:
SELECT l.*, ct.name AS connectionType, b.title AS targetBookTitle, tl.content AS targetText
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
JOIN book b ON l.targetBookId = b.id
JOIN line tl ON l.targetLineId = tl.id
WHERE l.sourceLineId IN (?)
ORDER BY b.orderIndex;

selectLinksBySourceBook:
SELECT l.*, ct.name AS connectionType
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
WHERE l.sourceBookId = ?;

selectCommentatorsByBook:
SELECT DISTINCT l.targetBookId, b.title AS targetBookTitle, a.name AS author, COUNT(*) AS linkCount
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
JOIN book b ON l.targetBookId = b.id
LEFT JOIN book_author ba ON b.id = ba.bookId
LEFT JOIN author a ON ba.authorId = a.id
WHERE l.sourceBookId = ?
AND ct.name IN ('COMMENTARY', 'TARGUM')
GROUP BY l.targetBookId, b.title, a.name
ORDER BY b.orderIndex, b.title;

-- מחזיר את כל המפרשים על **טווח** שורות מקור (מ-startLineIndex ועד
-- endLineIndex, לא כולל), עם `targetLineIndex` (=MIN(tl.lineIndex)) — השורה
-- הראשונה בספר המפרש על פני כל הטווח. כך אפשר לאסוף את כל מפרשי הקטע
-- (כותרת ועד הכותרת הבאה) ולפתוח כל מפרש במיקום המקביל הראשון שלו.
--
-- הטווח מסונן לפי `sl.lineIndex` של שורת המקור (לא לפי id), כדי להתיישר עם
-- ה-`segment` של ערכי ה-TOC (=`line.lineIndex`). אינדקס `idx_line_book_index`
-- על `line(bookId, lineIndex)` משרת את הסינון.
-- פרמטרים: (sourceBookId, startLineIndex, endLineIndex).
selectCommentatorsByLineRange:
SELECT l.targetBookId, b.title AS targetBookTitle, a.name AS author,
       COUNT(*) AS linkCount, MIN(tl.lineIndex) AS targetLineIndex
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
JOIN book b ON l.targetBookId = b.id
JOIN line sl ON l.sourceLineId = sl.id
JOIN line tl ON l.targetLineId = tl.id
LEFT JOIN book_author ba ON b.id = ba.bookId
LEFT JOIN author a ON ba.authorId = a.id
WHERE l.sourceBookId = ?
AND ct.name IN ('COMMENTARY', 'TARGUM')
AND sl.lineIndex >= ?
AND sl.lineIndex < ?
GROUP BY l.targetBookId, b.title, a.name
ORDER BY b.orderIndex, b.title;

insert:
INSERT INTO link (sourceBookId, targetBookId, sourceLineId, targetLineId, connectionTypeId)
VALUES (?, ?, ?, ?, ?);

delete:
DELETE FROM link WHERE id = ?;

deleteByBookId:
DELETE FROM link WHERE sourceBookId = ? OR targetBookId = ?;

lastInsertRowId:
SELECT last_insert_rowid();

-- Count links by source book
countLinksBySourceBook:
SELECT COUNT(*) FROM link WHERE sourceBookId = ?;

-- Count links by target book
countLinksByTargetBook:
SELECT COUNT(*) FROM link WHERE targetBookId = ?;

-- Count links by source book and connection type
countLinksBySourceBookAndType:
SELECT COUNT(*)
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
WHERE l.sourceBookId = ? AND ct.name = ?;

-- Count links by target book and connection type
countLinksByTargetBookAndType:
SELECT COUNT(*)
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
WHERE l.targetBookId = ? AND ct.name = ?;
''',
  'PdfOutlineCacheQueries.sq': r'''
-- Queries for persistent cache of external PDF outlines

selectByFilePath:
SELECT *
FROM pdf_outline_cache
WHERE filePath = ?
LIMIT 1;

selectAllFilePaths:
SELECT filePath
FROM pdf_outline_cache;

upsert:
INSERT INTO pdf_outline_cache (
  filePath,
  fileSize,
  lastModified,
  outlineJson,
  createdAt,
  accessedAt
)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(filePath) DO UPDATE SET
  fileSize = excluded.fileSize,
  lastModified = excluded.lastModified,
  outlineJson = excluded.outlineJson,
  createdAt = excluded.createdAt,
  accessedAt = excluded.accessedAt;

updateAccessedAt:
UPDATE pdf_outline_cache
SET accessedAt = ?
WHERE filePath = ?;

deleteByFilePath:
DELETE FROM pdf_outline_cache
WHERE filePath = ?;

deleteAccessedBefore:
DELETE FROM pdf_outline_cache
WHERE accessedAt < ?;
''',
  'PubDateQueries.sq': r'''
-- Queries for publication dates

selectAll:
SELECT * FROM pub_date ORDER BY date;

selectById:
SELECT * FROM pub_date WHERE id = ?;

selectByDate:
SELECT * FROM pub_date WHERE date = ? LIMIT 1;

selectByBookId:
SELECT p.* FROM pub_date p
JOIN book_pub_date bp ON p.id = bp.pubDateId
WHERE bp.bookId = ?;

insert:
INSERT INTO pub_date (date)
VALUES (?)
ON CONFLICT (date) DO NOTHING;

linkBookPubDate:
INSERT INTO book_pub_date (bookId, pubDateId)
VALUES (?, ?)
ON CONFLICT (bookId, pubDateId) DO NOTHING;

delete:
DELETE FROM pub_date WHERE id = ?;

countAll:
SELECT COUNT(*) FROM pub_date;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'PubPlaceQueries.sq': r'''
-- Queries for publication places

selectAll:
SELECT * FROM pub_place ORDER BY name;

selectById:
SELECT * FROM pub_place WHERE id = ?;

selectByName:
SELECT * FROM pub_place WHERE name = ? LIMIT 1;

selectByBookId:
SELECT p.* FROM pub_place p
JOIN book_pub_place bp ON p.id = bp.pubPlaceId
WHERE bp.bookId = ?;

insert:
INSERT INTO pub_place (name)
VALUES (?)
ON CONFLICT (name) DO NOTHING;

linkBookPubPlace:
INSERT INTO book_pub_place (bookId, pubPlaceId)
VALUES (?, ?)
ON CONFLICT (bookId, pubPlaceId) DO NOTHING;

delete:
DELETE FROM pub_place WHERE id = ?;

countAll:
SELECT COUNT(*) FROM pub_place;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'SearchQueries.sq': r'''
-- Search queries for full-text search functionality
-- Note: FTS5 has been removed from the schema, Lucene is used instead

searchAll:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
WHERE l.content LIKE '%' || ? || '%'
ORDER BY b.title, l.lineIndex
LIMIT ? OFFSET ?;

searchInBook:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
WHERE l.content LIKE '%' || ? || '%'
    AND b.id = ?
ORDER BY l.lineIndex
LIMIT ? OFFSET ?;

searchByAuthor:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
INNER JOIN book_author ba ON b.id = ba.bookId
INNER JOIN author a ON ba.authorId = a.id
WHERE l.content LIKE '%' || ? || '%'
    AND a.name LIKE '%' || ? || '%'
ORDER BY b.title, l.lineIndex
LIMIT ? OFFSET ?;

searchWithBookFilter:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
WHERE l.content LIKE '%' || ? || '%'
    AND b.title LIKE '%' || ? || '%'
ORDER BY b.title, l.lineIndex
LIMIT ? OFFSET ?;

searchExactPhrase:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
WHERE l.content LIKE '%' || ? || '%'
ORDER BY b.title, l.lineIndex
LIMIT ? OFFSET ?;

searchWithOperators:
SELECT 
    l.id,
    l.lineIndex,
    l.content as snippet,
    b.id as bookId,
    b.title as bookTitle,
    1.0 as rank
FROM line l
INNER JOIN book b ON l.bookId = b.id
WHERE l.content LIKE '%' || ? || '%'
ORDER BY b.title, l.lineIndex
LIMIT ? OFFSET ?;

countSearchResults:
SELECT COUNT(*) as count
FROM line l
WHERE l.content LIKE '%' || ? || '%';

countSearchResultsInBook:
SELECT COUNT(*) as count
FROM line l
WHERE l.content LIKE '%' || ? || '%'
    AND l.bookId = ?;

rebuildFts5Index:
SELECT 1;
''',
  'SourceQueries.sq': r'''
-- Source queries

selectAll:
SELECT * FROM source ORDER BY name;

selectById:
SELECT * FROM source WHERE id = ?;

selectByName:
SELECT * FROM source WHERE name = ? LIMIT 1;

insert:
INSERT INTO source (name) VALUES (?);

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'TocQueries.sq': r'''
-- TocQueries.sq
-- Note: COALESCE(l.lineIndex, t.lineIndex, t.lineId) is used to support:
-- 1. Regular books: lineId points to line table, l.lineIndex is used
-- 2. External books: lineIndex stored directly in tocEntry table
-- 3. Legacy fallback: lineId used directly if neither above works

selectByBookId:
SELECT t.*, tt.text, COALESCE(l.lineIndex, t.lineIndex, t.lineId) as lineIndex
FROM tocEntry t
JOIN tocText tt ON t.textId = tt.id
LEFT JOIN line l ON t.lineId = l.id
WHERE t.bookId = ?
ORDER BY COALESCE(l.lineIndex, t.lineIndex, t.lineId) ASC,
         CASE WHEN t.id < 0 THEN -t.id ELSE t.id END ASC;

selectTocById:
SELECT t.*, tt.text, COALESCE(l.lineIndex, t.lineIndex, t.lineId) as lineIndex
FROM tocEntry t
JOIN tocText tt ON t.textId = tt.id
LEFT JOIN line l ON t.lineId = l.id
WHERE t.id = ?;

selectRootByBookId:
SELECT t.*, tt.text, COALESCE(l.lineIndex, t.lineIndex, t.lineId) as lineIndex
FROM tocEntry t
JOIN tocText tt ON t.textId = tt.id
LEFT JOIN line l ON t.lineId = l.id
WHERE t.bookId = ? AND t.parentId IS NULL
ORDER BY COALESCE(l.lineIndex, t.lineIndex, t.lineId) ASC,
         CASE WHEN t.id < 0 THEN -t.id ELSE t.id END ASC;

selectChildren:
SELECT t.*, tt.text, COALESCE(l.lineIndex, t.lineIndex, t.lineId) as lineIndex
FROM tocEntry t
JOIN tocText tt ON t.textId = tt.id
LEFT JOIN line l ON t.lineId = l.id
WHERE t.parentId = ?
ORDER BY COALESCE(l.lineIndex, t.lineIndex, t.lineId) ASC,
         CASE WHEN t.id < 0 THEN -t.id ELSE t.id END ASC;

selectByLineId:
SELECT t.*, tt.text, COALESCE(l.lineIndex, t.lineIndex, t.lineId) as lineIndex
FROM tocEntry t
JOIN tocText tt ON t.textId = tt.id
LEFT JOIN line l ON t.lineId = l.id
WHERE t.lineId = ?;

insert:
INSERT INTO tocEntry (bookId, parentId, textId, level, lineId, lineIndex, isLastChild, hasChildren)
VALUES (?, ?, ?, ?, ?, ?, ?, ?);

updateLineId:
UPDATE tocEntry SET lineId = ? WHERE id = ?;

updateLineIndex:
UPDATE tocEntry SET lineIndex = ? WHERE id = ?;

updateIsLastChild:
UPDATE tocEntry SET isLastChild = ? WHERE id = ?;

updateHasChildren:
UPDATE tocEntry SET hasChildren = ? WHERE id = ?;

delete:
DELETE FROM tocEntry WHERE id = ?;

deleteByBookId:
DELETE FROM tocEntry WHERE bookId = ?;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'TocTextQueries.sq': r'''
-- Queries for table of contents texts

selectAll:
SELECT * FROM tocText ORDER BY text;

selectById:
SELECT * FROM tocText WHERE id = ?;

selectByText:
SELECT * FROM tocText WHERE text = ? LIMIT 1;

insert:
INSERT INTO tocText (text)
VALUES (?)
ON CONFLICT (text) DO NOTHING;

insertAndGetId:
INSERT OR IGNORE INTO tocText (text)
VALUES (?);

selectIdByText:
SELECT id FROM tocText WHERE text = ? LIMIT 1;

delete:
DELETE FROM tocText WHERE id = ?;

countAll:
SELECT COUNT(*) FROM tocText;

lastInsertRowId:
SELECT last_insert_rowid();
''',
  'TopicQueries.sq': r'''
-- Requêtes pour les topics

selectAll:
SELECT * FROM topic ORDER BY name;

selectById:
SELECT * FROM topic WHERE id = ?;

selectByName:
SELECT * FROM topic WHERE name = ? LIMIT 1;

selectByBookId:
SELECT t.* FROM topic t
JOIN book_topic bt ON t.id = bt.topicId
WHERE bt.bookId = ?
ORDER BY t.name;

insert:
INSERT INTO topic (name)
VALUES (?)
ON CONFLICT (name) DO NOTHING;

insertAndGetId:
INSERT OR IGNORE INTO topic (name)
VALUES (?);

selectIdByName:
SELECT id FROM topic WHERE name = ? LIMIT 1;

delete:
DELETE FROM topic WHERE id = ?;

countAll:
SELECT COUNT(*) FROM topic;

lastInsertRowId:
SELECT last_insert_rowid();

-- Requêtes pour la table de jonction book_topic

linkBookTopic:
INSERT INTO book_topic (bookId, topicId)
VALUES (?, ?)
ON CONFLICT (bookId, topicId) DO NOTHING;

unlinkBookTopic:
DELETE FROM book_topic WHERE bookId = ? AND topicId = ?;

deleteAllBookTopics:
DELETE FROM book_topic WHERE bookId = ?;

countBookTopics:
SELECT COUNT(*) FROM book_topic WHERE bookId = ?;
''',
};
