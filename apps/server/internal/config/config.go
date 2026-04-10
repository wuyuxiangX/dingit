package config

import (
	"fmt"
	"os"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	App       AppConfig       `mapstructure:"app"`
	Server    ServerConfig    `mapstructure:"server"`
	Database  DatabaseConfig  `mapstructure:"database"`
	Logger    LoggerConfig    `mapstructure:"logger"`
	CORS      CORSConfig      `mapstructure:"cors"`
	RateLimit RateLimitConfig `mapstructure:"rate_limit"`
	APIKey    string          `mapstructure:"api_key"`
}

type RateLimitConfig struct {
	Enabled        bool    `mapstructure:"enabled"`
	RequestsPerSec float64 `mapstructure:"requests_per_second"`
	BurstSize      int     `mapstructure:"burst_size"`
}

type AppConfig struct {
	Name string `mapstructure:"name"`
	Env  string `mapstructure:"env"` // local, development, production
}

type ServerConfig struct {
	Port int `mapstructure:"port"`
}

type DatabaseConfig struct {
	URL string `mapstructure:"url"`
}

type LoggerConfig struct {
	Level  string `mapstructure:"level"`  // debug, info, warn, error
	Format string `mapstructure:"format"` // console, json
	File   string `mapstructure:"file"`   // e.g. logs/dingit.log
}

type CORSConfig struct {
	AllowedOrigins []string `mapstructure:"allowed_origins"`
}

func (c *Config) IsDevelopment() bool {
	return c.App.Env == "local" || c.App.Env == "development"
}

func (c *Config) IsProduction() bool {
	return c.App.Env == "production"
}

func Load() (*Config, error) {
	env := os.Getenv("APP_ENV")
	if env == "" {
		env = "local"
	}

	v := viper.New()

	// Defaults
	v.SetDefault("app.name", "dingit")
	v.SetDefault("app.env", env)
	v.SetDefault("server.port", 8080)
	v.SetDefault("logger.level", "info")
	v.SetDefault("logger.format", "console")
	v.SetDefault("cors.allowed_origins", []string{"*"})
	v.SetDefault("rate_limit.enabled", true)
	v.SetDefault("rate_limit.requests_per_second", 10.0)
	v.SetDefault("rate_limit.burst_size", 20)

	// Read config file
	v.SetConfigName(env)
	v.SetConfigType("yaml")
	v.AddConfigPath("./configs")
	v.AddConfigPath(".")

	if err := v.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("read config: %w", err)
		}
		// Not an error — env-var-only deploys are fine — but log so
		// operators notice when they expected a config file to be
		// picked up. Uses stderr because the structured logger is
		// not initialized yet at this point in startup.
		fmt.Fprintf(os.Stderr, "config: no %s.yaml found in ./configs — using defaults + env overrides\n", env)
	} else {
		fmt.Fprintf(os.Stderr, "config: loaded %s\n", v.ConfigFileUsed())
	}

	// Environment variable overrides
	v.SetEnvPrefix("")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	_ = v.BindEnv("server.port", "PORT")
	_ = v.BindEnv("database.url", "DATABASE_URL")
	_ = v.BindEnv("app.env", "APP_ENV")
	_ = v.BindEnv("api_key", "DINGIT_API_KEY")
	_ = v.BindEnv("rate_limit.enabled", "RATE_LIMIT_ENABLED")
	_ = v.BindEnv("rate_limit.requests_per_second", "RATE_LIMIT_RPS")
	_ = v.BindEnv("rate_limit.burst_size", "RATE_LIMIT_BURST")

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	if cfg.Database.URL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	// Refuse to start in production with a known weak shared default.
	// The old docker-compose.yml offered `dingit_dev_password` as a
	// fallback; a booted prod server with that string in its DSN is
	// almost certainly a misconfigured deploy.
	if cfg.IsProduction() {
		for _, weak := range weakPasswords {
			if strings.Contains(cfg.Database.URL, ":"+weak+"@") {
				return nil, fmt.Errorf("refusing to start in production with known weak DB password %q — set POSTGRES_PASSWORD", weak)
			}
		}
		// CORS wide-open check. Not a hard fail — there are legitimate
		// reasons to allow all origins (public API, no cookies) — but
		// it should be an explicit choice, not a default. Print a
		// prominent warning so operators notice during rollout.
		for _, o := range cfg.CORS.AllowedOrigins {
			if o == "*" {
				fmt.Fprintln(os.Stderr, "WARNING: CORS allowed_origins=* in production — confirm this is intentional")
				break
			}
		}
	}

	return &cfg, nil
}

// weakPasswords is the deny-list of shared defaults that must never be
// used in production. Keep this short — it's not a password strength
// checker, just a guard against copy/paste mistakes.
var weakPasswords = []string{
	"dingit_dev_password",
	"postgres",
	"password",
	"change_me_in_production",
	"changeme",
}
