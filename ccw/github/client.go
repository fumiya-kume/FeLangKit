package github

// GitHubClient handles GitHub operations using gh CLI
type GitHubClient struct {
	// No fields needed - uses gh CLI commands
}

// NewGitHubClient creates a new GitHub client instance
func NewGitHubClient() *GitHubClient {
	return &GitHubClient{}
}