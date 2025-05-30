package types

import (
	"time"
)

// Workflow and configuration types

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

type ClaudeContext struct {
	IssueData        *Issue                     `json:"issue_data"`
	WorktreeConfig   *WorktreeConfig           `json:"worktree_config"`
	ProjectPath      string                     `json:"project_path"`
	ValidationErrors []ValidationError         `json:"validation_errors,omitempty"`
	IsRetry          bool                      `json:"is_retry"`
	RetryAttempt     int                       `json:"retry_attempt"`
	TaskType         string                    `json:"task_type"` // "implementation" or "pr_description"
}

type PRDescriptionRequest struct {
	Issue                 *Issue            `json:"issue"`
	WorktreeConfig        *WorktreeConfig   `json:"worktree_config"`
	ValidationResult      *ValidationResult `json:"validation_result"`
	ImplementationSummary string            `json:"implementation_summary"`
}

type Config struct {
	WorktreeBase         string             `json:"worktree_base"`
	MaxRetries           int                `json:"max_retries"`
	ClaudeTimeout        string             `json:"claude_timeout"`
	DebugMode            bool               `json:"debug_mode"`
	ThemeName            string             `json:"theme_name"`
	AnimationsEnabled    bool               `json:"animations_enabled"`
	PerformanceConfig    *PerformanceConfig `json:"performance_config,omitempty"`
	GitTimeout           string             `json:"git_timeout,omitempty"`
	GitRetryAttempts     int                `json:"git_retry_attempts,omitempty"`
}

// Workflow and progress tracking models
type WorkflowStep struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Status      string `json:"status"` // "pending", "in_progress", "completed", "failed"
	StartTime   time.Time
	EndTime     time.Time
}

type ProgressTracker struct {
	Steps       []WorkflowStep `json:"steps"`
	CurrentStep int            `json:"current_step"`
	StartTime   time.Time      `json:"start_time"`
	TotalSteps  int            `json:"total_steps"`
}