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

// waitForImplementationSummary waits for implementation summary with count-up timer
func (app *CCWApp) waitForImplementationSummary(summaryResultChan <-chan types.ImplementationSummaryResult) string {
	startTime := time.Now()
	ticker := time.NewTicker(5 * time.Second) // Less frequent updates for shorter task
	defer ticker.Stop()
	
	// Timer display channel
	timerDone := make(chan bool, 1)
	
	// Start timer display goroutine
	go func() {
		for {
			select {
			case <-ticker.C:
				elapsed := time.Since(startTime).Round(time.Second)
				timerIcon := getConsoleChar("⏱️", "[TIMER]")
				app.ui.Info(fmt.Sprintf("%s Implementation summary generation: %s elapsed", timerIcon, elapsed.String()))
			case <-timerDone:
				return
			}
		}
	}()
	
	// Wait for completion or timeout
	select {
	case summaryResult := <-summaryResultChan:
		// Stop timer display
		timerDone <- true
		
		elapsed := time.Since(startTime).Round(time.Second)
		if summaryResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Implementation summary generation failed after %s: %v", elapsed.String(), summaryResult.Error))
			return "Implementation completed with changes."
		} else {
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s Implementation summary generated in %s", successIcon, elapsed.String()))
			return summaryResult.Summary
		}
	case <-time.After(30 * time.Second):
		// Stop timer display
		timerDone <- true
		
		elapsed := time.Since(startTime).Round(time.Second)
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s Implementation summary generation timed out after %s", warningIcon, elapsed.String()))
		return "Implementation completed with changes."
	}
}


// pushChangesToRemote pushes branch changes to remote repository with progress tracking
func (app *CCWApp) pushChangesToRemote(branchName, worktreePath string) error {
	app.debugStep("step7", "Pushing changes to remote", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
	})
	
	// Start push progress tracking
	startTime := time.Now()
	app.ui.UpdateProgress("push", "in_progress")
	pushIcon := getConsoleChar("📤", "[PUSHING]")
	app.ui.Info(fmt.Sprintf("%s Pushing changes to remote...", pushIcon))
	
	// Push with timer (git push is usually fast, so no need for ticker updates)
	if err := app.gitOps.PushBranch(worktreePath, branchName); err != nil {
		elapsed := time.Since(startTime).Round(time.Second)
		app.ui.UpdateProgress("push", "failed")
		app.logger.Error("workflow", "Failed to push branch", map[string]interface{}{
			"branch_name":   branchName,
			"worktree_path": worktreePath,
			"error":         err.Error(),
			"elapsed_time":  elapsed.String(),
		})
		return fmt.Errorf("failed to push changes after %s: %w", elapsed.String(), err)
	}
	
	elapsed := time.Since(startTime).Round(time.Second)
	app.ui.UpdateProgress("push", "completed")
	successIcon := getConsoleChar("✅", "[SUCCESS]")
	app.ui.Success(fmt.Sprintf("%s Changes pushed successfully in %s!", successIcon, elapsed.String()))
	app.debugStep("step7", "Branch pushed successfully", map[string]interface{}{
		"elapsed_time": elapsed.String(),
	})
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

