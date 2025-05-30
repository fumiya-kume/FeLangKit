package github

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"ccw/types"
)

// GitHub client using gh CLI
type GitHubClient struct {
	// No fields needed - uses gh CLI commands
}

// Check if gh CLI is available and authenticated
func CheckGHCLI() error {
	debugLog("CheckGHCLI", "Checking gh CLI availability and authentication", nil)

	// Check if gh command is available
	if _, err := exec.LookPath("gh"); err != nil {
		debugLog("CheckGHCLI", "gh CLI not found in PATH", map[string]interface{}{
			"error": err.Error(),
		})
		return fmt.Errorf("gh CLI is not installed. Please install it: brew install gh")
	}

	debugLog("CheckGHCLI", "gh CLI found in PATH", nil)

	// Check if user is authenticated
	cmd := exec.Command("gh", "auth", "status")
	output, err := cmd.CombinedOutput()

	if err != nil {
		debugLog("CheckGHCLI", "gh auth status failed", map[string]interface{}{
			"error":  err.Error(),
			"output": string(output),
		})
		return fmt.Errorf("gh CLI is not authenticated. Please run: gh auth login")
	}

	debugLog("CheckGHCLI", "gh CLI authentication verified", map[string]interface{}{
		"output": string(output),
	})

	return nil
}

// Fetch issue data using gh CLI
func (gc *GitHubClient) GetIssue(owner, repo string, issueNumber int) (*types.Issue, error) {
	apiEndpoint := fmt.Sprintf("repos/%s/%s/issues/%d", owner, repo, issueNumber)
	debugLog("GetIssue", "Fetching issue data", map[string]interface{}{
		"owner":        owner,
		"repo":         repo,
		"issue_number": issueNumber,
		"api_endpoint": apiEndpoint,
	})

	cmd := exec.Command("gh", "api", apiEndpoint)

	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			debugLog("GetIssue", "gh api command failed", map[string]interface{}{
				"error":   err.Error(),
				"stderr":  string(exitError.Stderr),
				"command": fmt.Sprintf("gh api %s", apiEndpoint),
			})
		} else {
			debugLog("GetIssue", "gh command execution failed", map[string]interface{}{
				"error":   err.Error(),
				"command": fmt.Sprintf("gh api %s", apiEndpoint),
			})
		}
		return nil, fmt.Errorf("failed to fetch issue via gh CLI: %w", err)
	}

	debugLog("GetIssue", "Issue data received", map[string]interface{}{
		"output_length": len(output),
		"raw_output":    truncateString(string(output), 500),
	})

	var issue types.Issue
	if err := json.Unmarshal(output, &issue); err != nil {
		debugLog("GetIssue", "Failed to decode issue JSON", map[string]interface{}{
			"error":      err.Error(),
			"raw_output": string(output),
		})
		return nil, fmt.Errorf("failed to decode issue data: %w", err)
	}

	debugLog("GetIssue", "Issue decoded successfully", map[string]interface{}{
		"issue_title":  issue.Title,
		"issue_state":  issue.State,
		"issue_labels": len(issue.Labels),
	})

	return &issue, nil
}

// Create pull request using gh CLI
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

// Check for existing PRs for this branch
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

// Get PR status and checks
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
			Conclusion string `json:"conclusion"`
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
		if check.State == "FAILURE" || check.Conclusion == "FAILURE" {
			return "failed", nil
		}
		if check.State == "PENDING" || check.State == "IN_PROGRESS" {
			return "pending", nil
		}
	}

	return "success", nil
}

