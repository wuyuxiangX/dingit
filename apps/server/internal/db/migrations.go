package db

import (
	"context"
	"database/sql"
	"embed"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

// migrationsFS holds every SQL file under ./migrations, compiled into the
// binary at build time. Using embed.FS keeps the Dockerfile simple: the
// migrations travel with the binary, no extra COPY step needed.
//
//go:embed migrations/*.sql
var migrationsFS embed.FS

const migrationsDir = "migrations"

// openSQLFromPool returns a *sql.DB that shares the underlying pgxpool.
// The returned DB must be Close()'d by the caller; closing it releases the
// pgx stdlib wrapper without closing the underlying pool, so it's safe to
// use during server bootstrap and then continue using the pool normally.
func openSQLFromPool(pool *pgxpool.Pool) *sql.DB {
	return stdlib.OpenDBFromPool(pool)
}

// configureGoose sets the embedded FS and dialect. Safe to call more than
// once — goose treats these as global state, but the values never change.
func configureGoose() error {
	goose.SetBaseFS(migrationsFS)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("goose set dialect: %w", err)
	}
	return nil
}

// RunMigrations applies all pending goose migrations against the given pool.
// Safe to call on an already-migrated database: goose skips versions that
// are already recorded in its tracking table (goose_db_version).
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	db := openSQLFromPool(pool)
	defer db.Close()

	if err := configureGoose(); err != nil {
		return err
	}
	if err := goose.UpContext(ctx, db, migrationsDir); err != nil {
		return fmt.Errorf("goose up: %w", err)
	}
	return nil
}

// PrintMigrationStatus writes goose's human-readable status table to stdout.
// Used by the --migrate-status CLI flag.
func PrintMigrationStatus(ctx context.Context, pool *pgxpool.Pool) error {
	db := openSQLFromPool(pool)
	defer db.Close()

	if err := configureGoose(); err != nil {
		return err
	}
	if err := goose.StatusContext(ctx, db, migrationsDir); err != nil {
		return fmt.Errorf("goose status: %w", err)
	}
	return nil
}
