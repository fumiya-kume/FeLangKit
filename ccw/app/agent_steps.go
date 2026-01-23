package app

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"ccw/git"
	"ccw/types"
)

// STEP 1: Issue Analysis Agent (non-interactive Claude Code)
func (app *CCWApp) runIssueAnalysisAgent(issue *types.Issue, owner, repo string) (*types.IssueAnalysisResult, error) {
	app.ui.Info("Running Issue Analysis Agent (non-interactive Claude Code)")

	// Generate analysis prompt
	prompt := app.generateIssueAnalysisPrompt(issue, owner, repo)

	// Execute non-interactive Claude Code for analysis
	result, err := app.agentExecutor.ExecuteNonInteractiveAgent("IssueAnalysis", prompt, 5*time.Minute)
	if err != nil {
		return nil, fmt.Errorf("issue analysis agent failed: %w", err)
	}

	// Parse the analysis result
	analysisResult := &types.IssueAnalysisResult{
		AnalysisID:       fmt.Sprintf("issue-%d-agent-%d", issue.Number, time.Now().Unix()),
		Timestamp:        time.Now(),
		Success:          true,
		ExecutiveSummary: app.extractAnalysisSummary(result),
		// Additional parsing would happen here in real implementation
	}

	app.ui.Success("Issue Analysis Agent completed")
	return analysisResult, nil
}

// STEP 2: Implementation Agent (interactive Claude Code)
func (app *CCWApp) runImplementationAgent(issue *types.Issue, analysis *types.IssueAnalysisResult) error {
	app.ui.Info("Running Implementation Agent (interactive Claude Code)")

	// Generate implementation context
	contextPrompt := app.generateImplementationPrompt(issue, analysis)
	contextPath := filepath.Join(app.worktreeConfig.WorktreePath, "implementation_context.md")

	if err := os.WriteFile(contextPath, []byte(contextPrompt), 0644); err != nil {
		return fmt.Errorf("failed to create implementation context: %w", err)
	}

	// Execute interactive Claude Code for implementation
	err := app.agentExecutor.ExecuteInteractiveAgent("Implementation", contextPath, 15*time.Minute)
	if err != nil {
		return fmt.Errorf("implementation agent failed: %w", err)
	}

	app.ui.Success("Implementation Agent completed")
	return nil
}

// STEP 3: Verification + PR Review Agent
func (app *CCWApp) runVerificationAndReviewAgent(issue *types.Issue, analysis *types.IssueAnalysisResult) (*git.ValidationResult, error) {
	app.ui.Info("Running Verification + PR Review Agent")

	// Run swift build, test, lint
	validationResult, err := app.validator.ValidateImplementation(app.worktreeConfig.WorktreePath)
	if err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	// Convert validation errors for PR review
	var errorStrings []string
	for _, validationError := range validationResult.Errors {
		errorStrings = append(errorStrings, fmt.Sprintf("[%s] %s", validationError.Type, validationError.Message))
	}

	// Run PR Review Agent (non-interactive Claude Code)
	reviewPrompt := app.generateVerificationPrompt(issue, errorStrings)
	reviewResult, err := app.agentExecutor.ExecuteNonInteractiveAgent("PRReview", reviewPrompt, 3*time.Minute)
	if err != nil {
		app.logger.Error("workflow", "PR review agent failed", map[string]interface{}{
			"error": err.Error(),
		})
		// Continue anyway - review is not critical
	}

	// Save review result for reference
	reviewPath := filepath.Join(app.worktreeConfig.WorktreePath, ".pr-review.md")
	if err := os.WriteFile(reviewPath, []byte(reviewResult), 0644); err != nil {
		app.logger.Warn("workflow", "failed to save PR review", map[string]interface{}{
			"path":  reviewPath,
			"error": err.Error(),
		})
	}

	if validationResult.Success {
		app.ui.Success("Verification + PR Review Agent completed - All checks passed")
	} else {
		app.ui.Warning(fmt.Sprintf("Verification found %d issues", len(validationResult.Errors)))
	}

	return validationResult, nil
}

// STEP 4: Conditional Fixing Agent (if verify fails)
func (app *CCWApp) runFixingAgent(issue *types.Issue, analysis *types.IssueAnalysisResult, verificationResult *git.ValidationResult) error {
	app.ui.Info("Running Fixing Agent (addressing verification errors)")

	// Generate fixing prompt
	fixingPrompt := app.generateFixingPrompt(issue, verificationResult)
	contextPath := filepath.Join(app.worktreeConfig.WorktreePath, "fixing_context.md")

	if err := os.WriteFile(contextPath, []byte(fixingPrompt), 0644); err != nil {
		return fmt.Errorf("failed to create fixing context: %w", err)
	}

	// Execute interactive Claude Code for fixing
	err := app.agentExecutor.ExecuteInteractiveAgent("Fixing", contextPath, 10*time.Minute)
	if err != nil {
		return fmt.Errorf("fixing agent failed: %w", err)
	}

	app.ui.Success("Fixing Agent completed")
	return nil
}

