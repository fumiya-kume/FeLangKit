package git

import (
	"fmt"
	"path/filepath"
	"time"

	"ccw/github"
	"ccw/types"
)

// Worktree configuration functions

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