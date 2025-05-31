package github

import (
	"fmt"
	"os/exec"
)

// CheckGHCLI checks if gh CLI is available and authenticated
func CheckGHCLI() error {
	debugLog("CheckGHCLI", "Checking gh CLI availability and authentication", nil)

	// Check if gh command is available
	if _, err := exec.LookPath("gh"); err != nil {
		debugLog("CheckGHCLI", "gh CLI not found in PATH", map[string]interface{}{
			"error": err.Error(),
		})
		return fmt.Errorf("gh CLI is not installed. Please install it: brew install gh")
	}

	debugLog("CheckGHCLI", "gh CLI found in PATH", nil)

	// Check if user is authenticated
	cmd := exec.Command("gh", "auth", "status")
	output, err := cmd.CombinedOutput()

	if err != nil {
		debugLog("CheckGHCLI", "gh auth status failed", map[string]interface{}{
			"error":  err.Error(),
			"output": string(output),
		})
		return fmt.Errorf("gh CLI is not authenticated. Please run: gh auth login")
	}

	debugLog("CheckGHCLI", "gh CLI authentication verified", map[string]interface{}{
		"output": string(output),
	})

	return nil
}