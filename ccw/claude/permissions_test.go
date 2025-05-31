package claude

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestSetupPermissivePermissions(t *testing.T) {
	// Create temporary directory for testing
	tempDir, err := os.MkdirTemp("", "ccw-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test setting up permissions
	err = SetupPermissivePermissions(tempDir)
	if err != nil {
		t.Fatalf("SetupPermissivePermissions failed: %v", err)
	}

	// Verify the .claude directory was created
	claudeDir := filepath.Join(tempDir, ".claude")
	if _, err := os.Stat(claudeDir); os.IsNotExist(err) {
		t.Fatal(".claude directory was not created")
	}

	// Verify the settings file was created
	settingsFile := filepath.Join(claudeDir, "settings.local.json")
	if _, err := os.Stat(settingsFile); os.IsNotExist(err) {
		t.Fatal("settings.local.json file was not created")
	}

	// Read and verify the contents
	data, err := os.ReadFile(settingsFile)
	if err != nil {
		t.Fatalf("Failed to read settings file: %v", err)
	}

	var permissions ClaudePermissions
	if err := json.Unmarshal(data, &permissions); err != nil {
		t.Fatalf("Failed to parse JSON: %v", err)
	}

	// Verify the permissions structure
	if len(permissions.Permissions.Allow) != 2 {
		t.Fatalf("Expected 2 allow permissions, got %d", len(permissions.Permissions.Allow))
	}

	expectedPerms := []string{"Bash(*)", "WebFetch(domain:github.com)"}
	for i, expected := range expectedPerms {
		if permissions.Permissions.Allow[i] != expected {
			t.Errorf("Expected permission %q, got %q", expected, permissions.Permissions.Allow[i])
		}
	}

	if permissions.EnableAllProjectMcpServers {
		t.Error("EnableAllProjectMcpServers should be false")
	}
}

func TestValidatePermissionsFile(t *testing.T) {
	// Create temporary directory for testing
	tempDir, err := os.MkdirTemp("", "ccw-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test validation when file doesn't exist
	err = ValidatePermissionsFile(tempDir)
	if err == nil {
		t.Error("Expected error when file doesn't exist")
	}

	// Setup permissions first
	err = SetupPermissivePermissions(tempDir)
	if err != nil {
		t.Fatalf("SetupPermissivePermissions failed: %v", err)
	}

	// Test validation when file exists and is valid
	err = ValidatePermissionsFile(tempDir)
	if err != nil {
		t.Errorf("ValidatePermissionsFile failed: %v", err)
	}
}