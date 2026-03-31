package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var statusCmd = &cobra.Command{
	Use:   "status [notification-id]",
	Short: "Check notification status or server health",
	RunE:  runStatus,
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

func runStatus(cmd *cobra.Command, args []string) error {
	c := newClient()

	if len(args) > 0 {
		data, err := c.Get(args[0])
		if err != nil {
			return err
		}
		fmt.Printf("Notification: %s\n", data["id"])
		fmt.Printf("  Title:  %s\n", data["title"])
		fmt.Printf("  Status: %s\n", data["status"])
		fmt.Printf("  Source: %s\n", data["source"])
		if v, ok := data["actioned_value"]; ok && v != nil {
			fmt.Printf("  Action: %s\n", v)
		}
		return nil
	}

	health, err := c.Health()
	if err != nil {
		return err
	}
	fmt.Printf("Server Status: %s\n", health["status"])
	fmt.Printf("  Uptime: %.0fs\n", health["uptime_seconds"])
	fmt.Printf("  Connected clients: %.0f\n", health["connected_clients"])
	fmt.Printf("  Pending notifications: %.0f\n", health["pending_notifications"])
	return nil
}
