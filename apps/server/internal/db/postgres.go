package db

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Connect opens a pgx connection pool, pings it, and applies any pending
// versioned migrations via goose before returning. This is the normal entry
// point used by the server's main boot path.
func Connect(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	pool, err := ConnectWithoutMigrate(ctx, databaseURL)
	if err != nil {
		return nil, err
	}

	if err := RunMigrations(ctx, pool); err != nil {
		pool.Close()
		return nil, fmt.Errorf("migration failed: %w", err)
	}

	return pool, nil
}

// ConnectWithoutMigrate opens a pgx connection pool and pings it, but does
// NOT run migrations. It's used by CLI-only short-circuits like
// --migrate-status, where we want to inspect the current migration state
// without applying anything, and by --migrate-only, which applies migrations
// explicitly and then exits without starting the server.
func ConnectWithoutMigrate(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("unable to ping database: %w", err)
	}

	return pool, nil
}
