package app

import (
	"context"
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
		
		// Step 5: Monitor CI checks with enhanced Goroutine implementation
		app.monitorCIChecksWithGoroutines(prResult.PullRequest.HTMLURL)
		
	case <-time.After(1 * time.Minute):
		app.ui.UpdateProgress("pr_creation", "failed")
		return fmt.Errorf("PR creation timed out")
	}

	app.ui.UpdateProgress("complete", "completed")
	celebrationIcon := getConsoleChar("🎉", "[COMPLETE]")
	app.ui.Success(fmt.Sprintf("%s Async workflow completed successfully!", celebrationIcon))
	
	// Cleanup worktree
	app.cleanupWorktree(worktreePath)
	
	return nil
}

// monitorCIChecksWithGoroutines monitors CI checks with enhanced Goroutine implementation
func (app *CCWApp) monitorCIChecksWithGoroutines(prURL string) {
	loadingIcon := getConsoleChar("⏳", "[MONITORING]")
	app.ui.Info(fmt.Sprintf("%s Starting enhanced CI monitoring...", loadingIcon))
	
	// Create context with configurable timeout (default: 30 minutes)
	timeout := 30 * time.Minute
	
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Start CI monitoring with Goroutines
	watchChannel := app.prManager.WatchPRChecksWithGoroutine(ctx, prURL)
	
	go func() {
		// Process real-time updates
		for update := range watchChannel.Updates {
			app.handleCIUpdate(update)
		}
	}()

	// Wait for completion or timeout
	select {
	case result := <-watchChannel.Completion:
		app.handleCICompletion(result, prURL)
	case <-ctx.Done():
		app.ui.Warning("CI monitoring timed out - workflow completed but CI may still be running")
		// Send cancel signal
		select {
		case watchChannel.Cancel <- struct{}{}:
		default:
		}
	}
}

// handleCIUpdate processes real-time CI status updates
func (app *CCWApp) handleCIUpdate(update types.CIWatchUpdate) {
	switch update.EventType {
	case "monitoring_started":
		clockIcon := getConsoleChar("🕐", "[STARTED]")
		app.ui.Info(fmt.Sprintf("%s %s", clockIcon, update.Message))
		
	case "status_change":
		progressIcon := getConsoleChar("📈", "[UPDATE]")
		app.ui.Info(fmt.Sprintf("%s %s", progressIcon, update.Message))
		
		if update.Status != nil && update.Status.FailedChecks > 0 {
			failureIcon := getConsoleChar("❌", "[FAILED]")
			app.ui.Warning(fmt.Sprintf("%s CI failures detected - analyzing for recovery options", failureIcon))
			app.analyzeCIFailuresForRecovery(update.Status)
		}
		
	case "all_complete":
		if update.Status != nil && update.Status.Conclusion == "success" {
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s All CI checks passed!", successIcon))
		} else {
			failureIcon := getConsoleChar("❌", "[FAILED]")
			app.ui.Error(fmt.Sprintf("%s CI checks failed", failureIcon))
		}
		
	case "error":
		errorIcon := getConsoleChar("⚠️", "[ERROR]")
		app.ui.Warning(fmt.Sprintf("%s %s", errorIcon, update.Message))
	}
}

// handleCICompletion processes final CI monitoring results
func (app *CCWApp) handleCICompletion(result types.CIWatchResult, prURL string) {
	duration := result.Duration.Truncate(time.Second)
	
	if result.Error != nil {
		errorIcon := getConsoleChar("⚠️", "[ERROR]")
		app.ui.Error(fmt.Sprintf("%s CI monitoring failed after %v: %v", errorIcon, duration, result.Error))
		return
	}

	if result.FinalStatus == nil {
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s CI monitoring completed after %v but no final status available", warningIcon, duration))
		return
	}

	// Report final results
	if result.FinalStatus.Conclusion == "success" {
		successIcon := getConsoleChar("🎉", "[COMPLETE]")
		app.ui.Success(fmt.Sprintf("%s CI monitoring completed successfully after %v", successIcon, duration))
		app.ui.Success(fmt.Sprintf("Final status: %d checks passed, %d failed", 
			result.FinalStatus.PassedChecks, result.FinalStatus.FailedChecks))
	} else {
		failureIcon := getConsoleChar("❌", "[FAILED]")
		app.ui.Error(fmt.Sprintf("%s CI monitoring completed with failures after %v", failureIcon, duration))
		app.ui.Error(fmt.Sprintf("Final status: %d checks passed, %d failed", 
			result.FinalStatus.PassedChecks, result.FinalStatus.FailedChecks))
			
		// Analyze failures for potential recovery
		app.analyzeCIFailuresForRecovery(result.FinalStatus)
	}
}

// analyzeCIFailuresForRecovery analyzes CI failures and suggests recovery actions
func (app *CCWApp) analyzeCIFailuresForRecovery(status *types.CIStatus) {
	failures := app.prManager.AnalyzeCIFailures(status)
	if len(failures) == 0 {
		return
	}

	app.ui.Info("Analyzing CI failures for potential recovery:")
	
	for _, failure := range failures {
		if failure.Recoverable {
			recoveryIcon := getConsoleChar("🔧", "[RECOVERY]")
			app.ui.Info(fmt.Sprintf("%s %s failure detected: %s", recoveryIcon, failure.Type, failure.CheckName))
			
			switch failure.Type {
			case types.CIFailureLint:
				app.ui.Info("  → Consider running: swiftlint lint --fix")
			case types.CIFailureBuild:
				app.ui.Info("  → Consider reviewing build errors and dependencies")
			case types.CIFailureTest:
				app.ui.Info("  → Consider reviewing test failures and updating tests")
			}
			
			if failure.DetailsURL != "" {
				app.ui.Info(fmt.Sprintf("  → Details: %s", failure.DetailsURL))
			}
		} else {
			warningIcon := getConsoleChar("⚠️", "[MANUAL]")
			app.ui.Warning(fmt.Sprintf("%s Manual intervention required for: %s", warningIcon, failure.CheckName))
		}
	}
}

// monitorCIChecks - legacy function kept for backward compatibility
func (app *CCWApp) monitorCIChecks(prURL string) {
	// Delegate to new implementation
	app.monitorCIChecksWithGoroutines(prURL)
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