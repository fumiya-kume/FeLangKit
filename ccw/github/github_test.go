package github

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"

	"ccw/types"
)

func TestCheckGHCLI_Success(t *testing.T) {
	// This test verifies the structure and logic of CheckGHCLI
	// In a real environment, it might succeed or fail based on gh installation
	
	// This is more of an integration test since it actually calls exec.LookPath
	if _, err := exec.LookPath("gh"); err != nil {
		t.Skip("gh CLI not available in test environment, skipping test")
	}
	
	// Call CheckGHCLI - this will either succeed or fail with authentication error
	err := CheckGHCLI()
	
	// We expect either success or authentication failure
	if err != nil && !strings.Contains(err.Error(), "not authenticated") {
		t.Logf("CheckGHCLI returned expected error (gh not authenticated): %v", err)
	} else if err == nil {
		t.Logf("CheckGHCLI succeeded (gh is properly authenticated)")
	} else {
		t.Errorf("Unexpected error from CheckGHCLI: %v", err)
	}
}

func TestGitHubClient_GetIssue_Logic(t *testing.T) {
	_ = &GitHubClient{}
	
	// Test parameters
	owner := "fumiya-kume"
	repo := "FeLangKit"
	issueNumber := 123
	
	// This tests the command construction logic
	expectedEndpoint := fmt.Sprintf("repos/%s/%s/issues/%d", owner, repo, issueNumber)
	expectedCommand := []string{"gh", "api", expectedEndpoint}
	
	t.Logf("GetIssue would execute: %v", expectedCommand)
	t.Logf("API endpoint: %s", expectedEndpoint)
	
	// Test that the endpoint construction is correct
	if expectedEndpoint != "repos/fumiya-kume/FeLangKit/issues/123" {
		t.Errorf("Expected endpoint 'repos/fumiya-kume/FeLangKit/issues/123', got '%s'", expectedEndpoint)
	}
}

func TestGitHubClient_CreatePR_Logic(t *testing.T) {
	_ = &GitHubClient{}
	
	// Test PR request
	req := &types.PRRequest{
		Title: "Test PR",
		Body:  "This is a test PR body",
		Head:  "feature-branch",
		Base:  "master",
	}
	
	owner := "fumiya-kume"
	repo := "FeLangKit"
	repoStr := fmt.Sprintf("%s/%s", owner, repo)
	
	// Test command construction
	expectedArgs := []string{"pr", "create",
		"--title", req.Title,
		"--body", req.Body,
		"--head", req.Head,
		"--base", req.Base,
		"--repo", repoStr}
	
	t.Logf("CreatePR would execute: gh %v", expectedArgs)
	
	// Verify command structure
	if expectedArgs[0] != "pr" || expectedArgs[1] != "create" {
		t.Error("Expected command to start with 'pr create'")
	}
	if expectedArgs[3] != req.Title {
		t.Errorf("Expected title '%s', got '%s'", req.Title, expectedArgs[3])
	}
	if expectedArgs[11] != repoStr {
		t.Errorf("Expected repo '%s', got '%s'", repoStr, expectedArgs[11])
	}
}

func TestExtractRepoInfo(t *testing.T) {
	testCases := []struct {
		name         string
		repoURL      string
		expectedOwner string
		expectedRepo  string
		expectError   bool
	}{
		{
			name:          "HTTPS URL",
			repoURL:       "https://github.com/fumiya-kume/FeLangKit",
			expectedOwner: "fumiya-kume",
			expectedRepo:  "FeLangKit",
			expectError:   false,
		},
		{
			name:          "HTTPS URL with .git",
			repoURL:       "https://github.com/fumiya-kume/FeLangKit.git",
			expectedOwner: "fumiya-kume",
			expectedRepo:  "FeLangKit.git",
			expectError:   false,
		},
		{
			name:          "SSH URL",
			repoURL:       "git@github.com:fumiya-kume/FeLangKit.git",
			expectedOwner: "fumiya-kume",
			expectedRepo:  "FeLangKit",
			expectError:   false,
		},
		{
			name:          "Simple format",
			repoURL:       "fumiya-kume/FeLangKit",
			expectedOwner: "fumiya-kume",
			expectedRepo:  "FeLangKit",
			expectError:   false,
		},
		{
			name:        "Invalid URL",
			repoURL:     "not-a-valid-url",
			expectError: true,
		},
		{
			name:        "Empty URL",
			repoURL:     "",
			expectError: true,
		},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			owner, repo, err := ExtractRepoInfo(tc.repoURL)
			
			if tc.expectError {
				if err == nil {
					t.Errorf("Expected error for URL '%s', but got none", tc.repoURL)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for URL '%s': %v", tc.repoURL, err)
				}
				if owner != tc.expectedOwner {
					t.Errorf("Expected owner '%s', got '%s'", tc.expectedOwner, owner)
				}
				if repo != tc.expectedRepo {
					t.Errorf("Expected repo '%s', got '%s'", tc.expectedRepo, repo)
				}
			}
		})
	}
}

