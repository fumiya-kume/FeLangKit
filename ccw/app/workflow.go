package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"ccw/git"
	"ccw/github"
	"ccw/types"
)

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

	// Step 5: Validate implementation
	validationResult, err := app.validateImplementation()
	if err != nil {
		return err
	}

	// Step 6: Execute async PR workflow if validation successful
	if validationResult.Success {
		return app.executeAsyncWorkflow(issue, validationResult)
	}

	app.ui.Warning("Implementation validation failed")
	app.logger.Error("workflow", "Implementation validation failed", map[string]interface{}{
		"validation_errors": validationResult.Errors,
		"worktree_path":     app.worktreeConfig.WorktreePath,
	})
	return fmt.Errorf("validation failed")
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