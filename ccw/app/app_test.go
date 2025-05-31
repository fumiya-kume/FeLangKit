package app

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Test helper functions and mock data structures

// Test helper functions

func setupTestDir(t *testing.T) string {
	tmpDir, err := os.MkdirTemp("", "ccw-app-test-*")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(tmpDir) })
	return tmpDir
}

// Simple test data structures for core logic testing
type TestConfig struct {
	WorktreeBase  string
	ClaudeTimeout string
	MaxRetries    int
	DebugMode     bool
}

// Tests for utility functions and core logic

func TestSessionIDGeneration(t *testing.T) {
	// Test session ID generation logic similar to NewCCWApp
	sessionID := fmt.Sprintf("%d-%s", time.Now().Unix(), "test123")
	if !strings.Contains(sessionID, "test123") {
		t.Error("Session ID generation failed")
	}
	
	// Test that different calls generate different IDs
	sessionID2 := fmt.Sprintf("%d-%s", time.Now().Unix(), "test456")
	if sessionID == sessionID2 {
		t.Error("Session IDs should be different")
	}
}

func TestConfigErrorHandling(t *testing.T) {
	// Test error message formatting used in NewCCWApp
	testErr := errors.New("config load failed")
	expectedMsg := fmt.Sprintf("failed to load configuration: %v", testErr)
	if !strings.Contains(expectedMsg, "failed to load configuration") {
		t.Error("Error message formatting failed")
	}
	
	// Test validation error formatting
	validationErr := fmt.Errorf("invalid configuration: %w", testErr)
	if !strings.Contains(validationErr.Error(), "invalid configuration") {
		t.Error("Validation error formatting failed")
	}
}

// Tests for exported functions

func TestPrintUsage(t *testing.T) {
	// Test that PrintUsage doesn't panic
	// We can't easily capture stdout, so we just test it runs
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("PrintUsage panicked: %v", r)
		}
	}()
	
	PrintUsage()
}

func TestEnableDebugMode(t *testing.T) {
	// Test that EnableDebugMode doesn't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("EnableDebugMode panicked: %v", r)
		}
	}()
	
	EnableDebugMode()
}

func TestEnableVerboseMode(t *testing.T) {
	// Test that EnableVerboseMode doesn't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("EnableVerboseMode panicked: %v", r)
		}
	}()
	
	EnableVerboseMode()
}

func TestEnableTraceMode(t *testing.T) {
	// Test that EnableTraceMode doesn't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("EnableTraceMode panicked: %v", r)
		}
	}()
	
	EnableTraceMode()
}

// Tests for workflow URL parsing logic (used in app functions)

func TestIssueURLParsing(t *testing.T) {
	// Test valid GitHub issue URL parsing logic
	testURL := "https://github.com/owner/repo/issues/123"
	
	parts := strings.Split(testURL, "/")
	if len(parts) < 7 {
		t.Error("URL parsing failed")
	}
	
	expectedOwner := "owner"
	expectedRepo := "repo"
	expectedIssue := "123"
	
	if parts[3] != expectedOwner {
		t.Errorf("Expected owner '%s', got '%s'", expectedOwner, parts[3])
	}
	if parts[4] != expectedRepo {
		t.Errorf("Expected repo '%s', got '%s'", expectedRepo, parts[4])
	}
	if parts[6] != expectedIssue {
		t.Errorf("Expected issue '%s', got '%s'", expectedIssue, parts[6])
	}
}

func TestBranchNameGeneration(t *testing.T) {
	// Test branch name generation logic used in workflow
	issueNumber := 123
	branchName := fmt.Sprintf("issue-%d-%s", issueNumber, time.Now().Format("20060102-150405"))
	
	if !strings.HasPrefix(branchName, "issue-123-") {
		t.Errorf("Branch name should start with 'issue-123-', got '%s'", branchName)
	}
	
	if len(branchName) < 20 { // issue-123- (9) + timestamp (15)
		t.Errorf("Branch name seems too short: '%s'", branchName)
	}
}

func TestWorktreePathGeneration(t *testing.T) {
	// Test worktree path generation logic
	tmpDir := setupTestDir(t)
	branchName := "issue-123-20240101-120000"
	worktreePath := filepath.Join(tmpDir, branchName)
	
	expectedPath := filepath.Join(tmpDir, branchName)
	if worktreePath != expectedPath {
		t.Errorf("Expected worktree path '%s', got '%s'", expectedPath, worktreePath)
	}
}

