package cmd

import (
	"fmt"

	"github.com/dingit-me/cli/internal/config"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Configure CLI settings",
	Long: `Manage dingit configuration.

Available subcommands:
  list    List all config values
  get     Get a single config value
  set     Set a config value
  unset   Clear a config value
  path    Print config file path

Valid keys: server_url, api_key, default_source, default_priority, color`,
}

// --- subcommands ---

var configListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all config values",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		reveal, _ := cmd.Flags().GetBool("reveal")
		cfg := config.Load()
		fmt.Println("Current config:")
		for _, key := range config.ValidKeys {
			meta := config.KeyMeta[key]
			val := cfg.Get(key)
			display := config.FormatValue(val, meta.Sensitive, reveal)
			fmt.Printf("  %-18s %s\n", key+":", display)
		}
		return nil
	},
}

var configGetCmd = &cobra.Command{
	Use:               "get <key>",
	Short:             "Get a single config value",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeConfigKeys,
	RunE: func(cmd *cobra.Command, args []string) error {
		key := args[0]
		if err := config.ValidateKey(key); err != nil {
			return err
		}
		reveal, _ := cmd.Flags().GetBool("reveal")
		cfg := config.Load()
		meta := config.KeyMeta[key]
		val := cfg.Get(key)
		fmt.Println(config.FormatValue(val, meta.Sensitive, reveal))
		return nil
	},
}

var configSetCmd = &cobra.Command{
	Use:               "set <key> <value>",
	Short:             "Set a config value",
	Args:              cobra.ExactArgs(2),
	ValidArgsFunction: completeConfigKeys,
	RunE: func(cmd *cobra.Command, args []string) error {
		key, value := args[0], args[1]
		if err := config.ValidateKey(key); err != nil {
			return err
		}
		if err := config.ValidateValue(key, value); err != nil {
			return err
		}
		cfg := config.Load()
		cfg.Set(key, value)
		if err := cfg.Save(); err != nil {
			return err
		}
		meta := config.KeyMeta[key]
		fmt.Printf("Set %s = %s\n", key, config.FormatValue(value, meta.Sensitive, false))
		return nil
	},
}

var configUnsetCmd = &cobra.Command{
	Use:               "unset <key>",
	Short:             "Clear a config value",
	Args:              cobra.ExactArgs(1),
	ValidArgsFunction: completeConfigKeys,
	RunE: func(cmd *cobra.Command, args []string) error {
		key := args[0]
		if err := config.ValidateKey(key); err != nil {
			return err
		}
		cfg := config.Load()
		cfg.Unset(key)
		if err := cfg.Save(); err != nil {
			return err
		}
		// If the key has a default, surface it so users understand why
		// `config list` still shows a value after unset.
		if def := config.DefaultFor(key); def != "" {
			fmt.Printf("Unset %s (will use default: %s)\n", key, def)
		} else {
			fmt.Printf("Unset %s\n", key)
		}
		return nil
	},
}

var configPathCmd = &cobra.Command{
	Use:   "path",
	Short: "Print config file path",
	Args:  cobra.NoArgs,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println(config.Path())
	},
}

func init() {
	configCmd.AddCommand(configListCmd, configGetCmd, configSetCmd, configUnsetCmd, configPathCmd)

	// --reveal flag on list and get. Defined per-command (not package-
	// global) so test runs and long-lived cobra instances don't leak
	// state across invocations.
	configListCmd.Flags().Bool("reveal", false, "Show sensitive values in full")
	configGetCmd.Flags().Bool("reveal", false, "Show sensitive values in full")

	rootCmd.AddCommand(configCmd)
}

func completeConfigKeys(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	if len(args) >= 1 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	return config.ValidKeys, cobra.ShellCompDirectiveNoFileComp
}
