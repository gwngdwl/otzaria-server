Otzaria API server built with [Shelf](https://pub.dev/packages/shelf).

The current MVP exposes:

- `GET /health`
- `GET /version` — read from `db_meta.content_version_int` in `seforim.db`
- `GET /library` — full category tree with nested books + metadata
- `GET /books` — flat book list; `?category=<id>` filters to one category
- `GET /books/{id}` — full book metadata + feature flags (`hasNekudot`, `hasCommentaryConnection`, …)
- `GET /books/{id}/exists` — `{ "exists": bool }`
- `GET /books/{id}/text` — full raw text (`text/plain`, lines joined by `\n`, nikud/teamim preserved)
- `GET /books/{id}/text/range?start=&end=` — `{ startLine, endLine, totalLines, lines[] }` by `lineIndex` (inclusive)
- `GET /books/{id}/toc` — table-of-contents tree (`{ text, index, level, children[] }`)
- `GET /books/{id}/links` — all links where the book is the source
- `GET /books/{id}/links/range?start=&end=&targets=` — links in a line range (by `lineIndex`); `targets` = comma-separated `targetBookId`s to filter
- `POST /links/content` — body `{ "targetLineIds": [int,…] }` → `{ "content": { "<lineId>": "<text>" } }`
- ⭐ `GET /books/{id}/page?start=&end=&commentators=` — **lines + links + commentary content in a single call** (commentary keyed `"targetBookId:targetLineId"`). This is the endpoint that avoids a network round-trip per scroll.

All catalog/content endpoints read directly through the `otzaria_core` DAOs/repository, so the
output matches what the Flutter client loads from the local library (parity). The server only ever
opens `seforim.db` read-only.

## Running with the Dart SDK

Set `SEFORIM_DB_PATH` to an existing `seforim.db` and run the server:

```bash
SEFORIM_DB_PATH=/srv/otzaria/seforim.db dart run bin/server.dart
```

Then verify:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/version
```

## Running with Docker

Build from the repository root so Docker can see both `apps/server` and the local `packages/otzaria_core` dependency:

```bash
docker build -f apps/server/Dockerfile -t otzaria-server .
docker run --rm -p 8080:8080 \
	-e SEFORIM_DB_PATH=/data/seforim.db \
	-v /srv/otzaria/seforim.db:/data/seforim.db:ro \
	otzaria-server
```

For VPS deployment, prefer the root `compose.yaml`; see `deploy/README.md`.
