package internal

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// GitOperations handles all git-related operations
type GitOperations struct {
	basePath      string
	timeout       time.Duration
	retryAttempts int
	retryDelay    time.Duration
}

// NewGitOperations creates a new git operations instance
func NewGitOperations(basePath string) *GitOperations {
	return &GitOperations{
		basePath:      basePath,
		timeout:       2 * time.Minute,
		retryAttempts: 3,
		retryDelay:    2 * time.Second,
	}
}

// CreateWorktree creates a new git worktree for isolated development
func (g *GitOperations) CreateWorktree(worktreePath, branchName string) error {
	// Create parent directory if it doesn't exist
	parentDir := filepath.Dir(worktreePath)
	if err := os.MkdirAll(parentDir, 0755); err != nil {
		return fmt.Errorf("failed to create parent directory: %w", err)
	}

	// Create the worktree with the new branch
	cmd := g.createGitCommand("worktree", "add", "-b", branchName, worktreePath, "origin/master")
	cmd.Dir = g.basePath

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create git worktree: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// RemoveWorktree removes a git worktree
func (g *GitOperations) RemoveWorktree(worktreePath string) error {
	cmd := g.createGitCommand("worktree", "remove", "--force", worktreePath)
	cmd.Dir = filepath.Dir(worktreePath)

	if err := cmd.Run(); err != nil {
		// If git worktree remove fails, try manual cleanup
		return os.RemoveAll(worktreePath)
	}
	return nil
}

// ListWorktrees returns all active worktrees
func (g *GitOperations) ListWorktrees() ([]string, error) {
	cmd := g.createGitCommand("worktree", "list", "--porcelain")
	cmd.Dir = g.basePath

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list worktrees: %w", err)
	}

	var worktrees []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")
			if path != g.basePath {
				worktrees = append(worktrees, path)
			}
		}
	}
	return worktrees, nil
}

// CommitChanges stages all changes and creates a commit
func (g *GitOperations) CommitChanges(worktreePath, commitMessage string) error {
	// Stage all changes
	addCmd := g.createGitCommand("add", "--all")
	addCmd.Dir = worktreePath
	if err := addCmd.Run(); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Check if there are any changes to commit
	statusCmd := g.createGitCommand("status", "--porcelain")
	statusCmd.Dir = worktreePath
	output, err := statusCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check for changes: %w", err)
	}

	if strings.TrimSpace(string(output)) == "" {
		return fmt.Errorf("no changes to commit")
	}

	// Create commit
	commitCmd := g.createGitCommand("commit", "-m", commitMessage)
	commitCmd.Dir = worktreePath
	if err := commitCmd.Run(); err != nil {
		return fmt.Errorf("failed to create commit: %w", err)
	}

	return nil
}

// PushBranch pushes a branch to the remote repository
func (g *GitOperations) PushBranch(worktreePath, branchName string) error {
	return g.executeWithRetry(func() error {
		cmd := g.createGitCommand("push", "-u", "origin", branchName)
		cmd.Dir = worktreePath
		return cmd.Run()
	})
}

// SyncWithUpstream synchronizes with upstream master
func (g *GitOperations) SyncWithUpstream(worktreePath string) error {
	// Fetch latest changes
	if err := g.executeWithRetry(func() error {
		cmd := g.createGitCommand("fetch", "origin", "master")
		cmd.Dir = worktreePath
		return cmd.Run()
	}); err != nil {
		return fmt.Errorf("failed to fetch from origin: %w", err)
	}

	// Rebase onto latest master
	rebaseCmd := g.createGitCommand("rebase", "origin/master")
	rebaseCmd.Dir = worktreePath
	if err := rebaseCmd.Run(); err != nil {
		return fmt.Errorf("failed to rebase onto master: %w", err)
	}

	return nil
}

// HasUncommittedChanges checks if there are uncommitted changes
func (g *GitOperations) HasUncommittedChanges(worktreePath string) (bool, error) {
	cmd := g.createGitCommand("status", "--porcelain")
	cmd.Dir = worktreePath

	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// GetCurrentBranch returns the current branch name
func (g *GitOperations) GetCurrentBranch(worktreePath string) (string, error) {
	cmd := g.createGitCommand("branch", "--show-current")
	cmd.Dir = worktreePath

	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get current branch: %w", err)
	}

	return strings.TrimSpace(string(output)), nil
}

// CheckBranchExists checks if a branch exists on remote
func (g *GitOperations) CheckBranchExists(branchName string) (bool, error) {
	cmd := g.createGitCommand("ls-remote", "--heads", "origin", branchName)
	cmd.Dir = g.basePath

	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check remote branch: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// GenerateCommitMessage generates an AI-powered commit message
func (g *GitOperations) GenerateCommitMessage(worktreePath string) (string, error) {
	// For now, return a simple commit message
	// TODO: Integrate with Claude API for AI-generated messages
	return "feat: implement changes", nil
}

// ValidateRepository ensures we're in a valid git repository
func (g *GitOperations) ValidateRepository() error {
	cmd := g.createGitCommand("rev-parse", "--git-dir")
	cmd.Dir = g.basePath

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("not a git repository")
	}
	return nil
}

// Helper methods

func (g *GitOperations) createGitCommand(args ...string) *exec.Cmd {
	cmd := exec.Command("git", args...)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	return cmd
}

func (g *GitOperations) executeWithRetry(fn func() error) error {
	var lastErr error
	for i := 0; i < g.retryAttempts; i++ {
		if err := fn(); err != nil {
			lastErr = err
			if !isRetryableError(err) {
				return err
			}
			if i < g.retryAttempts-1 {
				time.Sleep(g.retryDelay)
			}
		} else {
			return nil
		}
	}
	return lastErr
}

func isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	errStr := err.Error()
	retryablePatterns := []string{
		"connection timed out",
		"network is unreachable",
		"connection reset by peer",
		"no route to host",
		"operation timed out",
		"SSL_ERROR_SYSCALL",
		"Failed to connect",
	}

	for _, pattern := range retryablePatterns {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}
	return false
}

// Quality validation

type ValidationResult struct {
	LintPassed  bool
	BuildPassed bool
	TestsPassed bool
	LintOutput  string
	BuildOutput string
	TestOutput  string
}

// ValidateImplementation runs SwiftLint, build, and tests
func ValidateImplementation(worktreePath string) (*ValidationResult, error) {
	result := &ValidationResult{}

	// Run SwiftLint
	lintCmd := exec.Command("swiftlint", "lint", "--quiet")
	lintCmd.Dir = worktreePath
	lintOutput, err := lintCmd.CombinedOutput()
	result.LintOutput = string(lintOutput)
	result.LintPassed = err == nil

	// Run build
	buildCmd := exec.Command("swift", "build")
	buildCmd.Dir = worktreePath
	buildOutput, err := buildCmd.CombinedOutput()
	result.BuildOutput = string(buildOutput)
	result.BuildPassed = err == nil

	// Run tests
	testCmd := exec.Command("swift", "test")
	testCmd.Dir = worktreePath
	testOutput, err := testCmd.CombinedOutput()
	result.TestOutput = string(testOutput)
	result.TestsPassed = err == nil

	return result, nil
}

// AutoFixLintIssues runs SwiftLint with --fix flag
func AutoFixLintIssues(worktreePath string) error {
	cmd := exec.Command("swiftlint", "lint", "--fix")
	cmd.Dir = worktreePath
	return cmd.Run()
}
