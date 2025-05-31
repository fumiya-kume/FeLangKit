package git

import (
	"fmt"

	"ccw/types"
)

// Commit and push operations

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
		config:            g.appConfig,
	}

	// Convert types.Issue to git.Issue
	gitIssue := &Issue{
		Number: issue.Number,
		Title:  issue.Title,
		Body:   issue.Body,
	}
	commitMessage, err := generator.GenerateEnhancedCommitMessage(worktreePath, gitIssue)
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