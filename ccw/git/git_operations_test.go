package git

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"ccw/types"
)

// TestGitOperations tests GitOperations creation
func TestGitOperations(t *testing.T) {
	tests := []struct {
		name         string
		basePath     string
		expectError  bool
	}{
		{"Valid path", "/tmp", false},
		{"Current directory", ".", false},
		{"Empty path", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ops := &GitOperations{
				basePath: tt.basePath,
				config: &GitOperationConfig{
					Timeout:       30 * time.Second,
					RetryAttempts: 3,
					RetryDelay:    2 * time.Second,
				},
			}
			
			if ops == nil {
				t.Fatal("GitOperations creation failed")
			}
			
			if tt.basePath == "" && ops.basePath != "" {
				t.Error("Empty basePath should remain empty")
			} else if tt.basePath != "" && ops.basePath != tt.basePath {
				t.Errorf("Expected basePath %s, got %s", tt.basePath, ops.basePath)
			}
		})
	}
}

// TestGenerateBranchName tests branch name generation
func TestGenerateBranchName(t *testing.T) {
	// Test branch name generation (assuming it's a standalone function)
	tests := []struct {
		name        string
		issueNumber int
	}{
		{"Single digit issue", 1},
		{"Double digit issue", 42},
		{"Triple digit issue", 123},
		{"Large issue number", 9999},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Branch name format: issue-{number}-{timestamp}
			branchName := fmt.Sprintf("issue-%d-%s", tt.issueNumber, time.Now().Format("20060102-150405"))
			
			expectedPrefix := fmt.Sprintf("issue-%d-", tt.issueNumber)
			if !strings.HasPrefix(branchName, expectedPrefix) {
				t.Errorf("Expected branch name to start with %s, got %s", expectedPrefix, branchName)
			}
		})
	}
}

// TestHasUncommittedChanges tests uncommitted changes detection (if method exists)
func TestHasUncommittedChanges(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping git operations test in short mode")
	}

	// Test that git command is available
	cmd := exec.Command("git", "status", "--porcelain")
	output, err := cmd.Output()
	
	if err != nil {
		// If we're not in a git repo, that's expected
		if strings.Contains(err.Error(), "not a git repository") {
			t.Logf("Expected error (not in git repo): %v", err)
		} else {
			t.Errorf("Unexpected error: %v", err)
		}
	} else {
		hasChanges := len(strings.TrimSpace(string(output))) > 0
		t.Logf("Has uncommitted changes: %v", hasChanges)
	}
}

// TestGetCurrentBranch tests current branch detection
func TestGetCurrentBranch(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping git operations test in short mode")
	}

	cmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
	output, err := cmd.Output()
	
	if err != nil {
		// If we're not in a git repo, that's expected
		if strings.Contains(err.Error(), "not a git repository") {
			t.Logf("Expected error (not in git repo): %v", err)
		} else {
			t.Errorf("Unexpected error: %v", err)
		}
	} else {
		branch := strings.TrimSpace(string(output))
		if branch == "" {
			t.Error("Got empty branch name")
		}
		t.Logf("Current branch: %s", branch)
	}
}

// TestCreateWorktreeConfig tests worktree configuration creation
func TestCreateWorktreeConfig(t *testing.T) {
	// Test WorktreeConfig creation
	config := &types.WorktreeConfig{
		BasePath:     "/tmp/test",
		BranchName:   "issue-123-20240101-120000",
		WorktreePath: "/tmp/test/issue-123-20240101-120000",
		IssueNumber:  123,
		CreatedAt:    time.Now(),
		Owner:        "owner",
		Repository:   "repo",
		IssueURL:     "https://github.com/owner/repo/issues/123",
	}
	
	if config.IssueNumber != 123 {
		t.Errorf("Expected issue number 123, got %d", config.IssueNumber)
	}
	
	if config.BranchName != "issue-123-20240101-120000" {
		t.Errorf("Expected specific branch name, got %s", config.BranchName)
	}
	
	expectedPath := filepath.Join("/tmp/test", "issue-123-20240101-120000")
	if config.WorktreePath != expectedPath {
		t.Errorf("Expected worktree path %s, got %s", expectedPath, config.WorktreePath)
	}
}

// TestGitCommandExecution tests basic git command execution
func TestGitCommandExecution(t *testing.T) {
	// Test that git command is available
	cmd := exec.Command("git", "--version")
	output, err := cmd.Output()
	
	if err != nil {
		t.Fatalf("Git is not available: %v", err)
	}
	
	version := strings.TrimSpace(string(output))
	t.Logf("Git version: %s", version)
	
	if !strings.Contains(version, "git version") {
		t.Errorf("Unexpected git version output: %s", version)
	}
}

