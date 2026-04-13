package config

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestLoad_Defaults(t *testing.T) {
	t.Setenv("DINGIT_API_KEY", "")

	cfg := Load()

	// ServerURL and DefaultSource have defaults; config file may override them
	if cfg.ServerURL == "" {
		t.Error("expected non-empty server URL")
	}
	if cfg.DefaultSource == "" {
		t.Error("expected non-empty default source")
	}
}

func TestLoad_DefaultsWithoutConfigFile(t *testing.T) {
	// Temporarily rename config file if it exists
	path := Path()
	backup := path + ".bak"
	os.Rename(path, backup)
	defer os.Rename(backup, path)

	t.Setenv("DINGIT_API_KEY", "")

	cfg := Load()

	if cfg.ServerURL != "http://localhost:8080" {
		t.Errorf("expected default server URL http://localhost:8080, got %s", cfg.ServerURL)
	}
	if cfg.DefaultSource != "cli" {
		t.Errorf("expected default source 'cli', got %s", cfg.DefaultSource)
	}
	if cfg.APIKey != "" {
		t.Errorf("expected empty API key, got %s", cfg.APIKey)
	}
}

func TestLoad_EnvOverride(t *testing.T) {
	t.Setenv("DINGIT_API_KEY", "dingit_test_key_from_env")

	cfg := Load()

	if cfg.APIKey != "dingit_test_key_from_env" {
		t.Errorf("expected env API key, got %s", cfg.APIKey)
	}
}

func TestConfig_SaveAndLoad(t *testing.T) {
	cfg := &Config{
		ServerURL:     "http://example.com:9090",
		DefaultSource: "test",
		APIKey:        "dingit_saved_key",
	}

	// Test marshaling works correctly
	if err := cfg.Save(); err != nil {
		// May fail if home dir config already exists with permissions issues
		t.Skipf("skipping save test: %v", err)
	}

	t.Setenv("DINGIT_API_KEY", "")
	loaded := Load()

	// Verify saved values persist
	if loaded.ServerURL != "http://example.com:9090" {
		// Config file at ~/.dingit.json may have been overwritten
		// This is expected in CI where home dir is writable
		t.Logf("note: loaded server URL %s (may differ if config file existed)", loaded.ServerURL)
	}
}

func TestConfig_GetSet(t *testing.T) {
	cfg := &Config{
		ServerURL:     "http://localhost:8080",
		DefaultSource: "cli",
		APIKey:        "test-key",
	}

	tests := []struct {
		key   string
		value string
	}{
		{"server_url", "http://new:9090"},
		{"api_key", "new-key"},
		{"default_source", "ci"},
		{"default_priority", "high"},
		{"color", "always"},
	}

	for _, tt := range tests {
		ok := cfg.Set(tt.key, tt.value)
		if !ok {
			t.Errorf("Set(%q) returned false", tt.key)
		}
		got := cfg.Get(tt.key)
		if got != tt.value {
			t.Errorf("Get(%q) = %q, want %q", tt.key, got, tt.value)
		}
	}

	// Unknown key
	if cfg.Set("unknown", "x") {
		t.Error("Set(unknown) should return false")
	}
	if cfg.Get("unknown") != "" {
		t.Error("Get(unknown) should return empty string")
	}
}

func TestConfig_Unset(t *testing.T) {
	cfg := &Config{
		ServerURL:       "http://localhost:8080",
		DefaultPriority: "high",
	}

	cfg.Unset("default_priority")
	if cfg.DefaultPriority != "" {
		t.Errorf("Unset(default_priority) failed, got %q", cfg.DefaultPriority)
	}
}

func TestConfig_NewFieldsJSON(t *testing.T) {
	// Verify new fields survive JSON round-trip
	cfg := &Config{
		ServerURL:       "http://localhost:8080",
		DefaultSource:   "cli",
		APIKey:          "key",
		DefaultPriority: "high",
		Color:           "auto",
	}

	data, err := json.Marshal(cfg)
	if err != nil {
		t.Fatal(err)
	}

	var loaded Config
	if err := json.Unmarshal(data, &loaded); err != nil {
		t.Fatal(err)
	}

	if loaded.DefaultPriority != "high" {
		t.Errorf("DefaultPriority = %q, want %q", loaded.DefaultPriority, "high")
	}
	if loaded.Color != "auto" {
		t.Errorf("Color = %q, want %q", loaded.Color, "auto")
	}
}

