package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"ccw/commit"
	"ccw/git"
	"ccw/github"
	"ccw/types"
)

// getConsoleChar returns console-safe characters based on CI environment
func getConsoleCharWorkflow(fancy, simple string) string {
	if os.Getenv("CCW_CONSOLE_MODE") == "true" || 
	   os.Getenv("CI") == "true" || 
	   os.Getenv("GITHUB_ACTIONS") == "true" ||
	   os.Getenv("GITLAB_CI") == "true" ||
	   os.Getenv("JENKINS_URL") != "" {
		return simple
	}
	return fancy
}

// ExecuteListWorkflow handles interactive issue selection workflow
func (app *CCWApp) ExecuteListWorkflow(repoURL string, state string, labels []string, limit int) error {
	// Extract repository information
	owner, repo, err := github.ExtractRepoInfo(repoURL)
	if err != nil {
		return fmt.Errorf("failed to extract repository info: %w", err)
	}

	app.ui.Info(fmt.Sprintf("Fetching issues from %s/%s...", owner, repo))
	
	// Fetch issues from GitHub
	issues, err := app.githubClient.ListIssues(owner, repo, state, labels, limit)
	if err != nil {
		return fmt.Errorf("failed to fetch issues: %w", err)
	}

	if len(issues) == 0 {
		app.ui.Warning("No issues found matching the criteria")
		return nil
	}

	// Display issue selection interface
	selectedIssues, err := app.ui.DisplayIssueSelection(issues)
	if err != nil {
		return fmt.Errorf("issue selection failed: %w", err)
	}

	app.ui.Info(fmt.Sprintf("Selected %d issue(s) for processing", len(selectedIssues)))

	// Process each selected issue
	for i, issue := range selectedIssues {
		app.ui.Info(fmt.Sprintf("Processing issue %d of %d: #%d %s", i+1, len(selectedIssues), issue.Number, issue.Title))
		
		// Construct issue URL
		issueURL := fmt.Sprintf("https://github.com/%s/%s/issues/%d", owner, repo, issue.Number)
		
		// Execute normal workflow for this issue
		if err := app.ExecuteWorkflow(issueURL); err != nil {
			app.ui.Warning(fmt.Sprintf("Failed to process issue #%d: %v", issue.Number, err))
			// Continue with next issue rather than failing completely
			continue
		}
		
		app.ui.Success(fmt.Sprintf("Successfully processed issue #%d", issue.Number))
	}

	app.ui.Success("All selected issues have been processed!")
	return nil
}

// ExecuteWorkflow runs the main workflow for a given issue URL
func (app *CCWApp) ExecuteWorkflow(issueURL string) error {
	app.debugStep("executeWorkflow", "Starting workflow execution", map[string]interface{}{
		"issue_url": issueURL,
	})
	
	if app.ui.GetAnimations() {
		app.ui.DisplayProgressHeaderWithBackground()
	} else {
		app.ui.DisplayHeader()
	}

	// Step 1: Extract issue info
	app.debugStep("step1", "Extracting issue information", map[string]interface{}{
		"issue_url": issueURL,
	})
	
	app.ui.UpdateProgress("setup", "in_progress")
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		app.logger.Error("workflow", "Failed to extract issue info", map[string]interface{}{
			"issue_url": issueURL,
			"error":     err.Error(),
		})
		return fmt.Errorf("failed to extract issue info: %w", err)
	}

	app.debugStep("step1", "Issue info extracted successfully", map[string]interface{}{
		"owner":        owner,
		"repo":         repo,
		"issue_number": issueNumber,
	})
	
	app.ui.Info(fmt.Sprintf("Processing issue #%d from %s/%s", issueNumber, owner, repo))

	// Step 2: Fetch issue data
	app.debugStep("step2", "Fetching GitHub issue data", map[string]interface{}{
		"owner":        owner,
		"repo":         repo,
		"issue_number": issueNumber,
	})
	
	app.ui.UpdateProgress("fetch", "in_progress")
	app.ui.Info("Fetching GitHub issue data...")
	
	issue, err := app.githubClient.GetIssue(owner, repo, issueNumber)
	if err != nil {
		app.ui.UpdateProgress("fetch", "failed")
		app.logger.Error("workflow", "Failed to fetch issue data", map[string]interface{}{
			"owner":        owner,
			"repo":         repo,
			"issue_number": issueNumber,
			"error":        err.Error(),
		})
		return fmt.Errorf("failed to fetch issue data: %w", err)
	}
	
	app.debugStep("step2", "Issue data fetched successfully", map[string]interface{}{
		"issue_title":  issue.Title,
		"issue_state":  issue.State,
		"issue_labels": len(issue.Labels),
		"issue_body":   truncateForLog(issue.Body, 200),
	})
	
	app.ui.UpdateProgress("fetch", "completed")

	// Step 3: Setup development environment
	if err := app.setupDevelopmentEnvironment(issue, issueNumber, owner, repo, issueURL); err != nil {
		return err
	}

	// Step 4: Run implementation
	if err := app.runImplementation(issue); err != nil {
		return err
	}

	// Step 5: Validate implementation with recovery
	validationResult, err := app.validateImplementationWithRecovery(issue)
	if err != nil {
		return err
	}

	// Step 6: Commit changes (REQUIRED before PR creation)
	if validationResult.Success {
		if err := app.commitChanges(issue); err != nil {
			return err
		}
		
		// Step 7: Execute async PR workflow after successful commit
		// Convert back to git.ValidationResult for async workflow
		gitValidationForAsync := convertTypesToGitValidationResult(validationResult)
		return app.executeAsyncWorkflow(issue, gitValidationForAsync)
	}

	app.ui.Warning("Implementation validation failed after all recovery attempts")
	app.logger.Error("workflow", "Implementation validation failed after recovery", map[string]interface{}{
		"validation_errors": validationResult.Errors,
		"worktree_path":     app.worktreeConfig.WorktreePath,
		"recovery_attempts": app.config.MaxRetries,
	})
	return fmt.Errorf("validation failed after %d recovery attempts", app.config.MaxRetries)
}

