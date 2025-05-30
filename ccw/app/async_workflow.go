package app

import (
	"fmt"
	"os"
	"strings"
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
		
		// Step 5: Monitor CI checks with proper Goroutine implementation
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

// monitorCIChecksWithGoroutines monitors CI checks with proper Goroutine implementation
func (app *CCWApp) monitorCIChecksWithGoroutines(prURL string) {
	loadingIcon := getConsoleChar("⏳", "[MONITORING]")
	app.ui.Info(fmt.Sprintf("%s Starting continuous CI monitoring...", loadingIcon))
	
	// Create channels for real-time updates
	updateChan := make(chan types.CIWatchUpdate, 10)
	
	// Start CI monitoring with Goroutines
	resultChan := app.prManager.WatchPRChecksWithGoroutine(prURL, updateChan)
	
	// Handle real-time CI updates in a separate Goroutine
	go app.handleCIUpdates(updateChan)
	
	// Wait for final result
	select {
	case result := <-resultChan:
		if result.Error != nil {
			app.ui.Warning(fmt.Sprintf("CI monitoring encountered an error: %v", result.Error))
			// Try to recover or provide fallback
			app.handleCIMonitoringFailure(prURL, result.Error)
		} else {
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s CI monitoring completed successfully", successIcon))
			
			if result.Status != nil {
				if result.Status.IsCompleted && !result.Status.IsFailed {
					app.ui.Success(fmt.Sprintf("All CI checks passed! Final status: %s", result.Status.Conclusion))
				} else if result.Status.IsFailed {
					app.ui.Warning(fmt.Sprintf("Some CI checks failed. Final status: %s", result.Status.Conclusion))
					// Attempt CI failure recovery
					app.handleCIFailureRecovery(prURL, result.Status)
				}
			}
		}
	case <-time.After(35 * time.Minute): // Extended timeout for proper CI monitoring
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s CI monitoring timed out after 35 minutes", warningIcon))
	}
}

// handleCIUpdates processes real-time CI status updates
func (app *CCWApp) handleCIUpdates(updateChan <-chan types.CIWatchUpdate) {
	for update := range updateChan {
		switch update.Type {
		case "status":
			if update.Status != nil {
				spinnerIcon := getConsoleChar("🔄", "[CHECKING]")
				app.ui.Info(fmt.Sprintf("%s CI Status: %s (%d checks)", 
					spinnerIcon, update.Status.Status, len(update.Status.Checks)))
				
				// Display individual check statuses
				for _, check := range update.Status.Checks {
					checkIcon := getConsoleChar("⏳", "[PENDING]")
					if check.Status == "completed" {
						if check.Conclusion == "success" {
							checkIcon = getConsoleChar("✅", "[PASS]")
						} else {
							checkIcon = getConsoleChar("❌", "[FAIL]")
						}
					}
					app.ui.Info(fmt.Sprintf("  %s %s: %s", checkIcon, check.Name, check.Status))
				}
			}
		case "completed":
			celebrationIcon := getConsoleChar("🎉", "[COMPLETE]")
			app.ui.Success(fmt.Sprintf("%s %s", celebrationIcon, update.Message))
		case "failed":
			errorIcon := getConsoleChar("❌", "[FAILED]")
			app.ui.Warning(fmt.Sprintf("%s %s", errorIcon, update.Message))
		default:
			app.ui.Info(update.Message)
		}
	}
}

// handleCIMonitoringFailure handles CI monitoring failures with recovery
func (app *CCWApp) handleCIMonitoringFailure(prURL string, err error) {
	app.ui.Warning("Attempting to recover CI monitoring...")
	
	// Fallback to basic monitoring
	ciResultChan := app.prManager.MonitorPRChecksAsync(prURL, 2*time.Minute)
	
	select {
	case ciResult := <-ciResultChan:
		if ciResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Fallback CI monitoring also failed: %v", ciResult.Error))
		} else {
			app.ui.Info(fmt.Sprintf("Fallback CI Status: %s", ciResult.Status.Status))
		}
	case <-time.After(3 * time.Minute):
		app.ui.Info("CI monitoring will continue in background")
	}
}

// handleCIFailureRecovery attempts to recover from CI failures
func (app *CCWApp) handleCIFailureRecovery(prURL string, status *types.CIWatchStatus) {
	app.ui.Info("Analyzing CI failures for potential auto-fixes...")
	
	for _, check := range status.Checks {
		if check.Conclusion == "failure" {
			app.ui.Info(fmt.Sprintf("Failed check: %s", check.Name))
			
			// Identify common failure types and suggest fixes
			if strings.Contains(strings.ToLower(check.Name), "lint") {
				app.ui.Info("Lint failure detected - consider running SwiftLint fixes")
			} else if strings.Contains(strings.ToLower(check.Name), "build") {
				app.ui.Info("Build failure detected - check for compilation errors")
			} else if strings.Contains(strings.ToLower(check.Name), "test") {
				app.ui.Info("Test failure detected - review test results and fix failing tests")
			}
		}
	}
	
	app.ui.Info("Manual intervention may be required to fix CI failures")
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