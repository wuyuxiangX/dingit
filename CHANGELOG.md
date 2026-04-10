# Changelog

All notable changes to Dingit are documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Server

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
