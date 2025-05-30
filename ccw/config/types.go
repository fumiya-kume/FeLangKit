package config

import "time"

// Configuration type definitions

// CCWConfig represents the complete CCW configuration with YAML support
type CCWConfig struct {
	// Core settings
	WorktreeBase      string `yaml:"worktree_base" json:"worktree_base"`
	MaxRetries        int    `yaml:"max_retries" json:"max_retries"`
	ClaudeTimeout     string `yaml:"claude_timeout" json:"claude_timeout"`
	DebugMode         bool   `yaml:"debug_mode" json:"debug_mode"`
	
	// UI Configuration
	UI UIConfiguration `yaml:"ui" json:"ui"`
	
	// Git Configuration
	Git GitConfiguration `yaml:"git" json:"git"`
	
	// Logging Configuration
	Logging LoggingConfiguration `yaml:"logging" json:"logging"`
	
	// Performance Configuration
	Performance PerformanceConfiguration `yaml:"performance" json:"performance"`
	
	// GitHub Configuration
	GitHub GitHubConfiguration `yaml:"github" json:"github"`
	
	// Claude Configuration
	Claude ClaudeConfiguration `yaml:"claude" json:"claude"`
	
	// Validation Recovery Configuration
	ValidationRecovery ValidationRecoveryConfiguration `yaml:"validation_recovery" json:"validation_recovery"`
}

// UI Configuration
type UIConfiguration struct {
	Theme       string `yaml:"theme" json:"theme"`
	Animations  bool   `yaml:"animations" json:"animations"`
	ColorOutput bool   `yaml:"color_output" json:"color_output"`
	Unicode     bool   `yaml:"unicode" json:"unicode"`
	Width       int    `yaml:"width" json:"width"`
	Height      int    `yaml:"height" json:"height"`
}

// Git Configuration
type GitConfiguration struct {
	Timeout       string `yaml:"timeout" json:"timeout"`
	RetryAttempts int    `yaml:"retry_attempts" json:"retry_attempts"`
	RetryDelay    string `yaml:"retry_delay" json:"retry_delay"`
	DefaultBranch string `yaml:"default_branch" json:"default_branch"`
	RemoteName    string `yaml:"remote_name" json:"remote_name"`
}

// Logging Configuration
type LoggingConfiguration struct {
	Level      string `yaml:"level" json:"level"`
	Format     string `yaml:"format" json:"format"` // "text" or "json"
	File       string `yaml:"file" json:"file"`
	MaxSize    int    `yaml:"max_size" json:"max_size"`
	MaxBackups int    `yaml:"max_backups" json:"max_backups"`
	MaxAge     int    `yaml:"max_age" json:"max_age"`
}

// Performance Configuration  
type PerformanceConfiguration struct {
	Level                      int     `yaml:"level" json:"level"`
	AdaptiveRefresh            bool    `yaml:"adaptive_refresh" json:"adaptive_refresh"`
	ContentCaching             bool    `yaml:"content_caching" json:"content_caching"`
	SelectiveUpdates           bool    `yaml:"selective_updates" json:"selective_updates"`
	MinRefreshInterval         string  `yaml:"min_refresh_interval" json:"min_refresh_interval"`
	MaxRefreshInterval         string  `yaml:"max_refresh_interval" json:"max_refresh_interval"`
	CacheSize                  int     `yaml:"cache_size" json:"cache_size"`
	ChangeDetectionSensitivity float64 `yaml:"change_detection_sensitivity" json:"change_detection_sensitivity"`
}

// GitHub Configuration
type GitHubConfiguration struct {
	MonitorCI     bool     `yaml:"monitor_ci" json:"monitor_ci"`
	PRTemplate    string   `yaml:"pr_template" json:"pr_template"`
	IssueTemplate string   `yaml:"issue_template" json:"issue_template"`
	DefaultLabels []string `yaml:"default_labels" json:"default_labels"`
	AutoAssign    bool     `yaml:"auto_assign" json:"auto_assign"`
}

// Claude Configuration
type ClaudeConfiguration struct {
	Timeout               string `yaml:"timeout" json:"timeout"`
	MaxRetries            int    `yaml:"max_retries" json:"max_retries"`
	Model                 string `yaml:"model" json:"model"`
	Context               string `yaml:"context" json:"context"`
	EnhancedCommitMessage bool   `yaml:"enhanced_commit_message" json:"enhanced_commit_message"`
}

// Validation Recovery Configuration
type ValidationRecoveryConfiguration struct {
	Enabled               bool     `yaml:"enabled" json:"enabled"`
	MaxAttempts           int      `yaml:"max_attempts" json:"max_attempts"`
	RecoveryTimeout       string   `yaml:"recovery_timeout" json:"recovery_timeout"`
	DelayBetweenAttempts  string   `yaml:"delay_between_attempts" json:"delay_between_attempts"`
	RecoverableErrorTypes []string `yaml:"recoverable_error_types" json:"recoverable_error_types"`
	AutoFixEnabled        bool     `yaml:"auto_fix_enabled" json:"auto_fix_enabled"`
	VerboseOutput         bool     `yaml:"verbose_output" json:"verbose_output"`
}

// Legacy Config struct for backward compatibility
type Config struct {
	WorktreeBase         string                     `json:"worktree_base"`
	MaxRetries           int                        `json:"max_retries"`
	ClaudeTimeout        string                     `json:"claude_timeout"`
	DebugMode            bool                       `json:"debug_mode"`
	ThemeName            string                     `json:"theme_name"`
	AnimationsEnabled    bool                       `json:"animations_enabled"`
	GitTimeout           string                     `json:"git_timeout,omitempty"`
	GitRetryAttempts     int                        `json:"git_retry_attempts,omitempty"`
	PerformanceConfig    *PerformanceConfigLegacy  `json:"performance_config,omitempty"`
}

// Legacy performance config for backward compatibility
type PerformanceConfigLegacy struct {
	EnableAdaptiveRefresh      bool
	EnableContentCaching       bool
	EnableSelectiveUpdates     bool
	MinRefreshInterval         time.Duration
	MaxRefreshInterval         time.Duration
	CacheSize                  int
	CacheTTL                   time.Duration
	OptimizationLevel          int
	DebounceThreshold          time.Duration
	ChangeDetectionSensitivity float64
}