package config

import (
	"os"
	"path/filepath"

	"encoding/json"
)

type Config struct {
	ServerURL     string `json:"server_url"`
	DefaultSource string `json:"default_source"`
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
	if err != nil {
		return c
	}
	_ = json.Unmarshal(data, c)
	return c
}

func (c *Config) Save() error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configPath(), data, 0644)
}
