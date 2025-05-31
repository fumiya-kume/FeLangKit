package github

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

// ExtractRepoInfo extracts repository information from URL
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

// GetCurrentRepoURL gets current repository's GitHub remote URL
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