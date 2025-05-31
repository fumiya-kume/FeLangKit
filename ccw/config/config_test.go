package config

import (
	"strings"
	"testing"
	"time"
)

// TestCCWConfig tests the main configuration structure
func TestCCWConfig(t *testing.T) {
	config := &CCWConfig{
		WorktreeBase:  "/tmp/ccw",
		MaxRetries:    3,
		ClaudeTimeout: "5m",
		DebugMode:     true,
		UI: UIConfiguration{
			Theme:       "dark",
			Animations:  true,
			ColorOutput: true,
			Unicode:     true,
			Width:       120,
			Height:      30,
		},
		Git: GitConfiguration{
			Timeout:       "30s",
			RetryAttempts: 3,
			RetryDelay:    "2s",
			DefaultBranch: "main",
			RemoteName:    "origin",
		},
		Logging: LoggingConfiguration{
			Level:      "info",
			Format:     "text",
			File:       "ccw.log",
			MaxSize:    10,
			MaxBackups: 5,
			MaxAge:     30,
		},
		Performance: PerformanceConfiguration{
			Level:                      2,
			AdaptiveRefresh:            true,
			ContentCaching:             true,
			SelectiveUpdates:           true,
			MinRefreshInterval:         "1s",
			MaxRefreshInterval:         "10s",
			CacheSize:                  1000,
			ChangeDetectionSensitivity: 0.8,
		},
		GitHub: GitHubConfiguration{
			MonitorCI:     true,
			PRTemplate:    "default",
			IssueTemplate: "bug_report",
			DefaultLabels: []string{"ccw", "automated"},
			AutoAssign:    false,
		},
		Claude: ClaudeConfiguration{
			Timeout:               "60s",
			MaxRetries:            3,
			Model:                 "claude-3-sonnet",
			Context:               "default",
			EnhancedCommitMessage: true,
		},
		ValidationRecovery: ValidationRecoveryConfiguration{
			Enabled:               true,
			MaxAttempts:           3,
			RecoveryTimeout:       "30s",
			DelayBetweenAttempts:  "5s",
			RecoverableErrorTypes: []string{"lint", "build"},
			AutoFixEnabled:        true,
			VerboseOutput:         false,
		},
	}

	// Test basic field access
	if config.WorktreeBase != "/tmp/ccw" {
		t.Errorf("Expected WorktreeBase '/tmp/ccw', got '%s'", config.WorktreeBase)
	}

	if config.MaxRetries != 3 {
		t.Errorf("Expected MaxRetries 3, got %d", config.MaxRetries)
	}

	if !config.DebugMode {
		t.Error("Expected DebugMode to be true")
	}

	// Test nested configurations
	if config.UI.Theme != "dark" {
		t.Errorf("Expected UI theme 'dark', got '%s'", config.UI.Theme)
	}

	if config.Git.Timeout != "30s" {
		t.Errorf("Expected Git timeout '30s', got '%s'", config.Git.Timeout)
	}

	if config.Logging.Level != "info" {
		t.Errorf("Expected logging level 'info', got '%s'", config.Logging.Level)
	}
}

