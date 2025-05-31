package git

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Repository information and validation functions

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