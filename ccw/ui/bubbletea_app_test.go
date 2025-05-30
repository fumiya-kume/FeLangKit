package ui

import (
	"testing"
	"time"
)

func TestNewCCWApp(t *testing.T) {
	// Test creating a CCWApp with default options
	app := NewDefaultCCWApp()
	if app == nil {
		t.Fatal("NewDefaultCCWApp() returned nil")
	}

	if app.ui == nil {
		t.Error("CCWApp.ui is nil")
	}

	if app.options == nil {
		t.Error("CCWApp.options is nil")
	}

	// Verify default options
	if app.options.Theme != "modern" {
		t.Errorf("Expected theme 'modern', got '%s'", app.options.Theme)
	}

	if !app.options.EnableAnimations {
		t.Error("Expected animations to be enabled by default")
	}

	if !app.options.EnableLogging {
		t.Error("Expected logging to be enabled by default")
	}
}

func TestCCWAppOptions(t *testing.T) {
	options := &CCWAppOptions{
		Theme:            "minimal",
		EnableAnimations: false,
		DebugMode:        true,
		ForceConsoleMode: true,
		LogBufferSize:    500,
		DefaultTimeout:   10 * time.Second,
	}

	app := NewCCWApp(options)
	if app == nil {
		t.Fatal("NewCCWApp() returned nil")
	}

	if app.options.Theme != "minimal" {
		t.Errorf("Expected theme 'minimal', got '%s'", app.options.Theme)
	}

	if app.options.EnableAnimations {
		t.Error("Expected animations to be disabled")
	}

	if !app.options.DebugMode {
		t.Error("Expected debug mode to be enabled")
	}

	if !app.options.ForceConsoleMode {
		t.Error("Expected console mode to be forced")
	}
}

func TestCCWAppInitialization(t *testing.T) {
	app := NewDefaultCCWApp()
	
	// Should not be initialized yet
	if app.initialized {
		t.Error("CCWApp should not be initialized before calling Initialize()")
	}

	// Initialize the app
	err := app.Initialize()
	if err != nil {
		t.Fatalf("Initialize() failed: %v", err)
	}

	if !app.initialized {
		t.Error("CCWApp should be initialized after calling Initialize()")
	}

	if app.model == nil {
		t.Error("CCWApp.model should be initialized")
	}

	// Should be safe to call Initialize() again
	err = app.Initialize()
	if err != nil {
		t.Errorf("Second Initialize() call failed: %v", err)
	}
}

func TestWorkflowStringRepresentation(t *testing.T) {
	tests := []struct {
		workflow CCWWorkflow
		expected string
	}{
		{WorkflowMainMenu, "Main Menu"},
		{WorkflowIssueSelection, "Issue Selection"},
		{WorkflowProgressTracking, "Progress Tracking"},
		{WorkflowDoctorCheck, "Doctor Check"},
		{CCWWorkflow(999), "Unknown"},
	}

	for _, test := range tests {
		if got := test.workflow.String(); got != test.expected {
			t.Errorf("Workflow.String() for %d: expected %s, got %s", 
				int(test.workflow), test.expected, got)
		}
	}
}

func TestCanRunInteractive(t *testing.T) {
	// Test with forced console mode
	options := &CCWAppOptions{
		ForceConsoleMode: true,
	}
	app := NewCCWApp(options)
	
	if app.interactive {
		t.Error("App should not be interactive when ForceConsoleMode is true")
	}

	// Test with default options (should detect terminal capabilities)
	app = NewDefaultCCWApp()
	// Interactive mode detection depends on the actual terminal environment
	// so we just verify the app was created successfully
	if app == nil {
		t.Error("NewDefaultCCWApp() should create a valid app")
	}
}