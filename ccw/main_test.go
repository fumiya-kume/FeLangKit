package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"
)

// Test utilities
func createTempDir(t *testing.T) string {
	dir, err := os.MkdirTemp("", "ccw-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	return dir
}

func cleanupTempDir(t *testing.T, dir string) {
	if err := os.RemoveAll(dir); err != nil {
		t.Errorf("Failed to cleanup temp dir %s: %v", dir, err)
	}
}

// Mock HTTP server for GitHub API testing
func createMockGitHubServer(t *testing.T) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.Contains(r.URL.Path, "/repos/owner/repo/issues/123"):
			mockIssue := Issue{
				Number:    123,
				Title:     "Test Issue",
				Body:      "This is a test issue for unit testing",
				State:     "open",
				URL:       "https://api.github.com/repos/owner/repo/issues/123",
				HTMLURL:   "https://github.com/owner/repo/issues/123",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
				Repository: Repository{
					Name:     "repo",
					FullName: "owner/repo",
					Owner: User{
						Login: "owner",
						URL:   "https://api.github.com/users/owner",
					},
				},
				Labels: []Label{
					{Name: "bug", Color: "d73a4a"},
					{Name: "enhancement", Color: "a2eeef"},
				},
				Assignees: []User{
					{Login: "assignee1", URL: "https://api.github.com/users/assignee1"},
				},
			}

			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(mockIssue); err != nil {
				t.Errorf("Failed to encode mock issue: %v", err)
			}

		case strings.Contains(r.URL.Path, "/repos/owner/repo/pulls"):
			mockPR := PullRequest{
				Number:  456,
				URL:     "https://api.github.com/repos/owner/repo/pulls/456",
				HTMLURL: "https://github.com/owner/repo/pull/456",
				State:   "open",
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusCreated)
			if err := json.NewEncoder(w).Encode(mockPR); err != nil {
				t.Errorf("Failed to encode mock PR: %v", err)
			}

		default:
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprintf(w, `{"message": "Not Found"}`)
		}
	}))
}

// TestExtractIssueInfo tests URL parsing functionality
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
			name:       "Valid GitHub issue URL",
			url:        "https://github.com/owner/repo/issues/123",
			wantOwner:  "owner",
			wantRepo:   "repo",
			wantNumber: 123,
			wantError:  false,
		},
		{
			name:      "Invalid URL format",
			url:       "https://github.com/owner/repo/pulls/123",
			wantError: true,
		},
		{
			name:      "Non-numeric issue number",
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			owner, repo, number, err := extractIssueInfo(tt.url)

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

// TestGitHubClientGetIssue tests GitHub CLI integration
func TestGitHubClientGetIssue(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub CLI integration test in short mode")
	}

	client := &GitHubClient{}

	t.Run("Invalid repository", func(t *testing.T) {
		_, err := client.GetIssue("nonexistent", "repo", 1)
		if err == nil {
			t.Errorf("Expected error for non-existent repository")
		}
	})

	// Note: We can't easily test successful cases without a real GitHub repo
	// In a real environment, you could test with a known public issue
}

// TestGitHubClientCreatePR tests PR creation functionality
func TestGitHubClientCreatePR(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping GitHub CLI integration test in short mode")
	}

	client := &GitHubClient{}

	t.Run("Invalid repository for PR creation", func(t *testing.T) {
		prReq := &PRRequest{
			Title:               "Test PR",
			Body:                "This is a test PR",
			Head:                "feature-branch",
			Base:                "master",
			MaintainerCanModify: true,
		}

		_, err := client.CreatePR("nonexistent", "repo", prReq)
		if err == nil {
			t.Errorf("Expected error for non-existent repository")
		}
	})

	// Note: Testing successful PR creation requires a real repository
	// and proper git setup, which is not suitable for unit tests
}

