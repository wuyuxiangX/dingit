package cmd

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
)

// exportPageSize is the fetch window for paginating through history.
// Not a flag because users don't care; --max is the real knob.
const exportPageSize = 100

var exportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export notification history to JSON or CSV",
	RunE:  runExport,
}

func init() {
	exportCmd.Flags().String("format", "json", "Output format: json or csv")
	exportCmd.Flags().String("output", "", "Write to file instead of stdout")
	exportCmd.Flags().String("status", "", "Filter by status (pending/actioned/dismissed/expired)")
	exportCmd.Flags().String("priority", "", "Filter by priority (urgent/high/normal/low)")
	exportCmd.Flags().Int("max", 10000, "Safety cap — stop after this many rows")

	rootCmd.AddCommand(exportCmd)
}

// csvHeader pins an ordered column set so notification shape drift on
// the server doesn't silently reorder the user's exported file.
var csvHeader = []string{
	"id",
	"timestamp",
	"priority",
	"status",
	"source",
	"title",
	"body",
	"actioned_value",
}

func runExport(cmd *cobra.Command, args []string) error {
	format, _ := cmd.Flags().GetString("format")
	outputPath, _ := cmd.Flags().GetString("output")
	status, _ := cmd.Flags().GetString("status")
	priority, _ := cmd.Flags().GetString("priority")
	maxRows, _ := cmd.Flags().GetInt("max")

	format = strings.ToLower(format)
	if format != "json" && format != "csv" {
		return fmt.Errorf("unsupported format %q (expected json or csv)", format)
	}

	c := newClient()

	// Dedup by id across pages. The server orders by timestamp DESC and
	// new notifications arriving mid-export would shift page boundaries,
	// causing page N+1 to re-serve rows already seen on page N. Tracking
	// ids the client already wrote is a cheap, server-agnostic guard.
	seen := make(map[string]struct{}, maxRows)
	all := make([]map[string]interface{}, 0, maxRows)
	page := 1
	for {
		result, err := c.List(status, priority, page, exportPageSize)
		if err != nil {
			return err
		}
		for _, item := range result.Items {
			id, _ := item["id"].(string)
			if _, dup := seen[id]; dup {
				continue
			}
			seen[id] = struct{}{}
			all = append(all, item)
			if len(all) >= maxRows {
				break
			}
		}
		if len(all) >= maxRows {
			fmt.Fprintf(os.Stderr, "warning: truncated at --max=%d rows\n", maxRows)
			break
		}
		if page >= result.TotalPages || len(result.Items) == 0 {
			break
		}
		page++
	}

	out := io.Writer(os.Stdout)
	if outputPath != "" {
		f, err := os.Create(outputPath)
		if err != nil {
			return fmt.Errorf("open output: %w", err)
		}
		defer f.Close()
		out = f
	}

	if format == "json" {
		enc := json.NewEncoder(out)
		enc.SetIndent("", "  ")
		return enc.Encode(all)
	}
	return writeCSV(out, all)
}

func writeCSV(out io.Writer, rows []map[string]interface{}) error {
	w := csv.NewWriter(out)
	defer w.Flush()

	if err := w.Write(csvHeader); err != nil {
		return err
	}
	for _, r := range rows {
		rec := make([]string, len(csvHeader))
		for i, col := range csvHeader {
			rec[i] = csvString(r[col])
		}
		if err := w.Write(rec); err != nil {
			return err
		}
	}
	return nil
}

// csvString renders a notification field value as a CSV cell. Go's
// encoding/csv already wraps fields containing newlines, commas, or
// quotes per RFC 4180, so we pass strings through untouched.
func csvString(v interface{}) string {
	switch x := v.(type) {
	case nil:
		return ""
	case string:
		return x
	case float64:
		return strconv.FormatFloat(x, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(x)
	default:
		b, err := json.Marshal(x)
		if err != nil {
			return ""
		}
		return string(b)
	}
}
