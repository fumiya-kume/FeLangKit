package pr

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"ccw/types"
)

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
