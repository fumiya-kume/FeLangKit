package config

import "time"

// Default configuration values

// GetDefaultCCWConfig returns default configuration values
func GetDefaultCCWConfig() *CCWConfig {
	return &CCWConfig{
		WorktreeBase:  ".",
		MaxRetries:    3,
		ClaudeTimeout: "30m",
		DebugMode:     false,
		
		UI: UIConfiguration{
			Theme:       "default",
			Animations:  true,
			ColorOutput: true,
			Unicode:     true,
			Width:       80,
			Height:      24,
		},
		
		Git: GitConfiguration{
			Timeout:       "30s",
			RetryAttempts: 3,
			RetryDelay:    "2s",
			DefaultBranch: "master",
			RemoteName:    "origin",
		},
		
		Logging: LoggingConfiguration{
			Level:      "info",
			Format:     "text",
			File:       "",
			MaxSize:    10,
			MaxBackups: 3,
			MaxAge:     7,
		},
		
		Performance: PerformanceConfiguration{
			Level:                      2,
			AdaptiveRefresh:            true,
			ContentCaching:             true,
			SelectiveUpdates:           true,
			MinRefreshInterval:         "100ms",
			MaxRefreshInterval:         "2s",
			CacheSize:                  100,
			ChangeDetectionSensitivity: 0.1,
		},
		
		GitHub: GitHubConfiguration{
			MonitorCI:     false,
			PRTemplate:    "",
			IssueTemplate: "",
			DefaultLabels: []string{},
			AutoAssign:    false,
		},
		
		Claude: ClaudeConfiguration{
			Timeout:               "30m",
			MaxRetries:            3,
			Model:                 "",
			Context:               "",
			EnhancedCommitMessage: true,
		},
	}
}

// GetDefaultPerformanceConfig returns default performance configuration for legacy support
func GetDefaultPerformanceConfig() *PerformanceConfigLegacy {
	return &PerformanceConfigLegacy{
		EnableAdaptiveRefresh:      true,
		EnableContentCaching:       true,
		EnableSelectiveUpdates:     true,
		MinRefreshInterval:         100 * time.Millisecond,
		MaxRefreshInterval:         2 * time.Second,
		CacheSize:                  100,
		CacheTTL:                   10 * time.Minute,
		OptimizationLevel:          2,
		DebounceThreshold:          50 * time.Millisecond,
		ChangeDetectionSensitivity: 0.1,
	}
}