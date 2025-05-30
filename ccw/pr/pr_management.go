package pr

import (
	"context"
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