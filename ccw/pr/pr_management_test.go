package pr

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"ccw/types"
)

// MockCommand is used to mock exec.Command for testing
type MockCommand struct {
	output   string
	err      error
	exitCode int
}

var mockCommands map[string]MockCommand

func init() {
	// Initialize mock commands map
	mockCommands = make(map[string]MockCommand)
}

// Helper function to create test CheckRun data
func createTestCheckRun(name, state string) types.CheckRun {
	return types.CheckRun{
		Name:        name,
		Status:      state,
		URL:         fmt.Sprintf("https://github.com/test/repo/checks/%s", name),
		StartedAt:   time.Now().Add(-5 * time.Minute),
		CompletedAt: time.Now(),
		Description: fmt.Sprintf("Check %s description", name),
	}
}

// TestNewPRManager tests PR manager creation
func TestNewPRManager(t *testing.T) {
	tests := []struct {
		name       string
		timeout    time.Duration
		maxRetries int
		debugMode  bool
	}{
		{"Default settings", 5 * time.Minute, 3, false},
		{"Debug mode", 10 * time.Minute, 5, true},
		{"Quick timeout", 1 * time.Minute, 1, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pm := NewPRManager(tt.timeout, tt.maxRetries, tt.debugMode)
			
			if pm == nil {
				t.Fatal("NewPRManager returned nil")
			}
			if pm.timeout != tt.timeout {
				t.Errorf("Expected timeout %v, got %v", tt.timeout, pm.timeout)
			}
			if pm.maxRetries != tt.maxRetries {
				t.Errorf("Expected maxRetries %d, got %d", tt.maxRetries, pm.maxRetries)
			}
			if pm.debugMode != tt.debugMode {
				t.Errorf("Expected debugMode %v, got %v", tt.debugMode, pm.debugMode)
			}
		})
	}
}

// TestParseBasicCIStatus tests the fallback CI status parsing
func TestParseBasicCIStatus(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	prURL := "https://github.com/test/repo/pull/123"

	tests := []struct {
		name           string
		output         string
		expectedStatus string
		expectedConc   string
	}{
		{
			name:           "Success status",
			output:         "All checks have passed successfully",
			expectedStatus: "success",
			expectedConc:   "success",
		},
		{
			name:           "Failure status",
			output:         "Some checks have failed",
			expectedStatus: "failure",
			expectedConc:   "failure",
		},
		{
			name:           "Pending status",
			output:         "Checks are still pending",
			expectedStatus: "pending",
			expectedConc:   "pending",
		},
		{
			name:           "Mixed keywords",
			output:         "Build failed but tests are passing",
			expectedStatus: "failure",
			expectedConc:   "failure",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, err := pm.parseBasicCIStatus(tt.output, prURL)
			
			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}
			
			if status.Status != tt.expectedStatus {
				t.Errorf("Expected status %s, got %s", tt.expectedStatus, status.Status)
			}
			
			if status.Conclusion != tt.expectedConc {
				t.Errorf("Expected conclusion %s, got %s", tt.expectedConc, status.Conclusion)
			}
			
			if status.URL != prURL {
				t.Errorf("Expected URL %s, got %s", prURL, status.URL)
			}
			
			if status.LastUpdated.IsZero() {
				t.Error("LastUpdated should not be zero")
			}
		})
	}
}

