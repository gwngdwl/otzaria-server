# Deployment

This is the practical VPS deployment path for the current MVP server. The API exposes `/health`,
`/version`, the catalog/content endpoints (`/library`, `/books`, `/books/{id}`, `/text`, `/text/range`,
`/toc`), and the links + unified page endpoints (`/links`, `/links/range`, `POST /links/content`,
`/page`). The service opens `seforim.db` read-only and never writes its content.

## Server prerequisites

- A Linux VPS with Docker and Docker Compose.
- A directory on the VPS holding `seforim.db`. The default directory used by `compose.yaml` is
  `/srv/otzaria` (so the DB is `/srv/otzaria/seforim.db`).
- Port `8080` open locally, or a reverse proxy in front of it.

> **WAL sidecars / writable directory.** Otzaria's `seforim.db` ships in WAL journal mode, so SQLite
> must create `seforim.db-shm` / `seforim.db-wal` next to it even on a read-only connection. The DB
> *content* is never modified (opened with `OpenMode.readOnly`), but the **directory must be writable**.
> That's why `compose.yaml` bind-mounts the *directory* (writable), not the file as `:ro`.

## First deployment

On the VPS:

```bash
sudo mkdir -p /srv/otzaria
sudo chown "$USER:$USER" /srv/otzaria
```

Download the current database release:

```bash
sudo apt-get update
sudo apt-get install -y curl git zstd
curl -L -o /srv/otzaria/seforim.db.zst \
	https://github.com/Otzaria/SeforimLibrary/releases/download/db-v1/seforim.db.zst
zstd -d --rm /srv/otzaria/seforim.db.zst -o /srv/otzaria/seforim.db
chmod 644 /srv/otzaria/seforim.db
```

Then deploy:

```bash
git clone https://github.com/gwngdwl/otzaria-server.git
cd otzaria-server
OTZARIA_SEFORIM_DIR=/srv/otzaria docker compose up -d --build
```

Verify locally on the VPS:

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/version
```

Expected shape:

```json
{"status":"ok"}
{"contentVersion":1,"indexVersion":null,"builtAt":null}
```

## Update deployment

```bash
git pull --ff-only
OTZARIA_SEFORIM_DIR=/srv/otzaria docker compose up -d --build
docker compose logs --tail=100 api
```

Use `OTZARIA_SERVER_PORT=9090` if the host port should not be `8080`.