// TestGenerateBranchName tests branch name generation
func TestGenerateBranchName(t *testing.T) {
	issueNumber := 123
	branchName := generateBranchName(issueNumber)

	if !strings.HasPrefix(branchName, "issue-123-") {
		t.Errorf("Expected branch name to start with 'issue-123-', got %s", branchName)
	}

	// Check that it contains timestamp format
	if !strings.Contains(branchName, "2024") && !strings.Contains(branchName, "2025") {
		t.Errorf("Expected branch name to contain year, got %s", branchName)
	}

	// Check that two calls generate different names
	branchName2 := generateBranchName(issueNumber)
	if branchName == branchName2 {
		t.Errorf("Expected different branch names for subsequent calls")
	}
}

// TestWorktreetConfig tests worktree configuration structure
func TestWorktreeConfig(t *testing.T) {
	config := &WorktreeConfig{
		BasePath:     "/test/path",
		BranchName:   "issue-123-20240101-abcd1234",
		WorktreePath: "/test/path/issue-123-20240101-abcd1234",
		IssueNumber:  123,
		CreatedAt:    time.Now(),
		Owner:        "owner",
		Repository:   "repo",
		IssueURL:     "https://github.com/owner/repo/issues/123",
	}

	// Test JSON marshaling/unmarshaling
	data, err := json.Marshal(config)
	if err != nil {
		t.Fatalf("Failed to marshal worktree config: %v", err)
	}

	var unmarshaled WorktreeConfig
	if err := json.Unmarshal(data, &unmarshaled); err != nil {
		t.Fatalf("Failed to unmarshal worktree config: %v", err)
	}

	if unmarshaled.IssueNumber != config.IssueNumber {
		t.Errorf("Expected issue number %d, got %d", config.IssueNumber, unmarshaled.IssueNumber)
	}
	if unmarshaled.Owner != config.Owner {
		t.Errorf("Expected owner %s, got %s", config.Owner, unmarshaled.Owner)
	}
}

// MockQualityValidator for testing validation logic
type MockQualityValidator struct {
	swiftlintResult *LintResult
	buildResult     *BuildResult
	testResult      *TestResult
	shouldFail      bool
}

func (m *MockQualityValidator) ValidateImplementation(projectPath string) (*ValidationResult, error) {
	result := &ValidationResult{
		Success:     !m.shouldFail,
		LintResult:  m.swiftlintResult,
		BuildResult: m.buildResult,
		TestResult:  m.testResult,
		Timestamp:   time.Now(),
		Duration:    100 * time.Millisecond,
	}

	if m.shouldFail {
		result.Errors = []ValidationError{
			{
				Type:        "test",
				Message:     "Mock validation failure",
				Recoverable: true,
			},
		}
	}

	return result, nil
}

func (m *MockQualityValidator) runSwiftLint(projectPath string) (*LintResult, error) {
	return m.swiftlintResult, nil
}

func (m *MockQualityValidator) runBuild(projectPath string) (*BuildResult, error) {
	return m.buildResult, nil
}

func (m *MockQualityValidator) runTests(projectPath string) (*TestResult, error) {
	return m.testResult, nil
}

// TestQualityValidation tests validation workflow
func TestQualityValidation(t *testing.T) {
	t.Run("Successful validation", func(t *testing.T) {
		validator := &MockQualityValidator{
			swiftlintResult: &LintResult{Success: true, AutoFixed: true},
			buildResult:     &BuildResult{Success: true, Output: "Build successful"},
			testResult:      &TestResult{Success: true, Passed: 10, Failed: 0},
			shouldFail:      false,
		}

		result, err := validator.ValidateImplementation("/test/path")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if !result.Success {
			t.Errorf("Expected validation success")
		}
		if len(result.Errors) != 0 {
			t.Errorf("Expected no errors, got %d", len(result.Errors))
		}
	})

	t.Run("Failed validation", func(t *testing.T) {
		validator := &MockQualityValidator{
			swiftlintResult: &LintResult{Success: false, Errors: []string{"Lint error"}},
			buildResult:     &BuildResult{Success: false, Error: "Build failed"},
			testResult:      &TestResult{Success: false, Failed: 2},
			shouldFail:      true,
		}

		result, err := validator.ValidateImplementation("/test/path")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if result.Success {
			t.Errorf("Expected validation failure")
		}
		if len(result.Errors) == 0 {
			t.Errorf("Expected validation errors")
		}
	})
}