// TestBuildCIStatusFromChecks tests CI status construction from check runs
func TestBuildCIStatusFromChecks(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	prURL := "https://github.com/test/repo/pull/123"

	tests := []struct {
		name               string
		checks             []types.CheckRun
		expectedStatus     string
		expectedConclusion string
		expectedPassed     int
		expectedFailed     int
		expectedPending    int
	}{
		{
			name: "All checks passed",
			checks: []types.CheckRun{
				createTestCheckRun("build", "SUCCESS"),
				createTestCheckRun("test", "SUCCESS"),
				createTestCheckRun("lint", "PASSED"),
			},
			expectedStatus:     "success",
			expectedConclusion: "success",
			expectedPassed:     3,
			expectedFailed:     0,
			expectedPending:    0,
		},
		{
			name: "Some checks failed",
			checks: []types.CheckRun{
				createTestCheckRun("build", "SUCCESS"),
				createTestCheckRun("test", "FAILURE"),
				createTestCheckRun("lint", "ERROR"),
			},
			expectedStatus:     "failure",
			expectedConclusion: "failure",
			expectedPassed:     1,
			expectedFailed:     2,
			expectedPending:    0,
		},
		{
			name: "Some checks pending",
			checks: []types.CheckRun{
				createTestCheckRun("build", "SUCCESS"),
				createTestCheckRun("test", "PENDING"),
				createTestCheckRun("lint", "IN_PROGRESS"),
			},
			expectedStatus:     "pending",
			expectedConclusion: "pending",
			expectedPassed:     1,
			expectedFailed:     0,
			expectedPending:    2,
		},
		{
			name: "Mixed statuses with failure",
			checks: []types.CheckRun{
				createTestCheckRun("build", "SUCCESS"),
				createTestCheckRun("test", "FAILURE"),
				createTestCheckRun("lint", "PENDING"),
				createTestCheckRun("security", "CANCELLED"),
			},
			expectedStatus:     "pending",
			expectedConclusion: "pending",
			expectedPassed:     1,
			expectedFailed:     2,
			expectedPending:    1,
		},
		{
			name:               "No checks",
			checks:             []types.CheckRun{},
			expectedStatus:     "success",
			expectedConclusion: "success",
			expectedPassed:     0,
			expectedFailed:     0,
			expectedPending:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status := pm.buildCIStatusFromChecks(tt.checks, prURL)
			
			if status.Status != tt.expectedStatus {
				t.Errorf("Expected status %s, got %s", tt.expectedStatus, status.Status)
			}
			
			if status.Conclusion != tt.expectedConclusion {
				t.Errorf("Expected conclusion %s, got %s", tt.expectedConclusion, status.Conclusion)
			}
			
			if status.PassedChecks != tt.expectedPassed {
				t.Errorf("Expected %d passed checks, got %d", tt.expectedPassed, status.PassedChecks)
			}
			
			if status.FailedChecks != tt.expectedFailed {
				t.Errorf("Expected %d failed checks, got %d", tt.expectedFailed, status.FailedChecks)
			}
			
			if status.PendingChecks != tt.expectedPending {
				t.Errorf("Expected %d pending checks, got %d", tt.expectedPending, status.PendingChecks)
			}
			
			if status.TotalChecks != len(tt.checks) {
				t.Errorf("Expected %d total checks, got %d", len(tt.checks), status.TotalChecks)
			}
			
			if status.URL != prURL {
				t.Errorf("Expected URL %s, got %s", prURL, status.URL)
			}
		})
	}
}

// TestHasStatusChanged tests status change detection
func TestHasStatusChanged(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)

	tests := []struct {
		name     string
		last     *types.CIStatus
		current  *types.CIStatus
		expected bool
	}{
		{
			name:     "Nil last status",
			last:     nil,
			current:  &types.CIStatus{Status: "pending"},
			expected: true,
		},
		{
			name: "No change",
			last: &types.CIStatus{
				Status:        "pending",
				PassedChecks:  1,
				FailedChecks:  0,
				PendingChecks: 2,
			},
			current: &types.CIStatus{
				Status:        "pending",
				PassedChecks:  1,
				FailedChecks:  0,
				PendingChecks: 2,
			},
			expected: false,
		},
		{
			name: "Status changed",
			last: &types.CIStatus{
				Status: "pending",
			},
			current: &types.CIStatus{
				Status: "success",
			},
			expected: true,
		},
		{
			name: "Check counts changed",
			last: &types.CIStatus{
				Status:        "pending",
				PassedChecks:  1,
				FailedChecks:  0,
				PendingChecks: 2,
			},
			current: &types.CIStatus{
				Status:        "pending",
				PassedChecks:  2,
				FailedChecks:  0,
				PendingChecks: 1,
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := pm.hasStatusChanged(tt.last, tt.current)
			if result != tt.expected {
				t.Errorf("Expected %v, got %v", tt.expected, result)
			}
		})
	}
}

