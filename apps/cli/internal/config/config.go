package config

import (
	"os"
	"path/filepath"

	"encoding/json"
)

type Config struct {
	ServerURL     string `json:"server_url"`
	DefaultSource string `json:"default_source"`
	APIKey        string `json:"api_key"`
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".dingit.json")
}

func Load() *Config {
	c := &Config{
		ServerURL:     "http://localhost:8080",
		DefaultSource: "cli",
	}
	data, err := os.ReadFile(configPath())
	if err == nil {
		_ = json.Unmarshal(data, c)
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
	return os.WriteFile(configPath(), data, 0600)
}
