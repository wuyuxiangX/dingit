package service

import (
	"strings"
	"testing"
)

func TestGenerateAPIKey_Format(t *testing.T) {
	key := GenerateAPIKey()

	if !strings.HasPrefix(key, "dingit_") {
		t.Errorf("expected prefix 'dingit_', got %s", key[:7])
	}
	// dingit_ (7) + 64 hex chars = 71
	if len(key) != 71 {
		t.Errorf("expected length 71, got %d", len(key))
	}
}

func TestGenerateAPIKey_Unique(t *testing.T) {
	key1 := GenerateAPIKey()
	key2 := GenerateAPIKey()

	if key1 == key2 {
		t.Error("expected unique keys, got duplicates")
	}
}

func TestHashAPIKey_Deterministic(t *testing.T) {
	key := "dingit_test_key_123"
	hash1 := HashAPIKey(key)
	hash2 := HashAPIKey(key)

	if hash1 != hash2 {
		t.Error("expected same hash for same input")
	}
}

func TestHashAPIKey_DifferentInputs(t *testing.T) {
	hash1 := HashAPIKey("key_a")
	hash2 := HashAPIKey("key_b")

	if hash1 == hash2 {
		t.Error("expected different hashes for different inputs")
	}
}

func TestHashAPIKey_Length(t *testing.T) {
	hash := HashAPIKey("test")
	// SHA256 hex = 64 chars
	if len(hash) != 64 {
		t.Errorf("expected SHA256 hex length 64, got %d", len(hash))
	}
}
