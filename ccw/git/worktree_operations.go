package git

import (
	"fmt"
	"os"
	"path/filepath"

	"ccw/platform"
	"ccw/types"
)

// Additional worktree operations

// Setup git worktree for isolated development
func setupWorktree(config *types.WorktreeConfig) error {
	// Ensure the base path exists with platform-appropriate permissions
	if err := os.MkdirAll(config.BasePath, platform.GetFilePermissions(false)); err != nil {
		return fmt.Errorf("failed to create base path: %w", err)
	}

	// Create git worktree using cross-platform command execution
	cmd := createGitCommand([]string{"worktree", "add", config.WorktreePath, "master"}, config.BasePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create git worktree: %w", err)
	}

	// Create and checkout feature branch
	cmd = createGitCommand([]string{"checkout", "-b", config.BranchName}, config.WorktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create feature branch: %w", err)
	}

	return nil
}

// Remove git worktree after completion
func cleanupWorktree(worktreePath string) error {
	// Get the parent directory to run git worktree remove from
	parentDir := filepath.Dir(worktreePath)

	// Remove the worktree using cross-platform command
	cmd := createGitCommand([]string{"worktree", "remove", "--force", worktreePath}, parentDir)
	if err := cmd.Run(); err != nil {
		// If git worktree remove fails, try manual cleanup
		return os.RemoveAll(worktreePath)
	}

	return nil
}