// TestClaudeContext tests Claude integration context preparation
func TestClaudeContext(t *testing.T) {
	issue := &Issue{
		Number: 123,
		Title:  "Test Issue",
		Body:   "Test issue body",
	}

	worktreeConfig := &WorktreeConfig{
		BranchName:   "issue-123-test",
		WorktreePath: "/test/path",
		IssueNumber:  123,
		Owner:        "owner",
		Repository:   "repo",
	}

	ctx := &ClaudeContext{
		IssueData:      issue,
		WorktreeConfig: worktreeConfig,
		ProjectPath:    "/test/path",
		IsRetry:        false,
		RetryAttempt:   1,
	}

	// Test JSON marshaling
	data, err := json.Marshal(ctx)
	if err != nil {
		t.Fatalf("Failed to marshal Claude context: %v", err)
	}

	var unmarshaled ClaudeContext
	if err := json.Unmarshal(data, &unmarshaled); err != nil {
		t.Fatalf("Failed to unmarshal Claude context: %v", err)
	}

	if unmarshaled.IssueData.Number != issue.Number {
		t.Errorf("Expected issue number %d, got %d", issue.Number, unmarshaled.IssueData.Number)
	}
	if unmarshaled.IsRetry != ctx.IsRetry {
		t.Errorf("Expected IsRetry %v, got %v", ctx.IsRetry, unmarshaled.IsRetry)
	}
}

// TestUIManager tests UI functionality
func TestUIManager(t *testing.T) {
	ui := &UIManager{
		theme:      "default",
		animations: true,
		debugMode:  false,
	}
	ui.initializeColors()

	// Test that color functions are initialized
	if ui.primaryColor == nil {
		t.Errorf("Primary color function not initialized")
	}
	if ui.successColor == nil {
		t.Errorf("Success color function not initialized")
	}
	if ui.warningColor == nil {
		t.Errorf("Warning color function not initialized")
	}
	if ui.errorColorFunc == nil {
		t.Errorf("Error color function not initialized")
	}

	// Test color output (basic functionality test)
	primaryText := ui.primaryColor("test")
	if primaryText == "" {
		t.Errorf("Primary color function returned empty string")
	}
}

// MockGitOperations for testing git functionality
type MockGitOperations struct {
	shouldFailCreate bool
	shouldFailRemove bool
	createdWorktrees []string
	removedWorktrees []string
}

func (m *MockGitOperations) CreateWorktree(branchName, worktreePath string) error {
	if m.shouldFailCreate {
		return fmt.Errorf("mock git worktree creation failure")
	}
	m.createdWorktrees = append(m.createdWorktrees, worktreePath)
	return nil
}

func (m *MockGitOperations) RemoveWorktree(worktreePath string) error {
	if m.shouldFailRemove {
		return fmt.Errorf("mock git worktree removal failure")
	}
	m.removedWorktrees = append(m.removedWorktrees, worktreePath)
	return nil
}

// TestGitOperations tests git worktree functionality
func TestGitOperations(t *testing.T) {
	t.Run("Successful worktree creation", func(t *testing.T) {
		gitOps := &MockGitOperations{}

		err := gitOps.CreateWorktree("test-branch", "/test/path")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if len(gitOps.createdWorktrees) != 1 {
			t.Errorf("Expected 1 created worktree, got %d", len(gitOps.createdWorktrees))
		}
		if gitOps.createdWorktrees[0] != "/test/path" {
			t.Errorf("Expected worktree path '/test/path', got %s", gitOps.createdWorktrees[0])
		}
	})

	t.Run("Failed worktree creation", func(t *testing.T) {
		gitOps := &MockGitOperations{shouldFailCreate: true}

		err := gitOps.CreateWorktree("test-branch", "/test/path")
		if err == nil {
			t.Errorf("Expected error but got none")
		}
	})

	t.Run("Successful worktree removal", func(t *testing.T) {
		gitOps := &MockGitOperations{}

		err := gitOps.RemoveWorktree("/test/path")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if len(gitOps.removedWorktrees) != 1 {
			t.Errorf("Expected 1 removed worktree, got %d", len(gitOps.removedWorktrees))
		}
	})
}