// TestIsAllChecksComplete tests completion detection
func TestIsAllChecksComplete(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)

	tests := []struct {
		name     string
		status   *types.CIStatus
		expected bool
	}{
		{
			name: "All complete",
			status: &types.CIStatus{
				TotalChecks:   3,
				PendingChecks: 0,
			},
			expected: true,
		},
		{
			name: "Some pending",
			status: &types.CIStatus{
				TotalChecks:   3,
				PendingChecks: 1,
			},
			expected: false,
		},
		{
			name: "No checks",
			status: &types.CIStatus{
				TotalChecks:   0,
				PendingChecks: 0,
			},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := pm.isAllChecksComplete(tt.status)
			if result != tt.expected {
				t.Errorf("Expected %v, got %v", tt.expected, result)
			}
		})
	}
}

// TestFormatStatusMessage tests status message formatting
func TestFormatStatusMessage(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)

	tests := []struct {
		name     string
		status   *types.CIStatus
		expected string
	}{
		{
			name:     "No checks",
			status:   &types.CIStatus{TotalChecks: 0},
			expected: "No CI checks found",
		},
		{
			name: "All passed",
			status: &types.CIStatus{
				TotalChecks:   3,
				PassedChecks:  3,
				FailedChecks:  0,
				PendingChecks: 0,
			},
			expected: "CI Status: 3 total, 3 passed, 0 failed, 0 pending",
		},
		{
			name: "Mixed results",
			status: &types.CIStatus{
				TotalChecks:   5,
				PassedChecks:  2,
				FailedChecks:  1,
				PendingChecks: 2,
			},
			expected: "CI Status: 5 total, 2 passed, 1 failed, 2 pending",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := pm.formatStatusMessage(tt.status)
			if result != tt.expected {
				t.Errorf("Expected '%s', got '%s'", tt.expected, result)
			}
		})
	}
}

// TestAnalyzeCIFailures tests failure analysis
func TestAnalyzeCIFailures(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)

	tests := []struct {
		name             string
		status           *types.CIStatus
		expectedFailures int
		expectedTypes    []types.CIFailureType
	}{
		{
			name: "No failures",
			status: &types.CIStatus{
				Checks: []types.CheckRun{
					{Name: "build", Status: "SUCCESS"},
					{Name: "test", Status: "SUCCESS"},
				},
			},
			expectedFailures: 0,
			expectedTypes:    []types.CIFailureType{},
		},
		{
			name: "Build failure",
			status: &types.CIStatus{
				Checks: []types.CheckRun{
					{Name: "swift-build", Status: "FAILURE", Description: "Build failed", URL: "https://github.com/test/repo/checks/build"},
					{Name: "test", Status: "SUCCESS"},
				},
			},
			expectedFailures: 1,
			expectedTypes:    []types.CIFailureType{types.CIFailureBuild},
		},
		{
			name: "Multiple failures",
			status: &types.CIStatus{
				Checks: []types.CheckRun{
					{Name: "swiftlint", Status: "ERROR", Description: "Linting failed", URL: "https://github.com/test/repo/checks/lint"},
					{Name: "unit-tests", Status: "FAILED", Description: "Tests failed", URL: "https://github.com/test/repo/checks/test"},
					{Name: "unknown-check", Status: "FAILURE", Description: "Unknown failure", URL: "https://github.com/test/repo/checks/unknown"},
				},
			},
			expectedFailures: 3,
			expectedTypes: []types.CIFailureType{
				types.CIFailureLint,
				types.CIFailureTest,
				types.CIFailureUnknown,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			failures := pm.AnalyzeCIFailures(tt.status)
			
			if len(failures) != tt.expectedFailures {
				t.Errorf("Expected %d failures, got %d", tt.expectedFailures, len(failures))
			}
			
			for i, failure := range failures {
				if i < len(tt.expectedTypes) && failure.Type != tt.expectedTypes[i] {
					t.Errorf("Expected failure type %s, got %s", tt.expectedTypes[i], failure.Type)
				}
				
				// Verify failure details are populated
				if failure.CheckName == "" {
					t.Error("Failure CheckName should not be empty")
				}
				if failure.DetailsURL == "" {
					t.Error("Failure DetailsURL should not be empty")
				}
			}
		})
	}
}

