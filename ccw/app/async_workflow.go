package app

import (
	"fmt"
	"time"

	"ccw/commit"
	"ccw/types"
)

// ExecuteAsyncPRWorkflow handles the async PR creation workflow
func (app *CCWApp) ExecuteAsyncPRWorkflow(issue *types.Issue, worktreePath, branchName string, validationResult *types.ValidationResult) error {
	app.debugStep("async_workflow", "Starting async PR creation workflow", map[string]interface{}{
		"worktree_path": worktreePath,
		"branch_name":   branchName,
	})

	// Step 1: Start async operations concurrently
	app.ui.Info("Starting async analysis and PR generation...")
	app.ui.UpdateProgress("analysis", "in_progress")

	// Start implementation summary generation (async)
	summaryResultChan := app.claudeIntegration.GenerateImplementationSummaryAsync(worktreePath)

	// Start commit message generation (async)
	issueForCommit := &commit.Issue{
		Number: issue.Number,
		Title:  issue.Title,
		Body:   issue.Body,
	}
	commitResultChan := app.commitGenerator.GenerateEnhancedCommitMessageAsync(worktreePath, issueForCommit)

	// Display progress while waiting for async operations
	app.ui.Info("⏳ Generating implementation summary...")
	app.ui.Info("⏳ Creating commit message...")

	// Wait for implementation summary with timeout
	implementationSummary := app.waitForImplementationSummary(summaryResultChan)
	
	// Wait for commit message with timeout
	commitMessage := app.waitForCommitMessage(commitResultChan, issue)
	
	// Use commit message for future commits (could be saved or used later)
	app.debugStep("commit_message", "Generated commit message", map[string]interface{}{
		"message": commitMessage,
	})

	app.ui.UpdateProgress("analysis", "completed")

	// Step 2: Push changes to remote
	if err := app.pushChangesToRemote(branchName, worktreePath); err != nil {
		return err
	}

	// Step 3: Generate PR description and create PR
	return app.createPullRequestAsync(issue, validationResult, implementationSummary, branchName, worktreePath)
}

// waitForImplementationSummary waits for implementation summary with timeout
func (app *CCWApp) waitForImplementationSummary(summaryResultChan <-chan types.ImplementationSummaryResult) string {
	select {
	case summaryResult := <-summaryResultChan:
		if summaryResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Implementation summary generation failed: %v", summaryResult.Error))
			return "Implementation completed with changes."
		} else {
			app.ui.Success("✅ Implementation summary generated")
			return summaryResult.Summary
		}
	case <-time.After(30 * time.Second):
		app.ui.Warning("⚠️ Implementation summary generation timed out")
		return "Implementation completed with changes."
	}
}

// waitForCommitMessage waits for commit message with timeout
func (app *CCWApp) waitForCommitMessage(commitResultChan <-chan commit.CommitMessageResult, issue *types.Issue) string {
	select {
	case commitResult := <-commitResultChan:
		if commitResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Commit message generation failed: %v", commitResult.Error))
			return fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
		} else {
			app.ui.Success("✅ Commit message generated")
			return commitResult.Message
		}
	case <-time.After(30 * time.Second):
		app.ui.Warning("⚠️ Commit message generation timed out")
		return fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
	}
}

