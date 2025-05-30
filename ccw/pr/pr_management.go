package pr

import (
	"context"
	"encoding/json"
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

// WatchPRChecksWithGoroutine monitors PR CI checks continuously using gh pr checks --watch
func (pm *PRManager) WatchPRChecksWithGoroutine(ctx context.Context, prURL string) *types.CIWatchChannel {
	updatesChan := make(chan types.CIWatchUpdate, 10)
	completionChan := make(chan types.CIWatchResult, 1)
	cancelChan := make(chan struct{}, 1)

	go func() {
		defer close(updatesChan)
		defer close(completionChan)

		result := &types.CIWatchResult{
			Updates: make([]types.CIWatchUpdate, 0),
		}
		startTime := time.Now()

		// Send initial status update
		updatesChan <- types.CIWatchUpdate{
			EventType: "monitoring_started",
			Message:   "Starting CI monitoring",
			Timestamp: time.Now(),
		}

		// Monitor CI checks continuously
		pm.monitorChecksLoop(ctx, prURL, updatesChan, result, cancelChan)

		result.Duration = time.Since(startTime)
		completionChan <- *result
	}()

	return &types.CIWatchChannel{
		Updates:    updatesChan,
		Completion: completionChan,
		Cancel:     cancelChan,
	}
}

// monitorChecksLoop continuously monitors CI checks with polling
func (pm *PRManager) monitorChecksLoop(ctx context.Context, prURL string, updatesChan chan types.CIWatchUpdate, result *types.CIWatchResult, cancelChan chan struct{}) {
	ticker := time.NewTicker(10 * time.Second) // Poll every 10 seconds
	defer ticker.Stop()

	var lastStatus *types.CIStatus
	
	for {
		select {
		case <-ctx.Done():
			result.Error = ctx.Err()
			return
		case <-cancelChan:
			return
		case <-ticker.C:
			currentStatus, err := pm.fetchCurrentCIStatus(ctx, prURL)
			if err != nil {
				updatesChan <- types.CIWatchUpdate{
					EventType: "error",
					Message:   fmt.Sprintf("Error fetching CI status: %v", err),
					Timestamp: time.Now(),
				}
				continue
			}

			// Check for status changes
			if pm.hasStatusChanged(lastStatus, currentStatus) {
				update := types.CIWatchUpdate{
					Status:    currentStatus,
					EventType: "status_change",
					Message:   pm.formatStatusMessage(currentStatus),
					Timestamp: time.Now(),
				}
				updatesChan <- update
				result.Updates = append(result.Updates, update)
			}

			// Check for completion
			if pm.isAllChecksComplete(currentStatus) {
				result.FinalStatus = currentStatus
				updatesChan <- types.CIWatchUpdate{
					Status:    currentStatus,
					EventType: "all_complete",
					Message:   fmt.Sprintf("All CI checks completed with status: %s", currentStatus.Conclusion),
					Timestamp: time.Now(),
				}
				return
			}

			lastStatus = currentStatus
		}
	}
}

// fetchCurrentCIStatus fetches current CI status using gh CLI
func (pm *PRManager) fetchCurrentCIStatus(ctx context.Context, prURL string) (*types.CIStatus, error) {
	cmd := exec.CommandContext(ctx, "gh", "pr", "checks", prURL, "--json", "name,state,conclusion,link,startedAt,completedAt")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch CI status: %w\nOutput: %s", err, string(output))
	}

	var checks []types.CheckRun
	if err := json.Unmarshal(output, &checks); err != nil {
		// Fallback to basic parsing if JSON fails
		return pm.parseBasicCIStatus(string(output), prURL)
	}

	return pm.buildCIStatusFromChecks(checks, prURL), nil
}

// buildCIStatusFromChecks constructs CIStatus from CheckRun array
func (pm *PRManager) buildCIStatusFromChecks(checks []types.CheckRun, prURL string) *types.CIStatus {
	status := &types.CIStatus{
		Checks:        checks,
		LastUpdated:   time.Now(),
		URL:           prURL,
		TotalChecks:   len(checks),
		PassedChecks:  0,
		FailedChecks:  0,
		PendingChecks: 0,
	}

	for _, check := range checks {
		switch check.Conclusion {
		case "success":
			status.PassedChecks++
		case "failure", "error", "cancelled":
			status.FailedChecks++
		default:
			status.PendingChecks++
		}
	}

	// Determine overall status
	if status.PendingChecks > 0 {
		status.Status = "pending"
		status.Conclusion = "pending"
	} else if status.FailedChecks > 0 {
		status.Status = "failure"
		status.Conclusion = "failure"
	} else {
		status.Status = "success"
		status.Conclusion = "success"
	}

	return status
}

