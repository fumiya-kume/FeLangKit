package logging

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"ccw/types"
)

// Logging and error handling functionality

// UI integration variables
var (
	uiLogFunc    func(types.LogEntry) // Function to send logs to UI
	uiModeActive bool                 // Whether UI mode is active
)

// Logger wraps the types.Logger and provides implementation
type Logger struct {
	logLevel   types.LogLevel
	logFile    *os.File
	sessionID  string
	enableFile bool
	enableJSON bool
}

// Initialize logger
func NewLogger(sessionID string, enableFile bool) (*Logger, error) {
	logger := &Logger{
		logLevel:   types.LogLevelInfo,
		sessionID:  sessionID,
		enableFile: enableFile,
		enableJSON: os.Getenv("CCW_LOG_JSON") == "true",
	}

	// Set log level from environment
	if level := os.Getenv("CCW_LOG_LEVEL"); level != "" {
		switch level {
		case "debug":
			logger.logLevel = types.LogLevelDebug
		case "info":
			logger.logLevel = types.LogLevelInfo
		case "warn":
			logger.logLevel = types.LogLevelWarn
		case "error":
			logger.logLevel = types.LogLevelError
		}
	}

	// Initialize file logging if enabled
	if enableFile {
		logDir := filepath.Join(".", ".ccw", "logs")
		if err := os.MkdirAll(logDir, 0755); err != nil {
			return nil, fmt.Errorf("failed to create log directory: %w", err)
		}

		logFileName := fmt.Sprintf("ccw-%s.log", sessionID)
		logFilePath := filepath.Join(logDir, logFileName)

		file, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return nil, fmt.Errorf("failed to open log file: %w", err)
		}
		logger.logFile = file
	}

	return logger, nil
}

// Close logger
func (l *Logger) Close() error {
	if l.logFile != nil {
		return l.logFile.Close()
	}
	return nil
}

// Log methods
func (l *Logger) Debug(component, message string, context ...map[string]interface{}) {
	l.log(types.LogLevelDebug, component, message, context...)
}

func (l *Logger) Info(component, message string, context ...map[string]interface{}) {
	l.log(types.LogLevelInfo, component, message, context...)
}

func (l *Logger) Warn(component, message string, context ...map[string]interface{}) {
	l.log(types.LogLevelWarn, component, message, context...)
}

func (l *Logger) Error(component, message string, context ...map[string]interface{}) {
	l.log(types.LogLevelError, component, message, context...)
}

func (l *Logger) Fatal(component, message string, context ...map[string]interface{}) {
	l.log(types.LogLevelFatal, component, message, context...)
}

// Core logging method
func (l *Logger) log(level types.LogLevel, component, message string, context ...map[string]interface{}) {
	if level < l.logLevel {
		return
	}

	entry := types.LogEntry{
		Timestamp: time.Now(),
		Level:     l.levelToString(level),
		Message:   message,
		SessionID: l.sessionID,
		Component: component,
	}

	if len(context) > 0 {
		entry.Context = context[0]
	}

	// Output to console
	l.outputToConsole(entry)

	// Output to file if enabled
	if l.enableFile && l.logFile != nil {
		l.outputToFile(entry)
	}
}

// Convert log level to string
func (l *Logger) levelToString(level types.LogLevel) string {
	switch level {
	case types.LogLevelDebug:
		return "DEBUG"
	case types.LogLevelInfo:
		return "INFO"
	case types.LogLevelWarn:
		return "WARN"
	case types.LogLevelError:
		return "ERROR"
	case types.LogLevelFatal:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// Output log entry to console
func (l *Logger) outputToConsole(entry types.LogEntry) {
	// Send to UI buffer if available (this will be set up via an interface)
	if uiLogFunc != nil {
		uiLogFunc(entry)
	}

	// Also output to console (can be disabled when UI is active)
	if !uiModeActive {
		if l.enableJSON {
			if jsonData, err := json.Marshal(entry); err == nil {
				fmt.Println(string(jsonData))
			}
		} else {
			timestamp := entry.Timestamp.Format("2006-01-02 15:04:05")
			fmt.Printf("[%s] %s [%s] %s: %s\n",
				timestamp, entry.Level, entry.Component, entry.SessionID, entry.Message)
		}
	}
}

// Output log entry to file
func (l *Logger) outputToFile(entry types.LogEntry) {
	if l.logFile == nil {
		return
	}

	var output string
	if l.enableJSON {
		if jsonData, err := json.Marshal(entry); err == nil {
			output = string(jsonData) + "\n"
		}
	} else {
		timestamp := entry.Timestamp.Format("2006-01-02 15:04:05")
		output = fmt.Sprintf("[%s] %s [%s] %s: %s\n",
			timestamp, entry.Level, entry.Component, entry.SessionID, entry.Message)
	}

	l.logFile.WriteString(output)
}

// Error persistence functionality

// Create error store
func NewErrorStore(filePath string, maxErrors int) *types.ErrorStore {
	return &types.ErrorStore{
		// Note: types.ErrorStore fields are private, so this is a placeholder
		// We would need to implement error store functionality here
	}
}

// Persist error to store
func (l *Logger) PersistError(errorType, message, component string, issueNumber int, worktreePath string, context map[string]interface{}) error {
	// Implementation would go here for error persistence
	// For now, just log the error
	l.Error(component, fmt.Sprintf("%s: %s", errorType, message), context)
	return nil
}

// UI Integration functions

// SetUILogFunction sets the function to send logs to the UI
func SetUILogFunction(fn func(types.LogEntry)) {
	uiLogFunc = fn
}

// SetUIMode enables or disables UI mode
func SetUIMode(active bool) {
	uiModeActive = active
}

// IsUIMode returns whether UI mode is active
func IsUIMode() bool {
	return uiModeActive
}
