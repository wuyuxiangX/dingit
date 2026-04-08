package cmd

import (
	"fmt"
	"os"

	"github.com/dingit-me/cli/internal/client"
	"github.com/dingit-me/cli/internal/config"
	"github.com/spf13/cobra"
)

var serverURL string
var apiKeyFlag string
var jsonOutput bool

var rootCmd = &cobra.Command{
	Use:   "dingit",
	Short: "Dingit CLI - Send and manage notifications",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&serverURL, "server", "", "Server URL override")
	rootCmd.PersistentFlags().StringVar(&apiKeyFlag, "api-key", "", "API key override")
	rootCmd.PersistentFlags().BoolVar(&jsonOutput, "json", false, "Output as JSON")
}

func newClient() *client.Client {
	cfg := config.Load()
	base := cfg.ServerURL
	if serverURL != "" {
		base = serverURL
	}
	apiKey := cfg.APIKey
	if apiKeyFlag != "" {
		apiKey = apiKeyFlag
	}
	return client.New(base, apiKey)
}
