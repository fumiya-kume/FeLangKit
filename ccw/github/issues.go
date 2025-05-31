package github

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"

	"ccw/types"
)

// GetIssue fetches issue data using gh CLI
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

// ListIssues fetches issues from a repository
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

// ExtractIssueInfo extracts issue information from URL
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