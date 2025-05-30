package git

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Git operations for worktree and branch management

// CreateWorktree creates a git worktree for isolated development
func (g *Operations) CreateWorktree(branchName, worktreePath string) error {
	// Create the worktree directory
	if err := os.MkdirAll(filepath.Dir(worktreePath), 0755); err != nil {
		return fmt.Errorf("failed to create worktree directory: %w", err)
	}

	// Create git worktree using cross-platform command with timeout
	cmd := CreateGitCommandWithTimeout([]string{"worktree", "add", "-b", branchName, worktreePath, "HEAD"}, g.basePath, g.GetTimeout())

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create git worktree: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// RemoveWorktree removes a git worktree
func (g *Operations) RemoveWorktree(worktreePath string) error {
	// Get the parent directory to run git worktree remove from
	parentDir := filepath.Dir(worktreePath)

	// Remove the worktree using cross-platform command
	cmd := CreateGitCommand([]string{"worktree", "remove", "--force", worktreePath}, parentDir)
	if err := cmd.Run(); err != nil {
		// If git worktree remove fails, try manual cleanup
		return os.RemoveAll(worktreePath)
	}

	return nil
}

// PushBranch pushes a branch to remote repository with retry logic
func (g *Operations) PushBranch(worktreePath, branchName string) error {
	// Push to remote with retry logic for network operations
	if err := ExecuteGitCommandWithRetry([]string{"push", "-u", "origin", branchName}, worktreePath); err != nil {
		return fmt.Errorf("failed to push branch: %w", err)
	}

	return nil
}

// HasUncommittedChanges checks if there are uncommitted changes
func (g *Operations) HasUncommittedChanges(worktreePath string) (bool, error) {
	cmd := CreateGitCommand([]string{"status", "--porcelain"}, worktreePath)
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// GetCurrentBranch returns the current branch name
func (g *Operations) GetCurrentBranch(worktreePath string) (string, error) {
	cmd := CreateGitCommand([]string{"branch", "--show-current"}, worktreePath)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get current branch: %w", err)
	}

	return strings.TrimSpace(string(output)), nil
}

// ListWorktrees returns a list of all worktrees
func (g *Operations) ListWorktrees() ([]string, error) {
	cmd := CreateGitCommand([]string{"worktree", "list", "--porcelain"}, g.basePath)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list worktrees: %w", err)
	}

	var worktrees []string
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")
			// Skip the main worktree (usually the repository root)
			if path != g.basePath {
				worktrees = append(worktrees, path)
			}
		}
	}

	return worktrees, nil
}

// CheckBranchExists checks if a branch exists on remote
func (g *Operations) CheckBranchExists(branchName string) (bool, error) {
	cmd := CreateGitCommand([]string{"ls-remote", "--heads", "origin", branchName}, g.basePath)
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check remote branch: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// SyncWithUpstream synchronizes with upstream before creating PR
func (g *Operations) SyncWithUpstream(worktreePath string) error {
	// Fetch latest changes from origin with retry logic
	if err := ExecuteGitCommandWithRetry([]string{"fetch", "origin", "master"}, worktreePath); err != nil {
		return fmt.Errorf("failed to fetch from origin: %w", err)
	}

	// Rebase onto latest master (local operation, no retry needed)
	cmd := CreateGitCommand([]string{"rebase", "origin/master"}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to rebase onto master: %w", err)
	}

	return nil
}

// CommitChanges stages all changes and creates a commit with the provided message
func (g *Operations) CommitChanges(worktreePath, commitMessage string) error {
	// Stage all changes
	addCmd := CreateGitCommand([]string{"add", "."}, worktreePath)
	if err := addCmd.Run(); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Check if there are any changes to commit
	statusCmd := CreateGitCommand([]string{"status", "--porcelain"}, worktreePath)
	output, err := statusCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check for changes: %w", err)
	}

	if strings.TrimSpace(string(output)) == "" {
		return fmt.Errorf("no changes to commit")
	}

	// Create commit with the provided message
	commitCmd := CreateGitCommand([]string{"commit", "-m", commitMessage}, worktreePath)
	if err := commitCmd.Run(); err != nil {
		return fmt.Errorf("failed to create commit: %w", err)
	}

	return nil
}