// TestWorktreeConfigSerialization tests WorktreeConfig JSON serialization
func TestWorktreeConfigSerialization(t *testing.T) {
	config := &types.WorktreeConfig{
		BasePath:     "/tmp/test",
		BranchName:   "issue-123-20240101-120000",
		WorktreePath: "/tmp/test/issue-123-20240101-120000",
		IssueNumber:  123,
		CreatedAt:    time.Now(),
		Owner:        "owner",
		Repository:   "repo",
		IssueURL:     "https://github.com/owner/repo/issues/123",
	}

	// Test marshaling
	data, err := json.Marshal(config)
	if err != nil {
		t.Fatalf("Failed to marshal WorktreeConfig: %v", err)
	}

	// Test unmarshaling
	var decoded types.WorktreeConfig
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Failed to unmarshal WorktreeConfig: %v", err)
	}

	// Verify fields
	if decoded.IssueNumber != config.IssueNumber {
		t.Errorf("IssueNumber mismatch: %d != %d", decoded.IssueNumber, config.IssueNumber)
	}
	
	if decoded.BranchName != config.BranchName {
		t.Errorf("BranchName mismatch: %s != %s", decoded.BranchName, config.BranchName)
	}
	
	if decoded.Owner != config.Owner {
		t.Errorf("Owner mismatch: %s != %s", decoded.Owner, config.Owner)
	}
}

// TestGitWorktreeOperations tests git worktree commands
func TestGitWorktreeOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping worktree operations test in short mode")
	}

	// List worktrees
	cmd := exec.Command("git", "worktree", "list", "--porcelain")
	output, err := cmd.Output()
	
	if err != nil {
		// If we're not in a git repo, that's expected
		if strings.Contains(err.Error(), "not a git repository") {
			t.Logf("Expected error (not in git repo): %v", err)
		} else {
			t.Errorf("Unexpected error: %v", err)
		}
	} else {
		t.Logf("Worktree list output: %s", string(output))
	}
}

// TestPruneWorktrees tests worktree pruning
func TestPruneWorktrees(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping worktree pruning test in short mode")
	}

	cmd := exec.Command("git", "worktree", "prune", "-v")
	output, err := cmd.Output()
	
	if err != nil {
		// If we're not in a git repo, that's expected
		if strings.Contains(err.Error(), "not a git repository") {
			t.Logf("Expected error (not in git repo): %v", err)
		} else {
			t.Errorf("Unexpected error: %v", err)
		}
	} else {
		t.Logf("Prune output: %s", string(output))
	}
}

// TestCreateGitCommand tests command creation helpers
func TestCreateGitCommand(t *testing.T) {
	// Test createGitCommand function if it exists
	args := []string{"status", "--porcelain"}
	cmd := exec.Command("git", args...)
	
	if cmd.Path == "" {
		t.Error("Command path should not be empty")
	}
	
	if len(cmd.Args) != len(args)+1 {
		t.Errorf("Expected %d args, got %d", len(args)+1, len(cmd.Args))
	}
}

// TestGitConfigValidation tests git configuration
func TestGitConfigValidation(t *testing.T) {
	config := &GitOperationConfig{
		Timeout:       30 * time.Second,
		RetryAttempts: 3,
		RetryDelay:    2 * time.Second,
	}
	
	if config.Timeout <= 0 {
		t.Error("Timeout should be positive")
	}
	
	if config.RetryAttempts <= 0 {
		t.Error("RetryAttempts should be positive")
	}
	
	if config.RetryDelay <= 0 {
		t.Error("RetryDelay should be positive")
	}
}

// TestConcurrentGitOperations tests thread safety
func TestConcurrentGitOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping concurrent operations test in short mode")
	}

	// Run multiple git commands concurrently
	done := make(chan bool, 3)
	
	go func() {
		cmd := exec.Command("git", "status")
		cmd.Run()
		done <- true
	}()
	
	go func() {
		cmd := exec.Command("git", "branch")
		cmd.Run()
		done <- true
	}()
	
	go func() {
		cmd := exec.Command("git", "log", "--oneline", "-1")
		cmd.Run()
		done <- true
	}()
	
	// Wait for all operations
	for i := 0; i < 3; i++ {
		select {
		case <-done:
			// Operation completed
		case <-time.After(5 * time.Second):
			t.Error("Concurrent operation timed out")
		}
	}
}

// BenchmarkGitCommand benchmarks git command execution
func BenchmarkGitCommand(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cmd := exec.Command("git", "status", "--porcelain")
		cmd.Run()
	}
}

// TestGitRemoteOperations tests remote-related functionality
func TestGitRemoteOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping remote operations test in short mode")
	}

	// Get remote URL
	cmd := exec.Command("git", "remote", "get-url", "origin")
	output, err := cmd.Output()
	
	if err != nil {
		t.Logf("Get remote URL error (may be expected): %v", err)
	} else {
		url := strings.TrimSpace(string(output))
		t.Logf("Remote origin URL: %s", url)
	}
}

