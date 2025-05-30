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
	Status        string
	Checks        []CheckRun
	LastUpdated   time.Time
	URL           string
	Conclusion    string
	TotalChecks   int
	PassedChecks  int
	FailedChecks  int
	PendingChecks int
}

type CheckRun struct {
	Name        string    `json:"name"`
	Status      string    `json:"status"`
	Conclusion  string    `json:"conclusion"`
	URL         string    `json:"html_url"`
	StartedAt   time.Time `json:"started_at"`
	CompletedAt time.Time `json:"completed_at"`
	DetailsURL  string    `json:"details_url,omitempty"`
	Summary     string    `json:"summary,omitempty"`
	Text        string    `json:"text,omitempty"`
}

// Enhanced CI monitoring types for real-time updates
type CIWatchUpdate struct {
	Status      *CIStatus
	CheckUpdate *CheckRun
	EventType   string // "status_change", "check_complete", "all_complete", "failure"
	Message     string
	Timestamp   time.Time
}

type CIWatchResult struct {
	FinalStatus *CIStatus
	Updates     []CIWatchUpdate
	Error       error
	Duration    time.Duration
}

// CI failure types for recovery mechanisms
type CIFailureType string

const (
	CIFailureBuild   CIFailureType = "build"
	CIFailureLint    CIFailureType = "lint"
	CIFailureTest    CIFailureType = "test"
	CIFailureUnknown CIFailureType = "unknown"
)

type CIFailureInfo struct {
	Type        CIFailureType
	CheckName   string
	FailureText string
	DetailsURL  string
	Recoverable bool
}
