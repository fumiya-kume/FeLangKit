package pr

import (
	"bufio"
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"ccw/types"
)

// PRManager handles pull request operations with async support
type PRManager struct {
	timeout    time.Duration
	maxRetries int
	debugMode  bool
}

// NewPRManager creates a new PR manager instance
func NewPRManager(timeout time.Duration, maxRetries int, debugMode bool) *PRManager {
	return &PRManager{
		timeout:    timeout,
		maxRetries: maxRetries,
		debugMode:  debugMode,
	}
}

// CreatePullRequestAsync creates a pull request asynchronously
func (pm *PRManager) CreatePullRequestAsync(req *types.PRRequest, worktreePath string) <-chan types.PRResult {
	resultChan := make(chan types.PRResult, 1)

	go func() {
		defer close(resultChan)

		pr, err := pm.CreatePullRequest(req, worktreePath)
		resultChan <- types.PRResult{
			PullRequest: pr,
			Error:       err,
		}
	}()

	return resultChan
}

// CreatePullRequest creates a pull request synchronously
func (pm *PRManager) CreatePullRequest(req *types.PRRequest, worktreePath string) (*types.PullRequest, error) {
	// Create command with timeout
	cmdCtx, cancel := context.WithTimeout(context.Background(), pm.timeout)
	defer cancel()

	// Build gh pr create command
	args := []string{"pr", "create", "--title", req.Title, "--body", req.Body}
	if req.Base != "" {
		args = append(args, "--base", req.Base)
	}

	cmd := exec.CommandContext(cmdCtx, "gh", args...)
	cmd.Dir = worktreePath

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to create pull request: %w\nOutput: %s", err, string(output))
	}

	// Parse the PR URL from output
	outputStr := strings.TrimSpace(string(output))
	lines := strings.Split(outputStr, "\n")
	var prURL string
	
	for _, line := range lines {
		if strings.Contains(line, "github.com") && strings.Contains(line, "/pull/") {
			prURL = strings.TrimSpace(line)
			break
		}
	}

	if prURL == "" {
		return nil, fmt.Errorf("could not extract PR URL from gh output: %s", outputStr)
	}

	// Extract PR number from URL
	parts := strings.Split(prURL, "/")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid PR URL format: %s", prURL)
	}

	prNumber := parts[len(parts)-1]

	return &types.PullRequest{
		URL:     prURL,
		HTMLURL: prURL,
		State:   "open",
		Number:  parseInt(prNumber), // Helper function to parse int safely
	}, nil
}

// MonitorPRChecksAsync monitors PR CI checks asynchronously
func (pm *PRManager) MonitorPRChecksAsync(prURL string, timeout time.Duration) <-chan types.CIStatusResult {
	resultChan := make(chan types.CIStatusResult, 1)

	go func() {
		defer close(resultChan)

		status, err := pm.MonitorPRChecks(prURL, timeout)
		resultChan <- types.CIStatusResult{
			Status: status,
			Error:  err,
		}
	}()

	return resultChan
}

// MonitorPRChecks monitors PR CI checks synchronously  
func (pm *PRManager) MonitorPRChecks(prURL string, timeout time.Duration) (*types.CIStatus, error) {
	// Create command with timeout
	cmdCtx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Use gh to check PR status
	cmd := exec.CommandContext(cmdCtx, "gh", "pr", "checks", prURL)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to check PR status: %w\nOutput: %s", err, string(output))
	}

	// Parse the output to determine status
	outputStr := strings.TrimSpace(string(output))
	
	// Basic parsing - in production this would be more sophisticated
	status := &types.CIStatus{
		LastUpdated: time.Now(),
		URL:         prURL,
	}

	if strings.Contains(strings.ToLower(outputStr), "success") || 
	   strings.Contains(strings.ToLower(outputStr), "passing") {
		status.Status = "success"
		status.Conclusion = "success"
	} else if strings.Contains(strings.ToLower(outputStr), "fail") ||
			  strings.Contains(strings.ToLower(outputStr), "error") {
		status.Status = "failure"
		status.Conclusion = "failure"
	} else if strings.Contains(strings.ToLower(outputStr), "pending") ||
			  strings.Contains(strings.ToLower(outputStr), "running") {
		status.Status = "pending"
		status.Conclusion = "pending"
	} else {
		status.Status = "unknown"
		status.Conclusion = "unknown"
	}

	return status, nil
}

