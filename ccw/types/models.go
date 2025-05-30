package types

import (
	"fmt"
	"os"
	"sync"
	"time"
)

// Core data models for GitHub integration and workflow

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

// Performance optimization models
type PerformanceConfig struct {
	EnableAdaptiveRefresh      bool
	EnableContentCaching       bool
	EnableSelectiveUpdates     bool
	MinRefreshInterval         time.Duration
	MaxRefreshInterval         time.Duration
	CacheSize                  int
	CacheTTL                   time.Duration
	OptimizationLevel          int
	DebounceThreshold          time.Duration
	ChangeDetectionSensitivity float64
}

type PerformanceMetrics struct {
	TotalRenders        int
	SkippedRenders      int
	AverageRenderTime   time.Duration
	MaxRenderTime       time.Duration
	MinRenderTime       time.Duration
	ContentChangeRate   float64
	OptimizationLevel   int
	AdaptiveAdjustments int
	mutex               sync.RWMutex
}

type ChangeDetector struct {
	lastContent   string
	lastHash      string
	changeHistory []time.Time
	sensitivity   float64
	minInterval   time.Duration
	mutex         sync.RWMutex
}

type AdaptiveRefreshController struct {
	currentInterval   time.Duration
	minInterval       time.Duration
	maxInterval       time.Duration
	changeVelocity    float64
	lastAdjustment    time.Time
	adjustmentHistory []time.Duration
	optimizationLevel int
	mutex             sync.RWMutex
}

type ContentCache struct {
	cache       map[string]CachedContent
	maxSize     int
	ttl         time.Duration
	hitCount    int
	missCount   int
	mutex       sync.RWMutex
	lastCleanup time.Time
}

type CachedContent struct {
	content     string
	hash        string
	timestamp   time.Time
	accessCount int
	lastAccess  time.Time
	size        int
}

type PerformanceOptimizer struct {
	config                    *PerformanceConfig
	changeDetector            *ChangeDetector
	adaptiveController        *AdaptiveRefreshController
	contentCache              *ContentCache
	Metrics                   *PerformanceMetrics
	mutex                     sync.RWMutex
	isOptimizationEnabled     bool
	lastOptimizationCheck     time.Time
	optimizationCheckInterval time.Duration
}

// UI models
type TerminalSize struct {
	Width             int
	Height            int
	SupportsColors    bool
	SupportsUnicode   bool
	SupportsScrolling bool
	RefreshRate       time.Duration
}

type ThemeConfig struct {
	Name         string
	BorderStyle  string // "single", "double", "rounded", "thick"
	PrimaryColor string
	AccentColor  string
	SuccessColor string
	WarningColor string
	ErrorColor   string
	InfoColor    string
}

type UIState struct {
	HeaderContent            string
	ScrollRegionSet          bool
	CursorSaved              bool
	LastRender               time.Time
	ContentChanged           bool
	RenderCount              int64
	LastContentHash          string
	ConsecutiveNoChanges     int
	AdaptiveInterval         time.Duration
	SkippedRenders           int
	DirtyRegions             []DirtyRegion
	ContentCache             *ContentCache
}

type DirtyRegion struct {
	StartLine int
	EndLine   int
	StartCol  int
	EndCol    int
	Content   string
	Priority  int
	Timestamp time.Time
}