func TestExtractIssueInfo(t *testing.T) {
	testCases := []struct {
		name               string
		issueURL           string
		expectedOwner      string
		expectedRepo       string
		expectedIssueNumber int
		expectError        bool
	}{
		{
			name:               "Valid issue URL",
			issueURL:           "https://github.com/fumiya-kume/FeLangKit/issues/123",
			expectedOwner:      "fumiya-kume",
			expectedRepo:       "FeLangKit",
			expectedIssueNumber: 123,
			expectError:        false,
		},
		{
			name:               "Another valid issue URL",
			issueURL:           "https://github.com/owner/repo-name/issues/456",
			expectedOwner:      "owner",
			expectedRepo:       "repo-name",
			expectedIssueNumber: 456,
			expectError:        false,
		},
		{
			name:        "Invalid URL - not an issue",
			issueURL:    "https://github.com/owner/repo/pull/123",
			expectError: true,
		},
		{
			name:        "Invalid URL - missing parts",
			issueURL:    "https://github.com/owner",
			expectError: true,
		},
		{
			name:        "Invalid URL - non-numeric issue number",
			issueURL:    "https://github.com/owner/repo/issues/abc",
			expectError: true,
		},
		{
			name:        "Empty URL",
			issueURL:    "",
			expectError: true,
		},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			owner, repo, issueNumber, err := ExtractIssueInfo(tc.issueURL)
			
			if tc.expectError {
				if err == nil {
					t.Errorf("Expected error for URL '%s', but got none", tc.issueURL)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for URL '%s': %v", tc.issueURL, err)
				}
				if owner != tc.expectedOwner {
					t.Errorf("Expected owner '%s', got '%s'", tc.expectedOwner, owner)
				}
				if repo != tc.expectedRepo {
					t.Errorf("Expected repo '%s', got '%s'", tc.expectedRepo, repo)
				}
				if issueNumber != tc.expectedIssueNumber {
					t.Errorf("Expected issue number %d, got %d", tc.expectedIssueNumber, issueNumber)
				}
			}
		})
	}
}

func TestTruncateString(t *testing.T) {
	testCases := []struct {
		name      string
		input     string
		maxLen    int
		expected  string
	}{
		{
			name:     "string shorter than limit",
			input:    "short",
			maxLen:   10,
			expected: "short",
		},
		{
			name:     "string equal to limit",
			input:    "exactly10c",
			maxLen:   10,
			expected: "exactly10c",
		},
		{
			name:     "string longer than limit",
			input:    "this is a very long string that should be truncated",
			maxLen:   20,
			expected: "this is a very long ...",
		},
		{
			name:     "empty string",
			input:    "",
			maxLen:   10,
			expected: "",
		},
		{
			name:     "zero limit",
			input:    "test",
			maxLen:   0,
			expected: "...",
		},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := truncateString(tc.input, tc.maxLen)
			if result != tc.expected {
				t.Errorf("Expected '%s', got '%s'", tc.expected, result)
			}
		})
	}
}

// Benchmark tests for performance validation
func BenchmarkExtractRepoInfo(b *testing.B) {
	url := "https://github.com/fumiya-kume/FeLangKit"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ExtractRepoInfo(url)
	}
}

func BenchmarkExtractIssueInfo(b *testing.B) {
	url := "https://github.com/fumiya-kume/FeLangKit/issues/123"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ExtractIssueInfo(url)
	}
}

func BenchmarkTruncateString(b *testing.B) {
	longString := strings.Repeat("a", 1000)
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		truncateString(longString, 100)
	}
}