// STEP 5: Commit Agent (small, meaningful commits)
func (app *CCWApp) runCommitAgent(issue *types.Issue, analysis *types.IssueAnalysisResult) error {
	app.ui.Info("Running Commit Agent (small, meaningful commits)")

	// Generate commit prompt
	commitPrompt := app.generateCommitPrompt(issue, analysis)

	// Execute non-interactive Claude Code for commit message
	commitResult, err := app.agentExecutor.ExecuteNonInteractiveAgent("Commit", commitPrompt, 3*time.Minute)
	if err != nil {
		return fmt.Errorf("commit agent failed: %w", err)
	}

	// Parse commit message from Claude Code output
	commitMessage := app.parseCommitMessageFromResult(commitResult, issue)

	// Create the actual git commit
	if err := app.gitOps.CommitChanges(app.worktreeConfig.WorktreePath, commitMessage); err != nil {
		return fmt.Errorf("failed to commit changes: %w", err)
	}

	app.ui.Success("Commit Agent completed")
	return nil
}

// STEP 6: PR Description Agent (non-interactive Claude Code)
func (app *CCWApp) runPRDescriptionAgent(issue *types.Issue, analysis *types.IssueAnalysisResult) (string, string, error) {
	app.ui.Info("Running PR Description Agent (non-interactive Claude Code)")

	// Generate PR description prompt
	prPrompt := app.generatePRDescriptionPrompt(issue, analysis)

	// Execute non-interactive Claude Code for PR description
	prResult, err := app.agentExecutor.ExecuteNonInteractiveAgent("PRDescription", prPrompt, 3*time.Minute)
	if err != nil {
		return "", "", fmt.Errorf("PR description agent failed: %w", err)
	}

	// Parse PR title and description from Claude Code output
	prTitle, prDescription := app.parsePRDescriptionFromResult(prResult, issue)

	app.ui.Success("PR Description Agent completed")
	return prTitle, prDescription, nil
}

// STEP 7: PR Creation with gh command (Golang program)
func (app *CCWApp) runPRCreationWithGH(prTitle, prDescription string) error {
	app.ui.Info("Running PR Creation with gh command")

	// Push the branch first
	if err := app.gitOps.PushBranch(app.worktreeConfig.WorktreePath, app.worktreeConfig.BranchName); err != nil {
		return fmt.Errorf("failed to push branch: %w", err)
	}

	// Use gh CLI for PR creation (let gh use repository's default branch)
	cmd := exec.Command("gh", "pr", "create",
		"--title", prTitle,
		"--body", prDescription)
	cmd.Dir = app.worktreeConfig.WorktreePath

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to create PR: %w (output: %s)", err, string(output))
	}

	// Extract PR URL from gh output
	prURL := strings.TrimSpace(string(output))
	app.ui.Success(fmt.Sprintf("PR created: %s", prURL))

	// Store PR URL for monitoring
	app.currentPRURL = prURL

	return nil
}

// STEP 8: PR Monitoring + Auto-Fix Agent
func (app *CCWApp) runPRMonitoringAgent(issue *types.Issue, owner, repo string) error {
	app.ui.Info("Running PR Monitoring + Auto-Fix Agent")

	// Use existing CI monitoring infrastructure
	timeout := 30 * time.Minute
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Start CI monitoring with existing goroutine system
	watchChannel := app.prManager.WatchPRChecksWithGoroutine(ctx, app.currentPRURL)

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		// Process real-time updates
		for update := range watchChannel.Updates {
			app.handleCIUpdateWithAgent(update, issue)
		}
	}()

	// Wait for completion
	select {
	case result := <-watchChannel.Completion:
		wg.Wait()
		return app.handleCICompletionWithAgent(result, issue)
	case <-ctx.Done():
		wg.Wait()
		app.ui.Warning("CI monitoring timed out")
		return nil
	}
}

// ciFixMutex prevents concurrent CI fix agent runs
var ciFixMutex sync.Mutex
var ciFixRunning bool

// Handle CI updates with agent integration (non-blocking)
func (app *CCWApp) handleCIUpdateWithAgent(update types.CIWatchUpdate, issue *types.Issue) {
	if update.Status != nil && update.Status.FailedChecks > 0 {
		// Check if a CI fix is already running (non-blocking)
		ciFixMutex.Lock()
		if ciFixRunning {
			ciFixMutex.Unlock()
			app.ui.Info("CI fix agent already running, skipping duplicate trigger")
			return
		}
		ciFixRunning = true
		ciFixMutex.Unlock()

		app.ui.Warning("CI failures detected - running CI fixing agent")

		// Analyze failures
		failures := app.prManager.AnalyzeCIFailures(update.Status)

		// Run CI fixing agent asynchronously to avoid blocking the update channel
		go func() {
			defer func() {
				ciFixMutex.Lock()
				ciFixRunning = false
				ciFixMutex.Unlock()
			}()

			if err := app.runCIFixingAgent(issue, failures); err != nil {
				app.ui.Error(fmt.Sprintf("CI fixing agent failed: %v", err))
			}
		}()
	}
}

