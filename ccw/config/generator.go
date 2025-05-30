package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Configuration file generation

// SaveToFile saves current configuration to YAML file
func (c *CCWConfig) SaveToFile(filename string) error {
	data, err := yaml.Marshal(c)
	if err != nil {
		return fmt.Errorf("failed to marshal config to YAML: %w", err)
	}
	
	// Ensure directory exists
	dir := filepath.Dir(filename)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}
	
	if err := os.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}
	
	return nil
}

// GenerateSampleConfig generates a sample configuration file with documentation
func GenerateSampleConfig(filename string) error {
	yamlData := `# CCW Configuration File
# Claude Code Worktree automation tool configuration

# Core Settings
worktree_base: "."
max_retries: 3
claude_timeout: "30m"
debug_mode: false

# User Interface
ui:
  theme: "default"          # Options: default, minimal, modern, compact
  animations: true          # Enable terminal animations
  color_output: true        # Enable colored output
  unicode: true             # Enable Unicode characters
  width: 80                 # Terminal width (0 = auto-detect)
  height: 24                # Terminal height (0 = auto-detect)

# Git Operations
git:
  timeout: "30s"            # Timeout for git commands
  retry_attempts: 3         # Number of retry attempts for network operations
  retry_delay: "2s"         # Delay between retries
  default_branch: "master"  # Default branch name
  remote_name: "origin"     # Default remote name

# Logging
logging:
  level: "info"             # Log level: debug, info, warn, error
  format: "text"            # Log format: text, json
  file: ""                  # Log file path (empty = stdout only)
  max_size: 10              # Max log file size in MB
  max_backups: 3            # Number of log file backups to keep
  max_age: 7                # Max age of log files in days

# Performance Optimization
performance:
  level: 2                          # Performance level: 0=disabled, 1=basic, 2=aggressive
  adaptive_refresh: true            # Enable adaptive refresh rate
  content_caching: true             # Enable content caching
  selective_updates: true           # Enable selective UI updates
  min_refresh_interval: "100ms"     # Minimum refresh interval
  max_refresh_interval: "2s"        # Maximum refresh interval
  cache_size: 100                   # Content cache size
  change_detection_sensitivity: 0.1 # Change detection sensitivity (0.0-1.0)

# GitHub Integration
github:
  monitor_ci: false         # Monitor CI status after PR creation
  pr_template: ""           # Path to PR description template
  issue_template: ""        # Path to issue template
  default_labels: []        # Default labels to apply to PRs
  auto_assign: false        # Auto-assign PRs to current user

# Claude Code Integration
claude:
  timeout: "30m"                   # Timeout for Claude Code operations
  max_retries: 3                   # Max retries for Claude Code operations
  model: ""                        # Specific Claude model to use (empty = default)
  context: ""                      # Additional context file path
  enhanced_commit_message: true    # Enable AI-powered commit message generation
`
	
	if err := os.WriteFile(filename, []byte(yamlData), 0644); err != nil {
		return fmt.Errorf("failed to write sample config: %w", err)
	}
	
	return nil
}