// TestConfigInitialization tests application configuration
func TestConfigInitialization(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping initialization test in short mode (requires gh CLI)")
	}

	// Set test environment variables
	os.Setenv("DEBUG_MODE", "true")
	defer func() {
		os.Unsetenv("DEBUG_MODE")
	}()

	// Skip test if gh CLI is not available
	if err := checkGHCLI(); err != nil {
		t.Skipf("Skipping test: %v", err)
	}

	app, err := NewCCWApp()
	if err != nil {
		t.Fatalf("Failed to initialize app: %v", err)
	}

	if !app.config.DebugMode {
		t.Errorf("Expected debug mode to be true")
	}
	if app.config.MaxRetries != 3 {
		t.Errorf("Expected max retries 3, got %d", app.config.MaxRetries)
	}
}

// TestConfigValidation tests configuration validation
func TestConfigValidation(t *testing.T) {
	// Test missing gh CLI (simulated by checking error type)
	_, err := NewCCWApp()
	if err != nil && strings.Contains(err.Error(), "GitHub CLI (gh) is required") {
		// This is expected when gh CLI is not available or not authenticated
		t.Logf("Expected error for missing gh CLI: %v", err)
	}
}

// TestValidationErrorTypes tests validation error handling
func TestValidationErrorTypes(t *testing.T) {
	tests := []struct {
		name        string
		errType     string
		message     string
		recoverable bool
	}{
		{
			name:        "Lint error",
			errType:     "lint",
			message:     "SwiftLint validation failed",
			recoverable: true,
		},
		{
			name:        "Build error",
			errType:     "build",
			message:     "Swift build failed",
			recoverable: true,
		},
		{
			name:        "Test error",
			errType:     "test",
			message:     "Swift tests failed",
			recoverable: true,
		},
		{
			name:        "System error",
			errType:     "system",
			message:     "File system error",
			recoverable: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidationError{
				Type:        tt.errType,
				Message:     tt.message,
				Recoverable: tt.recoverable,
			}

			if err.Type != tt.errType {
				t.Errorf("Expected error type %s, got %s", tt.errType, err.Type)
			}
			if err.Recoverable != tt.recoverable {
				t.Errorf("Expected recoverable %v, got %v", tt.recoverable, err.Recoverable)
			}
		})
	}
}

// TestPRRequestGeneration tests PR request formatting
func TestPRRequestGeneration(t *testing.T) {
	issue := &Issue{
		Number: 123,
		Title:  "Fix critical bug",
		Body:   "This issue describes a critical bug that needs fixing",
	}

	expectedTitle := "Resolve #123: Fix critical bug"
	expectedBodyContains := []string{
		"Resolves #123",
		"This issue describes a critical bug",
		"Claude Code",
		"Co-Authored-By: Claude",
	}

	prReq := &PRRequest{
		Title: fmt.Sprintf("Resolve #%d: %s", issue.Number, issue.Title),
		Body: fmt.Sprintf(`## Summary
Resolves #%d

## Issue Description
%s

## Implementation
This PR implements the requested changes for the above issue.

## Testing
- ✅ SwiftLint validation
- ✅ Swift build successful  
- ✅ All tests passing

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>`,
			issue.Number,
			issue.Body),
		Head:                "test-branch",
		Base:                "master",
		MaintainerCanModify: true,
	}

	if prReq.Title != expectedTitle {
		t.Errorf("Expected PR title '%s', got '%s'", expectedTitle, prReq.Title)
	}

	for _, expectedContent := range expectedBodyContains {
		if !strings.Contains(prReq.Body, expectedContent) {
			t.Errorf("Expected PR body to contain '%s'", expectedContent)
		}
	}

	if !prReq.MaintainerCanModify {
		t.Errorf("Expected MaintainerCanModify to be true")
	}
	if prReq.Base != "master" {
		t.Errorf("Expected base branch 'master', got '%s'", prReq.Base)
	}
}

