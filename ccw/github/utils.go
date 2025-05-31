package github

import (
	"encoding/json"
	"fmt"
	"os"
)

// debugLog provides debug logging helper functions
func debugLog(function, message string, context map[string]interface{}) {
	if os.Getenv("DEBUG_MODE") == "true" || os.Getenv("VERBOSE_MODE") == "true" {
		contextStr := ""
		if context != nil {
			if data, err := json.Marshal(context); err == nil {
				contextStr = string(data)
			}
		}

		fmt.Printf("[DEBUG] [GitHub:%s] %s", function, message)
		if contextStr != "" {
			fmt.Printf(" | Context: %s", contextStr)
		}
		fmt.Println()
	}
}

// truncateString truncates string for logging purposes
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}