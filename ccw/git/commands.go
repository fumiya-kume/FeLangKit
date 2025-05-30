package git

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// Cross-platform git command execution with timeout support

// CreateGitCommand creates a git command with cross-platform compatibility and timeout support
func CreateGitCommand(args []string, workingDir string) *exec.Cmd {
	return CreateGitCommandWithTimeout(args, workingDir, GetDefaultGitConfig().Timeout)
}

// CreateGitCommandWithTimeout creates git command with specific timeout
func CreateGitCommandWithTimeout(args []string, workingDir string, timeout time.Duration) *exec.Cmd {
	ctx, _ := context.WithTimeout(context.Background(), timeout)
	var cmd *exec.Cmd
	
	switch runtime.GOOS {
	case "windows":
		// On Windows, ensure git.exe is used
		if commandExists("git") {
			cmd = exec.CommandContext(ctx, "git", args...)
		} else {
			// Try common Git for Windows paths
			gitPaths := []string{
				"C:\\Program Files\\Git\\bin\\git.exe",
				"C:\\Program Files (x86)\\Git\\bin\\git.exe",
			}
			for _, gitPath := range gitPaths {
				if _, err := os.Stat(gitPath); err == nil {
					cmd = exec.CommandContext(ctx, gitPath, args...)
					break
				}
			}
			if cmd == nil {
				cmd = exec.CommandContext(ctx, "git", args...)
			}
		}
	default:
		// Unix systems
		cmd = exec.CommandContext(ctx, "git", args...)
	}
	
	if workingDir != "" {
		cmd.Dir = workingDir
	}
	
	return cmd
}

// ExecuteGitCommandWithRetry executes git command with retry logic
func ExecuteGitCommandWithRetry(args []string, workingDir string) error {
	config := GetDefaultGitConfig()
	
	for attempt := 1; attempt <= config.RetryAttempts; attempt++ {
		cmd := CreateGitCommandWithTimeout(args, workingDir, config.Timeout)
		err := cmd.Run()
		
		if err == nil {
			return nil // Success
		}
		
		// Check if this is a timeout or network error that might benefit from retry
		if attempt < config.RetryAttempts && isRetryableError(err) {
			time.Sleep(config.RetryDelay)
			continue
		}
		
		return fmt.Errorf("git command failed after %d attempts: %w", attempt, err)
	}
	
	return nil
}

// Check if an error is retryable
func isRetryableError(err error) bool {
	if err == nil {
		return false
	}
	
	errStr := strings.ToLower(err.Error())
	retryablePatterns := []string{
		"timeout",
		"connection reset",
		"connection refused",
		"network is unreachable",
		"temporary failure",
		"could not read from remote repository",
	}
	
	for _, pattern := range retryablePatterns {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}
	
	return false
}

// Check if a command exists in PATH
func commandExists(command string) bool {
	switch runtime.GOOS {
	case "windows":
		// Try with .exe extension first
		if _, err := exec.LookPath(command + ".exe"); err == nil {
			return true
		}
		// Try without extension
		_, err := exec.LookPath(command)
		return err == nil
	default:
		_, err := exec.LookPath(command)
		return err == nil
	}
}