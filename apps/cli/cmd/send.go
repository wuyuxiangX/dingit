package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"slices"
	"strings"
	"time"

	"github.com/dingit-me/cli/internal/client"
	"github.com/dingit-me/cli/internal/config"
	"github.com/spf13/cobra"
)

var sendCmd = &cobra.Command{
	Use:   "send",
	Short: "Send a notification",
	RunE:  runSend,
}

func init() {
	sendCmd.Flags().StringP("title", "t", "", "Notification title (required)")
	sendCmd.Flags().StringP("body", "b", "", "Notification body (required)")
	sendCmd.Flags().StringSliceP("action", "a", nil, "Action button labels (repeatable)")
	sendCmd.Flags().String("actions-json", "", "Actions as JSON array (advanced)")
	sendCmd.Flags().StringP("callback", "c", "", "Callback URL for responses")
	sendCmd.Flags().StringP("source", "s", "", "Notification source")
	sendCmd.Flags().StringP("priority", "p", "normal", "Notification priority (urgent/high/normal/low)")
	sendCmd.Flags().String("icon", "", "Icon name or URL for the notification source")
	sendCmd.Flags().BoolP("wait", "w", false, "Wait for user response (blocks)")
	sendCmd.Flags().Int("ttl", 0, "Notification TTL in seconds (0 = no expiry)")

	_ = sendCmd.MarkFlagRequired("title")
	_ = sendCmd.MarkFlagRequired("body")

	rootCmd.AddCommand(sendCmd)
}

func runSend(cmd *cobra.Command, args []string) error {
	cfg := config.Load()

	title, _ := cmd.Flags().GetString("title")
	body, _ := cmd.Flags().GetString("body")
	source, _ := cmd.Flags().GetString("source")
	callback, _ := cmd.Flags().GetString("callback")
	wait, _ := cmd.Flags().GetBool("wait")
	priority, _ := cmd.Flags().GetString("priority")
	actionLabels, _ := cmd.Flags().GetStringSlice("action")
	icon, _ := cmd.Flags().GetString("icon")
	actionsJSON, _ := cmd.Flags().GetString("actions-json")

	if !slices.Contains([]string{"urgent", "high", "normal", "low"}, priority) {
		return fmt.Errorf("invalid priority %q: must be one of urgent, high, normal, low", priority)
	}

	if source == "" {
		source = cfg.DefaultSource
	}

	var actions []map[string]interface{}
	if actionsJSON != "" {
		if err := json.Unmarshal([]byte(actionsJSON), &actions); err != nil {
			return fmt.Errorf("invalid actions-json: %w", err)
		}
	} else if len(actionLabels) > 0 {
		for _, label := range actionLabels {
			actions = append(actions, map[string]interface{}{
				"label": label,
				"value": strings.ToLower(strings.ReplaceAll(label, " ", "_")),
			})
		}
	}

	ttl, _ := cmd.Flags().GetInt("ttl")

	c := newClient()
	req := &client.SendRequest{
		Title:       title,
		Body:        body,
		Source:      source,
		Priority:    priority,
		Icon:        icon,
		Actions:     actions,
		CallbackURL: callback,
	}
	if ttl > 0 {
		req.TTL = &ttl
	}
	result, err := c.Send(req)
	if err != nil {
		return err
	}

	fmt.Printf("Notification sent: %s\n", result.ID)

	if wait {
		fmt.Println("Waiting for response...")
		return pollForResponse(c, result.ID)
	}
	return nil
}

func pollForResponse(c *client.Client, id string) error {
	timeout := time.After(5 * time.Minute)
	for {
		select {
		case <-timeout:
			return fmt.Errorf("timed out waiting for response after 5 minutes")
		case <-time.After(2 * time.Second):
		}

		data, err := c.Get(id)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Poll error: %v\n", err)
			continue
		}

		status, _ := data["status"].(string)
		switch status {
		case "actioned":
			action, _ := data["actioned_value"].(string)
			fmt.Printf("Response received: %s\n", action)
			return nil
		case "dismissed":
			return fmt.Errorf("notification was dismissed")
		case "expired":
			return fmt.Errorf("notification expired")
		}
	}
}
