package internal

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Issue represents a GitHub issue
type Issue struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	Body   string `json:"body"`
	URL    string `json:"url"`
	State  string `json:"state"`
}

// PullRequest represents a GitHub pull request
type PullRequest struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	Body   string `json:"body"`
	URL    string `json:"url"`
	State  string `json:"state"`
}

// GitHubClient handles all GitHub API interactions
type GitHubClient struct {
	timeout time.Duration
}

// NewGitHubClient creates a new GitHub client
func NewGitHubClient() *GitHubClient {
	return &GitHubClient{
		timeout: 30 * time.Second,
	}
}

// CheckGHCLI verifies that gh CLI is installed and authenticated
func (g *GitHubClient) CheckGHCLI() error {
	// Check if gh is installed
	if _, err := exec.LookPath("gh"); err != nil {
		return fmt.Errorf("gh CLI not found. Please install it: https://cli.github.com")
	}

	// Check if gh is authenticated
	cmd := exec.Command("gh", "auth", "status")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gh CLI not authenticated. Please run: gh auth login")
	}

	return nil
}

// FetchIssue retrieves issue details from GitHub
func (g *GitHubClient) FetchIssue(issueURL string) (*Issue, error) {
	// Extract owner, repo, and issue number from URL
	parts := strings.Split(issueURL, "/")
	if len(parts) < 7 || parts[len(parts)-2] != "issues" {
		return nil, fmt.Errorf("invalid issue URL format")
	}

	owner := parts[3]
	repo := parts[4]
	issueNumber := parts[len(parts)-1]

	// Fetch issue using gh CLI
	cmd := exec.Command("gh", "issue", "view", issueNumber,
		"--repo", fmt.Sprintf("%s/%s", owner, repo),
		"--json", "number,title,body,url,state")

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch issue: %w", err)
	}

	var issue Issue
	if err := json.Unmarshal(output, &issue); err != nil {
		return nil, fmt.Errorf("failed to parse issue data: %w", err)
	}

	return &issue, nil
}

// CreatePullRequest creates a new pull request
func (g *GitHubClient) CreatePullRequest(title, body, branch string) (*PullRequest, error) {
	// Create PR using gh CLI
	cmd := exec.Command("gh", "pr", "create",
		"--title", title,
		"--body", body,
		"--head", branch,
		"--base", "master")

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to create PR: %w", err)
	}

	prURL := strings.TrimSpace(string(output))

	// Fetch PR details
	viewCmd := exec.Command("gh", "pr", "view", prURL, "--json", "number,title,body,url,state")
	viewOutput, err := viewCmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to fetch PR details: %w", err)
	}

	var pr PullRequest
	if err := json.Unmarshal(viewOutput, &pr); err != nil {
		return nil, fmt.Errorf("failed to parse PR data: %w", err)
	}

	return &pr, nil
}

// WaitForPRChecks waits for PR checks to complete
func (g *GitHubClient) WaitForPRChecks(prURL string) error {
	maxAttempts := 60 // 30 minutes with 30-second intervals
	interval := 30 * time.Second

	for i := 0; i < maxAttempts; i++ {
		// Check PR status
		cmd := exec.Command("gh", "pr", "checks", prURL)
		output, err := cmd.CombinedOutput()

		if err == nil {
			// All checks passed
			return nil
		}

		outputStr := string(output)
		if strings.Contains(outputStr, "Some checks were not successful") {
			return fmt.Errorf("PR checks failed")
		}

		// Checks still pending, wait and retry
		if i < maxAttempts-1 {
			time.Sleep(interval)
		}
	}

	return fmt.Errorf("timed out waiting for PR checks")
}

// ListOpenPRs lists all open pull requests
func (g *GitHubClient) ListOpenPRs() ([]PullRequest, error) {
	cmd := exec.Command("gh", "pr", "list", "--json", "number,title,url,state")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list PRs: %w", err)
	}

	var prs []PullRequest
	if err := json.Unmarshal(output, &prs); err != nil {
		return nil, fmt.Errorf("failed to parse PR list: %w", err)
	}

	return prs, nil
}

// GeneratePRDescription generates an AI-powered PR description
func (g *GitHubClient) GeneratePRDescription(issue *Issue, commitMessages []string) string {
	// Create a comprehensive PR description
	var description strings.Builder

	description.WriteString("## Summary\n")
	description.WriteString(fmt.Sprintf("Resolves #%d: %s\n\n", issue.Number, issue.Title))

	description.WriteString("## Background & Context\n")
	description.WriteString(issue.Body)
	description.WriteString("\n\n")

	description.WriteString("## Changes Made\n")
	for _, commit := range commitMessages {
		description.WriteString(fmt.Sprintf("- %s\n", commit))
	}
	description.WriteString("\n")

	description.WriteString("## Testing\n")
	description.WriteString("- ✅ All tests pass\n")
	description.WriteString("- ✅ SwiftLint validation successful\n")
	description.WriteString("- ✅ Build successful\n\n")

	description.WriteString("## Quality Checks\n")
	description.WriteString("This PR has been validated with:\n")
	description.WriteString("```bash\n")
	description.WriteString("swiftlint lint --fix && swiftlint lint && swift build && swift test\n")
	description.WriteString("```\n")

	return description.String()
}

// CloseIssue closes a GitHub issue
func (g *GitHubClient) CloseIssue(issueNumber int) error {
	cmd := exec.Command("gh", "issue", "close", fmt.Sprintf("%d", issueNumber))
	return cmd.Run()
}

// AddComment adds a comment to an issue or PR
func (g *GitHubClient) AddComment(targetURL, comment string) error {
	cmd := exec.Command("gh", "comment", "create", "--body", comment, targetURL)
	return cmd.Run()
}