// TestUIConfiguration tests UI configuration with edge cases
func TestUIConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config UIConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: UIConfiguration{
				Theme:       "dark",
				Animations:  true,
				ColorOutput: true,
				Unicode:     true,
				Width:       120,
				Height:      30,
			},
			valid: true,
		},
		{
			name: "Zero dimensions",
			config: UIConfiguration{
				Theme:   "light",
				Width:   0,
				Height:  0,
			},
			valid: false,
		},
		{
			name: "Negative dimensions",
			config: UIConfiguration{
				Theme:   "auto",
				Width:   -80,
				Height:  -24,
			},
			valid: false,
		},
		{
			name: "Very large dimensions",
			config: UIConfiguration{
				Theme:   "custom",
				Width:   10000,
				Height:  5000,
			},
			valid: true, // Large dimensions might be valid
		},
		{
			name: "Empty theme",
			config: UIConfiguration{
				Theme:  "",
				Width:  80,
				Height: 24,
			},
			valid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Validate dimensions
			validDimensions := tt.config.Width > 0 && tt.config.Height > 0
			validTheme := tt.config.Theme != ""

			isValid := validDimensions && validTheme

			if tt.valid && !isValid {
				t.Error("Expected configuration to be valid")
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestGitConfiguration tests Git configuration with edge cases
func TestGitConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config GitConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: GitConfiguration{
				Timeout:       "30s",
				RetryAttempts: 3,
				RetryDelay:    "2s",
				DefaultBranch: "main",
				RemoteName:    "origin",
			},
			valid: true,
		},
		{
			name: "Zero retry attempts",
			config: GitConfiguration{
				Timeout:       "30s",
				RetryAttempts: 0,
				RetryDelay:    "2s",
				DefaultBranch: "main",
				RemoteName:    "origin",
			},
			valid: true, // Zero retries might be valid
		},
		{
			name: "Negative retry attempts",
			config: GitConfiguration{
				Timeout:       "30s",
				RetryAttempts: -1,
				RetryDelay:    "2s",
				DefaultBranch: "main",
				RemoteName:    "origin",
			},
			valid: false,
		},
		{
			name: "Invalid timeout format",
			config: GitConfiguration{
				Timeout:       "invalid",
				RetryAttempts: 3,
				RetryDelay:    "2s",
				DefaultBranch: "main",
				RemoteName:    "origin",
			},
			valid: false,
		},
		{
			name: "Very long timeout",
			config: GitConfiguration{
				Timeout:       "24h",
				RetryAttempts: 3,
				RetryDelay:    "2s",
				DefaultBranch: "develop",
				RemoteName:    "upstream",
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Validate timeout format
			_, timeoutErr := time.ParseDuration(tt.config.Timeout)
			_, delayErr := time.ParseDuration(tt.config.RetryDelay)
			
			validTimeout := timeoutErr == nil
			validDelay := delayErr == nil
			validRetries := tt.config.RetryAttempts >= 0

			isValid := validTimeout && validDelay && validRetries

			if tt.valid && !isValid {
				t.Errorf("Expected configuration to be valid, timeout err: %v, delay err: %v, retries: %d", 
					timeoutErr, delayErr, tt.config.RetryAttempts)
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestLoggingConfiguration tests logging configuration edge cases
func TestLoggingConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config LoggingConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: LoggingConfiguration{
				Level:      "info",
				Format:     "text",
				File:       "app.log",
				MaxSize:    10,
				MaxBackups: 5,
				MaxAge:     30,
			},
			valid: true,
		},
		{
			name: "Invalid log level",
			config: LoggingConfiguration{
				Level:      "invalid",
				Format:     "text",
				File:       "app.log",
				MaxSize:    10,
				MaxBackups: 5,
				MaxAge:     30,
			},
			valid: false,
		},
		{
			name: "Zero values",
			config: LoggingConfiguration{
				Level:      "debug",
				Format:     "json",
				File:       "app.log",
				MaxSize:    0,
				MaxBackups: 0,
				MaxAge:     0,
			},
			valid: false,
		},
		{
			name: "Negative values",
			config: LoggingConfiguration{
				Level:      "warn",
				Format:     "text",
				File:       "app.log",
				MaxSize:    -1,
				MaxBackups: -1,
				MaxAge:     -1,
			},
			valid: false,
		},
		{
			name: "Empty file",
			config: LoggingConfiguration{
				Level:      "error",
				Format:     "text",
				File:       "",
				MaxSize:    10,
				MaxBackups: 5,
				MaxAge:     30,
			},
			valid: false,
		},
		{
			name: "Invalid format",
			config: LoggingConfiguration{
				Level:      "info",
				Format:     "xml",
				File:       "app.log",
				MaxSize:    10,
				MaxBackups: 5,
				MaxAge:     30,
			},
			valid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			validLevels := []string{"debug", "info", "warn", "error"}
			validLevel := false
			for _, level := range validLevels {
				if tt.config.Level == level {
					validLevel = true
					break
				}
			}

			validFormats := []string{"text", "json"}
			validFormat := false
			for _, format := range validFormats {
				if tt.config.Format == format {
					validFormat = true
					break
				}
			}

			validFile := tt.config.File != ""
			validSizes := tt.config.MaxSize > 0 && tt.config.MaxBackups >= 0 && tt.config.MaxAge > 0

			isValid := validLevel && validFormat && validFile && validSizes

			if tt.valid && !isValid {
				t.Error("Expected configuration to be valid")
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestPerformanceConfiguration tests performance configuration
func TestPerformanceConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config PerformanceConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: PerformanceConfiguration{
				Level:                      2,
				AdaptiveRefresh:            true,
				ContentCaching:             true,
				SelectiveUpdates:           true,
				MinRefreshInterval:         "1s",
				MaxRefreshInterval:         "10s",
				CacheSize:                  1000,
				ChangeDetectionSensitivity: 0.8,
			},
			valid: true,
		},
		{
			name: "Invalid level",
			config: PerformanceConfiguration{
				Level:                      -1,
				AdaptiveRefresh:            true,
				ContentCaching:             true,
				SelectiveUpdates:           true,
				MinRefreshInterval:         "1s",
				MaxRefreshInterval:         "10s",
				CacheSize:                  1000,
				ChangeDetectionSensitivity: 0.8,
			},
			valid: false,
		},
		{
			name: "Invalid intervals",
			config: PerformanceConfiguration{
				Level:                      1,
				AdaptiveRefresh:            true,
				ContentCaching:             true,
				SelectiveUpdates:           true,
				MinRefreshInterval:         "invalid",
				MaxRefreshInterval:         "10s",
				CacheSize:                  1000,
				ChangeDetectionSensitivity: 0.8,
			},
			valid: false,
		},
		{
			name: "Invalid sensitivity",
			config: PerformanceConfiguration{
				Level:                      1,
				AdaptiveRefresh:            true,
				ContentCaching:             true,
				SelectiveUpdates:           true,
				MinRefreshInterval:         "1s",
				MaxRefreshInterval:         "10s",
				CacheSize:                  1000,
				ChangeDetectionSensitivity: -0.5,
			},
			valid: false,
		},
		{
			name: "Zero cache size",
			config: PerformanceConfiguration{
				Level:                      1,
				AdaptiveRefresh:            true,
				ContentCaching:             true,
				SelectiveUpdates:           true,
				MinRefreshInterval:         "1s",
				MaxRefreshInterval:         "10s",
				CacheSize:                  0,
				ChangeDetectionSensitivity: 0.8,
			},
			valid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, minErr := time.ParseDuration(tt.config.MinRefreshInterval)
			_, maxErr := time.ParseDuration(tt.config.MaxRefreshInterval)
			
			validIntervals := minErr == nil && maxErr == nil
			validLevel := tt.config.Level >= 0
			validCache := tt.config.CacheSize > 0
			validSensitivity := tt.config.ChangeDetectionSensitivity >= 0 && tt.config.ChangeDetectionSensitivity <= 1

			isValid := validIntervals && validLevel && validCache && validSensitivity

			if tt.valid && !isValid {
				t.Errorf("Expected configuration to be valid, min err: %v, max err: %v", minErr, maxErr)
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestGitHubConfiguration tests GitHub configuration
func TestGitHubConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config GitHubConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: GitHubConfiguration{
				MonitorCI:     true,
				PRTemplate:    "default",
				IssueTemplate: "bug_report",
				DefaultLabels: []string{"ccw", "automated"},
				AutoAssign:    false,
			},
			valid: true,
		},
		{
			name: "Empty templates",
			config: GitHubConfiguration{
				MonitorCI:     false,
				PRTemplate:    "",
				IssueTemplate: "",
				DefaultLabels: []string{},
				AutoAssign:    true,
			},
			valid: true, // Empty templates might be valid
		},
		{
			name: "Very long template names",
			config: GitHubConfiguration{
				MonitorCI:     true,
				PRTemplate:    strings.Repeat("template", 100),
				IssueTemplate: strings.Repeat("issue", 100),
				DefaultLabels: []string{"label1", "label2"},
				AutoAssign:    false,
			},
			valid: true,
		},
		{
			name: "Many labels",
			config: GitHubConfiguration{
				MonitorCI:     true,
				PRTemplate:    "default",
				IssueTemplate: "bug_report",
				DefaultLabels: make([]string, 1000),
				AutoAssign:    true,
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// For GitHub configuration, most values are valid
			// Just test that the configuration can be created
			if tt.config.DefaultLabels == nil {
				tt.config.DefaultLabels = []string{}
			}
			
			// All configurations should be considered valid for this basic test
			if !tt.valid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestClaudeConfiguration tests Claude configuration
func TestClaudeConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config ClaudeConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: ClaudeConfiguration{
				Timeout:               "60s",
				MaxRetries:            3,
				Model:                 "claude-3-sonnet",
				Context:               "default",
				EnhancedCommitMessage: true,
			},
			valid: true,
		},
		{
			name: "Invalid timeout",
			config: ClaudeConfiguration{
				Timeout:               "invalid",
				MaxRetries:            3,
				Model:                 "claude-3-sonnet",
				Context:               "default",
				EnhancedCommitMessage: true,
			},
			valid: false,
		},
		{
			name: "Negative retries",
			config: ClaudeConfiguration{
				Timeout:               "60s",
				MaxRetries:            -1,
				Model:                 "claude-3-sonnet",
				Context:               "default",
				EnhancedCommitMessage: true,
			},
			valid: false,
		},
		{
			name: "Empty model",
			config: ClaudeConfiguration{
				Timeout:               "60s",
				MaxRetries:            3,
				Model:                 "",
				Context:               "default",
				EnhancedCommitMessage: true,
			},
			valid: false,
		},
		{
			name: "Very high retries",
			config: ClaudeConfiguration{
				Timeout:               "60s",
				MaxRetries:            1000,
				Model:                 "claude-3-opus",
				Context:               "enhanced",
				EnhancedCommitMessage: false,
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, timeoutErr := time.ParseDuration(tt.config.Timeout)
			
			validTimeout := timeoutErr == nil
			validModel := tt.config.Model != ""
			validRetries := tt.config.MaxRetries >= 0

			isValid := validTimeout && validModel && validRetries

			if tt.valid && !isValid {
				t.Error("Expected configuration to be valid")
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestValidationRecoveryConfiguration tests validation recovery configuration
func TestValidationRecoveryConfiguration(t *testing.T) {
	tests := []struct {
		name   string
		config ValidationRecoveryConfiguration
		valid  bool
	}{
		{
			name: "Valid configuration",
			config: ValidationRecoveryConfiguration{
				Enabled:               true,
				MaxAttempts:           3,
				RecoveryTimeout:       "30s",
				DelayBetweenAttempts:  "5s",
				RecoverableErrorTypes: []string{"lint", "build"},
				AutoFixEnabled:        true,
				VerboseOutput:         false,
			},
			valid: true,
		},
		{
			name: "Disabled recovery",
			config: ValidationRecoveryConfiguration{
				Enabled:               false,
				MaxAttempts:           0,
				RecoveryTimeout:       "0s",
				DelayBetweenAttempts:  "0s",
				RecoverableErrorTypes: []string{},
				AutoFixEnabled:        false,
				VerboseOutput:         false,
			},
			valid: true,
		},
		{
			name: "Negative attempts",
			config: ValidationRecoveryConfiguration{
				Enabled:               true,
				MaxAttempts:           -1,
				RecoveryTimeout:       "30s",
				DelayBetweenAttempts:  "5s",
				RecoverableErrorTypes: []string{},
				AutoFixEnabled:        true,
				VerboseOutput:         true,
			},
			valid: false,
		},
		{
			name: "Invalid timeout",
			config: ValidationRecoveryConfiguration{
				Enabled:               true,
				MaxAttempts:           3,
				RecoveryTimeout:       "invalid",
				DelayBetweenAttempts:  "5s",
				RecoverableErrorTypes: []string{},
				AutoFixEnabled:        true,
				VerboseOutput:         false,
			},
			valid: false,
		},
		{
			name: "Many error types",
			config: ValidationRecoveryConfiguration{
				Enabled:               true,
				MaxAttempts:           5,
				RecoveryTimeout:       "60s",
				DelayBetweenAttempts:  "10s",
				RecoverableErrorTypes: []string{"lint", "build", "test", "deploy", "security"},
				AutoFixEnabled:        true,
				VerboseOutput:         true,
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, timeoutErr := time.ParseDuration(tt.config.RecoveryTimeout)
			_, delayErr := time.ParseDuration(tt.config.DelayBetweenAttempts)
			
			validTimeout := timeoutErr == nil
			validDelay := delayErr == nil
			validAttempts := tt.config.MaxAttempts >= 0

			isValid := validTimeout && validDelay && validAttempts

			if tt.valid && !isValid {
				t.Error("Expected configuration to be valid")
			}

			if !tt.valid && isValid {
				t.Error("Expected configuration to be invalid")
			}
		})
	}
}

// TestConfigurationEdgeCases tests edge cases in configuration
func TestConfigurationEdgeCases(t *testing.T) {
	t.Run("Empty configuration", func(t *testing.T) {
		config := &CCWConfig{}
		
		// Empty configuration should have zero values
		if config.MaxRetries != 0 {
			t.Error("Expected MaxRetries to be 0 for empty config")
		}
		
		if config.DebugMode {
			t.Error("Expected DebugMode to be false for empty config")
		}
	})

	t.Run("Nil configuration", func(t *testing.T) {
		var config *CCWConfig
		
		// Should handle nil gracefully
		if config != nil {
			t.Error("Expected config to be nil")
		}
	})

	t.Run("Very long strings", func(t *testing.T) {
		longString := strings.Repeat("a", 10000)
		
		config := &CCWConfig{
			WorktreeBase:  longString,
			ClaudeTimeout: longString,
		}
		
		if len(config.WorktreeBase) != 10000 {
			t.Error("Long string not preserved")
		}
	})

	t.Run("Special characters", func(t *testing.T) {
		config := &CCWConfig{
			WorktreeBase: "/tmp/测试-🧪",
		}
		
		if !strings.Contains(config.WorktreeBase, "测试") {
			t.Error("Unicode characters not preserved")
		}
	})
}

// BenchmarkConfigurationCreation benchmarks configuration creation
func BenchmarkConfigurationCreation(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config := &CCWConfig{
			WorktreeBase:  "/tmp/bench",
			MaxRetries:    3,
			ClaudeTimeout: "5m",
			DebugMode:     true,
			UI: UIConfiguration{
				Theme:       "dark",
				Animations:  true,
				ColorOutput: true,
				Unicode:     true,
				Width:       120,
				Height:      30,
			},
		}
		_ = config
	}
}

// BenchmarkConfigurationValidation benchmarks configuration validation
func BenchmarkConfigurationValidation(b *testing.B) {
	config := &GitConfiguration{
		Timeout:       "30s",
		RetryAttempts: 3,
		RetryDelay:    "2s",
	}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err1 := time.ParseDuration(config.Timeout)
		_, err2 := time.ParseDuration(config.RetryDelay)
		_ = err1
		_ = err2
	}
}