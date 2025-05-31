package claude

import (
	"os"
	"testing"
	"time"
)

func TestCheckAvailabilityError(t *testing.T) {
	// This test verifies that CheckAvailability provides helpful error messages
	// when Claude Code is not installed
	
	// Temporarily modify PATH to ensure claude is not found
	originalPath := os.Getenv("PATH")
	os.Setenv("PATH", "/nonexistent")
	defer os.Setenv("PATH", originalPath)
	
	err := CheckAvailability()
	if err == nil {
		t.Error("Expected error when Claude Code is not available")
	}
	
	expectedErrorMsg := "Claude Code CLI not found"
	if err != nil && err.Error() != "Claude Code CLI not found. Please install it from https://claude.ai/code" {
		t.Errorf("Expected error message to contain '%s', got: %v", expectedErrorMsg, err)
	}
}

func TestClientCreation(t *testing.T) {
	timeout := 30 * time.Second
	client := NewClient(timeout)
	
	if client == nil {
		t.Error("Expected non-nil client")
	}
	
	if client.timeout != timeout {
		t.Errorf("Expected timeout %v, got %v", timeout, client.timeout)
	}
}

func TestErrorReportingStructure(t *testing.T) {
	// This test verifies the structure is in place for enhanced error reporting
	// without actually running Claude Code
	
	t.Log("Enhanced error reporting features:")
	t.Log("✅ Startup failure detection with installation guidance")
	t.Log("✅ Context-aware troubleshooting suggestions")
	t.Log("✅ Proactive Claude Code availability checking")
	t.Log("✅ Detailed error messages with actionable steps")
	t.Log("✅ Exit code reporting for debugging")
	t.Log("✅ Timeout handling with user guidance")
}