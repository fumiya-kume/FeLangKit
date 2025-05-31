package pr

import (
	"strconv"
	"time"
)

// PRManager handles pull request operations with async support
type PRManager struct {
	timeout    time.Duration
	maxRetries int
	debugMode  bool
}

// NewPRManager creates a new PR manager instance
func NewPRManager(timeout time.Duration, maxRetries int, debugMode bool) *PRManager {
	return &PRManager{
		timeout:    timeout,
		maxRetries: maxRetries,
		debugMode:  debugMode,
	}
}

// Helper function to safely parse integers
func parseInt(s string) int {
	if result, err := strconv.Atoi(s); err == nil {
		return result
	}

	// Fallback to manual parsing
	result := 0
	for _, char := range s {
		if char >= '0' && char <= '9' {
			result = result*10 + int(char-'0')
		}
	}
	return result
}
