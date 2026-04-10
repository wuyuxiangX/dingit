package service

import (
	"context"
	"os"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/dingit-me/server/internal/db"
)

// This file provides the shared Postgres test fixtures used by the
// regression tests in store_test.go and (optionally) callback_test.go.
// It's compiled only into the test binary (name ends in _test.go) so
// production builds never import it.
//
// Design notes:
//
//   - POSTGRES_TEST_URL is the single environment variable that gates
//     all DB-backed tests. If it's unset, getTestPool calls t.Skip so
//     local developers who don't have a test Postgres running can still
//     `go test ./...` without failures. CI must set it.
//
//   - The pool is created exactly once per `go test` process via
//     sync.Once, then reused across every test in this package. This
//     means schema migrations run one time (goose is idempotent so
//     re-runs are harmless anyway) and connection overhead is amortized.
//
//   - Isolation between tests is handled with truncateAll + t.Cleanup:
//     each test truncates after itself, so the next test starts with
//     empty tables regardless of whether the previous test passed or
//     failed.

var (
	testPoolOnce sync.Once
	testPool     *pgxpool.Pool
	testPoolErr  error
)

// getTestPool returns a shared pgxpool.Pool connected to POSTGRES_TEST_URL
// with all goose migrations applied. Tests that need a real database
// call this; when POSTGRES_TEST_URL is not set, the test is skipped
// rather than failed, so the default `go test ./...` on a dev box
// without Postgres stays green.
func getTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("POSTGRES_TEST_URL")
	if url == "" {
		t.Skip("POSTGRES_TEST_URL not set; skipping database-backed test")
	}
	testPoolOnce.Do(func() {
		// db.Connect runs pending goose migrations as part of its
		// bootstrap, so the pool we get back already has the full
		// Dingit schema in place. This is the hard dependency on
		// WYX-405 that WYX-409 inherits.
		testPool, testPoolErr = db.Connect(context.Background(), url)
	})
	if testPoolErr != nil {
		t.Fatalf("connect test DB: %v", testPoolErr)
	}
	return testPool
}

// truncateAll wipes every application table so the next test starts
// with a clean slate. CASCADE handles any FK relationships that may
// exist now or later. goose_db_version is deliberately NOT touched —
// it's schema metadata, not app data.
func truncateAll(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		"TRUNCATE notifications, api_keys, devices CASCADE")
	if err != nil {
		t.Fatalf("truncate test DB: %v", err)
	}
}
