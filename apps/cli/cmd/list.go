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
	listCmd.Flags().String("priority", "", "Filter by priority (urgent/high/normal/low)")
	listCmd.Flags().Int("page", 1, "Page number")
	listCmd.Flags().Int("page-size", 20, "Results per page")
	listCmd.Flags().Int("limit", 0, "Alias for --page-size")

	rootCmd.AddCommand(listCmd)
}

func runList(cmd *cobra.Command, args []string) error {
	status, _ := cmd.Flags().GetString("status")
	priority, _ := cmd.Flags().GetString("priority")
	page, _ := cmd.Flags().GetInt("page")
	pageSize, _ := cmd.Flags().GetInt("page-size")
	limit, _ := cmd.Flags().GetInt("limit")

	if limit > 0 && !cmd.Flags().Changed("page-size") {
		pageSize = limit
	}

	c := newClient()
	result, err := c.List(status, priority, page, pageSize)
	if err != nil {
		return err
	}

	if len(result.Items) == 0 {
		fmt.Println("No notifications found.")
		return nil
	}

	fmt.Printf("Notifications (%d total):\n", result.Total)
	fmt.Println(strings.Repeat("─", 60))

	for _, n := range result.Items {
		s, _ := n["status"].(string)
		id, _ := n["id"].(string)
		title, _ := n["title"].(string)
		source, _ := n["source"].(string)
		ts, _ := n["timestamp"].(string)
		p, _ := n["priority"].(string)

		priorityTag := ""
		if p != "" && p != "normal" {
			priorityTag = fmt.Sprintf(" [%s]", strings.ToUpper(p))
		}

		fmt.Printf("  [%s]%s %s\n", strings.ToUpper(s), priorityTag, id)
		fmt.Printf("  %s (from: %s)\n", title, source)
		fmt.Printf("  %s\n\n", ts)
	}

	fmt.Printf("Page %d of %d (%d total)\n", result.Page, result.TotalPages, result.Total)
	return nil
}