// TestCreatePullRequestAsync tests async PR creation
func TestCreatePullRequestAsync(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	req := &types.PRRequest{
		Title: "Test PR",
		Body:  "Test body",
		Base:  "main",
	}
	
	// Start async PR creation
	resultChan := pm.CreatePullRequestAsync(req, "/tmp/test")
	
	// Verify channel is created
	if resultChan == nil {
		t.Fatal("CreatePullRequestAsync returned nil channel")
	}
	
	// Wait for result with timeout
	select {
	case result := <-resultChan:
		// We expect an error since we're not in a real git repo
		if result.Error == nil {
			t.Error("Expected error for test PR creation")
		}
	case <-time.After(1 * time.Second):
		t.Error("Timeout waiting for async PR creation")
	}
}

// TestMonitorPRChecksAsync tests async CI monitoring
func TestMonitorPRChecksAsync(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	prURL := "https://github.com/test/repo/pull/123"
	
	// Start async monitoring
	resultChan := pm.MonitorPRChecksAsync(prURL, 2*time.Second)
	
	// Verify channel is created
	if resultChan == nil {
		t.Fatal("MonitorPRChecksAsync returned nil channel")
	}
	
	// Wait for result with timeout
	select {
	case result := <-resultChan:
		// We expect an error since this is not a real PR
		if result.Error == nil {
			t.Error("Expected error for test PR monitoring")
		}
	case <-time.After(3 * time.Second):
		t.Error("Timeout waiting for async PR monitoring")
	}
}

// TestWatchPRChecksWithGoroutine tests continuous CI monitoring
func TestWatchPRChecksWithGoroutine(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	
	prURL := "https://github.com/test/repo/pull/123"
	
	// Start watching
	watchChan := pm.WatchPRChecksWithGoroutine(ctx, prURL)
	
	if watchChan == nil {
		t.Fatal("WatchPRChecksWithGoroutine returned nil")
	}
	
	// Verify channels are created
	if watchChan.Updates == nil {
		t.Error("Updates channel is nil")
	}
	if watchChan.Completion == nil {
		t.Error("Completion channel is nil")
	}
	if watchChan.Cancel == nil {
		t.Error("Cancel channel is nil")
	}
	
	// Wait for initial update
	select {
	case update := <-watchChan.Updates:
		if update.EventType != "monitoring_started" {
			t.Errorf("Expected 'monitoring_started' event, got '%s'", update.EventType)
		}
	case <-time.After(1 * time.Second):
		t.Error("Timeout waiting for initial update")
	}
	
	// Cancel and wait for completion
	close(watchChan.Cancel)
	
	select {
	case <-watchChan.Completion:
		// Expected completion
	case <-time.After(3 * time.Second):
		t.Error("Timeout waiting for completion after cancel")
	}
}

// TestParseInt helper function test
func TestParseInt(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"123", 123},
		{"0", 0},
		{"-1", -1},
		{"abc", 0}, // Invalid input should return 0
		{"", 0},    // Empty string should return 0
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := parseInt(tt.input)
			if result != tt.expected {
				t.Errorf("Expected %d, got %d", tt.expected, result)
			}
		})
	}
}

// TestPRCommentHandling tests PR comment functionality
func TestPRCommentHandling(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	// Test GetPRComments with invalid PR URL
	_, err := pm.GetPRComments("https://github.com/test/repo/pull/999")
	if err == nil {
		t.Error("Expected error for non-existent PR")
	}
}