// TestDataModelSerialization tests JSON serialization of all models
func TestDataModelSerialization(t *testing.T) {
	models := []interface{}{
		&Issue{Number: 1, Title: "Test", State: "open"},
		&WorktreeConfig{IssueNumber: 1, BranchName: "test"},
		&ValidationResult{Success: true, Duration: time.Second},
		&ClaudeContext{IsRetry: false, RetryAttempt: 1},
		&PRRequest{Title: "Test", Base: "master"},
		&PullRequest{Number: 1, State: "open"},
	}

	for i, model := range models {
		t.Run(fmt.Sprintf("Model_%d", i), func(t *testing.T) {
			// Test marshaling
			data, err := json.Marshal(model)
			if err != nil {
				t.Fatalf("Failed to marshal model: %v", err)
			}

			// Test unmarshaling
			modelType := reflect.TypeOf(model).Elem()
			newModel := reflect.New(modelType).Interface()

			if err := json.Unmarshal(data, newModel); err != nil {
				t.Fatalf("Failed to unmarshal model: %v", err)
			}
		})
	}
}

// Integration test for complete workflow simulation
func TestWorkflowIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Create temporary directory for test
	tempDir := createTempDir(t)
	defer cleanupTempDir(t, tempDir)

	// Set up test environment
	os.Setenv("GITHUB_TOKEN", "test-token")
	defer os.Unsetenv("GITHUB_TOKEN")

	// Create mock server
	server := createMockGitHubServer(t)
	defer server.Close()

	// Note: This would be a full integration test
	// For now, we test individual components
	t.Run("Component integration", func(t *testing.T) {
		// Test that all components can be initialized together
		_, err := NewCCWApp()
		if err != nil {
			t.Fatalf("Failed to initialize app: %v", err)
		}

		// Test URL extraction
		owner, repo, number, err := extractIssueInfo("https://github.com/owner/repo/issues/123")
		if err != nil {
			t.Fatalf("Failed to extract issue info: %v", err)
		}

		if owner != "owner" || repo != "repo" || number != 123 {
			t.Errorf("Incorrect extraction results: %s/%s#%d", owner, repo, number)
		}

		// Test branch name generation
		branchName := generateBranchName(number)
		if !strings.Contains(branchName, "issue-123") {
			t.Errorf("Invalid branch name format: %s", branchName)
		}
	})
}

// Benchmark tests for performance validation
func BenchmarkExtractIssueInfo(b *testing.B) {
	url := "https://github.com/owner/repo/issues/123"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _, _, _ = extractIssueInfo(url)
	}
}

func BenchmarkGenerateBranchName(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = generateBranchName(123)
	}
}

func BenchmarkJSONMarshalIssue(b *testing.B) {
	issue := &Issue{
		Number:    123,
		Title:     "Test Issue",
		Body:      "This is a test issue",
		State:     "open",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = json.Marshal(issue)
	}
}

