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

## Running tests

```sh
# Pure Go tests (no database required) — always safe to run
go test ./...
```

Store-layer and other database-backed regression tests skip gracefully
when there is no test Postgres available. To run the full suite locally,
point `POSTGRES_TEST_URL` at a disposable database:

```sh
# Option A — use docker-compose's postgres (fastest if you already have it up)
export POSTGRES_TEST_URL='postgres://dingit:'"$POSTGRES_PASSWORD"'@localhost:5432/dingit?sslmode=disable'
go test ./...

# Option B — spin up an isolated container just for tests
docker run -d --name dingit-pgtest -p 55434:5432 \
  -e POSTGRES_USER=dingit \
  -e POSTGRES_PASSWORD=testpw \
  -e POSTGRES_DB=dingit_test \
  postgres:17-alpine
export POSTGRES_TEST_URL='postgres://dingit:testpw@localhost:55434/dingit_test?sslmode=disable'
go test ./...
docker rm -f dingit-pgtest
```

The test helpers apply all goose migrations on first connection and
TRUNCATE every application table between individual test functions, so
you can run `go test` repeatedly without residual state. CI uses a
GitHub Actions Postgres service container with the same `POSTGRES_TEST_URL`
convention — see `.github/workflows/ci.yml`.

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

## Observability: Prometheus metrics

Dingit exposes operator metrics in the Prometheus text format at
**`GET /metrics`**. The endpoint is protected by the same API key as the
rest of the API — **never** expose it unauthenticated, because several of
the metrics (notification counts, push success rates) leak business
scale.

### Exposed metrics

| Name | Type | Labels | Meaning |
|---|---|---|---|
| `dingit_http_requests_total` | counter | `method`, `route`, `status` | Total HTTP requests by parameterized route and status code. |
| `dingit_http_request_duration_seconds` | histogram | `route` | Request latency distribution per route. Use `histogram_quantile()` for P95/P99. |
| `dingit_ws_connected_clients` | gauge | — | Current number of active WebSocket connections. |
| `dingit_push_delivery_total` | counter | `provider`, `result` | Push sends bucketed by provider (`apns`/`fcm`) and outcome (`success`/`invalid_token`/`error`). |
| `dingit_callback_delivery_total` | counter | `result`, `status_class` | Terminal webhook callback outcome. Result ∈ `{success, failure, rejected, dropped}`. |
| `dingit_notifications_by_status` | gauge | `status` | Current notification count per status bucket. |

Cardinality is bounded: the `route` label uses Gin's parameterized path
(e.g. `/api/notifications/:id`), **not** the raw URL, so a stream of
unique IDs won't explode your time-series database.

### Prometheus scrape config

Add a job like this to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: dingit
    metrics_path: /metrics
    scrape_interval: 30s
    static_configs:
      - targets:
          - dingit.example.com:8080
    authorization:
      type: Bearer
      credentials_file: /etc/prometheus/dingit-token
```

Where `/etc/prometheus/dingit-token` contains a single line with your
Dingit API key (`chmod 600`, owned by the Prometheus user).

### Grafana dashboard

An importable, datasource-agnostic dashboard lives at
[`deploy/grafana/dingit-dashboard.json`](../../deploy/grafana/dingit-dashboard.json).
To use it:

1. Grafana → **Dashboards** → **New** → **Import**
2. Upload the JSON or paste its contents
3. When prompted for `DS_PROMETHEUS`, pick the Prometheus data source that
   scrapes your Dingit server
4. Click **Import**

The dashboard has six panels mapping one-to-one to the six metrics above,
with sensible defaults (`rate(...[5m])`, stacked push/callback outcomes,
P95 latency per route).

### Verifying the endpoint

```sh
# Without auth — must return 401
curl -i http://localhost:8080/metrics

# With auth — returns text/plain with dingit_* metric families
curl -H "Authorization: Bearer $DINGIT_API_KEY" http://localhost:8080/metrics | grep ^dingit_
```

## Log aggregation (Loki stack)

Metrics tell you how much is happening; logs tell you *what*. The server
already emits structured [zap](https://github.com/uber-go/zap) JSON on
stdout, and [`deploy/logging/`](../../deploy/logging/) contains a
one-command reference stack that ingests those lines into Loki and
renders them in a pre-provisioned Grafana dashboard.

### What you get

* **Loki** — log store, filesystem-backed single binary. Fine for dev
  forensics and single-box deployments; point it at S3/GCS if you
  grow beyond that.
* **Promtail** — tails the host Docker JSON log files, keeps only the
  `dingit-server` container by default, and promotes zap's `level` and
  `source` fields into Loki labels.
* **Grafana** — pre-provisioned with the Loki datasource *and* a
  "Dingit · Logs" dashboard (log rate by level, recent warn/error
  panel, per-source volume).

Zero changes to the server are required. If you rename the Dingit
container away from `dingit-server`, update the `relabel_configs`
regex in `deploy/logging/promtail-config.yml` and the `container=`
label in `deploy/logging/grafana/dashboards/dingit-logs.json`.

### Bringing the stack up

The logging stack runs in its *own* compose project (`dingit-logging`)
so it sits next to the main production stack without touching it:

```sh
# In one terminal — the main app (once, if not already running)
docker compose -f deploy/docker-compose.yml up -d

# In another — the logging sidecar
docker compose -f deploy/logging/docker-compose.yml up -d
```

Then open **<http://localhost:3000>** and log in with `admin` / `admin`.
Grafana will have the Loki datasource pre-wired and the "Dingit · Logs"
dashboard inside the "Dingit" folder. Override the defaults with
`GRAFANA_USER` / `GRAFANA_PASSWORD` / `LOKI_PORT` / `GRAFANA_PORT` in
your shell if the defaults collide with something else on your box.

### Verifying end-to-end

```sh
# Generate a few log lines by sending test notifications
curl -X POST http://localhost:8080/api/notifications \
  -H "Authorization: Bearer $DINGIT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Loki test","body":"hello world","source":"loki-smoke-test"}'

# In Grafana → Explore → pick the Loki datasource → run:
#   {container="dingit-server"}
# You should see the zap JSON lines streaming in real time, and the
# "Notifications by source" dashboard panel should show a bar for
# "loki-smoke-test".
```

### Tearing it down

```sh
docker compose -f deploy/logging/docker-compose.yml down
# ...or with volumes (wipes ingested logs + Grafana user state):
docker compose -f deploy/logging/docker-compose.yml down -v
```
