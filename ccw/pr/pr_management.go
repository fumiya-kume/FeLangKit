package pr

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
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

// WatchPRChecksWithGoroutine monitors PR CI checks using gh pr checks --watch
func (pm *PRManager) WatchPRChecksWithGoroutine(prURL string, updateChan chan<- types.CIWatchUpdate) <-chan types.CIWatchResult {
	resultChan := make(chan types.CIWatchResult, 1)

	go func() {
		defer close(resultChan)
		defer close(updateChan)

		// Send initial status update
		updateChan <- types.CIWatchUpdate{
			Type:    "status",
			Message: "Starting CI monitoring...",
		}

		// Use gh pr checks --watch for continuous monitoring
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute) // 30 minute timeout
		defer cancel()

		cmd := exec.CommandContext(ctx, "gh", "pr", "checks", "--watch", prURL)
		
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			resultChan <- types.CIWatchResult{
				Error: fmt.Errorf("failed to create stdout pipe: %w", err),
			}
			return
		}

		if err := cmd.Start(); err != nil {
			resultChan <- types.CIWatchResult{
				Error: fmt.Errorf("failed to start gh pr checks --watch: %w", err),
			}
			return
		}

		scanner := bufio.NewScanner(stdout)
		var lastStatus *types.CIWatchStatus

		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}

			// Parse the output line and update status
			status := pm.parseWatchOutput(line, prURL)
			if status != nil {
				lastStatus = status
				
				// Send status update through channel
				updateChan <- types.CIWatchUpdate{
					Type:   "status",
					Status: status,
					Message: fmt.Sprintf("CI Status: %s", status.Status),
				}

				// Check if CI is completed
				if status.IsCompleted {
					updateChan <- types.CIWatchUpdate{
						Type:    "completed",
						Status:  status,
						Message: "CI checks completed successfully",
					}
					break
				}

				// Check if CI failed
				if status.IsFailed {
					updateChan <- types.CIWatchUpdate{
						Type:    "failed",
						Status:  status,
						Message: "CI checks failed",
					}
					break
				}
			}
		}

		// Wait for command to complete
		err = cmd.Wait()
		if err != nil && ctx.Err() != context.DeadlineExceeded {
			resultChan <- types.CIWatchResult{
				Status: lastStatus,
				Error:  fmt.Errorf("gh pr checks --watch failed: %w", err),
			}
			return
		}

		resultChan <- types.CIWatchResult{
			Status: lastStatus,
			Error:  nil,
		}
	}()

	return resultChan
}

// parseWatchOutput parses gh pr checks --watch output and returns CI status
func (pm *PRManager) parseWatchOutput(line, prURL string) *types.CIWatchStatus {
	// Try to parse as JSON first (gh outputs JSON in some cases)
	var jsonStatus map[string]interface{}
	if err := json.Unmarshal([]byte(line), &jsonStatus); err == nil {
		return pm.parseJSONStatus(jsonStatus, prURL)
	}

	// Fall back to text parsing
	return pm.parseTextStatus(line, prURL)
}

// parseJSONStatus parses JSON-formatted status from gh pr checks
func (pm *PRManager) parseJSONStatus(data map[string]interface{}, prURL string) *types.CIWatchStatus {
	status := &types.CIWatchStatus{
		PRURL:       prURL,
		LastUpdated: time.Now(),
	}

	if state, ok := data["state"].(string); ok {
		status.Status = state
		status.Conclusion = state
	}

	// Parse checks if available
	if checks, ok := data["check_runs"].([]interface{}); ok {
		for _, checkData := range checks {
			if checkMap, ok := checkData.(map[string]interface{}); ok {
				check := types.CheckRunWatch{
					Name:       getStringValue(checkMap, "name"),
					Status:     getStringValue(checkMap, "status"),
					Conclusion: getStringValue(checkMap, "conclusion"),
					URL:        getStringValue(checkMap, "html_url"),
				}
				
				if startedAt := getStringValue(checkMap, "started_at"); startedAt != "" {
					if t, err := time.Parse(time.RFC3339, startedAt); err == nil {
						check.StartedAt = t
					}
				}
				
				if completedAt := getStringValue(checkMap, "completed_at"); completedAt != "" {
					if t, err := time.Parse(time.RFC3339, completedAt); err == nil {
						check.CompletedAt = t
						if !check.StartedAt.IsZero() {
							check.Duration = check.CompletedAt.Sub(check.StartedAt).String()
						}
					}
				}
				
				status.Checks = append(status.Checks, check)
			}
		}
	}

	// Determine completion status
	status.IsCompleted = pm.areAllChecksCompleted(status.Checks)
	status.IsFailed = pm.hasFailedChecks(status.Checks)

	return status
}

// parseTextStatus parses text-formatted status from gh pr checks
func (pm *PRManager) parseTextStatus(line, prURL string) *types.CIWatchStatus {
	status := &types.CIWatchStatus{
		PRURL:       prURL,
		LastUpdated: time.Now(),
	}

	lineLower := strings.ToLower(line)
	
	// Parse status from text output
	if strings.Contains(lineLower, "✓") || strings.Contains(lineLower, "success") {
		status.Status = "success"
		status.Conclusion = "success"
		status.IsCompleted = true
	} else if strings.Contains(lineLower, "✗") || strings.Contains(lineLower, "fail") {
		status.Status = "failure"
		status.Conclusion = "failure"
		status.IsFailed = true
	} else if strings.Contains(lineLower, "pending") || strings.Contains(lineLower, "running") {
		status.Status = "pending"
		status.Conclusion = "pending"
	} else {
		status.Status = "unknown"
		status.Conclusion = "unknown"
	}

	return status
}

// areAllChecksCompleted checks if all CI checks are completed
func (pm *PRManager) areAllChecksCompleted(checks []types.CheckRunWatch) bool {
	if len(checks) == 0 {
		return false
	}
	
	for _, check := range checks {
		if check.Status != "completed" {
			return false
		}
	}
	return true
}

// hasFailedChecks checks if any CI checks have failed
func (pm *PRManager) hasFailedChecks(checks []types.CheckRunWatch) bool {
	for _, check := range checks {
		if check.Conclusion == "failure" || check.Conclusion == "cancelled" {
			return true
		}
	}
	return false
}

// getStringValue safely extracts string value from map
func getStringValue(data map[string]interface{}, key string) string {
	if value, ok := data[key].(string); ok {
		return value
	}
	return ""
}

// Helper function to safely parse integers
func parseInt(s string) int {
	// Simple integer parsing - in production use strconv.Atoi with error handling
	result := 0
	for _, char := range s {
		if char >= '0' && char <= '9' {
			result = result*10 + int(char-'0')
		}
	}
	return result
}