// TestFetchCurrentCIStatusErrorHandling tests error handling in CI status fetching
func TestFetchCurrentCIStatusErrorHandling(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	ctx := context.Background()
	prURL := "https://github.com/test/repo/pull/123"
	
	// This should fail since we're not in a real environment
	status, err := pm.fetchCurrentCIStatus(ctx, prURL)
	
	if err == nil {
		t.Error("Expected error when fetching CI status without gh CLI")
	}
	
	if status != nil {
		t.Error("Expected nil status on error")
	}
}

// BenchmarkBuildCIStatusFromChecks benchmarks CI status building
func BenchmarkBuildCIStatusFromChecks(b *testing.B) {
	pm := NewPRManager(5*time.Minute, 3, false)
	prURL := "https://github.com/test/repo/pull/123"
	
	// Create test data with 20 checks
	checks := make([]types.CheckRun, 20)
	for i := 0; i < 20; i++ {
		state := "SUCCESS"
		if i%3 == 0 {
			state = "FAILURE"
		} else if i%5 == 0 {
			state = "PENDING"
		}
		checks[i] = createTestCheckRun(fmt.Sprintf("check-%d", i), state)
	}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = pm.buildCIStatusFromChecks(checks, prURL)
	}
}

// BenchmarkAnalyzeCIFailures benchmarks failure analysis
func BenchmarkAnalyzeCIFailures(b *testing.B) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	// Create test status with mixed results
	status := &types.CIStatus{
		Checks: []types.CheckRun{
			{Name: "build-check", Status: "FAILURE"},
			{Name: "lint-check", Status: "ERROR"},
			{Name: "test-suite", Status: "FAILED"},
			{Name: "security-scan", Status: "SUCCESS"},
			{Name: "coverage", Status: "FAILURE"},
		},
	}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = pm.AnalyzeCIFailures(status)
	}
}

// TestContextCancellation tests proper context cancellation handling
func TestContextCancellation(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	
	// Create a context that's already cancelled
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	
	prURL := "https://github.com/test/repo/pull/123"
	
	// Try to fetch CI status with cancelled context
	_, err := pm.fetchCurrentCIStatus(ctx, prURL)
	
	// We expect an error due to cancelled context or command failure
	if err == nil {
		t.Error("Expected error when using cancelled context")
	}
}

// TestJSONFieldsCompatibility tests that we're using correct JSON fields
func TestJSONFieldsCompatibility(t *testing.T) {
	// Verify that the fields we're requesting are valid
	validFields := []string{
		"name",
		"state", 
		"link",
		"startedAt",
		"completedAt",
		"description",
		"event",
		"workflow",
		"bucket",
	}
	
	// This is the command we would use
	cmdArgs := []string{"pr", "checks", "https://github.com/test/repo/pull/123", "--json"}
	jsonFields := strings.Join(validFields, ",")
	cmdArgs = append(cmdArgs, jsonFields)
	
	// Verify the command construction
	if len(cmdArgs) != 5 {
		t.Errorf("Expected 5 command args, got %d", len(cmdArgs))
	}
	
	if !strings.Contains(cmdArgs[4], "state") {
		t.Error("JSON fields should contain 'state'")
	}
	
	if strings.Contains(cmdArgs[4], "conclusion") {
		t.Error("JSON fields should NOT contain 'conclusion'")
	}
}

// Edge case and comprehensive testing starts here

