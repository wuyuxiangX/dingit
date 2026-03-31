package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List notifications",
	RunE:  runList,
}

func init() {
	listCmd.Flags().String("status", "", "Filter by status (pending/actioned/dismissed/expired)")
	listCmd.Flags().Int("limit", 20, "Max results")

	rootCmd.AddCommand(listCmd)
}

func runList(cmd *cobra.Command, args []string) error {
	status, _ := cmd.Flags().GetString("status")
	limit, _ := cmd.Flags().GetInt("limit")

	c := newClient()
	notifications, total, err := c.List(status, limit)
	if err != nil {
		return err
	}

	if len(notifications) == 0 {
		fmt.Println("No notifications found.")
		return nil
	}

	fmt.Printf("Notifications (%d total):\n", total)
	fmt.Println(strings.Repeat("─", 60))

	for _, n := range notifications {
		s, _ := n["status"].(string)
		id, _ := n["id"].(string)
		title, _ := n["title"].(string)
		source, _ := n["source"].(string)
		ts, _ := n["timestamp"].(string)

		fmt.Printf("  [%s] %s\n", strings.ToUpper(s), id)
		fmt.Printf("  %s (from: %s)\n", title, source)
		fmt.Printf("  %s\n\n", ts)
	}
	return nil
}