// Get detailed CI status for monitoring
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
			Conclusion  string `json:"conclusion"`
			Link        string `json:"link"`
			StartedAt   string `json:"startedAt"`
			CompletedAt string `json:"completedAt"`
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
		checkRun := types.CheckRun{
			Name:       check.Name,
			Status:     strings.ToLower(check.State),
			Conclusion: strings.ToLower(check.Conclusion),
			URL:        check.Link,
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
		if check.State == "PENDING" || check.State == "IN_PROGRESS" {
			overallStatus = "pending"
		} else if check.State == "FAILURE" || check.Conclusion == "FAILURE" {
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

// Monitor CI status with updates
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

// List issues from a repository
func (gc *GitHubClient) ListIssues(owner, repo string, state string, labels []string, limit int) ([]*types.Issue, error) {
	// Build base URL
	url := fmt.Sprintf("repos/%s/%s/issues", owner, repo)

	// Add query parameters to URL
	params := []string{}
	if state != "" {
		params = append(params, fmt.Sprintf("state=%s", state))
	}
	if len(labels) > 0 {
		labelStr := strings.Join(labels, ",")
		params = append(params, fmt.Sprintf("labels=%s", labelStr))
	}
	if limit > 0 {
		params = append(params, fmt.Sprintf("per_page=%d", limit))
	}

	// Append query parameters to URL
	if len(params) > 0 {
		url += "?" + strings.Join(params, "&")
	}

	cmd := exec.Command("gh", "api", url)

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch issues via gh CLI: %w", err)
	}

	var issues []*types.Issue
	if err := json.Unmarshal(output, &issues); err != nil {
		return nil, fmt.Errorf("failed to decode issues data: %w", err)
	}

	return issues, nil
}

// Extract repository information from URL
func ExtractRepoInfo(repoURL string) (owner, repo string, err error) {
	// Handle different GitHub URL formats
	patterns := []string{
		`^https://github\.com/([^/]+)/([^/]+)/?$`,
		`^https://github\.com/([^/]+)/([^/]+)\.git$`,
		`^git@github\.com:([^/]+)/([^/]+)\.git$`,
		`^([^/]+)/([^/]+)$`, // Simple owner/repo format
	}

	for _, pattern := range patterns {
		re := regexp.MustCompile(pattern)
		matches := re.FindStringSubmatch(repoURL)

		if len(matches) == 3 {
			return matches[1], matches[2], nil
		}
	}

	return "", "", fmt.Errorf("invalid GitHub repository URL or format: %s", repoURL)
}

// Get current repository's GitHub remote URL
func GetCurrentRepoURL() (string, error) {
	// Try to get the origin remote URL
	cmd := exec.Command("git", "remote", "get-url", "origin")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get git remote URL: %w (make sure you're in a git repository)", err)
	}

	remoteURL := strings.TrimSpace(string(output))
	if remoteURL == "" {
		return "", fmt.Errorf("no git remote URL found")
	}

	// Convert SSH URL to HTTPS format if needed for consistency
	if strings.HasPrefix(remoteURL, "git@github.com:") {
		// Convert git@github.com:owner/repo.git to https://github.com/owner/repo
		sshPattern := regexp.MustCompile(`^git@github\.com:([^/]+)/(.+)\.git$`)
		matches := sshPattern.FindStringSubmatch(remoteURL)
		if len(matches) == 3 {
			remoteURL = fmt.Sprintf("https://github.com/%s/%s", matches[1], matches[2])
		}
	} else if strings.HasPrefix(remoteURL, "ssh://git@github.com/") {
		// Convert ssh://git@github.com/owner/repo.git to https://github.com/owner/repo
		sshPattern := regexp.MustCompile(`^ssh://git@github\.com/([^/]+)/(.+)\.git$`)
		matches := sshPattern.FindStringSubmatch(remoteURL)
		if len(matches) == 3 {
			remoteURL = fmt.Sprintf("https://github.com/%s/%s", matches[1], matches[2])
		}
	}

	// Remove .git suffix if present
	remoteURL = strings.TrimSuffix(remoteURL, ".git")

	return remoteURL, nil
}

// Extract issue information from URL
func ExtractIssueInfo(issueURL string) (owner, repo string, issueNumber int, err error) {
	re := regexp.MustCompile(`^https://github\.com/([^/]+)/([^/]+)/issues/(\d+)$`)
	matches := re.FindStringSubmatch(issueURL)

	if len(matches) != 4 {
		return "", "", 0, fmt.Errorf("invalid GitHub issue URL format")
	}

	owner = matches[1]
	repo = matches[2]
	issueNumber, err = strconv.Atoi(matches[3])
	if err != nil {
		return "", "", 0, fmt.Errorf("invalid issue number: %s", matches[3])
	}

	return owner, repo, issueNumber, nil
}

// Debug logging helper functions
func debugLog(function, message string, context map[string]interface{}) {
	if os.Getenv("DEBUG_MODE") == "true" || os.Getenv("VERBOSE_MODE") == "true" {
		contextStr := ""
		if context != nil {
			if data, err := json.Marshal(context); err == nil {
				contextStr = string(data)
			}
		}

		fmt.Printf("[DEBUG] [GitHub:%s] %s", function, message)
		if contextStr != "" {
			fmt.Printf(" | Context: %s", contextStr)
		}
		fmt.Println()
	}
}

// Truncate string for logging purposes
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
