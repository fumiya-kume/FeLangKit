package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// Configuration loading and environment variable handling

// LoadConfiguration loads configuration from YAML file with fallback to environment variables
func LoadConfiguration() (*CCWConfig, error) {
	config := GetDefaultCCWConfig()
	
	// Try to load from YAML file
	if err := loadFromYAMLFile(config); err != nil {
		// YAML file not found or invalid, continue with defaults
	}
	
	// Override with environment variables
	loadFromEnvironment(config)
	
	return config, nil
}

// Load configuration from YAML file
func loadFromYAMLFile(config *CCWConfig) error {
	// Try multiple possible config file locations
	configPaths := []string{
		"ccw.yaml",
		"ccw.yml",
		".ccw.yaml",
		".ccw.yml",
		filepath.Join(os.Getenv("HOME"), ".ccw.yaml"),
		filepath.Join(os.Getenv("HOME"), ".ccw.yml"),
		filepath.Join(os.Getenv("HOME"), ".config", "ccw", "config.yaml"),
		filepath.Join(os.Getenv("HOME"), ".config", "ccw", "config.yml"),
	}
	
	for _, configPath := range configPaths {
		if data, err := os.ReadFile(configPath); err == nil {
			if err := yaml.Unmarshal(data, config); err != nil {
				return fmt.Errorf("failed to parse YAML config file %s: %w", configPath, err)
			}
			return nil
		}
	}
	
	return fmt.Errorf("no config file found")
}

// Load configuration from environment variables
func loadFromEnvironment(config *CCWConfig) {
	// Core settings
	if val := os.Getenv("DEBUG_MODE"); val != "" {
		config.DebugMode = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_WORKTREE_BASE"); val != "" {
		config.WorktreeBase = val
	}
	if val := os.Getenv("CCW_MAX_RETRIES"); val != "" {
		if retries, err := strconv.Atoi(val); err == nil {
			config.MaxRetries = retries
		}
	}
	if val := os.Getenv("CCW_CLAUDE_TIMEOUT"); val != "" {
		config.ClaudeTimeout = val
	}
	
	// UI Configuration
	if val := os.Getenv("CCW_THEME"); val != "" {
		config.UI.Theme = val
	}
	if val := os.Getenv("CCW_ANIMATIONS"); val != "" {
		config.UI.Animations = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_COLOR_OUTPUT"); val != "" {
		config.UI.ColorOutput = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_UNICODE"); val != "" {
		config.UI.Unicode = strings.ToLower(val) == "true"
	}
	
	// Git Configuration
	if val := os.Getenv("CCW_GIT_TIMEOUT"); val != "" {
		config.Git.Timeout = val
	}
	if val := os.Getenv("CCW_GIT_RETRIES"); val != "" {
		if retries, err := strconv.Atoi(val); err == nil {
			config.Git.RetryAttempts = retries
		}
	}
	if val := os.Getenv("CCW_GIT_RETRY_DELAY"); val != "" {
		config.Git.RetryDelay = val
	}
	if val := os.Getenv("CCW_GIT_DEFAULT_BRANCH"); val != "" {
		config.Git.DefaultBranch = val
	}
	
	// Logging Configuration
	if val := os.Getenv("CCW_LOG_LEVEL"); val != "" {
		config.Logging.Level = val
	}
	if val := os.Getenv("CCW_LOG_FORMAT"); val != "" {
		config.Logging.Format = val
	}
	if val := os.Getenv("CCW_LOG_FILE"); val != "" {
		config.Logging.File = val
	}
	
	// Performance Configuration
	if val := os.Getenv("CCW_PERFORMANCE_LEVEL"); val != "" {
		if level, err := strconv.Atoi(val); err == nil {
			config.Performance.Level = level
		}
	}
	if val := os.Getenv("CCW_ADAPTIVE_REFRESH"); val != "" {
		config.Performance.AdaptiveRefresh = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_CONTENT_CACHING"); val != "" {
		config.Performance.ContentCaching = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_SELECTIVE_UPDATES"); val != "" {
		config.Performance.SelectiveUpdates = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_MIN_REFRESH_MS"); val != "" {
		config.Performance.MinRefreshInterval = val + "ms"
	}
	if val := os.Getenv("CCW_MAX_REFRESH_MS"); val != "" {
		config.Performance.MaxRefreshInterval = val + "ms"
	}
	if val := os.Getenv("CCW_CACHE_SIZE"); val != "" {
		if size, err := strconv.Atoi(val); err == nil {
			config.Performance.CacheSize = size
		}
	}
	
	// GitHub Configuration
	if val := os.Getenv("CCW_MONITOR_CI"); val != "" {
		config.GitHub.MonitorCI = strings.ToLower(val) == "true"
	}
	if val := os.Getenv("CCW_PR_TEMPLATE"); val != "" {
		config.GitHub.PRTemplate = val
	}
	if val := os.Getenv("CCW_ISSUE_TEMPLATE"); val != "" {
		config.GitHub.IssueTemplate = val
	}
	if val := os.Getenv("CCW_DEFAULT_LABELS"); val != "" {
		config.GitHub.DefaultLabels = strings.Split(val, ",")
	}
	if val := os.Getenv("CCW_AUTO_ASSIGN"); val != "" {
		config.GitHub.AutoAssign = strings.ToLower(val) == "true"
	}
	
	// Claude Configuration
	if val := os.Getenv("CCW_CLAUDE_TIMEOUT"); val != "" {
		config.Claude.Timeout = val
	}
	if val := os.Getenv("CCW_CLAUDE_MAX_RETRIES"); val != "" {
		if retries, err := strconv.Atoi(val); err == nil {
			config.Claude.MaxRetries = retries
		}
	}
	if val := os.Getenv("CCW_CLAUDE_MODEL"); val != "" {
		config.Claude.Model = val
	}
	if val := os.Getenv("CCW_CLAUDE_CONTEXT"); val != "" {
		config.Claude.Context = val
	}
	if val := os.Getenv("CCW_ENHANCED_COMMIT_MESSAGE"); val != "" {
		config.Claude.EnhancedCommitMessage = strings.ToLower(val) == "true"
	}
}