// setupDevelopmentEnvironment creates worktree and saves issue data
func (app *CCWApp) setupDevelopmentEnvironment(issue *types.Issue, issueNumber int, owner, repo, issueURL string) error {
	app.debugStep("step3", "Creating isolated development environment", map[string]interface{}{
		"issue_number": issueNumber,
	})
	
	app.ui.Info("Creating isolated development environment...")
	branchName := generateBranchName(issueNumber)
	worktreePath := filepath.Join(app.config.WorktreeBase, branchName)
	
	app.debugStep("step3", "Generated worktree configuration", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
		"base_path":     app.config.WorktreeBase,
	})
	
	app.worktreeConfig = &git.WorktreeConfig{
		BasePath:     app.config.WorktreeBase,
		BranchName:   branchName,
		WorktreePath: worktreePath,
		IssueNumber:  issueNumber,
		CreatedAt:    time.Now(),
		Owner:        owner,
		Repository:   repo,
		IssueURL:     issueURL,
	}

	// Create git worktree using new package
	if err := app.gitOps.CreateWorktree(branchName, worktreePath); err != nil {
		app.ui.UpdateProgress("setup", "failed")
		app.logger.Error("workflow", "Failed to create worktree", map[string]interface{}{
			"branch_name":   branchName,
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
		return fmt.Errorf("failed to create worktree: %w", err)
	}
	
	app.debugStep("step3", "Worktree created successfully", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
	})
	
	app.ui.UpdateProgress("setup", "completed")

	// Save issue and worktree data
	app.debugStep("step4", "Saving issue and worktree data", map[string]interface{}{
		"worktree_path": worktreePath,
	})
	
	issueDataFile := filepath.Join(worktreePath, ".issue-data.json")
	issueData, _ := json.MarshalIndent(issue, "", "  ")
	if err := os.WriteFile(issueDataFile, issueData, 0644); err != nil {
		app.logger.Error("workflow", "Failed to save issue data", map[string]interface{}{
			"file":  issueDataFile,
			"error": err.Error(),
		})
	}

	worktreeDataFile := filepath.Join(worktreePath, ".worktree-config.json")
	worktreeData, _ := json.MarshalIndent(app.worktreeConfig, "", "  ")
	if err := os.WriteFile(worktreeDataFile, worktreeData, 0644); err != nil {
		app.logger.Error("workflow", "Failed to save worktree config", map[string]interface{}{
			"file":  worktreeDataFile,
			"error": err.Error(),
		})
	}

	return nil
}

