package github

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"ccw/types"
)

// CreatePR creates a pull request using gh CLI
func (gc *GitHubClient) CreatePR(owner, repo string, req *types.PRRequest) (*types.PullRequest, error) {
	repoStr := fmt.Sprintf("%s/%s", owner, repo)

	debugLog("CreatePR", "Creating pull request", map[string]interface{}{
		"owner":    owner,
		"repo":     repo,
		"title":    req.Title,
		"head":     req.Head,
		"base":     req.Base,
		"body_len": len(req.Body),
		"repo_str": repoStr,
	})

	// Create PR using gh pr create command with comprehensive error capture
	args := []string{"pr", "create",
		"--title", req.Title,
		"--body", req.Body,
		"--head", req.Head,
		"--base", req.Base,
		"--repo", repoStr}

	debugLog("CreatePR", "Executing gh command", map[string]interface{}{
		"command": "gh",
		"args":    args,
	})

	cmd := exec.Command("gh", args...)

	// Capture both stdout and stderr
	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			debugLog("CreatePR", "gh pr create command failed", map[string]interface{}{
				"error":     err.Error(),
				"stderr":    string(exitError.Stderr),
				"exit_code": exitError.ExitCode(),
				"command":   fmt.Sprintf("gh %s", strings.Join(args, " ")),
				"owner":     owner,
				"repo":      repo,
				"head":      req.Head,
				"base":      req.Base,
			})
			return nil, fmt.Errorf("failed to create PR via gh CLI (exit code %d): %w\nStderr: %s",
				exitError.ExitCode(), err, string(exitError.Stderr))
		} else {
			debugLog("CreatePR", "gh pr create execution failed", map[string]interface{}{
				"error":   err.Error(),
				"command": fmt.Sprintf("gh %s", strings.Join(args, " ")),
				"owner":   owner,
				"repo":    repo,
			})
			return nil, fmt.Errorf("failed to create PR via gh CLI: %w", err)
		}
	}

	// Parse the PR URL from output to get PR number
	prURL := strings.TrimSpace(string(output))

	debugLog("CreatePR", "PR creation output received", map[string]interface{}{
		"raw_output": prURL,
		"output_len": len(prURL),
	})

	// Extract PR number from URL (e.g., https://github.com/owner/repo/pull/123)
	re := regexp.MustCompile(`/pull/(\d+)$`)
	matches := re.FindStringSubmatch(prURL)
	if len(matches) != 2 {
		debugLog("CreatePR", "Failed to extract PR number from URL", map[string]interface{}{
			"url":     prURL,
			"regex":   `/pull/(\d+)$`,
			"matches": matches,
		})
		return nil, fmt.Errorf("failed to extract PR number from URL: %s", prURL)
	}

	prNumber, err := strconv.Atoi(matches[1])
	if err != nil {
		debugLog("CreatePR", "Failed to parse PR number", map[string]interface{}{
			"pr_number_str": matches[1],
			"error":         err.Error(),
		})
		return nil, fmt.Errorf("failed to parse PR number: %w", err)
	}

	pr := &types.PullRequest{
		Number:  prNumber,
		URL:     prURL,
		HTMLURL: prURL,
		State:   "open",
	}

	debugLog("CreatePR", "PR created successfully", map[string]interface{}{
		"pr_number": prNumber,
		"pr_url":    prURL,
		"pr_state":  "open",
	})

	return pr, nil
}

// CheckExistingPR checks for existing PRs for this branch
func (gc *GitHubClient) CheckExistingPR(owner, repo, branchName string) (*types.PullRequest, error) {
	cmd := exec.Command("gh", "pr", "list",
		"--head", branchName,
		"--repo", fmt.Sprintf("%s/%s", owner, repo),
		"--json", "number,url,title,state")

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to check existing PRs: %w", err)
	}

	var prs []types.PullRequest
	if err := json.Unmarshal(output, &prs); err != nil {
		return nil, fmt.Errorf("failed to decode PR list: %w", err)
	}

	if len(prs) > 0 {
		return &prs[0], nil
	}

	return nil, nil
}

// GetPRStatus gets PR status and checks
func (gc *GitHubClient) GetPRStatus(owner, repo string, prNumber int) (string, error) {
	cmd := exec.Command("gh", "pr", "view", strconv.Itoa(prNumber),
		"--repo", fmt.Sprintf("%s/%s", owner, repo),
		"--json", "statusCheckRollup")

	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get PR status: %w", err)
	}

	var result struct {
		StatusCheckRollup []struct {
			State      string `json:"state"`
		} `json:"statusCheckRollup"`
	}

	if err := json.Unmarshal(output, &result); err != nil {
		return "", fmt.Errorf("failed to decode PR status: %w", err)
	}

	// Analyze check results
	if len(result.StatusCheckRollup) == 0 {
		return "pending", nil
	}

	for _, check := range result.StatusCheckRollup {
		if strings.ToUpper(check.State) == "FAILURE" || strings.ToUpper(check.State) == "FAILED" {
			return "failed", nil
		}
		if strings.ToUpper(check.State) == "PENDING" || strings.ToUpper(check.State) == "IN_PROGRESS" {
			return "pending", nil
		}
	}

	return "success", nil
}