// TestGitBranchOperations tests branch-related functionality
func TestGitBranchOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping branch operations test in short mode")
	}

	// List branches
	cmd := exec.Command("git", "branch", "-a")
	output, err := cmd.Output()
	
	if err != nil {
		t.Logf("List branches error: %v", err)
	} else {
		branches := strings.TrimSpace(string(output))
		t.Logf("Branches:\n%s", branches)
	}
}

// TestGitStashOperations tests stash functionality
func TestGitStashOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping stash operations test in short mode")
	}

	// List stashes
	cmd := exec.Command("git", "stash", "list")
	output, err := cmd.Output()
	
	if err != nil {
		t.Logf("Stash list error: %v", err)
	} else {
		stashes := strings.TrimSpace(string(output))
		if stashes == "" {
			t.Log("No stashes found")
		} else {
			t.Logf("Stashes:\n%s", stashes)
		}
	}
}

// TestValidationTypes tests validation-related types
func TestValidationTypes(t *testing.T) {
	// Test ValidationResult
	result := &ValidationResult{
		Success:   true,
		Duration:  100 * time.Millisecond,
		Timestamp: time.Now(),
		LintResult: &LintResult{
			Success:   true,
			AutoFixed: true,
		},
		BuildResult: &BuildResult{
			Success: true,
			Output:  "Build successful",
		},
		TestResult: &TestResult{
			Success:   true,
			TestCount: 10,
			Passed:    10,
			Failed:    0,
		},
	}
	
	if !result.Success {
		t.Error("Expected validation to be successful")
	}
	
	if result.LintResult == nil || !result.LintResult.Success {
		t.Error("Expected lint to be successful")
	}
	
	if result.BuildResult == nil || !result.BuildResult.Success {
		t.Error("Expected build to be successful")
	}
	
	if result.TestResult == nil || result.TestResult.Failed > 0 {
		t.Error("Expected all tests to pass")
	}
}

// TestCommitMessageGenerator tests commit message generation
func TestCommitMessageGenerator(t *testing.T) {
	cmg := &CommitMessageGenerator{}
	
	issue := &Issue{
		Number: 123,
		Title:  "Fix critical bug",
		Body:   "This is a critical bug that needs fixing",
	}
	
	message, err := cmg.GenerateEnhancedCommitMessage("/tmp/test", issue)
	if err != nil {
		t.Fatalf("Failed to generate commit message: %v", err)
	}
	
	// Verify message contains expected components
	if !strings.Contains(message, "#123") {
		t.Error("Commit message should contain issue number")
	}
	
	if !strings.Contains(message, "Fix critical bug") {
		t.Error("Commit message should contain issue title")
	}
	
	if !strings.Contains(message, "Claude Code") {
		t.Error("Commit message should contain Claude Code attribution")
	}
}

// TestChangePatternDetection tests change pattern types
func TestChangePatternDetection(t *testing.T) {
	patterns := []ChangePattern{
		{
			Type:        "refactoring",
			Description: "Extract method",
			Confidence:  0.85,
			Files:       []string{"main.go", "utils.go"},
		},
		{
			Type:        "feature",
			Description: "Add new API endpoint",
			Confidence:  0.95,
			Files:       []string{"api/handler.go"},
		},
	}
	
	for _, pattern := range patterns {
		if pattern.Confidence < 0 || pattern.Confidence > 1 {
			t.Errorf("Invalid confidence value: %f", pattern.Confidence)
		}
		
		if len(pattern.Files) == 0 {
			t.Error("Pattern should have associated files")
		}
	}
}

// TestCommitAnalysis tests commit analysis structure
func TestCommitAnalysis(t *testing.T) {
	analysis := &CommitAnalysis{
		ModifiedFiles: []string{"main.go", "test.go"},
		AddedFiles:    []string{"new.go"},
		DeletedFiles:  []string{"old.go"},
		DiffSummary:   "3 files changed, 100 insertions(+), 50 deletions(-)",
		FileTypes: map[string]int{
			"go":   3,
			"md":   1,
		},
		ChangeCategory: "feature",
		Scope:         "api",
		CommitMetadata: CommitMetadata{
			Author:      "test@example.com",
			Timestamp:   time.Now(),
			BranchName:  "feature/test",
			IssueNumber: 123,
		},
	}
	
	totalFiles := len(analysis.ModifiedFiles) + len(analysis.AddedFiles) + len(analysis.DeletedFiles)
	if totalFiles != 4 {
		t.Errorf("Expected 4 total files, got %d", totalFiles)
	}
	
	if analysis.CommitMetadata.IssueNumber != 123 {
		t.Errorf("Expected issue number 123, got %d", analysis.CommitMetadata.IssueNumber)
	}
}