// runImplementation executes Claude Code implementation
func (app *CCWApp) runImplementation(issue *types.Issue) error {
	app.debugStep("step5", "Starting Claude Code implementation", map[string]interface{}{
		"worktree_path": app.worktreeConfig.WorktreePath,
		"issue_number":  issue.Number,
	})
	
	app.ui.UpdateProgress("implementation", "in_progress")
	app.ui.Info("Running implementation...")
	
	// Convert git.WorktreeConfig to types.WorktreeConfig
	typesWorktreeConfig := &types.WorktreeConfig{
		BasePath:     app.worktreeConfig.BasePath,
		BranchName:   app.worktreeConfig.BranchName,
		WorktreePath: app.worktreeConfig.WorktreePath,
		IssueNumber:  app.worktreeConfig.IssueNumber,
		CreatedAt:    app.worktreeConfig.CreatedAt,
		Owner:        app.worktreeConfig.Owner,
		Repository:   app.worktreeConfig.Repository,
		IssueURL:     app.worktreeConfig.IssueURL,
	}
	
	claudeCtx := &types.ClaudeContext{
		IssueData:      issue,
		WorktreeConfig: typesWorktreeConfig,
		ProjectPath:    app.worktreeConfig.WorktreePath,
		TaskType:       "implementation",
	}
	
	app.debugStep("step5", "Executing Claude Code with context", map[string]interface{}{
		"claude_context": map[string]interface{}{
			"project_path": app.worktreeConfig.WorktreePath,
			"task_type":    "implementation",
			"issue_title":  issue.Title,
		},
	})
	
	if err := app.claudeIntegration.RunWithContext(claudeCtx); err != nil {
		app.logger.Error("workflow", "Claude Code execution failed", map[string]interface{}{
			"error":         err.Error(),
			"worktree_path": app.worktreeConfig.WorktreePath,
			"issue_number":  issue.Number,
		})
		app.ui.Warning(fmt.Sprintf("Claude Code execution warning: %v", err))
	} else {
		app.debugStep("step5", "Claude Code execution completed successfully", nil)
	}
	
	app.ui.UpdateProgress("implementation", "completed")
	return nil
}

// validateImplementation runs quality validation
func (app *CCWApp) validateImplementation() (*git.ValidationResult, error) {
	app.debugStep("step6", "Starting implementation validation", map[string]interface{}{
		"worktree_path": app.worktreeConfig.WorktreePath,
	})
	
	app.ui.UpdateProgress("validation", "in_progress")
	app.ui.Info("Validating implementation...")
	
	validationResult, err := app.validator.ValidateImplementation(app.worktreeConfig.WorktreePath)
	if err != nil {
		app.ui.UpdateProgress("validation", "failed")
		app.logger.Error("workflow", "Validation error", map[string]interface{}{
			"error":         err.Error(),
			"worktree_path": app.worktreeConfig.WorktreePath,
		})
		return nil, fmt.Errorf("validation error: %w", err)
	}

	app.debugStep("step6", "Validation completed", map[string]interface{}{
		"success":       validationResult.Success,
		"errors":        len(validationResult.Errors),
		"lint_success":  validationResult.LintResult != nil && validationResult.LintResult.Success,
		"build_success": validationResult.BuildResult != nil && validationResult.BuildResult.Success,
		"test_success":  validationResult.TestResult != nil && validationResult.TestResult.Success,
	})

	if validationResult.Success {
		app.ui.UpdateProgress("validation", "completed")
		app.ui.Success("Implementation validation successful!")
	}

	return validationResult, nil
}

// commitChanges creates a git commit with all changes before PR creation
func (app *CCWApp) commitChanges(issue *types.Issue) error {
	app.debugStep("step6_commit", "Creating git commit with all changes", map[string]interface{}{
		"worktree_path": app.worktreeConfig.WorktreePath,
		"issue_number":  issue.Number,
	})
	
	app.ui.UpdateProgress("commit", "in_progress")
	app.ui.Info("Committing changes...")
	
	// Generate commit message using the commit generator
	issueForCommit := &commit.Issue{
		Number: issue.Number,
		Title:  issue.Title,
		Body:   issue.Body,
	}
	
	// Generate commit message synchronously (blocking operation)
	commitResultChan := app.commitGenerator.GenerateEnhancedCommitMessageAsync(app.worktreeConfig.WorktreePath, issueForCommit)
	
	var commitMessage string
	select {
	case commitResult := <-commitResultChan:
		if commitResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Commit message generation failed: %v", commitResult.Error))
			commitMessage = fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
		} else {
			commitMessage = commitResult.Message
		}
	case <-time.After(30 * time.Second):
		app.ui.Warning("⚠️ Commit message generation timed out, using fallback")
		commitMessage = fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
	}
	
	app.debugStep("step6_commit", "Generated commit message", map[string]interface{}{
		"message": commitMessage,
	})
	
	// Create the actual git commit
	if err := app.gitOps.CommitChanges(app.worktreeConfig.WorktreePath, commitMessage); err != nil {
		app.ui.UpdateProgress("commit", "failed")
		app.logger.Error("workflow", "Failed to commit changes", map[string]interface{}{
			"error":         err.Error(),
			"worktree_path": app.worktreeConfig.WorktreePath,
			"issue_number":  issue.Number,
		})
		return fmt.Errorf("failed to commit changes: %w", err)
	}
	
	app.debugStep("step6_commit", "Git commit created successfully", map[string]interface{}{
		"worktree_path": app.worktreeConfig.WorktreePath,
	})
	
	app.ui.UpdateProgress("commit", "completed")
	successIcon := getConsoleCharWorkflow("✅", "[SUCCESS]")
	app.ui.Success(fmt.Sprintf("%s Changes committed successfully!", successIcon))
	
	return nil
}

