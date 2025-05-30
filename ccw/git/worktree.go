package git

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"ccw/types"
)

// Git operations
type GitOperations struct {
	basePath  string
	config    *GitOperationConfig
	appConfig *types.Config // Add app config for commit generation
}

// Get timeout from config or default
func (g *GitOperations) getTimeout() time.Duration {
	if g.config != nil {
		return g.config.Timeout
	}
	return 30 * time.Second // default timeout
}

// Create git worktree
func (g *GitOperations) CreateWorktree(branchName, worktreePath string) error {
	// Create the worktree directory
	if err := os.MkdirAll(filepath.Dir(worktreePath), 0755); err != nil {
		return fmt.Errorf("failed to create worktree directory: %w", err)
	}

	// Create git worktree using cross-platform command with timeout
	cmd := createGitCommandWithTimeout([]string{"worktree", "add", "-b", branchName, worktreePath, "HEAD"}, g.basePath, g.getTimeout())
	cmd.Dir = g.basePath
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create git worktree: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// Remove git worktree
func (g *GitOperations) RemoveWorktree(worktreePath string) error {
	cmd := exec.Command("git", "worktree", "remove", worktreePath, "--force")
	cmd.Dir = g.basePath
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to remove git worktree: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// List all worktrees
func (g *GitOperations) ListWorktrees() ([]string, error) {
	cmd := exec.Command("git", "worktree", "list", "--porcelain")
	cmd.Dir = g.basePath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to list worktrees: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	var worktrees []string
	
	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			worktreePath := strings.TrimPrefix(line, "worktree ")
			// Skip main worktree (current directory)
			if worktreePath != g.basePath && strings.Contains(worktreePath, "issue-") {
				worktrees = append(worktrees, worktreePath)
			}
		}
	}

	return worktrees, nil
}

// Check if there are uncommitted changes
func (g *GitOperations) HasUncommittedChanges(worktreePath string) (bool, error) {
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// Get list of changed files
func (g *GitOperations) GetChangedFiles(worktreePath string) ([]string, error) {
	cmd := exec.Command("git", "diff", "--name-only", "HEAD")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get changed files: %w", err)
	}

	files := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(files) == 1 && files[0] == "" {
		return []string{}, nil
	}

	return files, nil
}

// Push branch to remote
func (g *GitOperations) PushBranch(worktreePath, branchName string) error {
	cmd := exec.Command("git", "push", "-u", "origin", branchName)
	cmd.Dir = worktreePath
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to push branch: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// Cleanup orphaned branches
func (g *GitOperations) CleanupOrphanedBranches() error {
	// Get list of remote branches that have been merged
	cmd := exec.Command("git", "branch", "-r", "--merged", "origin/master")
	cmd.Dir = g.basePath
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list merged branches: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "origin/issue-") {
			branchName := strings.TrimPrefix(line, "origin/")
			
			// Delete the remote branch
			deleteCmd := exec.Command("git", "push", "origin", "--delete", branchName)
			deleteCmd.Dir = g.basePath
			if err := deleteCmd.Run(); err != nil {
				// Log error but continue with other branches
				fmt.Printf("Warning: failed to delete remote branch %s: %v\n", branchName, err)
			}
		}
	}

	return nil
}


// Check for branch conflicts
func (g *GitOperations) CheckBranchConflicts(branchName string) error {
	cmd := exec.Command("git", "show-ref", "--verify", "--quiet", fmt.Sprintf("refs/heads/%s", branchName))
	cmd.Dir = g.basePath
	
	if err := cmd.Run(); err == nil {
		// Branch exists, need to handle conflict
		return fmt.Errorf("branch %s already exists", branchName)
	}

	return nil
}

// Force cleanup of worktree (for error recovery)
func (g *GitOperations) ForceCleanupWorktree(worktreePath string) error {
	// Try normal removal first
	if err := g.RemoveWorktree(worktreePath); err == nil {
		return nil
	}

	// If that fails, manually remove directory
	if err := os.RemoveAll(worktreePath); err != nil {
		return fmt.Errorf("failed to force cleanup worktree: %w", err)
	}

	// Prune git worktree references
	cmd := exec.Command("git", "worktree", "prune")
	cmd.Dir = g.basePath
	if err := cmd.Run(); err != nil {
		// Log warning but don't fail
		fmt.Printf("Warning: failed to prune worktree references: %v\n", err)
	}

	return nil
}