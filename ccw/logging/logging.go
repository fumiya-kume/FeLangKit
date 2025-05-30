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

// Initialize logger
func NewLogger(sessionID string, enableFile bool) (*types.Logger, error) {
	logger := &types.Logger{
		logLevel:   types.LogLevelInfo,
		sessionID:  sessionID,
		enableFile: enableFile,
		enableJSON: os.Getenv("CCW_LOG_JSON") == "true",
	}

	// Set log level from environment
	if level := os.Getenv("CCW_LOG_LEVEL"); level != "" {
		switch level {
		case "debug":
			logger.logLevel = LogLevelDebug
		case "info":
			logger.logLevel = LogLevelInfo
		case "warn":
			logger.logLevel = LogLevelWarn
		case "error":
			logger.logLevel = LogLevelError
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
	l.log(LogLevelDebug, component, message, context...)
}

func (l *Logger) Info(component, message string, context ...map[string]interface{}) {
	l.log(LogLevelInfo, component, message, context...)
}

func (l *Logger) Warn(component, message string, context ...map[string]interface{}) {
	l.log(LogLevelWarn, component, message, context...)
}

func (l *Logger) Error(component, message string, context ...map[string]interface{}) {
	l.log(LogLevelError, component, message, context...)
}

func (l *Logger) Fatal(component, message string, context ...map[string]interface{}) {
	l.log(LogLevelFatal, component, message, context...)
}

// Core logging method
func (l *Logger) log(level LogLevel, component, message string, context ...map[string]interface{}) {
	if level < l.logLevel {
		return
	}

	entry := LogEntry{
		Timestamp: time.Now(),
		Level:     l.levelToString(level),
		Message:   message,
		SessionID: l.sessionID,
		Component: component,
	}

	if len(context) > 0 {
		entry.Context = context[0]
	}

	// Console output
	l.outputToConsole(entry)

	// File output
	if l.logFile != nil {
		l.outputToFile(entry)
	}
}

// Convert log level to string
func (l *Logger) levelToString(level LogLevel) string {
	switch level {
	case LogLevelDebug:
		return "DEBUG"
	case LogLevelInfo:
		return "INFO"
	case LogLevelWarn:
		return "WARN"
	case LogLevelError:
		return "ERROR"
	case LogLevelFatal:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// Output to console
func (l *Logger) outputToConsole(entry LogEntry) {
	if l.enableJSON {
		if data, err := json.Marshal(entry); err == nil {
			fmt.Println(string(data))
		}
	} else {
		// Human-readable format
		timestamp := entry.Timestamp.Format("15:04:05")
		if entry.Component != "" {
			fmt.Printf("[%s] %s [%s] %s\n", timestamp, entry.Level, entry.Component, entry.Message)
		} else {
			fmt.Printf("[%s] %s %s\n", timestamp, entry.Level, entry.Message)
		}
	}
}

// Output to file
func (l *Logger) outputToFile(entry LogEntry) {
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}
	
	l.logFile.WriteString(string(data) + "\n")
}

// Initialize error store
func NewErrorStore(sessionID string) (*ErrorStore, error) {
	errorDir := filepath.Join(".", ".ccw", "errors")
	if err := os.MkdirAll(errorDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create error directory: %w", err)
	}

	errorFile := filepath.Join(errorDir, fmt.Sprintf("errors-%s.json", sessionID))
	
	store := &ErrorStore{
		filePath:  errorFile,
		errors:    make([]PersistedError, 0),
		maxErrors: 100, // Keep last 100 errors
	}

	// Load existing errors
	store.loadErrors()

	return store, nil
}

// Persist error
func (es *ErrorStore) PersistError(sessionID, errorType, message, component string, context map[string]interface{}) string {
	errorID := fmt.Sprintf("%s-%d", sessionID, time.Now().Unix())
	
	persistedError := PersistedError{
		ID:        errorID,
		Timestamp: time.Now(),
		SessionID: sessionID,
		ErrorType: errorType,
		Message:   message,
		Component: component,
		Context:   context,
		Resolved:  false,
	}

	if ctx, ok := context["issue_number"]; ok {
		if issueNum, ok := ctx.(int); ok {
			persistedError.IssueNumber = issueNum
		}
	}

	if ctx, ok := context["worktree_path"]; ok {
		if path, ok := ctx.(string); ok {
			persistedError.WorktreePath = path
		}
	}

	es.errors = append(es.errors, persistedError)

	// Limit stored errors
	if len(es.errors) > es.maxErrors {
		es.errors = es.errors[len(es.errors)-es.maxErrors:]
	}

	es.saveErrors()
	return errorID
}

// Mark error as resolved
func (es *ErrorStore) ResolveError(errorID string) error {
	for i, err := range es.errors {
		if err.ID == errorID {
			es.errors[i].Resolved = true
			es.saveErrors()
			return nil
		}
	}
	return fmt.Errorf("error with ID %s not found", errorID)
}

// Get unresolved errors for context
func (es *ErrorStore) GetUnresolvedErrors(sessionID string, issueNumber int) []PersistedError {
	var unresolved []PersistedError
	
	for _, err := range es.errors {
		if !err.Resolved && err.SessionID == sessionID && err.IssueNumber == issueNumber {
			unresolved = append(unresolved, err)
		}
	}
	
	return unresolved
}

// Load errors from file
func (es *ErrorStore) loadErrors() error {
	data, err := os.ReadFile(es.filePath)
	if err != nil {
		// File doesn't exist yet, that's okay
		return nil
	}

	return json.Unmarshal(data, &es.errors)
}

// Save errors to file
func (es *ErrorStore) saveErrors() error {
	data, err := json.MarshalIndent(es.errors, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(es.filePath, data, 0644)
}

// Cleanup old errors
func (es *ErrorStore) CleanupOldErrors(maxAge time.Duration) {
	cutoff := time.Now().Add(-maxAge)
	
	filtered := make([]PersistedError, 0)
	for _, err := range es.errors {
		if err.Timestamp.After(cutoff) {
			filtered = append(filtered, err)
		}
	}
	
	es.errors = filtered
	es.saveErrors()
}

// Get error statistics
func (es *ErrorStore) GetErrorStats() map[string]int {
	stats := map[string]int{
		"total":      len(es.errors),
		"resolved":   0,
		"unresolved": 0,
	}

	typeStats := make(map[string]int)
	
	for _, err := range es.errors {
		typeStats[err.ErrorType]++
		if err.Resolved {
			stats["resolved"]++
		} else {
			stats["unresolved"]++
		}
	}

	// Add type-specific stats
	for errType, count := range typeStats {
		stats[errType] = count
	}

	return stats
}