// executeAsyncWorkflow runs the async PR creation workflow
func (app *CCWApp) executeAsyncWorkflow(issue *types.Issue, validationResult *git.ValidationResult) error {
	// Convert git.ValidationResult to types.ValidationResult
	typesValidationResult := ConvertValidationResult(validationResult)
	
	// Execute async workflow for PR creation
	return app.ExecuteAsyncPRWorkflow(issue, app.worktreeConfig.WorktreePath, app.worktreeConfig.BranchName, typesValidationResult)
}

// Helper functions

func generateBranchName(issueNumber int) string {
	timestamp := time.Now().Format("20060102-150405")
	return fmt.Sprintf("issue-%d-%s", issueNumber, timestamp)
}

func truncateForLog(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// debugStep helper function for workflow debugging
func (app *CCWApp) debugStep(step, message string, context map[string]interface{}) {
	if os.Getenv("DEBUG_MODE") == "true" || os.Getenv("VERBOSE_MODE") == "true" {
		app.logger.Debug("workflow", fmt.Sprintf("[%s] %s", step, message), context)
	}
	
	if os.Getenv("TRACE_MODE") == "true" {
		app.traceFunction(fmt.Sprintf("debugStep:%s", step), context)
	}
}

// traceFunction logs detailed function call information
func (app *CCWApp) traceFunction(funcName string, params map[string]interface{}) {
	if os.Getenv("TRACE_MODE") == "true" {
		app.logger.Debug("trace", fmt.Sprintf("FUNCTION: %s", funcName), params)
	}
}

// convertGitValidationResultToTypes converts git.ValidationResult to types.ValidationResult
func convertGitValidationResultToTypes(gitResult *git.ValidationResult) *types.ValidationResult {
	if gitResult == nil {
		return nil
	}
	
	// Convert errors
	var errors []types.ValidationError
	for _, err := range gitResult.Errors {
		errors = append(errors, types.ValidationError{
			Type:        err.Type,
			Message:     err.Message,
			File:        err.File,
			Line:        err.Line,
			Recoverable: err.Recoverable,
		})
	}
	
	// Convert LintResult
	var lintResult *types.LintResult
	if gitResult.LintResult != nil {
		lintResult = &types.LintResult{
			Success:   gitResult.LintResult.Success,
			Output:    gitResult.LintResult.Output,
			Errors:    gitResult.LintResult.Errors,
			Warnings:  gitResult.LintResult.Warnings,
			AutoFixed: gitResult.LintResult.AutoFixed,
		}
	}
	
	// Convert BuildResult
	var buildResult *types.BuildResult
	if gitResult.BuildResult != nil {
		buildResult = &types.BuildResult{
			Success: gitResult.BuildResult.Success,
			Output:  gitResult.BuildResult.Output,
			Error:   gitResult.BuildResult.Error,
		}
	}
	
	// Convert TestResult
	var testResult *types.TestResult
	if gitResult.TestResult != nil {
		testResult = &types.TestResult{
			Success:   gitResult.TestResult.Success,
			Output:    gitResult.TestResult.Output,
			TestCount: gitResult.TestResult.TestCount,
			Passed:    gitResult.TestResult.Passed,
			Failed:    gitResult.TestResult.Failed,
		}
	}
	
	return &types.ValidationResult{
		Success:     gitResult.Success,
		LintResult:  lintResult,
		BuildResult: buildResult,
		TestResult:  testResult,
		Errors:      errors,
		Duration:    gitResult.Duration,
		Timestamp:   gitResult.Timestamp,
	}
}

// convertGitWorktreeConfigToTypes converts git.WorktreeConfig to types.WorktreeConfig
func convertGitWorktreeConfigToTypes(gitConfig *git.WorktreeConfig) *types.WorktreeConfig {
	if gitConfig == nil {
		return nil
	}
	
	return &types.WorktreeConfig{
		BasePath:     gitConfig.BasePath,
		BranchName:   gitConfig.BranchName,
		WorktreePath: gitConfig.WorktreePath,
		IssueNumber:  gitConfig.IssueNumber,
		CreatedAt:    gitConfig.CreatedAt,
		Owner:        gitConfig.Owner,
		Repository:   gitConfig.Repository,
		IssueURL:     gitConfig.IssueURL,
	}
}

// convertTypesToGitValidationResult converts types.ValidationResult to git.ValidationResult
func convertTypesToGitValidationResult(typesResult *types.ValidationResult) *git.ValidationResult {
	if typesResult == nil {
		return nil
	}
	
	// Convert errors (now using the same type)
	errors := typesResult.Errors
	
	// Convert LintResult
	var lintResult *git.LintResult
	if typesResult.LintResult != nil {
		lintResult = &git.LintResult{
			Success:   typesResult.LintResult.Success,
			Output:    typesResult.LintResult.Output,
			Errors:    typesResult.LintResult.Errors,
			Warnings:  typesResult.LintResult.Warnings,
			AutoFixed: typesResult.LintResult.AutoFixed,
		}
	}
	
	// Convert BuildResult
	var buildResult *git.BuildResult
	if typesResult.BuildResult != nil {
		buildResult = &git.BuildResult{
			Success: typesResult.BuildResult.Success,
			Output:  typesResult.BuildResult.Output,
			Error:   typesResult.BuildResult.Error,
		}
	}
	
	// Convert TestResult
	var testResult *git.TestResult
	if typesResult.TestResult != nil {
		testResult = &git.TestResult{
			Success:   typesResult.TestResult.Success,
			Output:    typesResult.TestResult.Output,
			TestCount: typesResult.TestResult.TestCount,
			Passed:    typesResult.TestResult.Passed,
			Failed:    typesResult.TestResult.Failed,
		}
	}
	
	return &git.ValidationResult{
		Success:     typesResult.Success,
		LintResult:  lintResult,
		BuildResult: buildResult,
		TestResult:  testResult,
		Errors:      errors,
		Duration:    typesResult.Duration,
		Timestamp:   typesResult.Timestamp,
	}
}

// validateImplementationWithRecovery validates implementation and attempts recovery on failure
func (app *CCWApp) validateImplementationWithRecovery(issue *types.Issue) (*types.ValidationResult, error) {
	app.ui.UpdateProgress("validation", "in_progress")
	
	// First validation attempt
	gitValidationResult, err := app.validateImplementation()
	if err != nil {
		app.ui.UpdateProgress("validation", "failed")
		return nil, err
	}
	
	// Convert to types.ValidationResult
	validationResult := convertGitValidationResultToTypes(gitValidationResult)
	
	// If validation succeeds, we're done
	if validationResult.Success {
		app.ui.UpdateProgress("validation", "completed")
		app.ui.Success("Validation passed on first attempt")
		return validationResult, nil
	}
	
	// Check if any errors are recoverable
	hasRecoverableErrors := false
	for _, validationError := range validationResult.Errors {
		if validationError.Recoverable {
			hasRecoverableErrors = true
			break
		}
	}
	
	if !hasRecoverableErrors {
		app.ui.UpdateProgress("validation", "failed")
		app.ui.Warning("Validation failed with non-recoverable errors")
		return validationResult, nil
	}
	
	// Attempt recovery
	app.ui.Warning("Validation failed, attempting automatic recovery...")
	app.logger.Info("workflow", "Starting validation recovery process", map[string]interface{}{
		"initial_errors": len(validationResult.Errors),
		"max_retries":    app.config.MaxRetries,
	})
	
	for attempt := 1; attempt <= app.config.MaxRetries; attempt++ {
		app.ui.Info(fmt.Sprintf("Recovery attempt %d of %d", attempt, app.config.MaxRetries))
		
		// Run Claude Code with error context to fix issues
		if err := app.runRecoveryImplementation(issue, validationResult, attempt); err != nil {
			app.logger.Error("workflow", "Recovery implementation failed", map[string]interface{}{
				"attempt": attempt,
				"error":   err.Error(),
			})
			app.ui.Warning(fmt.Sprintf("Recovery attempt %d failed: %v", attempt, err))
			continue
		}
		
		// Re-validate after recovery attempt
		gitRecoveryResult, err := app.validateImplementation()
		if err != nil {
			app.logger.Error("workflow", "Validation after recovery failed", map[string]interface{}{
				"attempt": attempt,
				"error":   err.Error(),
			})
			continue
		}
		
		// Convert to types.ValidationResult
		recoveryResult := convertGitValidationResultToTypes(gitRecoveryResult)
		
		// Check if recovery was successful
		if recoveryResult.Success {
			app.ui.UpdateProgress("validation", "completed")
			app.ui.Success(fmt.Sprintf("Validation recovered successfully on attempt %d", attempt))
			app.logger.Info("workflow", "Validation recovery successful", map[string]interface{}{
				"successful_attempt": attempt,
				"total_attempts":     attempt,
			})
			return recoveryResult, nil
		}
		
		// Log progress for this attempt
		app.logger.Info("workflow", "Recovery attempt completed", map[string]interface{}{
			"attempt":         attempt,
			"still_has_errors": len(recoveryResult.Errors),
			"previous_errors":  len(validationResult.Errors),
		})
		
		// Update validation result for next iteration
		validationResult = recoveryResult
		
		app.ui.Warning(fmt.Sprintf("Recovery attempt %d completed but validation still failing (%d errors)", 
			attempt, len(recoveryResult.Errors)))
	}
	
	// All recovery attempts failed
	app.ui.UpdateProgress("validation", "failed")
	app.ui.Error(fmt.Sprintf("All %d recovery attempts failed", app.config.MaxRetries))
	return validationResult, nil
}

// runRecoveryImplementation executes Claude Code with validation error context
func (app *CCWApp) runRecoveryImplementation(issue *types.Issue, validationResult *types.ValidationResult, attempt int) error {
	app.debugStep("recovery", "Running recovery implementation", map[string]interface{}{
		"attempt":     attempt,
		"error_count": len(validationResult.Errors),
	})
	
	// Prepare Claude context with validation errors
	claudeContext := &types.ClaudeContext{
		IssueData:         issue,
		WorktreeConfig:    convertGitWorktreeConfigToTypes(app.worktreeConfig),
		ProjectPath:       app.worktreeConfig.WorktreePath,
		IsRetry:           true,
		RetryAttempt:      attempt,
		ValidationErrors:  validationResult.Errors,
		MaxRetries:        app.config.MaxRetries,
		TaskType:          "implementation",
	}
	
	// Execute Claude Code in recovery mode
	app.ui.Info(fmt.Sprintf("Running Claude Code for recovery (attempt %d)...", attempt))
	
	// Show validation error summary
	errorSummary := app.formatValidationErrorsForDisplay(validationResult)
	app.ui.Info("Errors to fix:")
	fmt.Println(errorSummary)
	
	if err := app.claudeIntegration.RunWithContext(claudeContext); err != nil {
		return fmt.Errorf("Claude Code recovery execution failed: %w", err)
	}
	
	app.ui.Success(fmt.Sprintf("Recovery attempt %d completed", attempt))
	return nil
}

// formatValidationErrorsForDisplay formats validation errors for user display
func (app *CCWApp) formatValidationErrorsForDisplay(result *types.ValidationResult) string {
	if len(result.Errors) == 0 {
		return "No errors found"
	}
	
	var output strings.Builder
	
	// Group errors by type
	errorsByType := make(map[string][]types.ValidationError)
	for _, err := range result.Errors {
		errorsByType[err.Type] = append(errorsByType[err.Type], err)
	}
	
	// Format each type
	for errorType, errors := range errorsByType {
		output.WriteString(fmt.Sprintf("  %s (%d errors):\n", strings.ToUpper(errorType), len(errors)))
		for _, err := range errors {
			if err.File != "" && err.Line > 0 {
				output.WriteString(fmt.Sprintf("    - %s:%d: %s\n", err.File, err.Line, err.Message))
			} else {
				output.WriteString(fmt.Sprintf("    - %s\n", err.Message))
			}
		}
		output.WriteString("\n")
	}
	
	return output.String()
}