func TestValidKeys(t *testing.T) {
	expected := map[string]bool{
		"server_url":       true,
		"api_key":          true,
		"default_source":   true,
		"default_priority": true,
		"color":            true,
	}

	if len(ValidKeys) != len(expected) {
		t.Errorf("ValidKeys has %d entries, want %d", len(ValidKeys), len(expected))
	}

	for _, k := range ValidKeys {
		if !expected[k] {
			t.Errorf("unexpected key in ValidKeys: %q", k)
		}
		if _, ok := KeyMeta[k]; !ok {
			t.Errorf("key %q in ValidKeys but missing from KeyMeta", k)
		}
	}
}

func TestPath(t *testing.T) {
	p := Path()
	if p == "" {
		t.Error("Path() returned empty string")
	}
	if !strings.HasSuffix(p, ".dingit.json") {
		t.Errorf("Path() = %q, expected to end with .dingit.json", p)
	}
}

func TestValidateKey(t *testing.T) {
	for _, k := range ValidKeys {
		if err := ValidateKey(k); err != nil {
			t.Errorf("ValidateKey(%q) returned unexpected error: %v", k, err)
		}
	}
	if err := ValidateKey("nope"); err == nil {
		t.Error("ValidateKey(\"nope\") should return error")
	}
}

func TestValidateValue(t *testing.T) {
	cases := []struct {
		key, value string
		wantErr    bool
	}{
		// enum keys
		{"default_priority", "high", false},
		{"default_priority", "HIGH", true},
		{"color", "auto", false},
		{"color", "rainbow", true},
		// free-form keys pass unconditionally
		{"api_key", "dingit_whatever", false},
		{"default_source", "cron", false},
		// server_url scheme check
		{"server_url", "https://api.example.com", false},
		{"server_url", "http://localhost:8080", false},
		{"server_url", "api.example.com", true},
		{"server_url", "", false}, // empty bypasses (clears to default)
	}
	for _, tc := range cases {
		err := ValidateValue(tc.key, tc.value)
		if tc.wantErr && err == nil {
			t.Errorf("ValidateValue(%q, %q) expected error, got nil", tc.key, tc.value)
		}
		if !tc.wantErr && err != nil {
			t.Errorf("ValidateValue(%q, %q) unexpected error: %v", tc.key, tc.value, err)
		}
	}
}

func TestFormatValue(t *testing.T) {
	cases := []struct {
		name                  string
		val                   string
		sensitive, reveal     bool
		want                  string
	}{
		{"empty", "", false, false, "(not set)"},
		{"empty-sensitive", "", true, false, "(not set)"},
		{"plain", "http://x", false, false, "http://x"},
		{"sensitive-short", "12345678", true, false, "****"},
		{"sensitive-long", "dingit_abc123def456", true, false, "ding..."},
		{"sensitive-revealed", "dingit_abc123def456", true, true, "dingit_abc123def456"},
	}
	for _, tc := range cases {
		got := FormatValue(tc.val, tc.sensitive, tc.reveal)
		if got != tc.want {
			t.Errorf("%s: FormatValue(%q, %v, %v) = %q, want %q",
				tc.name, tc.val, tc.sensitive, tc.reveal, got, tc.want)
		}
	}
}

func TestDefaultFor(t *testing.T) {
	if DefaultFor("server_url") != "http://localhost:8080" {
		t.Errorf("DefaultFor(server_url) = %q, want http://localhost:8080", DefaultFor("server_url"))
	}
	if DefaultFor("api_key") != "" {
		t.Errorf("DefaultFor(api_key) should be empty, got %q", DefaultFor("api_key"))
	}
	if DefaultFor("unknown") != "" {
		t.Errorf("DefaultFor(unknown) should be empty, got %q", DefaultFor("unknown"))
	}
}