// waitForPRDescription waits for PR description generation with count-up timer
func (app *CCWApp) waitForPRDescription(prDescResultChan <-chan types.PRDescriptionResult, prDescRequest *types.PRDescriptionRequest) string {
	startTime := time.Now()
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	
	// Timer display channel
	timerDone := make(chan bool, 1)
	
	// Start timer display goroutine
	go func() {
		for {
			select {
			case <-ticker.C:
				elapsed := time.Since(startTime).Round(time.Second)
				timerIcon := getConsoleChar("⏱️", "[TIMER]")
				app.ui.Info(fmt.Sprintf("%s PR description generation: %s elapsed", timerIcon, elapsed.String()))
			case <-timerDone:
				return
			}
		}
	}()
	
	// Wait for completion or timeout
	select {
	case prDescResult := <-prDescResultChan:
		// Stop timer display
		timerDone <- true
		
		elapsed := time.Since(startTime).Round(time.Second)
		if prDescResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("PR description generation failed after %s: %v", elapsed.String(), prDescResult.Error))
			return app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
		} else {
			successIcon := getConsoleChar("✅", "[SUCCESS]")
			app.ui.Success(fmt.Sprintf("%s PR description generated in %s", successIcon, elapsed.String()))
			return prDescResult.Description
		}
	case <-time.After(2 * time.Minute): // Longer timeout for PR description
		// Stop timer display
		timerDone <- true
		
		elapsed := time.Since(startTime).Round(time.Second)
		warningIcon := getConsoleChar("⚠️", "[WARNING]")
		app.ui.Warning(fmt.Sprintf("%s PR description generation timed out after %s, using fallback", warningIcon, elapsed.String()))
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
		
		// After CI passes, check for PR comments and address them
		app.handlePRCommentsAfterSuccess(prURL)
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

// handlePRCommentsAfterSuccess handles PR comment analysis and addressing after CI success
func (app *CCWApp) handlePRCommentsAfterSuccess(prURL string) {
	commentIcon := getConsoleChar("💬", "[COMMENTS]")
	app.ui.Info(fmt.Sprintf("%s Checking PR comments for actionable items...", commentIcon))
	
	// Fetch PR comments
	comments, err := app.prManager.GetPRComments(prURL)
	if err != nil {
		app.ui.Warning(fmt.Sprintf("Failed to fetch PR comments: %v", err))
		return
	}
	
	// Analyze comments for actionable items
	analysis := app.prManager.AnalyzePRComments(comments)
	
	app.ui.Info(fmt.Sprintf("Found %d total comments, %d actionable", 
		analysis.TotalComments, len(analysis.ActionableComments)))
	
	if !analysis.HasUnaddressedComments {
		checkIcon := getConsoleChar("✅", "[COMPLETE]")
		app.ui.Success(fmt.Sprintf("%s No actionable comments found - PR is ready!", checkIcon))
		return
	}
	
	// Display actionable comments
	app.displayActionableComments(analysis)
	
	// Address comments with Claude Code
	if app.shouldAddressComments(analysis) {
		app.addressPRCommentsWithFeedbackLoop(prURL, analysis)
	}
}

// displayActionableComments shows actionable comments to the user
func (app *CCWApp) displayActionableComments(analysis *types.PRCommentAnalysis) {
	app.ui.Info("Actionable comments found:")
	
	for i, actionable := range analysis.ActionableComments {
		priorityIcon := app.getPriorityIcon(actionable.Priority)
		categoryIcon := app.getCategoryIcon(actionable.Category)
		
		app.ui.Info(fmt.Sprintf("  %d. %s %s [%s] by %s:", 
			i+1, priorityIcon, categoryIcon, actionable.Priority, actionable.Comment.User.Login))
		app.ui.Info(fmt.Sprintf("     %s", actionable.Suggestion))
		
		// Show comment preview (first 100 chars)
		preview := actionable.Comment.Body
		if len(preview) > 100 {
			preview = preview[:100] + "..."
		}
		app.ui.Info(fmt.Sprintf("     \"%s\"", preview))
		app.ui.Info(fmt.Sprintf("     URL: %s", actionable.Comment.HTMLURL))
		fmt.Println()
	}
}

// shouldAddressComments determines if comments should be automatically addressed
func (app *CCWApp) shouldAddressComments(analysis *types.PRCommentAnalysis) bool {
	// Count high priority actionable comments
	highPriorityCount := 0
	for _, actionable := range analysis.ActionableComments {
		if actionable.Priority == types.CommentPriorityHigh {
			highPriorityCount++
		}
	}
	
	// Address if there are high priority comments or multiple medium priority ones
	return highPriorityCount > 0 || len(analysis.ActionableComments) >= 2
}