// GetDetailedCIStatus gets detailed CI status for monitoring
func (gc *GitHubClient) GetDetailedCIStatus(owner, repo string, prNumber int) (*types.CIStatus, error) {
	cmd := exec.Command("gh", "pr", "view", strconv.Itoa(prNumber),
		"--repo", fmt.Sprintf("%s/%s", owner, repo),
		"--json", "statusCheckRollup,url")

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get detailed CI status: %w", err)
	}

	var result struct {
		StatusCheckRollup []struct {
			Name        string `json:"name"`
			State       string `json:"state"`
			Link        string `json:"link"`
			StartedAt   string `json:"startedAt"`
			CompletedAt string `json:"completedAt"`
			Description string `json:"description"`
			Event       string `json:"event"`
			Workflow    string `json:"workflow"`
			Bucket      string `json:"bucket"`
		} `json:"statusCheckRollup"`
		URL string `json:"url"`
	}

	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("failed to decode detailed CI status: %w", err)
	}

	ciStatus := &types.CIStatus{
		LastUpdated: time.Now(),
		URL:         result.URL,
		Checks:      make([]types.CheckRun, 0, len(result.StatusCheckRollup)),
	}

	// Convert checks
	overallStatus := "success"
	for _, check := range result.StatusCheckRollup {
		// Derive conclusion from state since gh CLI doesn't provide conclusion field
		conclusion := ""
		state := strings.ToLower(check.State)
		switch strings.ToUpper(check.State) {
		case "SUCCESS":
			conclusion = "success"
		case "FAILURE", "FAILED":
			conclusion = "failure"
		case "PENDING", "IN_PROGRESS":
			conclusion = ""
		default:
			// For other states, check if it's completed
			if check.CompletedAt != "" {
				conclusion = state
			}
		}

		checkRun := types.CheckRun{
			Name:        check.Name,
			Status:      state,
			Conclusion:  conclusion,
			URL:         check.Link,
			Description: check.Description,
			Event:       check.Event,
			Workflow:    check.Workflow,
			Bucket:      check.Bucket,
		}

		// Parse timestamps
		if check.StartedAt != "" {
			if startedAt, err := time.Parse(time.RFC3339, check.StartedAt); err == nil {
				checkRun.StartedAt = startedAt
			}
		}
		if check.CompletedAt != "" {
			if completedAt, err := time.Parse(time.RFC3339, check.CompletedAt); err == nil {
				checkRun.CompletedAt = completedAt
			}
		}

		ciStatus.Checks = append(ciStatus.Checks, checkRun)

		// Determine overall status
		if strings.ToUpper(check.State) == "PENDING" || strings.ToUpper(check.State) == "IN_PROGRESS" {
			overallStatus = "pending"
		} else if strings.ToUpper(check.State) == "FAILURE" || strings.ToUpper(check.State) == "FAILED" {
			overallStatus = "failure"
			ciStatus.Conclusion = "failure"
		}
	}

	ciStatus.Status = overallStatus
	if overallStatus == "success" {
		ciStatus.Conclusion = "success"
	}

	return ciStatus, nil
}

// MonitorCIStatus monitors CI status with updates
func (gc *GitHubClient) MonitorCIStatus(owner, repo string, prNumber int, callback func(*types.CIStatus)) error {
	ticker := time.NewTicker(30 * time.Second) // Check every 30 seconds
	defer ticker.Stop()

	maxDuration := 30 * time.Minute // Maximum monitoring time
	timeout := time.After(maxDuration)

	// Initial check
	status, err := gc.GetDetailedCIStatus(owner, repo, prNumber)
	if err != nil {
		return fmt.Errorf("failed to get initial CI status: %w", err)
	}
	callback(status)

	// If already completed, return
	if status.Status == "success" || status.Status == "failure" {
		return nil
	}

	for {
		select {
		case <-timeout:
			return fmt.Errorf("CI monitoring timed out after %v", maxDuration)
		case <-ticker.C:
			status, err := gc.GetDetailedCIStatus(owner, repo, prNumber)
			if err != nil {
				// Log error but continue monitoring
				continue
			}

			callback(status)

			// Stop monitoring if CI is complete
			if status.Status == "success" || status.Status == "failure" {
				return nil
			}
		}
	}
}