package claude

import (
	"time"
)

// ClaudeIntegration handles Claude Code integration
type ClaudeIntegration struct {
	Timeout    time.Duration
	MaxRetries int
	DebugMode  bool
}

// NewClaudeIntegration creates a new Claude integration instance
func NewClaudeIntegration(timeout time.Duration, maxRetries int, debugMode bool) *ClaudeIntegration {
	return &ClaudeIntegration{
		Timeout:    timeout,
		MaxRetries: maxRetries,
		DebugMode:  debugMode,
	}
}