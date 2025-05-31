package claude

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// ClaudePermissions represents Claude Code permission configuration
type ClaudePermissions struct {
	Permissions struct {
		Allow []string `json:"allow"`
		Deny  []string `json:"deny"`
	} `json:"permissions"`
	EnableAllProjectMcpServers bool `json:"enableAllProjectMcpServers"`
}

// SetupPermissivePermissions creates permissive Claude Code permissions in the specified directory
func SetupPermissivePermissions(worktreePath string) error {
	claudeDir := filepath.Join(worktreePath, ".claude")
	settingsFile := filepath.Join(claudeDir, "settings.local.json")

	// Create .claude directory if it doesn't exist
	if err := os.MkdirAll(claudeDir, 0755); err != nil {
		return fmt.Errorf("failed to create .claude directory: %w", err)
	}

	// Create permissive permissions configuration
	permissions := ClaudePermissions{
		EnableAllProjectMcpServers: false,
	}
	permissions.Permissions.Allow = []string{
		"Bash(*)",                          // Allow any bash command
		"WebFetch(domain:github.com)",      // Allow GitHub API access
	}
	permissions.Permissions.Deny = []string{}

	// Marshal to JSON with proper formatting
	data, err := json.MarshalIndent(permissions, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal permissions to JSON: %w", err)
	}

	// Write to settings file
	if err := os.WriteFile(settingsFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write Claude permissions file: %w", err)
	}

	return nil
}

// SetupPermissionsFromTemplate creates Claude Code permissions using a template file
func SetupPermissionsFromTemplate(worktreePath, templatePath string) error {
	claudeDir := filepath.Join(worktreePath, ".claude")
	settingsFile := filepath.Join(claudeDir, "settings.local.json")

	// Create .claude directory if it doesn't exist
	if err := os.MkdirAll(claudeDir, 0755); err != nil {
		return fmt.Errorf("failed to create .claude directory: %w", err)
	}

	// Check if template exists
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		// Fall back to creating permissive permissions
		return SetupPermissivePermissions(worktreePath)
	}

	// Read template file
	templateData, err := os.ReadFile(templatePath)
	if err != nil {
		// Fall back to creating permissive permissions
		return SetupPermissivePermissions(worktreePath)
	}

	// Write template to settings file
	if err := os.WriteFile(settingsFile, templateData, 0644); err != nil {
		return fmt.Errorf("failed to write Claude permissions file: %w", err)
	}

	return nil
}

// ValidatePermissionsFile checks if the Claude permissions file exists and is valid
func ValidatePermissionsFile(worktreePath string) error {
	settingsFile := filepath.Join(worktreePath, ".claude", "settings.local.json")
	
	// Check if file exists
	if _, err := os.Stat(settingsFile); os.IsNotExist(err) {
		return fmt.Errorf("Claude permissions file not found: %s", settingsFile)
	}

	// Try to parse JSON to validate format
	data, err := os.ReadFile(settingsFile)
	if err != nil {
		return fmt.Errorf("failed to read Claude permissions file: %w", err)
	}

	var permissions ClaudePermissions
	if err := json.Unmarshal(data, &permissions); err != nil {
		return fmt.Errorf("invalid JSON in Claude permissions file: %w", err)
	}

	return nil
}

// GetDefaultTemplatePath returns the path to the default Claude settings template
func GetDefaultTemplatePath() string {
	// Assume template is in the same directory as the ccw executable
	return ".claude-settings-template.json"
}