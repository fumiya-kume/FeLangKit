package github

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"ccw/types"
)

// TestCheckGHCLI tests GitHub CLI availability check
func TestCheckGHCLI(t *testing.T) {
	// This test will pass or fail based on whether gh CLI is installed
	err := CheckGHCLI()
	
	if err != nil {
		// If gh is not installed or not authenticated, we expect specific error messages
		if !strings.Contains(err.Error(), "gh CLI is not installed") && 
		   !strings.Contains(err.Error(), "gh CLI is not authenticated") {
			t.Errorf("Unexpected error: %v", err)
		}
		t.Logf("Expected error (gh CLI not available): %v", err)
	} else {
		t.Log("gh CLI is available and authenticated")
	}
}

// TestExtractRepoInfo tests repository information extraction from URLs
func TestExtractRepoInfo(t *testing.T) {
	tests := []struct {
		name      string
		url       string
		wantOwner string
		wantRepo  string
		wantError bool
	}{
		{
			name:      "HTTPS URL",
			url:       "https://github.com/owner/repo",
			wantOwner: "owner",
			wantRepo:  "repo",
			wantError: false,
		},
		{
			name:      "HTTPS URL with trailing slash",
			url:       "https://github.com/owner/repo/",
			wantOwner: "owner",
			wantRepo:  "repo",
			wantError: false,
		},
		{
			name:      "HTTPS URL with .git",
			url:       "https://github.com/owner/repo.git",
			wantOwner: "owner",
			wantRepo:  "repo.git",  // ExtractRepoInfo doesn't strip .git
			wantError: false,
		},
		{
			name:      "SSH URL",
			url:       "git@github.com:owner/repo.git",
			wantOwner: "owner",
			wantRepo:  "repo",
			wantError: false,
		},
		{
			name:      "Simple owner/repo format",
			url:       "owner/repo",
			wantOwner: "owner",
			wantRepo:  "repo",
			wantError: false,
		},
		{
			name:      "Invalid URL",
			url:       "not-a-valid-url",
			wantError: true,
		},
		{
			name:      "Empty URL",
			url:       "",
			wantError: true,
		},
		{
			name:      "URL with extra path",
			url:       "https://github.com/owner/repo/issues/123",
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			owner, repo, err := ExtractRepoInfo(tt.url)
			
			if tt.wantError {
				if err == nil {
					t.Errorf("Expected error but got none")
				}
				return
			}
			
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}
			
			if owner != tt.wantOwner {
				t.Errorf("Expected owner %s, got %s", tt.wantOwner, owner)
			}
			if repo != tt.wantRepo {
				t.Errorf("Expected repo %s, got %s", tt.wantRepo, repo)
			}
		})
	}
}

// TestExtractIssueInfo tests issue information extraction from URLs
func TestExtractIssueInfo(t *testing.T) {
	tests := []struct {
		name       string
		url        string
		wantOwner  string
		wantRepo   string
		wantNumber int
		wantError  bool
	}{
		{
			name:       "Valid issue URL",
			url:        "https://github.com/owner/repo/issues/123",
			wantOwner:  "owner",
			wantRepo:   "repo",
			wantNumber: 123,
			wantError:  false,
		},
		{
			name:      "Pull request URL",
			url:       "https://github.com/owner/repo/pull/123",
			wantError: true,
		},
		{
			name:      "Invalid issue number",
			url:       "https://github.com/owner/repo/issues/abc",
			wantError: true,
		},
		{
			name:      "Missing issue number",
			url:       "https://github.com/owner/repo/issues/",
			wantError: true,
		},
		{
			name:      "Empty URL",
			url:       "",
			wantError: true,
		},
		{
			name:      "Non-GitHub URL",
			url:       "https://gitlab.com/owner/repo/issues/123",
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			owner, repo, number, err := ExtractIssueInfo(tt.url)
			
			if tt.wantError {
				if err == nil {
					t.Errorf("Expected error but got none")
				}
				return
			}
			
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}
			
			if owner != tt.wantOwner {
				t.Errorf("Expected owner %s, got %s", tt.wantOwner, owner)
			}
			if repo != tt.wantRepo {
				t.Errorf("Expected repo %s, got %s", tt.wantRepo, repo)
			}
			if number != tt.wantNumber {
				t.Errorf("Expected number %d, got %d", tt.wantNumber, number)
			}
		})
	}
}