// pushChangesToRemote pushes branch changes to remote repository
func (app *CCWApp) pushChangesToRemote(branchName, worktreePath string) error {
	app.debugStep("step7", "Pushing changes to remote", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
	})
	
	app.ui.Info("Pushing changes...")
	if err := app.gitOps.PushBranch(worktreePath, branchName); err != nil {
		app.logger.Error("workflow", "Failed to push branch", map[string]interface{}{
			"branch_name":   branchName,
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
		return fmt.Errorf("failed to push changes: %w", err)
	}
	
	app.debugStep("step7", "Branch pushed successfully", nil)
	return nil
}

// createPullRequestAsync generates PR description and creates PR asynchronously
func (app *CCWApp) createPullRequestAsync(issue *types.Issue, validationResult *types.ValidationResult, implementationSummary, branchName, worktreePath string) error {
	// Step 3: Start PR description generation (async)
	app.ui.UpdateProgress("pr_creation", "in_progress")
	app.ui.Info("⏳ Generating PR description...")

	prDescRequest := &types.PRDescriptionRequest{
		Issue: issue,
		WorktreeConfig: &types.WorktreeConfig{
			BasePath:     app.worktreeConfig.BasePath,
			BranchName:   app.worktreeConfig.BranchName,
			WorktreePath: app.worktreeConfig.WorktreePath,
			IssueNumber:  app.worktreeConfig.IssueNumber,
			CreatedAt:    app.worktreeConfig.CreatedAt,
			Owner:        app.worktreeConfig.Owner,
			Repository:   app.worktreeConfig.Repository,
			IssueURL:     app.worktreeConfig.IssueURL,
		},
		ValidationResult:      validationResult,
		ImplementationSummary: implementationSummary,
	}

	prDescResultChan := app.claudeIntegration.GeneratePRDescriptionAsync(prDescRequest)

	// Wait for PR description with progress indicator
	prDescription := app.waitForPRDescription(prDescResultChan, prDescRequest)

	// Step 4: Create PR (async)
	return app.createAndMonitorPR(issue, prDescription, branchName, worktreePath)
}

// waitForPRDescription waits for PR description generation with timeout
func (app *CCWApp) waitForPRDescription(prDescResultChan <-chan types.PRDescriptionResult, prDescRequest *types.PRDescriptionRequest) string {
	select {
	case prDescResult := <-prDescResultChan:
		if prDescResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("PR description generation failed: %v", prDescResult.Error))
			return app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
		} else {
			app.ui.Success("✅ PR description generated")
			return prDescResult.Description
		}
	case <-time.After(2 * time.Minute): // Longer timeout for PR description
		app.ui.Warning("⚠️ PR description generation timed out, using fallback")
		return app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
	}
}

// createAndMonitorPR creates PR and monitors CI checks
func (app *CCWApp) createAndMonitorPR(issue *types.Issue, prDescription, branchName, worktreePath string) error {
	app.ui.Info("⏳ Creating pull request...")
	prRequest := &types.PRRequest{
		Title: fmt.Sprintf("Resolve #%d: %s", issue.Number, issue.Title),
		Body:  prDescription,
		Head:  branchName,
		Base:  "master", // or "main"
		MaintainerCanModify: true,
	}

	prResultChan := app.prManager.CreatePullRequestAsync(prRequest, worktreePath)

	// Wait for PR creation
	select {
	case prResult := <-prResultChan:
		if prResult.Error != nil {
			app.ui.UpdateProgress("pr_creation", "failed")
			return fmt.Errorf("failed to create PR: %w", prResult.Error)
		}
		
		app.ui.UpdateProgress("pr_creation", "completed")
		app.ui.Success(fmt.Sprintf("✅ Pull request created: %s", prResult.PullRequest.HTMLURL))
		
		// Step 5: Monitor CI checks (async, optional)
		app.monitorCIChecks(prResult.PullRequest.HTMLURL)
		
	case <-time.After(1 * time.Minute):
		app.ui.UpdateProgress("pr_creation", "failed")
		return fmt.Errorf("PR creation timed out")
	}

	app.ui.UpdateProgress("complete", "completed")
	app.ui.Success("🎉 Async workflow completed successfully!")
	
	// Cleanup worktree
	app.cleanupWorktree(worktreePath)
	
	return nil
}

// monitorCIChecks monitors CI checks asynchronously
func (app *CCWApp) monitorCIChecks(prURL string) {
	app.ui.Info("⏳ Monitoring CI checks...")
	ciResultChan := app.prManager.MonitorPRChecksAsync(prURL, 5*time.Minute)
	
	select {
	case ciResult := <-ciResultChan:
		if ciResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("CI monitoring failed: %v", ciResult.Error))
		} else {
			app.ui.Info(fmt.Sprintf("CI Status: %s", ciResult.Status.Status))
		}
	case <-time.After(1 * time.Minute): // Short timeout for CI monitoring demo
		app.ui.Info("CI monitoring will continue in background")
	}
}

// cleanupWorktree removes the temporary worktree
func (app *CCWApp) cleanupWorktree(worktreePath string) {
	app.debugStep("step8", "Cleaning up worktree", map[string]interface{}{
		"worktree_path": worktreePath,
	})
	
	app.ui.Info("Cleaning up worktree...")
	if err := app.gitOps.RemoveWorktree(worktreePath); err != nil {
		app.logger.Error("workflow", "Failed to cleanup worktree", map[string]interface{}{
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
	} else {
		app.debugStep("step8", "Worktree cleaned up successfully", nil)
	}
}