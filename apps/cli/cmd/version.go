package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/dingit-me/cli/internal/buildinfo"
	"github.com/spf13/cobra"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show dingit CLI version and build info",
	// --json field names mirror server /api/health/debug build_info
	// so CLI↔server versions can be diffed directly.
	RunE: func(cmd *cobra.Command, args []string) error {
		if jsonOutput {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "  ")
			return enc.Encode(map[string]string{
				"version":    buildinfo.Version,
				"commit_sha": buildinfo.CommitSHA,
				"built_at":   buildinfo.BuiltAt,
			})
		}
		fmt.Println("dingit " + buildinfo.String())
		return nil
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
