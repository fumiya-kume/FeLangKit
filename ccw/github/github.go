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

// GitHub client using gh CLI
type GitHubClient struct {
	// No fields needed - uses gh CLI commands
}

// Check if gh CLI is available and authenticated
func CheckGHCLI() error {
	// Check if gh command is available
	if _, err := exec.LookPath("gh"); err != nil {
		return fmt.Errorf("gh CLI is not installed. Please install it: brew install gh")
	}
	
	// Check if user is authenticated
	cmd := exec.Command("gh", "auth", "status")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gh CLI is not authenticated. Please run: gh auth login")
	}
	
	return nil
}

// Fetch issue data using gh CLI
func (gc *GitHubClient) GetIssue(owner, repo string, issueNumber int) (*types.Issue, error) {
	cmd := exec.Command("gh", "api", fmt.Sprintf("repos/%s/%s/issues/%d", owner, repo, issueNumber))
	
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch issue via gh CLI: %w", err)
	}
	
	var issue types.Issue
	if err := json.Unmarshal(output, &issue); err != nil {
		return nil, fmt.Errorf("failed to decode issue data: %w", err)
	}
	
	return &issue, nil
}

// Create pull request using gh CLI
func (gc *GitHubClient) CreatePR(owner, repo string, req *types.PRRequest) (*types.PullRequest, error) {
	// Create PR using gh pr create command
	cmd := exec.Command("gh", "pr", "create", 
		"--title", req.Title,
		"--body", req.Body,
		"--head", req.Head,
		"--base", req.Base,
		"--repo", fmt.Sprintf("%s/%s", owner, repo))
	
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to create PR via gh CLI: %w", err)
	}
	
	// Parse the PR URL from output to get PR number
	prURL := strings.TrimSpace(string(output))
	
	// Extract PR number from URL (e.g., https://github.com/owner/repo/pull/123)
	re := regexp.MustCompile(`/pull/(\d+)$`)
	matches := re.FindStringSubmatch(prURL)
	if len(matches) != 2 {
		return nil, fmt.Errorf("failed to extract PR number from URL: %s", prURL)
	}
	
	prNumber, err := strconv.Atoi(matches[1])
	if err != nil {
		return nil, fmt.Errorf("failed to parse PR number: %w", err)
	}
	
	return &types.PullRequest{
		Number:  prNumber,
		URL:     prURL,
		HTMLURL: prURL,
		State:   "open",
	}, nil
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
			Status      string `json:"status"`
			Conclusion  string `json:"conclusion"`
			DetailsURL  string `json:"detailsUrl"`
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
			Status:     strings.ToLower(check.Status),
			Conclusion: strings.ToLower(check.Conclusion),
			URL:        check.DetailsURL,
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
		if check.Status == "PENDING" || check.Status == "IN_PROGRESS" {
			overallStatus = "pending"
		} else if check.Status == "FAILURE" || check.Conclusion == "FAILURE" {
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