// WatchPRChecksWithGoroutine continuously monitors PR CI checks using goroutines and channels
func (pm *PRManager) WatchPRChecksWithGoroutine(request *types.CIWatchRequest) <-chan types.CIWatchUpdate {
	updateChan := make(chan types.CIWatchUpdate, 10) // Buffered for real-time updates

	go func() {
		defer close(updateChan)

		// Create context with timeout
		ctx, cancel := context.WithTimeout(context.Background(), request.MaxWaitTime)
		defer cancel()

		// Send initial status
		updateChan <- types.CIWatchUpdate{
			Message:   "Starting CI monitoring...",
			Completed: false,
		}

		// Use gh pr checks --watch for continuous monitoring
		cmd := exec.CommandContext(ctx, "gh", "pr", "checks", "--watch", request.PRURL)
		cmd.Dir = request.WorktreePath

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			updateChan <- types.CIWatchUpdate{
				Error:     fmt.Errorf("failed to create stdout pipe: %w", err),
				Completed: true,
			}
			return
		}

		if err := cmd.Start(); err != nil {
			updateChan <- types.CIWatchUpdate{
				Error:     fmt.Errorf("failed to start gh pr checks --watch: %w", err),
				Completed: true,
			}
			return
		}

		// Read output in real-time
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			select {
			case <-ctx.Done():
				updateChan <- types.CIWatchUpdate{
					Error:     fmt.Errorf("CI monitoring timed out after %v", request.MaxWaitTime),
					Completed: true,
				}
				return
			default:
				line := strings.TrimSpace(scanner.Text())
				if line == "" {
					continue
				}

				// Parse check status from output
				status := pm.parseCheckOutput(line, request.PRURL)
				
				updateChan <- types.CIWatchUpdate{
					Status:    status,
					Message:   fmt.Sprintf("CI Update: %s", line),
					Completed: false,
				}

				// Check if all checks completed
				if status != nil && pm.areAllChecksCompleted(status) {
					updateChan <- types.CIWatchUpdate{
						Status:    status,
						Message:   "All CI checks completed",
						Completed: true,
					}
					return
				}
			}
		}

		// Wait for command completion
		if err := cmd.Wait(); err != nil {
			updateChan <- types.CIWatchUpdate{
				Error:     fmt.Errorf("gh pr checks --watch failed: %w", err),
				Completed: true,
			}
			return
		}
	}()

	return updateChan
}

// WatchPRChecksWithRecovery monitors CI with automatic failure recovery
func (pm *PRManager) WatchPRChecksWithRecovery(request *types.CIWatchRequest) <-chan types.CIWatchUpdate {
	updateChan := make(chan types.CIWatchUpdate, 10)

	go func() {
		defer close(updateChan)

		for attempt := 0; attempt <= request.RecoveryAttempts; attempt++ {
			// Start CI monitoring
			watchChan := pm.WatchPRChecksWithGoroutine(request)

			for update := range watchChan {
				updateChan <- update

				// Handle failures with recovery
				if update.Completed && update.Status != nil && request.EnableRecovery {
					if pm.hasRecoverableFailures(update.Status) && attempt < request.RecoveryAttempts {
						updateChan <- types.CIWatchUpdate{
							Message: fmt.Sprintf("Attempting recovery (attempt %d/%d)...", attempt+1, request.RecoveryAttempts),
						}

						// Attempt recovery
						if err := pm.attemptCIRecovery(update.Status, request); err != nil {
							updateChan <- types.CIWatchUpdate{
								Message: fmt.Sprintf("Recovery attempt failed: %v", err),
							}
						} else {
							updateChan <- types.CIWatchUpdate{
								Message: "Recovery changes pushed, restarting CI monitoring...",
							}
							break // Break inner loop to retry monitoring
						}
					}
				}

				// If completed successfully or no recovery needed, exit
				if update.Completed {
					return
				}
			}
		}

		updateChan <- types.CIWatchUpdate{
			Message:   "Max recovery attempts reached",
			Completed: true,
		}
	}()

	return updateChan
}

