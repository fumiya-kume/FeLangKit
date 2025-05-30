package app

import (
	"fmt"
	"os"
	"time"

	"ccw/types"
)

// getConsoleChar returns console-safe characters based on CI environment
func getConsoleChar(fancy, simple string) string {
	if os.Getenv("CCW_CONSOLE_MODE") == "true" || 
	   os.Getenv("CI") == "true" || 
	   os.Getenv("GITHUB_ACTIONS") == "true" ||
	   os.Getenv("GITLAB_CI") == "true" ||
	   os.Getenv("JENKINS_URL") != "" {
		return simple
	}
	return fancy
}

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

	// Display progress while waiting for async operations
	loadingIcon := getConsoleChar("⏳", "[GENERATING]")
	app.ui.Info(fmt.Sprintf("%s Generating implementation summary...", loadingIcon))

	// Wait for implementation summary with timeout
	implementationSummary := app.waitForImplementationSummary(summaryResultChan)

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
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s Implementation summary generated", successIcon))
			return summaryResult.Summary
		}
	case <-time.After(30 * time.Second):
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s Implementation summary generation timed out", warningIcon))
		return "Implementation completed with changes."
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
	loadingIcon := getConsoleChar("⏳", "[GENERATING]")
	app.ui.Info(fmt.Sprintf("%s Generating PR description...", loadingIcon))

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
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s PR description generated", successIcon))
			return prDescResult.Description
		}
	case <-time.After(2 * time.Minute): // Longer timeout for PR description
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s PR description generation timed out, using fallback", warningIcon))
		return app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
	}
}

// createAndMonitorPR creates PR and monitors CI checks
func (app *CCWApp) createAndMonitorPR(issue *types.Issue, prDescription, branchName, worktreePath string) error {
	loadingIcon := getConsoleChar("⏳", "[CREATING]")
	app.ui.Info(fmt.Sprintf("%s Creating pull request...", loadingIcon))
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
		successIcon := getConsoleChar("✅", "[SUCCESS]")
		app.ui.Success(fmt.Sprintf("%s Pull request created: %s", successIcon, prResult.PullRequest.HTMLURL))
		
		// Step 5: Monitor CI checks with proper Goroutine-based watching
		app.monitorCIChecksWithGoroutines(prResult.PullRequest, branchName, worktreePath)
		
		// Mark workflow as complete only after CI monitoring finishes
		app.ui.UpdateProgress("complete", "completed")
		celebrationIcon := getConsoleChar("🎉", "[COMPLETE]")
		app.ui.Success(fmt.Sprintf("%s Async workflow completed successfully!", celebrationIcon))
		
		// Cleanup worktree
		app.cleanupWorktree(worktreePath)
		
		return nil
		
	case <-time.After(1 * time.Minute):
		app.ui.UpdateProgress("pr_creation", "failed")
		return fmt.Errorf("PR creation timed out")
	}
}

// monitorCIChecksWithGoroutines monitors CI checks using Goroutines with proper real-time updates
func (app *CCWApp) monitorCIChecksWithGoroutines(pr *types.PullRequest, branchName, worktreePath string) {
	loadingIcon := getConsoleChar("⏳", "[MONITORING]")
	app.ui.Info(fmt.Sprintf("%s Starting continuous CI monitoring...", loadingIcon))
	
	// Create CI watch request with proper configuration
	request := &types.CIWatchRequest{
		PRURL:            pr.HTMLURL,
		PRNumber:         pr.Number,
		WorktreePath:     worktreePath,
		BranchName:       branchName,
		MaxWaitTime:      30 * time.Minute, // Much longer timeout for real CI monitoring
		UpdateInterval:   10 * time.Second,
		EnableRecovery:   true,
		RecoveryAttempts: 2,
	}
	
	// Start CI monitoring with recovery
	updateChan := app.prManager.WatchPRChecksWithRecovery(request)
	
	// Process real-time updates
	for update := range updateChan {
		if update.Error != nil {
			warningIcon := getConsoleChar("⚠️", "[WARNING]")
			app.ui.Warning(fmt.Sprintf("%s CI monitoring error: %v", warningIcon, update.Error))
		} else if update.Status != nil {
			app.displayCIStatus(update.Status, update.Message)
		} else if update.Message != "" {
			infoIcon := getConsoleChar("ℹ️", "[INFO]")
			app.ui.Info(fmt.Sprintf("%s %s", infoIcon, update.Message))
		}
		
		// Check if monitoring completed
		if update.Completed {
			if update.Status != nil && update.Status.Status == "success" {
				successIcon := getConsoleChar("✅", "[SUCCESS]")
				app.ui.Success(fmt.Sprintf("%s All CI checks passed!", successIcon))
			} else if update.Error == nil {
				completedIcon := getConsoleChar("🏁", "[COMPLETED]")
				app.ui.Info(fmt.Sprintf("%s CI monitoring completed", completedIcon))
			}
			break
		}
	}
}

// displayCIStatus displays detailed CI status information
func (app *CCWApp) displayCIStatus(status *types.CIStatus, message string) {
	if status.TotalChecks == 0 {
		return
	}
	
	// Display summary
	statusIcon := getConsoleChar("📊", "[STATUS]")
	summary := fmt.Sprintf("%s CI Status: %d total, %d passing, %d failing, %d pending", 
		statusIcon, status.TotalChecks, status.PassingChecks, status.FailingChecks, status.PendingChecks)
	
	switch status.Status {
	case "success":
		app.ui.Success(summary)
	case "failure":
		app.ui.Warning(summary)
		// Display failure details
		for _, failure := range status.FailureDetails {
			failIcon := getConsoleChar("❌", "[FAIL]")
			app.ui.Warning(fmt.Sprintf("  %s %s (%s): %s", failIcon, failure.CheckName, failure.FailType, failure.Message))
		}
	case "pending":
		app.ui.Info(summary)
	default:
		app.ui.Info(summary)
	}
	
	if message != "" {
		app.ui.Info(fmt.Sprintf("  %s", message))
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