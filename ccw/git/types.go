package git

import (
	"fmt"
	"time"
)

// Git operation types and configurations

// GitOperationConfig holds configuration for git operations
type GitOperationConfig struct {
	Timeout       time.Duration
	RetryAttempts int
	RetryDelay    time.Duration
}

// Operations manages git operations with timeout and retry configuration
type Operations struct {
	basePath  string
	config    *GitOperationConfig
	appConfig interface{} // Keep interface{} for flexibility
}

// WorktreeConfig represents configuration for git worktree operations
type WorktreeConfig struct {
	BasePath     string    `json:"base_path"`
	BranchName   string    `json:"branch_name"`
	WorktreePath string    `json:"worktree_path"`
	IssueNumber  int       `json:"issue_number"`
	CreatedAt    time.Time `json:"created_at"`
	Owner        string    `json:"owner"`
	Repository   string    `json:"repository"`
	IssueURL     string    `json:"issue_url"`
}

// ValidationResult represents the result of code quality validation
type ValidationResult struct {
	Success     bool              `json:"success"`
	LintResult  *LintResult       `json:"lint_result,omitempty"`
	BuildResult *BuildResult      `json:"build_result,omitempty"`
	TestResult  *TestResult       `json:"test_result,omitempty"`
	Errors      []ValidationError `json:"errors,omitempty"`
	Duration    time.Duration     `json:"duration"`
	Timestamp   time.Time         `json:"timestamp"`
}

// LintResult represents SwiftLint execution results
type LintResult struct {
	Success   bool     `json:"success"`
	Output    string   `json:"output"`
	Errors    []string `json:"errors"`
	Warnings  []string `json:"warnings"`
	AutoFixed bool     `json:"auto_fixed"`
}

// BuildResult represents Swift build results
type BuildResult struct {
	Success bool   `json:"success"`
	Output  string `json:"output"`
	Error   string `json:"error"`
}

// TestResult represents Swift test execution results
type TestResult struct {
	Success   bool   `json:"success"`
	Output    string `json:"output"`
	TestCount int    `json:"test_count"`
	Passed    int    `json:"passed"`
	Failed    int    `json:"failed"`
}

// ValidationError represents a validation error
type ValidationError struct {
	Type        string `json:"type"`
	Message     string `json:"message"`
	File        string `json:"file,omitempty"`
	Line        int    `json:"line,omitempty"`
	Recoverable bool   `json:"recoverable"`
}

// QualityValidator handles code quality validation
type QualityValidator struct {
	swiftlintEnabled bool
	buildEnabled     bool
	testsEnabled     bool
}

// Issue represents a GitHub issue (minimal definition for git package)
type Issue struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	Body   string `json:"body"`
}

// CommitMessageGenerator handles AI-powered commit message generation
type CommitMessageGenerator struct {
	claudeIntegration interface{}
	config           interface{}
}

// GenerateEnhancedCommitMessage creates an AI-powered commit message
func (cmg *CommitMessageGenerator) GenerateEnhancedCommitMessage(worktreePath string, issue *Issue) (string, error) {
	// For now, return a simple commit message
	// TODO: Implement AI-powered commit message generation
	return fmt.Sprintf("feat: implement solution for issue #%d\n\n%s\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>", 
		issue.Number, issue.Title), nil
}

// ChangePattern represents detected patterns in code changes
type ChangePattern struct {
	Type        string   `json:"type"`
	Description string   `json:"description"`
	Confidence  float64  `json:"confidence"`
	Files       []string `json:"files"`
}

// CommitAnalysis contains information about changes for commit message generation
type CommitAnalysis struct {
	ModifiedFiles   []string            `json:"modified_files"`
	AddedFiles      []string            `json:"added_files"`
	DeletedFiles    []string            `json:"deleted_files"`
	DiffSummary     string              `json:"diff_summary"`
	FileTypes       map[string]int      `json:"file_types"`
	ChangeCategory  string              `json:"change_category"`
	Scope           string              `json:"scope"`
	IssueContext    *Issue              `json:"issue_context,omitempty"`
	ChangePatterns  []ChangePattern     `json:"change_patterns"`
	CommitMetadata  CommitMetadata      `json:"commit_metadata"`
}

// CommitMetadata contains additional context for commit generation
type CommitMetadata struct {
	Author        string    `json:"author"`
	Timestamp     time.Time `json:"timestamp"`
	BranchName    string    `json:"branch_name"`
	IssueNumber   int       `json:"issue_number,omitempty"`
	WorktreePath  string    `json:"worktree_path"`
}