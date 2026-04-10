-- +goose Up
-- Initial schema snapshot for Dingit v1.0.
-- This migration is intentionally fully idempotent (IF NOT EXISTS everywhere)
-- so it can be safely re-applied against an existing production database that
-- was previously bootstrapped by the inline migrate() function in postgres.go.

CREATE TABLE IF NOT EXISTS notifications (
    id              TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    source          TEXT NOT NULL DEFAULT 'unknown',
    status          TEXT NOT NULL DEFAULT 'pending',
    priority        TEXT NOT NULL DEFAULT 'normal',
    actions         JSONB NOT NULL DEFAULT '[]',
    callback_url    TEXT,
    metadata        JSONB,
    actioned_value  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actioned_at     TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal';
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON notifications(priority);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS icon TEXT;

CREATE INDEX IF NOT EXISTS idx_notifications_expires ON notifications(expires_at)
    WHERE expires_at IS NOT NULL AND status = 'pending';

CREATE TABLE IF NOT EXISTS api_keys (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL DEFAULT '',
    key_hash     TEXT NOT NULL UNIQUE,
    prefix       TEXT NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS devices (
    id         TEXT PRIMARY KEY,
    token      TEXT NOT NULL UNIQUE,
    platform   TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +goose Down
-- A down migration is provided for completeness. Running it will drop all
-- application data — use with care.
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS api_keys;
DROP INDEX IF EXISTS idx_notifications_expires;
DROP INDEX IF EXISTS idx_notifications_priority;
DROP INDEX IF EXISTS idx_notifications_created;
DROP INDEX IF EXISTS idx_notifications_status;
DROP TABLE IF EXISTS notifications;
