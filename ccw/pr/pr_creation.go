package pr

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"ccw/types"
)

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