// Handle CI completion with agent integration
func (app *CCWApp) handleCICompletionWithAgent(result types.CIWatchResult, issue *types.Issue) error {
	// Check for errors first
	if result.Error != nil {
		return fmt.Errorf("CI monitoring failed: %w", result.Error)
	}

	// Check final status
	if result.FinalStatus == nil {
		app.ui.Warning("CI monitoring completed but no final status available")
		return nil
	}

	// Determine success from FinalStatus
	if result.FinalStatus.Conclusion == "success" || result.FinalStatus.FailedChecks == 0 {
		app.ui.Success("All CI checks passed!")
		return nil
	}

	// Analyze failures for recovery
	failures := app.prManager.AnalyzeCIFailures(result.FinalStatus)

	// Filter recoverable failures
	var recoverableFailures []types.CIFailureInfo
	for _, f := range failures {
		if f.Recoverable {
			recoverableFailures = append(recoverableFailures, f)
		}
	}

	if len(recoverableFailures) > 0 {
		app.ui.Warning("CI completed with recoverable failures - running final fix attempt")
		return app.runCIFixingAgent(issue, recoverableFailures)
	}

	app.ui.Error("CI completed with non-recoverable failures")
	return fmt.Errorf("CI completed with %d failures", result.FinalStatus.FailedChecks)
}

// CI Fixing Agent (called when CI fails)
func (app *CCWApp) runCIFixingAgent(issue *types.Issue, failures []types.CIFailureInfo) error {
	app.ui.Info("Starting CI Fixing Agent...")

	// Generate CI-specific fixing prompt
	fixingPrompt := app.generateCIFixingPrompt(issue, failures)
	contextPath := filepath.Join(app.worktreeConfig.WorktreePath, "ci_fixing_context.md")

	if err := os.WriteFile(contextPath, []byte(fixingPrompt), 0644); err != nil {
		return fmt.Errorf("failed to create CI fixing context: %w", err)
	}

	// Execute interactive Claude Code for CI fixing
	err := app.agentExecutor.ExecuteInteractiveAgent("CIFixing", contextPath, 10*time.Minute)
	if err != nil {
		return fmt.Errorf("CI fixing agent failed: %w", err)
	}

	// Commit the fixes
	commitMessage := fmt.Sprintf("fix: resolve CI failures\n\n- Address %d CI check failures\n- Auto-generated fixes for build, lint, and test issues\n\nRefs #%d",
		len(failures), issue.Number)

	if err := app.gitOps.CommitChanges(app.worktreeConfig.WorktreePath, commitMessage); err != nil {
		return fmt.Errorf("failed to commit CI fixes: %w", err)
	}

	// Push the fixes
	if err := app.gitOps.PushBranch(app.worktreeConfig.WorktreePath, app.worktreeConfig.BranchName); err != nil {
		return fmt.Errorf("failed to push CI fixes: %w", err)
	}

	app.ui.Success("CI fixes committed and pushed")
	return nil
}

// Helper functions for parsing and conversion

func (app *CCWApp) extractAnalysisSummary(result string) string {
	// Try to extract JSON analysis, fallback to simple summary
	type AnalysisJSON struct {
		AnalysisSummary string `json:"analysis_summary"`
	}

	var analysis AnalysisJSON
	if err := json.Unmarshal([]byte(result), &analysis); err == nil && analysis.AnalysisSummary != "" {
		return analysis.AnalysisSummary
	}

	// Fallback to first paragraph of result
	lines := strings.Split(result, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if len(line) > 20 && !strings.HasPrefix(line, "#") {
			return line
		}
	}

	return "Analysis completed by specialized agent"
}

func (app *CCWApp) parseCommitMessageFromResult(result string, issue *types.Issue) string {
	// Try to extract JSON commit message, fallback to simple message
	type CommitJSON struct {
		CommitMessages []struct {
			Message string `json:"message"`
		} `json:"commit_messages"`
	}

	var commit CommitJSON
	if err := json.Unmarshal([]byte(result), &commit); err == nil && len(commit.CommitMessages) > 0 {
		msg := strings.TrimSpace(commit.CommitMessages[0].Message)
		if msg != "" {
			return msg
		}
	}

	// Fallback to simple conventional commit format
	return fmt.Sprintf("feat: %s\n\nRefs #%d", issue.Title, issue.Number)
}

func (app *CCWApp) parsePRDescriptionFromResult(result string, issue *types.Issue) (string, string) {
	// Try to extract JSON PR description, fallback to simple format
	type PRJSON struct {
		Title       string `json:"title"`
		Description string `json:"description"`
	}

	var pr PRJSON
	if err := json.Unmarshal([]byte(result), &pr); err == nil && pr.Title != "" {
		return pr.Title, pr.Description
	}

	// Fallback to simple format
	title := fmt.Sprintf("Resolve #%d: %s", issue.Number, issue.Title)
	description := fmt.Sprintf(`## Summary
%s

## Changes
Implemented solution for issue #%d

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing performed

## Related
Closes #%d

---
Generated with Claude Code Workflow
`, issue.Title, issue.Number, issue.Number)

	return title, description
}