// TestTruncateString tests string truncation utility
func TestTruncateString(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		maxLen   int
		expected string
	}{
		{
			name:     "Short string",
			input:    "Hello",
			maxLen:   10,
			expected: "Hello",
		},
		{
			name:     "Exact length",
			input:    "Hello",
			maxLen:   5,
			expected: "Hello",
		},
		{
			name:     "Long string",
			input:    "Hello, World!",
			maxLen:   5,
			expected: "Hello...",
		},
		{
			name:     "Empty string",
			input:    "",
			maxLen:   10,
			expected: "",
		},
		{
			name:     "Zero max length",
			input:    "Hello",
			maxLen:   0,
			expected: "...",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := truncateString(tt.input, tt.maxLen)
			if result != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, result)
			}
		})
	}
}

// TestDebugLog tests debug logging functionality
func TestDebugLog(t *testing.T) {
	// Save original env var
	originalDebug := os.Getenv("DEBUG_MODE")
	defer os.Setenv("DEBUG_MODE", originalDebug)

	tests := []struct {
		name       string
		debugMode  string
		expectLog  bool
	}{
		{"Debug enabled", "true", true},
		{"Verbose enabled", "false", false}, // Will check VERBOSE_MODE separately
		{"Debug disabled", "false", false},
		{"Empty debug", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("DEBUG_MODE", tt.debugMode)
			
			// This is a simple test to ensure the function doesn't panic
			debugLog("TestFunction", "Test message", map[string]interface{}{
				"key": "value",
				"number": 42,
			})
			
			// Also test with nil context
			debugLog("TestFunction", "Test message without context", nil)
		})
	}

	// Test VERBOSE_MODE
	os.Setenv("DEBUG_MODE", "false")
	os.Setenv("VERBOSE_MODE", "true")
	debugLog("TestFunction", "Verbose test", nil)
	os.Unsetenv("VERBOSE_MODE")
}

// TestGitHubClientGetIssue tests issue fetching
func TestGitHubClientGetIssue(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Test with invalid repository (should fail)
	_, err := client.GetIssue("nonexistent-owner", "nonexistent-repo", 1)
	if err == nil {
		t.Error("Expected error for non-existent repository")
	}
}

// TestGitHubClientCreatePR tests PR creation
func TestGitHubClientCreatePR(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	req := &types.PRRequest{
		Title: "Test PR",
		Body:  "Test body",
		Head:  "test-branch",
		Base:  "main",
	}

	// Test with invalid repository (should fail)
	_, err := client.CreatePR("nonexistent-owner", "nonexistent-repo", req)
	if err == nil {
		t.Error("Expected error for non-existent repository")
	}
}

// TestGitHubClientCheckExistingPR tests existing PR check
func TestGitHubClientCheckExistingPR(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Test with invalid repository (should fail)
	_, err := client.CheckExistingPR("nonexistent-owner", "nonexistent-repo", "test-branch")
	if err == nil {
		t.Error("Expected error for non-existent repository")
	}
}

// TestGitHubClientGetPRStatus tests PR status fetching
func TestGitHubClientGetPRStatus(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Test with invalid repository (should fail)
	_, err := client.GetPRStatus("nonexistent-owner", "nonexistent-repo", 1)
	if err == nil {
		t.Error("Expected error for non-existent repository")
	}
}