// parseBasicCIStatus provides fallback parsing for non-JSON output
func (pm *PRManager) parseBasicCIStatus(output, prURL string) (*types.CIStatus, error) {
	status := &types.CIStatus{
		LastUpdated: time.Now(),
		URL:         prURL,
	}

	// Basic parsing logic (existing implementation)
	if strings.Contains(strings.ToLower(output), "success") || 
	   strings.Contains(strings.ToLower(output), "passing") {
		status.Status = "success"
		status.Conclusion = "success"
	} else if strings.Contains(strings.ToLower(output), "fail") ||
			  strings.Contains(strings.ToLower(output), "error") {
		status.Status = "failure"
		status.Conclusion = "failure"
	} else {
		status.Status = "pending"
		status.Conclusion = "pending"
	}

	return status, nil
}

// hasStatusChanged checks if CI status has changed significantly
func (pm *PRManager) hasStatusChanged(last, current *types.CIStatus) bool {
	if last == nil {
		return true
	}
	
	return last.Status != current.Status ||
		   last.PassedChecks != current.PassedChecks ||
		   last.FailedChecks != current.FailedChecks ||
		   last.PendingChecks != current.PendingChecks
}

// isAllChecksComplete determines if all CI checks have completed
func (pm *PRManager) isAllChecksComplete(status *types.CIStatus) bool {
	return status.PendingChecks == 0 && status.TotalChecks > 0
}

// formatStatusMessage creates a human-readable status message
func (pm *PRManager) formatStatusMessage(status *types.CIStatus) string {
	if status.TotalChecks == 0 {
		return "No CI checks found"
	}

	return fmt.Sprintf("CI Status: %d total, %d passed, %d failed, %d pending", 
		status.TotalChecks, status.PassedChecks, status.FailedChecks, status.PendingChecks)
}

// AnalyzeCIFailures analyzes failed checks for potential recovery
func (pm *PRManager) AnalyzeCIFailures(status *types.CIStatus) []types.CIFailureInfo {
	var failures []types.CIFailureInfo

	for _, check := range status.Checks {
		if check.Conclusion == "failure" || check.Conclusion == "error" {
			failure := types.CIFailureInfo{
				CheckName:  check.Name,
				DetailsURL: check.URL,
			}

			// Analyze failure type
			checkNameLower := strings.ToLower(check.Name)
			if strings.Contains(checkNameLower, "build") {
				failure.Type = types.CIFailureBuild
				failure.Recoverable = true
			} else if strings.Contains(checkNameLower, "lint") {
				failure.Type = types.CIFailureLint
				failure.Recoverable = true
			} else if strings.Contains(checkNameLower, "test") {
				failure.Type = types.CIFailureTest
				failure.Recoverable = true
			} else {
				failure.Type = types.CIFailureUnknown
				failure.Recoverable = false
			}

			failure.FailureText = check.Description

			failures = append(failures, failure)
		}
	}

	return failures
}

// GetPRComments retrieves all comments for a PR
func (pm *PRManager) GetPRComments(prURL string) ([]types.PRComment, error) {
	cmd := exec.Command("gh", "pr", "view", prURL, "--json", "comments")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch PR comments: %w\nOutput: %s", err, string(output))
	}

	var prData struct {
		Comments []types.PRComment `json:"comments"`
	}

	if err := json.Unmarshal(output, &prData); err != nil {
		return nil, fmt.Errorf("failed to parse PR comments: %w", err)
	}

	return prData.Comments, nil
}

// AnalyzePRComments analyzes PR comments to identify actionable items
func (pm *PRManager) AnalyzePRComments(comments []types.PRComment) *types.PRCommentAnalysis {
	analysis := &types.PRCommentAnalysis{
		Comments:           comments,
		ActionableComments: make([]types.ActionableComment, 0),
		TotalComments:      len(comments),
	}

	for _, comment := range comments {
		actionable := pm.analyzeCommentContent(comment)
		if actionable.Actionable {
			analysis.ActionableComments = append(analysis.ActionableComments, actionable)
			analysis.HasUnaddressedComments = true
		}
	}

	return analysis
}

