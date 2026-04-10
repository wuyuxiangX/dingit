# Changelog

All notable changes to Dingit are documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Server

- **Prometheus `/metrics` endpoint + Grafana dashboard**
  ([WYX-406](https://linear.app/wyx/issue/WYX-406)).
  Adds a protected `GET /metrics` endpoint exposing six core observability
  metrics in the Prometheus text format:

  - `dingit_http_requests_total{method,route,status}` (counter)
  - `dingit_http_request_duration_seconds{route}` (histogram)
  - `dingit_ws_connected_clients` (gauge)
  - `dingit_push_delivery_total{provider,result}` (counter)
  - `dingit_callback_delivery_total{result,status_class}` (counter)
  - `dingit_notifications_by_status{status}` (gauge)

  The `route` label uses Gin's parameterized path pattern
  (`/api/notifications/:id`), never the raw URL, so path parameters
  don't explode label cardinality.

  **Security**: `/metrics` is protected by the existing API key
  middleware. Unauthenticated requests return `401`. Several of the
  metrics (notification counts, push success rates) would leak
  business-scale information if exposed publicly.

  **Grafana dashboard**: an importable dashboard lives at
  `deploy/grafana/dingit-dashboard.json`, with six panels mapping
  one-to-one to the metrics above. Uses the standard Grafana
  `${DS_PROMETHEUS}` variable so it binds cleanly to any existing
  Prometheus data source at import time — no hardcoded UIDs.

  See `apps/server/README.md` for scrape config examples.

- **Versioned database migrations via `pressly/goose`**
  ([WYX-405](https://linear.app/wyx/issue/WYX-405)).
  Replaces the inline multi-statement `migrate()` function in
  `internal/db/postgres.go` with discrete, embedded SQL migration files
  under `internal/db/migrations/`. The initial snapshot is
  `001_init.sql`, which is fully idempotent and reproduces the v1.0
  schema byte-for-byte.

  New CLI flags on `dingit-server`:

  - `--migrate-only`: apply pending migrations and exit, no HTTP listener.
    Designed for Kubernetes init containers and CI deploy steps.
  - `--migrate-status`: print the list of applied and pending migrations
    and exit.

  **Upgrading from pre-goose builds**: no manual action required. On
  first boot, goose creates a new `goose_db_version` table and applies
  `001_init.sql`. Because every statement in that file uses
  `IF NOT EXISTS` guards, the existing production tables are left
  untouched and no rows are mutated. After the upgrade, run
  `./dingit-server --migrate-status` to confirm `001_init.sql` is
  reported as Applied.

  Note: goose's tracking table is named `goose_db_version`, not
  `schema_migrations`. This is the upstream default and is semantically
  equivalent to `schema_migrations` in `golang-migrate`.

  This change is the prerequisite for all v1.3 schema-touching work
  (C 组: 通知预调度、已读/未读、通知分组、通知模板、免打扰).