type HeaderUpdateManager struct {
	IsRunning             bool
	Mutex                 sync.Mutex
	StopChannel           chan bool
	UpdateFunc            func()
	Interval              time.Duration
	LastUpdate            time.Time
	ContentHash           string
	AdaptiveMode          bool
	PerformanceMetrics    *PerformanceMetrics
	ContentBuffer         []string
	BufferSize            int
	LastSignificantChange time.Time
	ChangeThreshold       float64
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

// PerformanceOptimizer implementation functions

// NewPerformanceOptimizer creates a new performance optimizer
func NewPerformanceOptimizer(config *PerformanceConfig) *PerformanceOptimizer {
	return &PerformanceOptimizer{
		config: config,
		changeDetector: &ChangeDetector{
			sensitivity:   config.ChangeDetectionSensitivity,
			minInterval:   config.MinRefreshInterval,
			changeHistory: make([]time.Time, 0),
		},
		adaptiveController: &AdaptiveRefreshController{
			currentInterval:   config.MinRefreshInterval,
			minInterval:       config.MinRefreshInterval,
			maxInterval:       config.MaxRefreshInterval,
			optimizationLevel: config.OptimizationLevel,
			adjustmentHistory: make([]time.Duration, 0),
		},
		contentCache: &ContentCache{
			cache:   make(map[string]CachedContent),
			maxSize: config.CacheSize,
			ttl:     config.CacheTTL,
		},
		Metrics: &PerformanceMetrics{
			TotalRenders:      0,
			SkippedRenders:    0,
			AverageRenderTime: 0,
			MaxRenderTime:     0,
			MinRenderTime:     time.Hour, // Start with high value
			ContentChangeRate: 0,
			OptimizationLevel: config.OptimizationLevel,
		},
		isOptimizationEnabled:     config.EnableAdaptiveRefresh,
		optimizationCheckInterval: 10 * time.Second,
	}
}

// GetDefaultPerformanceConfig returns default performance configuration
func GetDefaultPerformanceConfig() *PerformanceConfig {
	return &PerformanceConfig{
		EnableAdaptiveRefresh:      true,
		EnableContentCaching:       true,
		EnableSelectiveUpdates:     true,
		MinRefreshInterval:         100 * time.Millisecond,
		MaxRefreshInterval:         1 * time.Second,
		CacheSize:                  100,
		CacheTTL:                   5 * time.Minute,
		OptimizationLevel:          2,
		DebounceThreshold:          50 * time.Millisecond,
		ChangeDetectionSensitivity: 0.1,
	}
}

// Performance optimizer methods
func (po *PerformanceOptimizer) GetOptimalRefreshInterval() time.Duration {
	po.mutex.RLock()
	defer po.mutex.RUnlock()
	
	if po.adaptiveController != nil {
		return po.adaptiveController.currentInterval
	}
	return po.config.MinRefreshInterval
}

func (po *PerformanceOptimizer) GetPerformanceStats() *PerformanceMetrics {
	po.mutex.RLock()
	defer po.mutex.RUnlock()
	return po.Metrics
}

func (po *PerformanceOptimizer) DetectContentChange(content string) (bool, float64) {
	po.mutex.Lock()
	defer po.mutex.Unlock()
	
	if po.changeDetector == nil {
		return true, 1.0 // Always update if no detector
	}
	
	// Simple change detection based on content hash
	currentHash := po.calculateContentHash(content)
	hasChanged := currentHash != po.changeDetector.lastHash
	
	if hasChanged {
		po.changeDetector.lastContent = content
		po.changeDetector.lastHash = currentHash
		po.changeDetector.changeHistory = append(po.changeDetector.changeHistory, time.Now())
		
		// Keep only recent changes (last 10 seconds)
		cutoff := time.Now().Add(-10 * time.Second)
		filtered := make([]time.Time, 0)
		for _, t := range po.changeDetector.changeHistory {
			if t.After(cutoff) {
				filtered = append(filtered, t)
			}
		}
		po.changeDetector.changeHistory = filtered
		
		return true, 1.0
	}
	
	return false, 0.0
}

func (po *PerformanceOptimizer) calculateContentHash(content string) string {
	// Simple hash based on content length and first/last chars
	if len(content) == 0 {
		return "empty"
	}
	return fmt.Sprintf("%d-%c-%c", len(content), content[0], content[len(content)-1])
}

// AccessibleMetrics returns publicly accessible metrics
func (po *PerformanceOptimizer) AccessibleMetrics() *PerformanceMetrics {
	po.mutex.RLock()
	defer po.mutex.RUnlock()
	
	// Create a copy to avoid race conditions
	metricsCopy := *po.Metrics
	return &metricsCopy
}

// String returns a formatted string representation of PerformanceMetrics
func (pm *PerformanceMetrics) String() string {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	
	// Handle the case where MinRenderTime is uninitialized (1 hour default)
	minRenderTime := pm.MinRenderTime
	if minRenderTime >= time.Hour {
		minRenderTime = 0 // Show 0 if no renders have occurred
	}
	
	return fmt.Sprintf("PerformanceStats{TotalRenders:%d, SkippedRenders:%d, AvgRenderTime:%s, MaxRenderTime:%s, MinRenderTime:%s, ChangeRate:%.2f, OptLevel:%d, Adjustments:%d}",
		pm.TotalRenders,
		pm.SkippedRenders,
		pm.AverageRenderTime,
		pm.MaxRenderTime,
		minRenderTime,
		pm.ContentChangeRate,
		pm.OptimizationLevel,
		pm.AdaptiveAdjustments,
	)
}