Otzaria API server built with [Shelf](https://pub.dev/packages/shelf).

The current MVP exposes:

- `GET /health`
- `GET /version`, read from `db_meta.content_version_int` in `seforim.db`

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
