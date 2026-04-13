package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

type Config struct {
	ServerURL       string `json:"server_url"`
	DefaultSource   string `json:"default_source"`
	APIKey          string `json:"api_key"`
	DefaultPriority string `json:"default_priority,omitempty"`
	Color           string `json:"color,omitempty"`
}

// ValidKeys lists all config key names that can be used with get/set/unset,
// in the order they are displayed by `dingit config list`.
var ValidKeys = []string{"server_url", "api_key", "default_source", "default_priority", "color"}

// KeyInfo describes a config key's display label, sensitivity, default
// value and allowed values (if any).
//
// A non-empty Default is auto-applied by Load() when the field is empty,
// so unsetting a keyed field effectively restores the default. An empty
// AllowedValues slice means "any string is accepted" and the caller is
// expected to supply custom validation (e.g. URL scheme for server_url).
type KeyInfo struct {
	Label         string
	Sensitive     bool
	Default       string
	AllowedValues []string
}

// KeyMeta is the single source of truth for config key metadata.
// Add a new field: (1) add it to Config, (2) add an entry here, (3) add
// the key to ValidKeys, (4) wire it in Get/Set.
var KeyMeta = map[string]KeyInfo{
	"server_url":       {Label: "Server URL", Default: "http://localhost:8080"},
	"api_key":          {Label: "API Key", Sensitive: true},
	"default_source":   {Label: "Default Source", Default: "cli"},
	"default_priority": {Label: "Default Priority", AllowedValues: []string{"urgent", "high", "normal", "low"}},
	"color":            {Label: "Color Output", AllowedValues: []string{"auto", "always", "never"}},
}

// Get returns the value of a config key by name. Returns empty string for unknown keys.
func (c *Config) Get(key string) string {
	switch key {
	case "server_url":
		return c.ServerURL
	case "api_key":
		return c.APIKey
	case "default_source":
		return c.DefaultSource
	case "default_priority":
		return c.DefaultPriority
	case "color":
		return c.Color
	default:
		return ""
	}
}

// Set sets the value of a config key by name. Returns false for unknown keys.
func (c *Config) Set(key, value string) bool {
	switch key {
	case "server_url":
		c.ServerURL = value
	case "api_key":
		c.APIKey = value
	case "default_source":
		c.DefaultSource = value
	case "default_priority":
		c.DefaultPriority = value
	case "color":
		c.Color = value
	default:
		return false
	}
	return true
}

// Unset clears the value of a config key by name. Returns false for unknown keys.
func (c *Config) Unset(key string) bool {
	return c.Set(key, "")
}

// DefaultFor returns the default value for a key, or empty string if the
// key has no default.
func DefaultFor(key string) string {
	return KeyMeta[key].Default
}

// ValidateKey returns nil if key is recognized, otherwise an error listing
// the valid keys.
func ValidateKey(key string) error {
	if slices.Contains(ValidKeys, key) {
		return nil
	}
	return fmt.Errorf("unknown config key %q; valid keys: %s", key, strings.Join(ValidKeys, ", "))
}

// ValidateValue checks a value against its key's allowed values and any
// key-specific rules. Assumes the key has already passed ValidateKey.
func ValidateValue(key, value string) error {
	info := KeyMeta[key]
	if len(info.AllowedValues) > 0 && !slices.Contains(info.AllowedValues, value) {
		return fmt.Errorf("invalid %s %q; must be one of: %s",
			key, value, strings.Join(info.AllowedValues, ", "))
	}
	// Keys with free-form values still need lightweight structural checks.
	if key == "server_url" && value != "" &&
		!strings.HasPrefix(value, "http://") && !strings.HasPrefix(value, "https://") {
		return fmt.Errorf("server_url must start with http:// or https://")
	}
	return nil
}

// FormatValue renders a config value for display. Empty values render
// as "(not set)". Sensitive values are masked unless reveal is true:
// for values longer than 8 chars we show the first 4 as a recognition
// prefix; shorter values are fully masked to avoid leaking too much.
func FormatValue(val string, sensitive, reveal bool) string {
	if val == "" {
		return "(not set)"
	}
	if sensitive && !reveal {
		if len(val) <= 8 {
			return "****"
		}
		return val[:4] + "..."
	}
	return val
}

// Path returns the absolute path to the config file.
func Path() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".dingit.json")
}

func Load() *Config {
	c := &Config{}
	data, err := os.ReadFile(Path())
	if err == nil {
		_ = json.Unmarshal(data, c)
	}

	// Apply defaults from KeyMeta for any empty fields so that Unset
	// effectively "restores the default". This keeps the default table
	// in one place instead of duplicating it across Load/cmd/validation.
	for key, info := range KeyMeta {
		if info.Default != "" && c.Get(key) == "" {
			c.Set(key, info.Default)
		}
	}

	// Environment variable overrides
	if v := os.Getenv("DINGIT_API_KEY"); v != "" {
		c.APIKey = v
	}

	return c
}

func (c *Config) Save() error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(Path(), data, 0600)
}