// analyzeCommentContent analyzes individual comment content for actionability
func (pm *PRManager) analyzeCommentContent(comment types.PRComment) types.ActionableComment {
	body := strings.ToLower(comment.Body)
	actionable := types.ActionableComment{
		Comment:    comment,
		Actionable: false,
		Priority:   types.CommentPriorityLow,
	}

	// Skip bot comments (GitHub bots, PR review bots, etc.)
	if pm.isBotComment(comment) {
		actionable.Category = types.CommentBotGenerated
		return actionable
	}

	// Detect actionable patterns
	if pm.containsCodeSuggestion(body) {
		actionable.Category = types.CommentCodeReview
		actionable.Priority = types.CommentPriorityHigh
		actionable.Actionable = true
		actionable.Suggestion = "Code change suggestion detected"
	} else if pm.containsQuestion(body) {
		actionable.Category = types.CommentQuestion
		actionable.Priority = types.CommentPriorityMedium
		actionable.Actionable = true
		actionable.Suggestion = "Question requiring response"
	} else if pm.containsRequest(body) {
		actionable.Category = types.CommentRequest
		actionable.Priority = types.CommentPriorityHigh
		actionable.Actionable = true
		actionable.Suggestion = "Specific request or change needed"
	} else if pm.containsApproval(body) {
		actionable.Category = types.CommentApproval
		actionable.Actionable = false
	} else {
		actionable.Category = types.CommentDiscussion
		actionable.Actionable = pm.requiresResponse(body)
		if actionable.Actionable {
			actionable.Priority = types.CommentPriorityMedium
			actionable.Suggestion = "Discussion requiring response"
		}
	}

	return actionable
}

// isBotComment checks if comment is from a bot
func (pm *PRManager) isBotComment(comment types.PRComment) bool {
	botPatterns := []string{
		"github-actions", "dependabot", "codecov", "sonarcloud",
		"copilot", "renovate", "greenkeeper", "snyk-bot",
	}
	
	username := strings.ToLower(comment.User.Login)
	for _, pattern := range botPatterns {
		if strings.Contains(username, pattern) {
			return true
		}
	}
	
	return false
}

// containsCodeSuggestion detects code suggestions in comment
func (pm *PRManager) containsCodeSuggestion(body string) bool {
	patterns := []string{
		"suggest", "should be", "could be", "consider changing",
		"you might want to", "it would be better", "recommend",
		"```", "this should", "please change",
	}
	
	for _, pattern := range patterns {
		if strings.Contains(body, pattern) {
			return true
		}
	}
	
	return false
}

// containsQuestion detects questions in comment
func (pm *PRManager) containsQuestion(body string) bool {
	return strings.Contains(body, "?") || 
		   strings.Contains(body, "why") ||
		   strings.Contains(body, "how") ||
		   strings.Contains(body, "what") ||
		   strings.Contains(body, "when") ||
		   strings.Contains(body, "where")
}

// containsRequest detects specific requests in comment
func (pm *PRManager) containsRequest(body string) bool {
	patterns := []string{
		"please", "can you", "could you", "would you",
		"need to", "must", "required", "fix this",
		"add", "remove", "update", "change this",
	}
	
	for _, pattern := range patterns {
		if strings.Contains(body, pattern) {
			return true
		}
	}
	
	return false
}

// containsApproval detects approval comments
func (pm *PRManager) containsApproval(body string) bool {
	patterns := []string{
		"lgtm", "looks good", "approved", "great work",
		"nice job", "well done", "👍", "✅", ":+1:",
		"ship it", "ready to merge",
	}
	
	for _, pattern := range patterns {
		if strings.Contains(body, pattern) {
			return true
		}
	}
	
	return false
}

// requiresResponse checks if general discussion requires response
func (pm *PRManager) requiresResponse(body string) bool {
	// Simple heuristic: longer comments or those mentioning the PR author likely need response
	return len(body) > 100 || 
		   strings.Contains(body, "@") ||
		   strings.Contains(body, "thoughts") ||
		   strings.Contains(body, "opinion")
}

// Helper function to safely parse integers
func parseInt(s string) int {
	if result, err := strconv.Atoi(s); err == nil {
		return result
	}
	
	// Fallback to manual parsing
	result := 0
	for _, char := range s {
		if char >= '0' && char <= '9' {
			result = result*10 + int(char-'0')
		}
	}
	return result
}