// addressPRCommentsWithFeedbackLoop addresses comments and creates feedback loop
func (app *CCWApp) addressPRCommentsWithFeedbackLoop(prURL string, analysis *types.PRCommentAnalysis) {
	workIcon := getConsoleChar("🔧", "[ADDRESSING]")
	app.ui.Info(fmt.Sprintf("%s Addressing PR comments with Claude Code...", workIcon))
	
	// Address comments using Claude Code
	if err := app.addressCommentsWithClaudeCode(prURL, analysis); err != nil {
		app.ui.Warning(fmt.Sprintf("Failed to address comments: %v", err))
		return
	}
	
	// Push changes after addressing comments
	if err := app.pushCommentAddressingChanges(prURL); err != nil {
		app.ui.Warning(fmt.Sprintf("Failed to push comment addressing changes: %v", err))
		return
	}
	
	// Create feedback loop - go back to CI monitoring
	app.startFeedbackLoop(prURL)
}

// addressCommentsWithClaudeCode uses Claude Code to address PR comments
func (app *CCWApp) addressCommentsWithClaudeCode(prURL string, analysis *types.PRCommentAnalysis) error {
	claudeIcon := getConsoleChar("🤖", "[CLAUDE]")
	app.ui.Info(fmt.Sprintf("%s Running Claude Code to address comments...", claudeIcon))
	
	// Prepare Claude context with comment information
	claudeContext := &types.ClaudeContext{
		ProjectPath:      app.worktreeConfig.WorktreePath,
		TaskType:        "comment_addressing",
		PRCommentAnalysis: analysis,
		PRURL:           prURL,
	}
	
	// Run Claude Code with comment context
	return app.claudeIntegration.RunWithContext(claudeContext)
}

// pushCommentAddressingChanges pushes changes made to address comments
func (app *CCWApp) pushCommentAddressingChanges(prURL string) error {
	// Extract branch name from worktree config
	branchName := app.worktreeConfig.BranchName
	worktreePath := app.worktreeConfig.WorktreePath
	
	// Use existing push functionality
	return app.pushChangesToRemote(branchName, worktreePath)
}

// startFeedbackLoop creates a feedback loop back to CI monitoring
func (app *CCWApp) startFeedbackLoop(prURL string) {
	loopIcon := getConsoleChar("🔄", "[FEEDBACK]")
	app.ui.Info(fmt.Sprintf("%s Starting feedback loop - returning to CI monitoring...", loopIcon))
	
	// Add a short delay to allow CI to start
	time.Sleep(30 * time.Second)
	
	// Restart CI monitoring for the same PR
	app.ui.Info("Changes pushed - restarting CI monitoring...")
	app.monitorCIChecksWithGoroutines(prURL)
}

// Helper functions for icons
func (app *CCWApp) getPriorityIcon(priority types.CommentPriority) string {
	switch priority {
	case types.CommentPriorityHigh:
		return getConsoleChar("🔴", "[HIGH]")
	case types.CommentPriorityMedium:
		return getConsoleChar("🟡", "[MEDIUM]")
	case types.CommentPriorityLow:
		return getConsoleChar("🟢", "[LOW]")
	default:
		return getConsoleChar("⚪", "[UNKNOWN]")
	}
}

func (app *CCWApp) getCategoryIcon(category types.CommentCategory) string {
	switch category {
	case types.CommentCodeReview:
		return getConsoleChar("👨‍💻", "[CODE]")
	case types.CommentSuggestion:
		return getConsoleChar("💡", "[SUGGEST]")
	case types.CommentQuestion:
		return getConsoleChar("❓", "[QUESTION]")
	case types.CommentRequest:
		return getConsoleChar("📝", "[REQUEST]")
	case types.CommentApproval:
		return getConsoleChar("👍", "[APPROVAL]")
	case types.CommentDiscussion:
		return getConsoleChar("💭", "[DISCUSS]")
	case types.CommentBotGenerated:
		return getConsoleChar("🤖", "[BOT]")
	default:
		return getConsoleChar("💬", "[COMMENT]")
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