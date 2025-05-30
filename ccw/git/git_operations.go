package git

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"ccw/github"
	"ccw/platform"
	"ccw/types"
)

// Git operations for worktree and branch management

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

// Git operation configuration is defined in types.go

// Default git operation configuration
func getDefaultGitConfig() *GitOperationConfig {
	return &GitOperationConfig{
		Timeout:       30 * time.Second,  // 30 second timeout for git operations
		RetryAttempts: 3,                 // Retry failed operations up to 3 times
		RetryDelay:    2 * time.Second,   // Wait 2 seconds between retries
	}
}

// Get git configuration from app config
func getGitConfigFromAppConfig(config *types.Config) *GitOperationConfig {
	gitConfig := getDefaultGitConfig()
	
	// Parse timeout from config
	if config.GitTimeout != "" {
		if timeout, err := time.ParseDuration(config.GitTimeout); err == nil {
			gitConfig.Timeout = timeout
		}
	}
	
	// Set retry attempts from config
	if config.GitRetryAttempts > 0 {
		gitConfig.RetryAttempts = config.GitRetryAttempts
	}
	
	return gitConfig
}

// Create git command with cross-platform compatibility and timeout support
func createGitCommand(args []string, workingDir string) *exec.Cmd {
	return createGitCommandWithTimeout(args, workingDir, getDefaultGitConfig().Timeout)
}

// Create git command with specific timeout
func createGitCommandWithTimeout(args []string, workingDir string, timeout time.Duration) *exec.Cmd {
	ctx, _ := context.WithTimeout(context.Background(), timeout)
	var cmd *exec.Cmd
	
	switch runtime.GOOS {
	case "windows":
		// On Windows, ensure git.exe is used
		if platform.CommandExists("git") {
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

// Execute git command with retry logic
func executeGitCommandWithRetry(args []string, workingDir string) error {
	config := getDefaultGitConfig()
	
	for attempt := 1; attempt <= config.RetryAttempts; attempt++ {
		cmd := createGitCommandWithTimeout(args, workingDir, config.Timeout)
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

// isRetryableError is defined in commands.go

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

// Push changes with enhanced commit message generation
func (g *GitOperations) PushChangesWithAICommit(worktreePath, branchName string, issue *types.Issue, claudeIntegration interface{}) error {
	// Add all changes using cross-platform command
	cmd := createGitCommand([]string{"add", "."}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Check if there are any changes to commit
	cmd = createGitCommand([]string{"diff", "--staged", "--quiet"}, worktreePath)
	if err := cmd.Run(); err == nil {
		// No changes to commit
		return fmt.Errorf("no changes to commit")
	}

	// Generate enhanced commit message
	generator := &CommitMessageGenerator{
		claudeIntegration: claudeIntegration,
		config:           g.appConfig,
	}
	
	commitMessage, err := generator.GenerateEnhancedCommitMessage(worktreePath, issue)
	if err != nil {
		// Fall back to simple commit message
		commitMessage = "Automated implementation via CCW\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
	}

	// Create commit with enhanced message
	cmd = createGitCommand([]string{"commit", "-m", commitMessage}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create commit: %w", err)
	}

	// Push to remote with retry logic for network operations
	if err := executeGitCommandWithRetry([]string{"push", "-u", "origin", branchName}, worktreePath); err != nil {
		return fmt.Errorf("failed to push changes: %w", err)
	}

	return nil
}

// Push changes to remote repository (legacy method)
func pushChanges(worktreePath, branchName string) error {
	// Add all changes using cross-platform command
	cmd := createGitCommand([]string{"add", "."}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Check if there are any changes to commit
	cmd = createGitCommand([]string{"diff", "--staged", "--quiet"}, worktreePath)
	if err := cmd.Run(); err == nil {
		// No changes to commit
		return fmt.Errorf("no changes to commit")
	}

	// Create commit with enhanced AI-generated message
	commitMessage := "Automated implementation via CCW\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
	cmd = createGitCommand([]string{"commit", "-m", commitMessage}, worktreePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create commit: %w", err)
	}

	// Push to remote with retry logic for network operations
	if err := executeGitCommandWithRetry([]string{"push", "-u", "origin", branchName}, worktreePath); err != nil {
		return fmt.Errorf("failed to push changes: %w", err)
	}

	return nil
}

// Check git repository status
func checkGitStatus(worktreePath string) (bool, error) {
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	// If output is empty, there are no changes
	return len(strings.TrimSpace(string(output))) > 0, nil
}

// Get current git branch
func getCurrentBranch(worktreePath string) (string, error) {
	cmd := exec.Command("git", "branch", "--show-current")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get current branch: %w", err)
	}

	return strings.TrimSpace(string(output)), nil
}

// Check if branch exists on remote
func checkRemoteBranch(worktreePath, branchName string) (bool, error) {
	cmd := exec.Command("git", "ls-remote", "--heads", "origin", branchName)
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check remote branch: %w", err)
	}

	return len(strings.TrimSpace(string(output))) > 0, nil
}

// Create worktree configuration
func createWorktreeConfig(issueURL string, worktreeBase string) (*types.WorktreeConfig, error) {
	// Extract issue information
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		return nil, err
	}

	// Generate unique branch name with timestamp
	timestamp := time.Now().Format("20060102-150405")
	branchName := fmt.Sprintf("issue-%d-%s", issueNumber, timestamp)
	
	// Create worktree path
	worktreePath := filepath.Join(worktreeBase, fmt.Sprintf("issue-%d-%s", issueNumber, timestamp))

	return &types.WorktreeConfig{
		BasePath:     worktreeBase,
		BranchName:   branchName,
		WorktreePath: worktreePath,
		IssueNumber:  issueNumber,
		CreatedAt:    time.Now(),
		Owner:        owner,
		Repository:   repo,
		IssueURL:     issueURL,
	}, nil
}

// Validate git repository
func validateGitRepository(path string) error {
	// Check if .git directory exists
	gitDir := filepath.Join(path, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		return fmt.Errorf("not a git repository: %s", path)
	}

	// Check if we can run git commands
	cmd := exec.Command("git", "status")
	cmd.Dir = path
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git repository is not accessible: %w", err)
	}

	return nil
}

// Get git repository information
func getGitRepoInfo(path string) (owner, repo string, err error) {
	cmd := exec.Command("git", "remote", "get-url", "origin")
	cmd.Dir = path
	output, err := cmd.Output()
	if err != nil {
		return "", "", fmt.Errorf("failed to get remote URL: %w", err)
	}

	remoteURL := strings.TrimSpace(string(output))
	
	// Parse GitHub URL
	if strings.Contains(remoteURL, "github.com") {
		// Handle both HTTPS and SSH URLs
		if strings.HasPrefix(remoteURL, "git@github.com:") {
			// SSH format: git@github.com:owner/repo.git
			parts := strings.TrimPrefix(remoteURL, "git@github.com:")
			parts = strings.TrimSuffix(parts, ".git")
			repoInfo := strings.Split(parts, "/")
			if len(repoInfo) == 2 {
				return repoInfo[0], repoInfo[1], nil
			}
		} else if strings.Contains(remoteURL, "https://github.com/") {
			// HTTPS format: https://github.com/owner/repo.git
			parts := strings.TrimPrefix(remoteURL, "https://github.com/")
			parts = strings.TrimSuffix(parts, ".git")
			repoInfo := strings.Split(parts, "/")
			if len(repoInfo) == 2 {
				return repoInfo[0], repoInfo[1], nil
			}
		}
	}

	return "", "", fmt.Errorf("unable to parse GitHub repository information from: %s", remoteURL)
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