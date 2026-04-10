# Dingit Server

Go + PostgreSQL backend for Dingit. The server is the single source of truth
for notifications, API keys, and device tokens.

## Running

```sh
# Normal boot (runs any pending DB migrations, then starts the HTTP server)
./dingit-server

# Generate an API key and exit
./dingit-server -generate-key

# Apply pending DB migrations and exit — no HTTP server
./dingit-server -migrate-only

# Print DB migration status and exit — no HTTP server
./dingit-server -migrate-status
```

`--migrate-only` is intended for use as a Kubernetes init container, a CI
deploy step, or a one-shot admin command. `--migrate-status` is the fastest
way to check "what version is this environment on?" without touching the
database manually.

## Database migrations

Schema changes are managed with [`pressly/goose`](https://github.com/pressly/goose).
Every migration is a plain `.sql` file under
[`internal/db/migrations/`](internal/db/migrations/), compiled into the
binary via `//go:embed` so the Docker image does not need any extra files.

Goose records applied versions in a table called `goose_db_version`. On
normal server boot (`./dingit-server` with no flags), `db.Connect` applies
every pending migration before the HTTP listener starts.

### Adding a new migration

1. Create a new file using the next sequence number. Keep the prefix
   zero-padded and descriptive:

   ```sh
   touch apps/server/internal/db/migrations/002_add_notification_tags.sql
   ```

2. Write the migration with goose's annotation markers:

   ```sql
   -- +goose Up
   ALTER TABLE notifications ADD COLUMN IF NOT EXISTS tags JSONB NOT NULL DEFAULT '[]';
   CREATE INDEX IF NOT EXISTS idx_notifications_tags ON notifications USING GIN (tags);

   -- +goose Down
   DROP INDEX IF EXISTS idx_notifications_tags;
   ALTER TABLE notifications DROP COLUMN IF EXISTS tags;
   ```

3. Prefer idempotent DDL (`IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`)
   whenever possible. Idempotent migrations are forgiving in disaster
   recovery and make it safe to re-run a migration after a partial failure.

4. If a statement contains embedded semicolons (stored procedures,
   `DO $$ ... $$` blocks), wrap it with `-- +goose StatementBegin` /
   `-- +goose StatementEnd` so goose's splitter doesn't break it up.

5. Verify the file parses:

   ```sh
   cd apps/server && go test ./internal/db/...
   ```

   The test suite runs `goose.CollectMigrations` over the embedded files
   and fails fast on any malformed annotations.

6. Apply locally to a dev database:

   ```sh
   ./dingit-server -migrate-only
   ./dingit-server -migrate-status
   ```

### Checking migration state on a running environment

```sh
./dingit-server -migrate-status
```

Sample output:

```
    Applied At                  Migration
    =======================================
    Fri Apr 10 12:34:56 2026 -- 001_init.sql
```

### First upgrade from pre-goose versions

Dingit v1.0 servers created their schema via an inline SQL string in
`internal/db/postgres.go`. The first boot of a post-goose server against
one of those databases is harmless: `001_init.sql` is fully idempotent, so
goose re-runs it against the existing tables (no rows are touched) and
records `version_id = 1` in the newly created `goose_db_version` table.
Operators do not need to take any manual action.

After the upgrade, confirm with:

```sh
./dingit-server -migrate-status
```

You should see `001_init.sql` reported as Applied.
