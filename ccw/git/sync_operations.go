package git

import (
	"fmt"
	"os/exec"
	"strings"
)

// Sync, rebase, and conflict operations

// Sync with upstream before creating PR
func syncWithUpstream(worktreePath string) error {
	// Fetch latest changes from origin with retry logic
	if err := executeGitCommandWithRetry([]string{"fetch", "origin", "master"}, worktreePath); err != nil {
		return fmt.Errorf("failed to fetch from origin: %w", err)
	}

	// Rebase onto latest master (local operation, no retry needed)
	cmd := createGitCommand([]string{"rebase", "origin/master"}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to rebase onto master: %w", err)
	}

	return nil
}

// Check for merge conflicts
func checkMergeConflicts(worktreePath string) (bool, error) {
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	// Look for conflict markers
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "UU ") || strings.HasPrefix(line, "AA ") {
			return true, nil
		}
	}

	return false, nil
}