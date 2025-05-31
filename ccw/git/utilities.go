package git

import (
	"fmt"
	"os/exec"
	"time"
)

// Common git utility functions

// Get git configuration from app config
func getGitConfigFromAppConfig(config interface{}) *GitOperationConfig {
	gitConfig := GetDefaultGitConfig()

	// Since config is interface{}, we can't access fields directly
	// This would need to be implemented based on the actual config type
	// For now, return default config
	return gitConfig
}

// Create git command with cross-platform compatibility and timeout support
func createGitCommand(args []string, workingDir string) *exec.Cmd {
	return CreateGitCommand(args, workingDir)
}

// Create git command with specific timeout
func createGitCommandWithTimeout(args []string, workingDir string, timeout time.Duration) *exec.Cmd {
	return CreateGitCommandWithTimeout(args, workingDir, timeout)
}

// Execute git command with retry logic
func executeGitCommandWithRetry(args []string, workingDir string) error {
	return ExecuteGitCommandWithRetry(args, workingDir)
}

// Ensure git configuration is set
func ensureGitConfig(worktreePath string) error {
	// Check if user.name is set
	cmd := exec.Command("git", "config", "user.name")
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		// Set default user name
		cmd = exec.Command("git", "config", "user.name", "CCW Automation")
		cmd.Dir = worktreePath
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to set git user.name: %w", err)
		}
	}

	// Check if user.email is set
	cmd = exec.Command("git", "config", "user.email")
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		// Set default user email
		cmd = exec.Command("git", "config", "user.email", "ccw@automation.local")
		cmd.Dir = worktreePath
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to set git user.email: %w", err)
		}
	}

	return nil
}