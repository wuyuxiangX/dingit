package cmd

import (
	"fmt"

	"github.com/dingit-me/cli/internal/config"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Configure CLI settings",
	RunE:  runConfig,
}

func init() {
	configCmd.Flags().String("set-server", "", "Set server URL")
	configCmd.Flags().String("set-source", "", "Set default source name")
	configCmd.Flags().String("set-api-key", "", "Set API key")
	configCmd.Flags().Bool("show", false, "Show current config")

	rootCmd.AddCommand(configCmd)
}

func runConfig(cmd *cobra.Command, args []string) error {
	cfg := config.Load()

	show, _ := cmd.Flags().GetBool("show")
	if show {
		fmt.Println("Current config:")
		fmt.Printf("  server_url:     %s\n", cfg.ServerURL)
		fmt.Printf("  default_source: %s\n", cfg.DefaultSource)
		if cfg.APIKey != "" {
			display := cfg.APIKey
			if len(display) > 15 {
				display = display[:15]
			}
			fmt.Printf("  api_key:        %s...\n", display)
		} else {
			fmt.Printf("  api_key:        (not set)\n")
		}
		return nil
	}

	server, _ := cmd.Flags().GetString("set-server")
	source, _ := cmd.Flags().GetString("set-source")
	apiKey, _ := cmd.Flags().GetString("set-api-key")

	if server == "" && source == "" && apiKey == "" {
		fmt.Println("Use --set-server, --set-source, or --set-api-key to set config, or --show to view.")
		return nil
	}

	if server != "" {
		cfg.ServerURL = server
	}
	if source != "" {
		cfg.DefaultSource = source
	}
	if apiKey != "" {
		cfg.APIKey = apiKey
	}

	if err := cfg.Save(); err != nil {
		return err
	}
	fmt.Println("Config saved.")
	return nil
}