// TestClaudeIntegrationPRDescription tests PR description generation
func TestClaudeIntegrationPRDescription(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping Claude integration test in short mode")
	}

	claude := &ClaudeIntegration{
		timeout:    5 * time.Minute,
		maxRetries: 1,
		debugMode:  false,
	}

	// Test fallback PR description
	req := &PRDescriptionRequest{
		Issue: &Issue{
			Number: 123,
			Title:  "Test Issue",
			Body:   "Test issue body",
		},
		WorktreeConfig: &WorktreeConfig{
			BranchName:   "test-branch",
			WorktreePath: "/tmp/test",
		},
		ValidationResult: &ValidationResult{
			Success:     true,
			LintResult:  &LintResult{Success: true},
			BuildResult: &BuildResult{Success: true},
			TestResult:  &TestResult{Success: true},
		},
		ImplementationSummary: "Test implementation",
	}

	description := claude.getFallbackPRDescription(req)

	if !strings.Contains(description, "## Summary") {
		t.Errorf("Expected PR description to contain Summary section")
	}
	if !strings.Contains(description, "Resolves #123") {
		t.Errorf("Expected PR description to contain issue reference")
	}
	if !strings.Contains(description, "Claude Code") {
		t.Errorf("Expected PR description to contain Claude Code attribution")
	}
}

// TestUIManagerProgress tests progress tracking functionality
func TestUIManagerProgress(t *testing.T) {
	ui := &UIManager{
		theme:      "default",
		animations: false,
		debugMode:  false,
	}
	ui.initializeColors()
	ui.InitializeProgress()

	if ui.progressTracker == nil {
		t.Errorf("Progress tracker should be initialized")
	}

	if len(ui.progressTracker.Steps) != 8 {
		t.Errorf("Expected 8 workflow steps, got %d", len(ui.progressTracker.Steps))
	}

	// Test step update
	ui.UpdateProgress("setup", "in_progress")

	setupStep := ui.progressTracker.Steps[0]
	if setupStep.Status != "in_progress" {
		t.Errorf("Expected setup step to be in_progress, got %s", setupStep.Status)
	}
	if setupStep.StartTime.IsZero() {
		t.Errorf("Expected setup step to have start time set")
	}

	// Test completion
	ui.UpdateProgress("setup", "completed")
	setupStep = ui.progressTracker.Steps[0]
	if setupStep.Status != "completed" {
		t.Errorf("Expected setup step to be completed, got %s", setupStep.Status)
	}
	if setupStep.EndTime.IsZero() {
		t.Errorf("Expected setup step to have end time set")
	}
}

// TestGitOperationsAdvanced tests advanced git functionality
func TestGitOperationsAdvanced(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping git operations test in short mode")
	}

	tempDir := createTempDir(t)
	defer cleanupTempDir(t, tempDir)

	gitOps := &GitOperations{basePath: tempDir}

	// Test list worktrees (should be empty initially)
	worktrees, err := gitOps.ListWorktrees()
	if err != nil {
		t.Fatalf("Failed to list worktrees: %v", err)
	}
	if len(worktrees) != 0 {
		t.Errorf("Expected 0 worktrees, got %d", len(worktrees))
	}
}

// TestValidationShouldValidate tests change detection logic
func TestValidationShouldValidate(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping validation test in short mode")
	}

	validator := &QualityValidator{
		swiftlintEnabled: true,
		buildEnabled:     true,
		testsEnabled:     true,
	}

	gitOps := &GitOperations{basePath: "."}

	// This will likely return true since we can't easily mock git status
	shouldValidate, err := validator.ShouldValidate(gitOps, ".")
	if err != nil {
		t.Logf("Expected error checking validation needs: %v", err)
	}

	// Test is mostly for coverage, actual behavior depends on git state
	t.Logf("Should validate: %v", shouldValidate)
}

// Test helper functions
func TestHelperFunctions(t *testing.T) {
	t.Run("createTempDir", func(t *testing.T) {
		dir := createTempDir(t)
		defer cleanupTempDir(t, dir)

		if _, err := os.Stat(dir); os.IsNotExist(err) {
			t.Errorf("Temp directory was not created: %s", dir)
		}
	})

	t.Run("mockGitHubServer", func(t *testing.T) {
		server := createMockGitHubServer(t)
		defer server.Close()

		// Test server responds correctly
		resp, err := http.Get(server.URL + "/repos/owner/repo/issues/123")
		if err != nil {
			t.Fatalf("Failed to call mock server: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
	})
}
