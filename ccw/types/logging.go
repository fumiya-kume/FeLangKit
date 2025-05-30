package types

import (
	"os"
	"time"
)

// Logging types

type LogLevel int

const (
	LogLevelDebug LogLevel = iota
	LogLevelInfo
	LogLevelWarn
	LogLevelError
	LogLevelFatal
)

// Logger structure
type Logger struct {
	logLevel   LogLevel
	logFile    *os.File
	sessionID  string
	enableFile bool
	enableJSON bool
}

// Log entry structure
type LogEntry struct {
	Timestamp time.Time              `json:"timestamp"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	SessionID string                 `json:"session_id"`
	Component string                 `json:"component"`
	Context   map[string]interface{} `json:"context,omitempty"`
}

// Error store for persistence
type ErrorStore struct {
	filePath  string
	errors    []PersistedError
	maxErrors int
}

// Persisted error structure
type PersistedError struct {
	ID           string                 `json:"id"`
	Timestamp    time.Time              `json:"timestamp"`
	SessionID    string                 `json:"session_id"`
	ErrorType    string                 `json:"error_type"`
	Message      string                 `json:"message"`
	Component    string                 `json:"component"`
	Context      map[string]interface{} `json:"context,omitempty"`
	IssueNumber  int                    `json:"issue_number,omitempty"`
	WorktreePath string                 `json:"worktree_path,omitempty"`
	Resolved     bool                   `json:"resolved"`
}
