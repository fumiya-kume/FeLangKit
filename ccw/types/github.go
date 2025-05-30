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
	Status      string
	Checks      []CheckRun
	LastUpdated time.Time
	URL         string
	Conclusion  string
}

type CheckRun struct {
	Name        string    `json:"name"`
	Status      string    `json:"status"`
	Conclusion  string    `json:"conclusion"`
	URL         string    `json:"html_url"`
	StartedAt   time.Time `json:"started_at"`
	CompletedAt time.Time `json:"completed_at"`
}

// Enhanced CI monitoring types for Goroutine-based implementation
type CIWatchStatus struct {
	PRURL       string          `json:"pr_url"`
	Status      string          `json:"status"`
	Conclusion  string          `json:"conclusion"`
	Checks      []CheckRunWatch `json:"checks"`
	LastUpdated time.Time       `json:"last_updated"`
	IsCompleted bool            `json:"is_completed"`
	IsFailed    bool            `json:"is_failed"`
}

type CheckRunWatch struct {
	Name        string    `json:"name"`
	Status      string    `json:"status"`
	Conclusion  string    `json:"conclusion"`
	URL         string    `json:"html_url"`
	StartedAt   time.Time `json:"started_at"`
	CompletedAt time.Time `json:"completed_at"`
	Duration    string    `json:"duration"`
}

type CIWatchResult struct {
	Status *CIWatchStatus `json:"status"`
	Error  error          `json:"error"`
}

type CIWatchUpdate struct {
	Type    string         `json:"type"` // "status", "check", "completed", "failed"
	Status  *CIWatchStatus `json:"status"`
	Check   *CheckRunWatch `json:"check"`
	Message string         `json:"message"`
}