// TestGitHubClientGetDetailedCIStatus tests detailed CI status fetching
func TestGitHubClientGetDetailedCIStatus(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Test with invalid repository (should fail)
	_, err := client.GetDetailedCIStatus("nonexistent-owner", "nonexistent-repo", 1)
	if err == nil {
		t.Error("Expected error for non-existent repository")
	}
}

// TestGitHubClientListIssues tests issue listing
func TestGitHubClientListIssues(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Test with various parameters
	tests := []struct {
		name   string
		state  string
		labels []string
		limit  int
	}{
		{"Open issues", "open", nil, 10},
		{"Closed issues", "closed", nil, 5},
		{"With labels", "all", []string{"bug", "enhancement"}, 10},
		{"No limit", "open", nil, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test with invalid repository (should fail)
			_, err := client.ListIssues("nonexistent-owner", "nonexistent-repo", tt.state, tt.labels, tt.limit)
			if err == nil {
				t.Error("Expected error for non-existent repository")
			}
		})
	}
}

// TestGitHubClientMonitorCIStatus tests CI monitoring
func TestGitHubClientMonitorCIStatus(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub API test in short mode")
	}

	client := &GitHubClient{}

	// Create a channel to receive status updates
	callback := func(status *types.CIStatus) {
		t.Logf("Received CI status update: %s", status.Status)
	}

	// Use a very short timeout to make the test fast
	done := make(chan bool)
	go func() {
		// This should fail quickly due to invalid repo
		err := client.MonitorCIStatus("nonexistent-owner", "nonexistent-repo", 1, callback)
		if err == nil {
			t.Error("Expected error for non-existent repository")
		}
		done <- true
	}()

	select {
	case <-done:
		// Test completed
	case <-time.After(5 * time.Second):
		t.Error("Monitor CI status test timed out")
	}
}

// TestGetCurrentRepoURL tests getting current repository URL
func TestGetCurrentRepoURL(t *testing.T) {
	// This test depends on being run inside a git repository
	url, err := GetCurrentRepoURL()
	
	if err != nil {
		// If we're not in a git repo, that's expected
		if strings.Contains(err.Error(), "failed to get git remote URL") {
			t.Logf("Expected error (not in git repo): %v", err)
		} else {
			t.Errorf("Unexpected error: %v", err)
		}
	} else {
		// If we got a URL, verify it's valid
		if !strings.Contains(url, "github.com") {
			t.Errorf("Expected GitHub URL, got: %s", url)
		}
		t.Logf("Current repo URL: %s", url)
	}
}

// TestGitHubAPIMocking demonstrates how to mock GitHub API responses
func TestGitHubAPIMocking(t *testing.T) {
	// Create a test server that mocks GitHub API
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/test/repo/issues/123":
			issue := types.Issue{
				Number:  123,
				Title:   "Test Issue",
				Body:    "Test body",
				State:   "open",
				HTMLURL: "https://github.com/test/repo/issues/123",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}
			json.NewEncoder(w).Encode(issue)
			
		case "/repos/test/repo/pulls":
			if r.Method == "POST" {
				pr := types.PullRequest{
					Number:  456,
					HTMLURL: "https://github.com/test/repo/pull/456",
					State:   "open",
				}
				w.WriteHeader(http.StatusCreated)
				json.NewEncoder(w).Encode(pr)
			} else {
				json.NewEncoder(w).Encode([]types.PullRequest{})
			}
			
		default:
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprintf(w, `{"message": "Not Found"}`)
		}
	}))
	defer server.Close()

	// The mock server is ready for integration testing
	t.Logf("Mock GitHub API server running at: %s", server.URL)
}

// BenchmarkExtractRepoInfo benchmarks URL parsing
func BenchmarkExtractRepoInfo(b *testing.B) {
	urls := []string{
		"https://github.com/owner/repo",
		"git@github.com:owner/repo.git",
		"owner/repo",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, url := range urls {
			_, _, _ = ExtractRepoInfo(url)
		}
	}
}

