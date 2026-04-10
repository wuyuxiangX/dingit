package db

import (
	"io/fs"
	"testing"

	"github.com/pressly/goose/v3"
)

// TestMigrationsFSHasInit verifies the embed.FS actually captured the
// migration files at build time. A silent embed miss (e.g., someone moves
// the file or breaks the //go:embed directive) should fail CI loudly.
func TestMigrationsFSHasInit(t *testing.T) {
	matches, err := fs.Glob(migrationsFS, "migrations/*.sql")
	if err != nil {
		t.Fatalf("fs.Glob: %v", err)
	}
	if len(matches) == 0 {
		t.Fatalf("no migration files found in embed.FS")
	}

	found := false
	for _, m := range matches {
		if m == "migrations/001_init.sql" {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected migrations/001_init.sql in FS; got %v", matches)
	}
}

// TestGooseCanCollectMigrations runs goose's own parser over the embedded
// files to catch malformed annotation markers ("-- +goose Up/Down"),
// missing boundaries, and similar issues. Does not require a live database.
func TestGooseCanCollectMigrations(t *testing.T) {
	if err := configureGoose(); err != nil {
		t.Fatalf("configureGoose: %v", err)
	}

	migrations, err := goose.CollectMigrations(migrationsDir, 0, goose.MaxVersion)
	if err != nil {
		t.Fatalf("goose.CollectMigrations: %v", err)
	}
	if len(migrations) == 0 {
		t.Fatalf("goose collected zero migrations from embed.FS")
	}

	// 001_init.sql must be version 1 — if someone later renames it to a
	// different numeric prefix, the ordering contract with production
	// (which assumes version 1 = the init snapshot) breaks silently.
	if migrations[0].Version != 1 {
		t.Fatalf("expected first migration version 1, got %d", migrations[0].Version)
	}
}
