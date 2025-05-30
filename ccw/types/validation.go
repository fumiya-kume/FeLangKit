package types

import (
	"fmt"
	"os/exec"
	"time"
)

// Validation result models

type ValidationResult struct {
	Success     bool              `json:"success"`
	LintResult  *LintResult       `json:"lint_result,omitempty"`
	BuildResult *BuildResult      `json:"build_result,omitempty"`
	TestResult  *TestResult       `json:"test_result,omitempty"`
	Errors      []ValidationError `json:"errors,omitempty"`
	Duration    time.Duration     `json:"duration"`
	Timestamp   time.Time         `json:"timestamp"`
}

type LintResult struct {
	Success   bool     `json:"success"`
	Output    string   `json:"output"`
	Errors    []string `json:"errors"`
	Warnings  []string `json:"warnings"`
	AutoFixed bool     `json:"auto_fixed"`
}

type BuildResult struct {
	Success bool   `json:"success"`
	Output  string `json:"output"`
	Error   string `json:"error"`
}

type TestResult struct {
	Success   bool   `json:"success"`
	Output    string `json:"output"`
	TestCount int    `json:"test_count"`
	Passed    int    `json:"passed"`
	Failed    int    `json:"failed"`
}

type ValidationError struct {
	Type        string      `json:"type"`
	Message     string      `json:"message"`
	File        string      `json:"file,omitempty"`
	Line        int         `json:"line,omitempty"`
	Recoverable bool        `json:"recoverable"`
	Cause       *ErrorCause `json:"cause,omitempty"`
}

type ErrorCause struct {
	RootError     string            `json:"root_error"`
	Command       string            `json:"command,omitempty"`
	ExitCode      int               `json:"exit_code,omitempty"`
	Stderr        string            `json:"stderr,omitempty"`
	Stdout        string            `json:"stdout,omitempty"`
	Context       map[string]string `json:"context,omitempty"`
	OriginalError error             `json:"-"` // Not serialized to JSON
}

// NewValidationErrorWithCause creates a ValidationError with detailed cause information
func NewValidationErrorWithCause(errorType, message string, err error, recoverable bool) ValidationError {
	validationErr := ValidationError{
		Type:        errorType,
		Message:     message,
		Recoverable: recoverable,
	}

	if err != nil {
		cause := &ErrorCause{
			RootError: err.Error(),
			Context:   make(map[string]string),
		}

		// Extract additional context from exec.ExitError
		if exitErr, ok := err.(*exec.ExitError); ok {
			cause.ExitCode = exitErr.ExitCode()
			cause.Stderr = string(exitErr.Stderr)
		}

		validationErr.Cause = cause
	}

	return validationErr
}

// NewCommandValidationError creates a ValidationError for command execution failures
func NewCommandValidationError(errorType, message, command string, err error, stdout, stderr string, recoverable bool) ValidationError {
	validationErr := ValidationError{
		Type:        errorType,
		Message:     message,
		Recoverable: recoverable,
	}

	cause := &ErrorCause{
		Command: command,
		Stdout:  stdout,
		Stderr:  stderr,
		Context: make(map[string]string),
	}

	if err != nil {
		cause.RootError = err.Error()
		if exitErr, ok := err.(*exec.ExitError); ok {
			cause.ExitCode = exitErr.ExitCode()
		}
	}

	validationErr.Cause = cause
	return validationErr
}

// AddContext adds contextual information to the error cause
func (ve *ValidationError) AddContext(key, value string) {
	if ve.Cause == nil {
		ve.Cause = &ErrorCause{
			Context: make(map[string]string),
		}
	}
	if ve.Cause.Context == nil {
		ve.Cause.Context = make(map[string]string)
	}
	ve.Cause.Context[key] = value
}

// GetDetailedError returns a formatted error message with cause information
func (ve *ValidationError) GetDetailedError() string {
	if ve.Cause == nil {
		return ve.Message
	}

	result := ve.Message
	if ve.Cause.RootError != "" {
		result += fmt.Sprintf("\nRoot cause: %s", ve.Cause.RootError)
	}
	if ve.Cause.Command != "" {
		result += fmt.Sprintf("\nCommand: %s", ve.Cause.Command)
	}
	if ve.Cause.ExitCode != 0 {
		result += fmt.Sprintf("\nExit code: %d", ve.Cause.ExitCode)
	}
	if ve.Cause.Stderr != "" {
		result += fmt.Sprintf("\nStderr: %s", ve.Cause.Stderr)
	}
	if len(ve.Cause.Context) > 0 {
		result += "\nContext:"
		for key, value := range ve.Cause.Context {
			result += fmt.Sprintf("\n  %s: %s", key, value)
		}
	}
	return result
}