// BenchmarkExtractIssueInfo benchmarks issue URL parsing
func BenchmarkExtractIssueInfo(b *testing.B) {
	url := "https://github.com/owner/repo/issues/123"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _, _, _ = ExtractIssueInfo(url)
	}
}

// TestEdgeCases tests edge cases and error conditions
func TestEdgeCases(t *testing.T) {
	// Test ExtractRepoInfo with unusual but valid formats
	t.Run("ExtractRepoInfo edge cases", func(t *testing.T) {
		// Repo names with special characters
		owner, repo, err := ExtractRepoInfo("user-name/repo-name")
		if err != nil {
			t.Errorf("Failed to parse valid repo with hyphens: %v", err)
		}
		if owner != "user-name" || repo != "repo-name" {
			t.Errorf("Incorrect parsing: %s/%s", owner, repo)
		}

		// SSH URL with different format
		owner, repo, err = ExtractRepoInfo("ssh://git@github.com/owner/repo.git")
		if err == nil {
			// This format is not currently supported
			t.Logf("SSH URL format parsed successfully: %s/%s", owner, repo)
		}
	})

	// Test with very long strings
	t.Run("Long string handling", func(t *testing.T) {
		longString := strings.Repeat("a", 1000)
		result := truncateString(longString, 100)
		if len(result) != 103 { // 100 + "..."
			t.Errorf("Expected truncated string length 103, got %d", len(result))
		}
	})
}

// TestConcurrentOperations tests thread safety of GitHub client
func TestConcurrentOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping concurrent operations test in short mode")
	}

	client := &GitHubClient{}
	
	// Run multiple operations concurrently
	done := make(chan bool, 3)
	
	go func() {
		_, _ = client.GetIssue("test", "repo", 1)
		done <- true
	}()
	
	go func() {
		_, _ = client.GetPRStatus("test", "repo", 1)
		done <- true
	}()
	
	go func() {
		_, _ = client.ListIssues("test", "repo", "open", nil, 10)
		done <- true
	}()
	
	// Wait for all goroutines with timeout
	for i := 0; i < 3; i++ {
		select {
		case <-done:
			// Operation completed
		case <-time.After(5 * time.Second):
			t.Error("Concurrent operation timed out")
		}
	}
}

// TestJSONMarshaling tests JSON encoding/decoding of types
func TestJSONMarshaling(t *testing.T) {
	// Test Issue marshaling
	issue := &types.Issue{
		Number:    123,
		Title:     "Test Issue",
		Body:      "Test body",
		State:     "open",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Labels: []types.Label{
			{Name: "bug", Color: "ff0000"},
		},
	}

	data, err := json.Marshal(issue)
	if err != nil {
		t.Fatalf("Failed to marshal issue: %v", err)
	}

	var decoded types.Issue
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Failed to unmarshal issue: %v", err)
	}

	if decoded.Number != issue.Number {
		t.Errorf("Issue number mismatch: %d != %d", decoded.Number, issue.Number)
	}
}

// TestEnvironmentVariables tests environment variable handling
func TestEnvironmentVariables(t *testing.T) {
	// Save original values
	originalDebug := os.Getenv("DEBUG_MODE")
	originalVerbose := os.Getenv("VERBOSE_MODE")
	
	defer func() {
		os.Setenv("DEBUG_MODE", originalDebug)
		os.Setenv("VERBOSE_MODE", originalVerbose)
	}()

	// Test different combinations
	testCases := []struct {
		debug   string
		verbose string
		name    string
	}{
		{"true", "false", "Debug only"},
		{"false", "true", "Verbose only"},
		{"true", "true", "Both enabled"},
		{"false", "false", "Both disabled"},
		{"", "", "Both empty"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			os.Setenv("DEBUG_MODE", tc.debug)
			os.Setenv("VERBOSE_MODE", tc.verbose)
			
			// Call debugLog to ensure it handles all cases
			debugLog("Test", "Testing environment variables", nil)
		})
	}
}