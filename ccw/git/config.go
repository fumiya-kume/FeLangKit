package git

import (
	"time"
)

// Git configuration management

// GetDefaultGitConfig returns default git operation configuration
func GetDefaultGitConfig() *GitOperationConfig {
	return &GitOperationConfig{
		Timeout:       30 * time.Second,  // 30 second timeout for git operations
		RetryAttempts: 3,                 // Retry failed operations up to 3 times
		RetryDelay:    2 * time.Second,   // Wait 2 seconds between retries
	}
}

// NewOperations creates a new git operations manager
func NewOperations(basePath string, config *GitOperationConfig, appConfig interface{}) *Operations {
	if config == nil {
		config = GetDefaultGitConfig()
	}
	
	return &Operations{
		basePath:  basePath,
		config:    config,
		appConfig: appConfig,
	}
}

// GetTimeout returns the configured timeout or default
func (g *Operations) GetTimeout() time.Duration {
	if g.config != nil {
		return g.config.Timeout
	}
	return 30 * time.Second // default timeout
}

// GetRetryAttempts returns the configured retry attempts
func (g *Operations) GetRetryAttempts() int {
	if g.config != nil {
		return g.config.RetryAttempts
	}
	return 3 // default retry attempts
}

// GetRetryDelay returns the configured retry delay
func (g *Operations) GetRetryDelay() time.Duration {
	if g.config != nil {
		return g.config.RetryDelay
	}
	return 2 * time.Second // default retry delay
}

// NewQualityValidator creates a new quality validator
func NewQualityValidator() *QualityValidator {
	return &QualityValidator{
		swiftlintEnabled: true,
		buildEnabled:     true,
		testsEnabled:     true,
	}
}

// NewCommitMessageGenerator creates a new commit message generator
func NewCommitMessageGenerator(claudeIntegration interface{}, config interface{}) *CommitMessageGenerator {
	return &CommitMessageGenerator{
		claudeIntegration: claudeIntegration,
		config:           config,
	}
}