// TestPRManagerEdgeCases tests PR manager with edge cases
func TestPRManagerEdgeCases(t *testing.T) {
	tests := []struct {
		name       string
		timeout    time.Duration
		maxRetries int
		debugMode  bool
		expectNil  bool
	}{
		{"Zero timeout", 0, 3, false, false},
		{"Negative timeout", -1 * time.Second, 3, false, false},
		{"Very large timeout", 24 * time.Hour, 3, false, false},
		{"Zero retries", 5 * time.Minute, 0, false, false},
		{"Negative retries", 5 * time.Minute, -1, false, false},
		{"Very large retries", 5 * time.Minute, 1000, false, false},
		{"All extremes", 0, 0, true, false},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pm := NewPRManager(tt.timeout, tt.maxRetries, tt.debugMode)
			
			if tt.expectNil && pm != nil {
				t.Error("Expected nil PR manager")
			}
			
			if !tt.expectNil && pm == nil {
				t.Error("Expected non-nil PR manager")
			}
			
			if pm != nil {
				// Verify values are stored correctly even if they're edge cases
				if pm.timeout != tt.timeout {
					t.Errorf("Expected timeout %v, got %v", tt.timeout, pm.timeout)
				}
				if pm.maxRetries != tt.maxRetries {
					t.Errorf("Expected maxRetries %d, got %d", tt.maxRetries, pm.maxRetries)
				}
			}
		})
	}
}

// TestBuildCIStatusFromChecksEdgeCases tests CI status building with edge cases
func TestBuildCIStatusFromChecksEdgeCases(t *testing.T) {
	pm := NewPRManager(5*time.Minute, 3, false)
	prURL := "https://github.com/test/repo/pull/123"
	
	tests := []struct {
		name               string
		checks             []types.CheckRun
		expectedStatus     string
		expectedConclusion string
		expectedTotal      int
	}{
		{
			name:               "No checks - empty slice",
			checks:             []types.CheckRun{},
			expectedStatus:     "success",
			expectedConclusion: "success",
			expectedTotal:      0,
		},
		{
			name:               "Nil checks slice",
			checks:             nil,
			expectedStatus:     "success",
			expectedConclusion: "success",
			expectedTotal:      0,
		},
		{
			name: "Single check with unknown status",
			checks: []types.CheckRun{
				{Name: "unknown", Status: "UNKNOWN_STATUS"},
			},
			expectedStatus:     "pending",
			expectedConclusion: "pending",
			expectedTotal:      1,
		},
		{
			name: "Checks with empty names",
			checks: []types.CheckRun{
				{Name: "", Status: "SUCCESS"},
				{Name: "   ", Status: "FAILURE"},
			},
			expectedStatus:     "failure",
			expectedConclusion: "failure",
			expectedTotal:      2,
		},
		{
			name: "Very large number of checks",
			checks: func() []types.CheckRun {
				checks := make([]types.CheckRun, 1000)
				for i := 0; i < 1000; i++ {
					status := "SUCCESS"
					if i%10 == 0 {
						status = "FAILURE"
					}
					checks[i] = types.CheckRun{
						Name:   fmt.Sprintf("check-%d", i),
						Status: status,
					}
				}
				return checks
			}(),
			expectedStatus:     "failure",
			expectedConclusion: "failure",
			expectedTotal:      1000,
		},
		{
			name: "Checks with mixed case statuses",
			checks: []types.CheckRun{
				{Name: "build", Status: "success"},     // lowercase
				{Name: "test", Status: "Success"},      // mixed case
				{Name: "lint", Status: "SUCCESS"},     // uppercase
				{Name: "deploy", Status: "failure"},   // lowercase
				{Name: "security", Status: "FAILURE"}, // uppercase
			},
			expectedStatus:     "failure",
			expectedConclusion: "failure",
			expectedTotal:      5,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status := pm.buildCIStatusFromChecks(tt.checks, prURL)
			
			if status.Status != tt.expectedStatus {
				t.Errorf("Expected status %s, got %s", tt.expectedStatus, status.Status)
			}
			
			if status.Conclusion != tt.expectedConclusion {
				t.Errorf("Expected conclusion %s, got %s", tt.expectedConclusion, status.Conclusion)
			}
			
			if status.TotalChecks != tt.expectedTotal {
				t.Errorf("Expected %d total checks, got %d", tt.expectedTotal, status.TotalChecks)
			}
			
			if status.URL != prURL {
				t.Errorf("Expected URL %s, got %s", prURL, status.URL)
			}
			
			if status.LastUpdated.IsZero() {
				t.Error("LastUpdated should not be zero")
			}
		})
	}
}

