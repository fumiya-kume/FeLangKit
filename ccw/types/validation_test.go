package types

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

// TestValidationResult tests validation result structure
func TestValidationResult(t *testing.T) {
	result := &ValidationResult{
		Success:   true,
		Duration:  100 * time.Millisecond,
		Timestamp: time.Now(),
		LintResult: &LintResult{
			Success:   true,
			AutoFixed: true,
			Errors:    []string{},
			Warnings:  []string{},
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
			Output:    "All tests passed",
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

	if result.Duration <= 0 {
		t.Error("Duration should be positive")
	}
}

// TestLintResult tests lint result structure
func TestLintResult(t *testing.T) {
	tests := []struct {
		name      string
		result    *LintResult
		expectErr bool
	}{
		{
			name: "Successful lint with auto-fix",
			result: &LintResult{
				Success:   true,
				AutoFixed: true,
				Errors:    []string{},
				Warnings:  []string{},
			},
			expectErr: false,
		},
		{
			name: "Failed lint with issues",
			result: &LintResult{
				Success:   false,
				AutoFixed: false,
				Errors:    []string{"Line 10: missing semicolon", "Line 25: unused variable"},
				Warnings:  []string{},
			},
			expectErr: true,
		},
		{
			name: "Lint with warnings only",
			result: &LintResult{
				Success:   true,
				AutoFixed: false,
				Errors:    []string{},
				Warnings:  []string{"Warning: deprecated function used"},
			},
			expectErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectErr && tt.result.Success {
				t.Error("Expected lint to fail but it succeeded")
			}

			if !tt.expectErr && !tt.result.Success {
				t.Error("Expected lint to succeed but it failed")
			}

			if tt.result.AutoFixed && (len(tt.result.Errors) > 0 || len(tt.result.Warnings) > 0) {
				t.Log("Lint auto-fixed issues:", append(tt.result.Errors, tt.result.Warnings...))
			}
		})
	}
}

// TestBuildResult tests build result structure
func TestBuildResult(t *testing.T) {
	tests := []struct {
		name   string
		result *BuildResult
	}{
		{
			name: "Successful build",
			result: &BuildResult{
				Success: true,
				Output:  "Build completed successfully",
			},
		},
		{
			name: "Failed build",
			result: &BuildResult{
				Success: false,
				Output:  "Build failed: compilation error in main.go:42",
			},
		},
		{
			name: "Build with warnings",
			result: &BuildResult{
				Success: true,
				Output:  "Build completed with 3 warnings",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.result.Output == "" {
				t.Error("Build output should not be empty")
			}

			if tt.result.Success && len(tt.result.Output) < 10 {
				t.Log("Short successful build output:", tt.result.Output)
			}
		})
	}
}

// TestTestResult tests test result structure
func TestTestResult(t *testing.T) {
	tests := []struct {
		name   string
		result *TestResult
		valid  bool
	}{
		{
			name: "All tests passed",
			result: &TestResult{
				Success:   true,
				TestCount: 50,
				Passed:    50,
				Failed:    0,
				Output:    "50 tests, 50 passed, 0 failed",
			},
			valid: true,
		},
		{
			name: "Some tests failed",
			result: &TestResult{
				Success:   false,
				TestCount: 50,
				Passed:    45,
				Failed:    5,
				Output:    "50 tests, 45 passed, 5 failed",
			},
			valid: true,
		},
		{
			name: "Invalid test counts",
			result: &TestResult{
				Success:   true,
				TestCount: 10,
				Passed:    15, // More passed than total
				Failed:    0,
				Output:    "Invalid test result",
			},
			valid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			totalRun := tt.result.Passed + tt.result.Failed
			
			if tt.valid && totalRun > tt.result.TestCount {
				t.Error("Total run tests cannot exceed test count")
			}

			if tt.result.Success && tt.result.Failed > 0 {
				t.Error("Test result cannot be successful with failed tests")
			}

			if !tt.result.Success && tt.result.Failed == 0 {
				t.Error("Test result cannot be failed without failed tests")
			}
		})
	}
}

// TestValidationError tests validation error structure
func TestValidationError(t *testing.T) {
	err := ValidationError{
		Type:        "lint_error",
		Message:     "Linting failed",
		File:        "main.go",
		Line:        42,
		Recoverable: true,
	}

	if err.Type == "" {
		t.Error("Error type should not be empty")
	}

	if err.Message == "" {
		t.Error("Error message should not be empty")
	}

	if !err.Recoverable {
		t.Error("Expected error to be recoverable")
	}

	// Test detailed error message
	detailedMsg := err.GetDetailedError()
	if detailedMsg != err.Message {
		t.Log("Detailed error message:", detailedMsg)
	}
}

