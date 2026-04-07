package db

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Connect(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("unable to ping database: %w", err)
	}

	if err := migrate(ctx, pool); err != nil {
		pool.Close()
		return nil, fmt.Errorf("migration failed: %w", err)
	}

	return pool, nil
}

func migrate(ctx context.Context, pool *pgxpool.Pool) error {
	query := `
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

	CREATE TABLE IF NOT EXISTS api_keys (
		id           TEXT PRIMARY KEY,
		name         TEXT NOT NULL DEFAULT '',
		key_hash     TEXT NOT NULL UNIQUE,
		prefix       TEXT NOT NULL DEFAULT '',
		created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		last_used_at TIMESTAMPTZ
	);
	`

	_, err := pool.Exec(ctx, query)
	return err
}
