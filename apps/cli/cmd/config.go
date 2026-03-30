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
		return nil
	}

	server, _ := cmd.Flags().GetString("set-server")
	source, _ := cmd.Flags().GetString("set-source")

	if server == "" && source == "" {
		fmt.Println("Use --set-server or --set-source to set config, or --show to view.")
		return nil
	}

	if server != "" {
		cfg.ServerURL = server
	}
	if source != "" {
		cfg.DefaultSource = source
	}

	if err := cfg.Save(); err != nil {
		return err
	}
	fmt.Println("Config saved.")
	return nil
}