// parseCheckOutput parses gh pr checks output and creates CIStatus
func (pm *PRManager) parseCheckOutput(output, prURL string) *types.CIStatus {
	status := &types.CIStatus{
		URL:           prURL,
		LastUpdated:   time.Now(),
		ChecksSummary: make(map[string]int),
	}

	// Parse different output formats from gh pr checks
	if strings.Contains(output, "✓") || strings.Contains(output, "success") {
		status.PassingChecks++
		status.ChecksSummary["success"]++
	} else if strings.Contains(output, "✗") || strings.Contains(output, "failure") {
		status.FailingChecks++
		status.ChecksSummary["failure"]++
		
		// Extract failure details
		failure := types.CheckFailureDetail{
			CheckName: pm.extractCheckName(output),
			Message:   output,
			FailType:  pm.determineFailureType(output),
		}
		status.FailureDetails = append(status.FailureDetails, failure)
	} else if strings.Contains(output, "○") || strings.Contains(output, "pending") {
		status.PendingChecks++
		status.ChecksSummary["pending"]++
	}

	status.TotalChecks = status.PassingChecks + status.FailingChecks + status.PendingChecks

	// Determine overall status
	if status.FailingChecks > 0 {
		status.Status = "failure"
		status.Conclusion = "failure"
	} else if status.PendingChecks > 0 {
		status.Status = "pending"
		status.Conclusion = "pending"
	} else if status.PassingChecks > 0 {
		status.Status = "success"
		status.Conclusion = "success"
	} else {
		status.Status = "unknown"
		status.Conclusion = "unknown"
	}

	return status
}

// areAllChecksCompleted checks if all CI checks have finished
func (pm *PRManager) areAllChecksCompleted(status *types.CIStatus) bool {
	return status.PendingChecks == 0 && status.TotalChecks > 0
}

// hasRecoverableFailures checks if failures can be automatically fixed
func (pm *PRManager) hasRecoverableFailures(status *types.CIStatus) bool {
	for _, failure := range status.FailureDetails {
		if failure.FailType == "lint" || failure.FailType == "build" {
			return true
		}
	}
	return false
}

// attemptCIRecovery attempts to fix CI failures automatically
func (pm *PRManager) attemptCIRecovery(status *types.CIStatus, request *types.CIWatchRequest) error {
	for _, failure := range status.FailureDetails {
		switch failure.FailType {
		case "lint":
			if err := pm.runLintFix(request.WorktreePath); err != nil {
				return fmt.Errorf("lint fix failed: %w", err)
			}
		case "build":
			// For build failures, we could potentially fix import issues or basic syntax
			// This is a placeholder for more sophisticated recovery logic
			return fmt.Errorf("build failure recovery not implemented")
		}
	}

	// Push recovery changes
	return pm.pushRecoveryChanges(request.WorktreePath, request.BranchName)
}

// runLintFix runs SwiftLint auto-fix
func (pm *PRManager) runLintFix(worktreePath string) error {
	cmd := exec.Command("swiftlint", "lint", "--fix")
	cmd.Dir = worktreePath
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("swiftlint fix failed: %w\nOutput: %s", err, string(output))
	}
	
	return nil
}

// pushRecoveryChanges pushes fixes to the remote branch
func (pm *PRManager) pushRecoveryChanges(worktreePath, branchName string) error {
	// Stage changes
	cmd := exec.Command("git", "add", "-A")
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Commit changes
	cmd = exec.Command("git", "commit", "-m", "fix: auto-fix CI failures\n\n🤖 Generated with CCW CI Recovery")
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		// If no changes to commit, that's okay
		if !strings.Contains(err.Error(), "nothing to commit") {
			return fmt.Errorf("failed to commit changes: %w", err)
		}
	}

	// Force push to update PR
	cmd = exec.Command("git", "push", "--force-with-lease", "origin", branchName)
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to push recovery changes: %w", err)
	}

	return nil
}

// extractCheckName extracts check name from gh output
func (pm *PRManager) extractCheckName(output string) string {
	parts := strings.Fields(output)
	if len(parts) > 1 {
		return parts[1]
	}
	return "unknown"
}

// determineFailureType determines the type of CI failure
func (pm *PRManager) determineFailureType(output string) string {
	lowerOutput := strings.ToLower(output)
	
	if strings.Contains(lowerOutput, "lint") || strings.Contains(lowerOutput, "swiftlint") {
		return "lint"
	} else if strings.Contains(lowerOutput, "build") || strings.Contains(lowerOutput, "compile") {
		return "build"
	} else if strings.Contains(lowerOutput, "test") {
		return "test"
	}
	
	return "other"
}

// Helper function to safely parse integers
func parseInt(s string) int {
	if result, err := strconv.Atoi(s); err == nil {
		return result
	}
	return 0
}