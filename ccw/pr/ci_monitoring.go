package pr

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"ccw/types"
)

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
