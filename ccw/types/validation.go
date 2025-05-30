package types

import (
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
	Type        string `json:"type"`
	Message     string `json:"message"`
	File        string `json:"file,omitempty"`
	Line        int    `json:"line,omitempty"`
	Recoverable bool   `json:"recoverable"`
}