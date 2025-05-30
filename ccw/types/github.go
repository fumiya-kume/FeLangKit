package types

import (
	"time"
)

// GitHub-related data models

type Issue struct {
	Number     int                    `json:"number"`
	Title      string                 `json:"title"`
	Body       string                 `json:"body"`
	State      string                 `json:"state"`
	URL        string                 `json:"url"`
	HTMLURL    string                 `json:"html_url"`
	Labels     []Label                `json:"labels"`
	Assignees  []User                 `json:"assignees"`
	CreatedAt  time.Time              `json:"created_at"`
	UpdatedAt  time.Time              `json:"updated_at"`
	Repository Repository             `json:"repository"`
	Metadata   map[string]interface{} `json:"metadata"`
}

type Label struct {
	Name  string `json:"name"`
	Color string `json:"color"`
}

type User struct {
	Login string `json:"login"`
	URL   string `json:"url"`
}

type Repository struct {
	Name     string `json:"name"`
	FullName string `json:"full_name"`
	Owner    User   `json:"owner"`
}

type PRRequest struct {
	Title               string `json:"title"`
	Body                string `json:"body"`
	Head                string `json:"head"`
	Base                string `json:"base"`
	MaintainerCanModify bool   `json:"maintainer_can_modify"`
}

type PullRequest struct {
	Number  int    `json:"number"`
	URL     string `json:"url"`
	HTMLURL string `json:"html_url"`
	State   string `json:"state"`
}

// CI monitoring models
type CIStatus struct {
	Status         string               `json:"status"`
	Checks         []CheckRun           `json:"checks"`
	LastUpdated    time.Time            `json:"last_updated"`
	URL            string               `json:"url"`
	Conclusion     string               `json:"conclusion"`
	TotalChecks    int                  `json:"total_checks"`
	PassingChecks  int                  `json:"passing_checks"`
	FailingChecks  int                  `json:"failing_checks"`
	PendingChecks  int                  `json:"pending_checks"`
	ChecksSummary  map[string]int       `json:"checks_summary"`
	FailureDetails []CheckFailureDetail `json:"failure_details"`
}

type CheckRun struct {
	Name        string    `json:"name"`
	Status      string    `json:"status"`
	Conclusion  string    `json:"conclusion"`
	URL         string    `json:"html_url"`
	StartedAt   time.Time `json:"started_at"`
	CompletedAt time.Time `json:"completed_at"`
	Output      string    `json:"output"`
	Summary     string    `json:"summary"`
}

type CheckFailureDetail struct {
	CheckName string `json:"check_name"`
	FailType  string `json:"fail_type"` // "build", "lint", "test", "other"
	Message   string `json:"message"`
	URL       string `json:"url"`
}

// CI monitoring channels and goroutine communication
type CIWatchUpdate struct {
	Status    *CIStatus `json:"status"`
	Error     error     `json:"error"`
	Completed bool      `json:"completed"`
	Message   string    `json:"message"`
}

type CIWatchRequest struct {
	PRURL           string        `json:"pr_url"`
	PRNumber        int           `json:"pr_number"`
	WorktreePath    string        `json:"worktree_path"`
	BranchName      string        `json:"branch_name"`
	MaxWaitTime     time.Duration `json:"max_wait_time"`
	UpdateInterval  time.Duration `json:"update_interval"`
	EnableRecovery  bool          `json:"enable_recovery"`
	RecoveryAttempts int          `json:"recovery_attempts"`
}