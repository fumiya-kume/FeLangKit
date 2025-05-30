package config

import "time"

// Configuration conversion utilities

// ToLegacyConfig converts CCWConfig to legacy Config struct for backward compatibility
func (c *CCWConfig) ToLegacyConfig() *Config {
	// Parse durations for legacy performance config
	minRefresh, _ := time.ParseDuration(c.Performance.MinRefreshInterval)
	maxRefresh, _ := time.ParseDuration(c.Performance.MaxRefreshInterval)
	
	return &Config{
		WorktreeBase:      c.WorktreeBase,
		MaxRetries:        c.MaxRetries,
		ClaudeTimeout:     c.ClaudeTimeout,
		DebugMode:         c.DebugMode,
		ThemeName:         c.UI.Theme,
		AnimationsEnabled: c.UI.Animations,
		GitTimeout:        c.Git.Timeout,
		GitRetryAttempts:  c.Git.RetryAttempts,
		PerformanceConfig: &PerformanceConfigLegacy{
			EnableAdaptiveRefresh:      c.Performance.AdaptiveRefresh,
			EnableContentCaching:       c.Performance.ContentCaching,
			EnableSelectiveUpdates:     c.Performance.SelectiveUpdates,
			MinRefreshInterval:         minRefresh,
			MaxRefreshInterval:         maxRefresh,
			CacheSize:                  c.Performance.CacheSize,
			OptimizationLevel:          c.Performance.Level,
			ChangeDetectionSensitivity: c.Performance.ChangeDetectionSensitivity,
		},
	}
}

// FromEnvironment creates a legacy performance config from environment variables
func GetPerformanceConfigFromEnv() *PerformanceConfigLegacy {
	config := GetDefaultPerformanceConfig()
	
	// This would be populated from environment variables
	// Implementation moved to main package for legacy support
	
	return config
}