// TestErrorCause tests error cause structure
func TestErrorCause(t *testing.T) {
	cause := &ErrorCause{
		RootError: "Command failed",
		Command:   "go build",
		ExitCode:  1,
		Stderr:    "compilation failed",
		Stdout:    "",
		Context:   map[string]string{"file": "main.go", "line": "42"},
	}

	if cause.RootError == "" {
		t.Error("Root error should not be empty")
	}

	if cause.Command == "" {
		t.Error("Command should not be empty")
	}

	if cause.ExitCode == 0 {
		t.Error("Exit code should indicate failure")
	}

	if len(cause.Context) == 0 {
		t.Error("Context should contain information")
	}
}

// TestNewValidationErrorWithCause tests validation error creation with cause
func TestNewValidationErrorWithCause(t *testing.T) {
	originalErr := fmt.Errorf("original error occurred")
	
	validationErr := NewValidationErrorWithCause("test_error", "Test error message", originalErr, true)
	
	if validationErr.Type != "test_error" {
		t.Errorf("Expected type 'test_error', got '%s'", validationErr.Type)
	}
	
	if validationErr.Message != "Test error message" {
		t.Errorf("Expected message 'Test error message', got '%s'", validationErr.Message)
	}
	
	if !validationErr.Recoverable {
		t.Error("Expected error to be recoverable")
	}
	
	if validationErr.Cause == nil {
		t.Error("Expected cause to be set")
	}
	
	if validationErr.Cause.RootError != originalErr.Error() {
		t.Errorf("Expected root error '%s', got '%s'", originalErr.Error(), validationErr.Cause.RootError)
	}
}

// TestNewCommandValidationError tests command validation error creation
func TestNewCommandValidationError(t *testing.T) {
	originalErr := fmt.Errorf("command failed")
	command := "go build"
	stdout := "Building..."
	stderr := "Error: compilation failed"
	
	validationErr := NewCommandValidationError("command_error", "Command execution failed", command, originalErr, stdout, stderr, false)
	
	if validationErr.Type != "command_error" {
		t.Errorf("Expected type 'command_error', got '%s'", validationErr.Type)
	}
	
	if validationErr.Recoverable {
		t.Error("Expected error to be non-recoverable")
	}
	
	if validationErr.Cause == nil {
		t.Error("Expected cause to be set")
	}
	
	if validationErr.Cause.Command != command {
		t.Errorf("Expected command '%s', got '%s'", command, validationErr.Cause.Command)
	}
	
	if validationErr.Cause.Stdout != stdout {
		t.Errorf("Expected stdout '%s', got '%s'", stdout, validationErr.Cause.Stdout)
	}
	
	if validationErr.Cause.Stderr != stderr {
		t.Errorf("Expected stderr '%s', got '%s'", stderr, validationErr.Cause.Stderr)
	}
}

// TestValidationErrorAddContext tests adding context to validation errors
func TestValidationErrorAddContext(t *testing.T) {
	validationErr := ValidationError{
		Type:        "test_error",
		Message:     "Test error",
		Recoverable: true,
	}
	
	// Add context to error without existing cause
	validationErr.AddContext("file", "main.go")
	validationErr.AddContext("line", "42")
	
	if validationErr.Cause == nil {
		t.Error("Expected cause to be created")
	}
	
	if validationErr.Cause.Context["file"] != "main.go" {
		t.Error("Expected file context to be set")
	}
	
	if validationErr.Cause.Context["line"] != "42" {
		t.Error("Expected line context to be set")
	}
}

// TestValidationErrorGetDetailedError tests detailed error message generation
func TestValidationErrorGetDetailedError(t *testing.T) {
	tests := []struct {
		name     string
		err      ValidationError
		contains []string
	}{
		{
			name: "Simple error without cause",
			err: ValidationError{
				Type:    "simple",
				Message: "Simple error message",
			},
			contains: []string{"Simple error message"},
		},
		{
			name: "Error with full cause information",
			err: ValidationError{
				Type:    "complex",
				Message: "Complex error occurred",
				Cause: &ErrorCause{
					RootError: "Root cause error",
					Command:   "go test",
					ExitCode:  1,
					Stderr:    "Test failed",
					Context:   map[string]string{"test": "TestExample"},
				},
			},
			contains: []string{"Complex error occurred", "Root cause error", "go test", "Exit code: 1", "Test failed", "test: TestExample"},
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			detailed := tt.err.GetDetailedError()
			
			for _, expected := range tt.contains {
				if !strings.Contains(detailed, expected) {
					t.Errorf("Expected detailed error to contain '%s', got: %s", expected, detailed)
				}
			}
		})
	}
}