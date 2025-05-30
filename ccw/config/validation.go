package config

import (
	"fmt"
	"strings"
	"time"
)

// Configuration validation

// Validate configuration values
func (c *CCWConfig) Validate() error {
	// Validate timeout formats
	if _, err := time.ParseDuration(c.ClaudeTimeout); err != nil {
		return fmt.Errorf("invalid claude_timeout format: %w", err)
	}
	if _, err := time.ParseDuration(c.Git.Timeout); err != nil {
		return fmt.Errorf("invalid git.timeout format: %w", err)
	}
	if _, err := time.ParseDuration(c.Git.RetryDelay); err != nil {
		return fmt.Errorf("invalid git.retry_delay format: %w", err)
	}
	if _, err := time.ParseDuration(c.Performance.MinRefreshInterval); err != nil {
		return fmt.Errorf("invalid performance.min_refresh_interval format: %w", err)
	}
	if _, err := time.ParseDuration(c.Performance.MaxRefreshInterval); err != nil {
		return fmt.Errorf("invalid performance.max_refresh_interval format: %w", err)
	}

	// Validate ranges
	if c.Git.RetryAttempts < 0 || c.Git.RetryAttempts > 10 {
		return fmt.Errorf("git.retry_attempts must be between 0 and 10")
	}
	if c.Performance.Level < 0 || c.Performance.Level > 2 {
		return fmt.Errorf("performance.level must be between 0 and 2")
	}
	if c.Performance.ChangeDetectionSensitivity < 0.0 || c.Performance.ChangeDetectionSensitivity > 1.0 {
		return fmt.Errorf("performance.change_detection_sensitivity must be between 0.0 and 1.0")
	}

	// Validate log level
	validLogLevels := []string{"debug", "info", "warn", "error"}
	valid := false
	for _, level := range validLogLevels {
		if c.Logging.Level == level {
			valid = true
			break
		}
	}
	if !valid {
		return fmt.Errorf("logging.level must be one of: %s", strings.Join(validLogLevels, ", "))
	}

	// Validate log format
	if c.Logging.Format != "text" && c.Logging.Format != "json" {
		return fmt.Errorf("logging.format must be 'text' or 'json'")
	}

	return nil
}