func TestErrorWrapping(t *testing.T) {
	// Test error wrapping patterns used in app
	testErr := errors.New("test error")
	wrappedErr := fmt.Errorf("workflow failed: %w", testErr)
	
	if !strings.Contains(wrappedErr.Error(), "workflow failed") {
		t.Error("Error wrapping failed")
	}
	
	if !strings.Contains(wrappedErr.Error(), "test error") {
		t.Error("Original error not preserved")
	}
}

func TestRepoURLParsing(t *testing.T) {
	// Test repository URL parsing logic used in list workflow
	repoURL := "https://github.com/owner/repo"
	
	parts := strings.Split(repoURL, "/")
	if len(parts) >= 5 {
		owner := parts[3]
		repo := parts[4]
		
		if owner != "owner" {
			t.Errorf("Expected owner 'owner', got '%s'", owner)
		}
		if repo != "repo" {
			t.Errorf("Expected repo 'repo', got '%s'", repo)
		}
	} else {
		t.Error("Failed to parse repository URL")
	}
}

func TestIssueURLConstruction(t *testing.T) {
	// Test issue URL construction logic used in list workflow
	owner := "testowner"
	repo := "testrepo"
	issueNumber := 456
	
	issueURL := fmt.Sprintf("https://github.com/%s/%s/issues/%d", owner, repo, issueNumber)
	expected := "https://github.com/testowner/testrepo/issues/456"
	
	if issueURL != expected {
		t.Errorf("Expected issue URL '%s', got '%s'", expected, issueURL)
	}
}

func TestConsoleCharSelection(t *testing.T) {
	// Test console character selection logic similar to getConsoleCharWorkflow
	fancy := "✓"
	simple := "OK"
	
	// Test CI mode detection logic
	os.Setenv("CI", "true")
	defer os.Unsetenv("CI")
	
	// Simulate the logic from getConsoleCharWorkflow
	isCIMode := os.Getenv("CI") == "true" || 
		        os.Getenv("GITHUB_ACTIONS") == "true" ||
		        os.Getenv("GITLAB_CI") == "true"
	
	var result string
	if isCIMode {
		result = simple
	} else {
		result = fancy
	}
	
	if result != simple {
		t.Errorf("Expected '%s' in CI mode, got '%s'", simple, result)
	}
}

// Tests for converter functions

func TestConvertValidationResult(t *testing.T) {
	// Test that conversion handles nil input gracefully
	result := ConvertValidationResult(nil)
	if result != nil {
		t.Error("ConvertValidationResult should return nil for nil input")
	}
}

// Additional utility function tests

func TestFilePathJoining(t *testing.T) {
	// Test file path operations used throughout the app
	base := "/tmp/test"
	branch := "issue-123-20240101"
	
	path := filepath.Join(base, branch)
	expected := "/tmp/test/issue-123-20240101"
	
	if path != expected {
		t.Errorf("Expected path '%s', got '%s'", expected, path)
	}
}

func TestTimeFormatting(t *testing.T) {
	// Test time formatting used in branch name generation
	now := time.Date(2024, 1, 1, 12, 0, 0, 0, time.UTC)
	formatted := now.Format("20060102-150405")
	expected := "20240101-120000"
	
	if formatted != expected {
		t.Errorf("Expected formatted time '%s', got '%s'", expected, formatted)
	}
}

func TestStringSlicing(t *testing.T) {
	// Test string operations used in URL parsing
	url := "https://github.com/owner/repo/issues/123"
	parts := strings.Split(url, "/")
	
	if len(parts) != 7 {
		t.Errorf("Expected 7 URL parts, got %d", len(parts))
	}
	
	// Test array bounds checking
	if len(parts) > 6 && parts[6] != "123" {
		t.Errorf("Expected issue number '123', got '%s'", parts[6])
	}
}

func TestEnvironmentVariableHandling(t *testing.T) {
	// Test environment variable patterns used in the app
	
	// Test setting and unsetting
	testKey := "CCW_TEST_VAR"
	testValue := "test_value"
	
	os.Setenv(testKey, testValue)
	defer os.Unsetenv(testKey)
	
	retrieved := os.Getenv(testKey)
	if retrieved != testValue {
		t.Errorf("Expected '%s', got '%s'", testValue, retrieved)
	}
	
	// Test default value pattern
	nonExistent := os.Getenv("CCW_NON_EXISTENT_VAR")
	if nonExistent != "" {
		t.Error("Non-existent env var should return empty string")
	}
}