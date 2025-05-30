package ui

import (
	"sync"
	"time"
)

// UI types and structures

// Manager handles terminal UI operations
type Manager struct {
	theme      string
	animations bool
	debugMode  bool
	
	// Color functions
	primaryColor   func(...interface{}) string
	successColor   func(...interface{}) string
	warningColor   func(...interface{}) string
	errorColorFunc func(...interface{}) string
	infoColor      func(...interface{}) string
	accentColor    func(...interface{}) string
	
	// Progress tracking
	progressTracker *ProgressTracker
	currentTheme    *ThemeConfig
	
	// Animation control
	animationRunning bool
	animationMutex   sync.Mutex
	
	// Advanced terminal control
	headerUpdateManager *HeaderUpdateManager
	state              *State
	terminalSize       TerminalSize
	updateInterval     time.Duration
	
	// Performance optimization
	performanceOptimizer interface{}
	lastContentHash      string
	renderDebouncer      *time.Timer
}

// TerminalSize represents terminal dimensions and capabilities
type TerminalSize struct {
	Width             int
	Height            int
	SupportsColors    bool
	SupportsUnicode   bool
	SupportsScrolling bool
	RefreshRate       time.Duration
}

// ThemeConfig represents UI theme configuration
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

// State tracks UI state
type State struct {
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
	ContentCache             interface{}
}

// DirtyRegion represents a region that needs updating
type DirtyRegion struct {
	StartLine int
	EndLine   int
	StartCol  int
	EndCol    int
	Content   string
	Priority  int
	Timestamp time.Time
}

// HeaderUpdateManager manages header updates
type HeaderUpdateManager struct {
	isRunning             bool
	mutex                 sync.Mutex
	stopChannel           chan bool
	updateFunc            func()
	interval              time.Duration
	lastUpdate            time.Time
	contentHash           string
	adaptiveMode          bool
	performanceMetrics    interface{}
	contentBuffer         []string
	bufferSize            int
	lastSignificantChange time.Time
	changeThreshold       float64
}

// WorkflowStep represents a step in the workflow
type WorkflowStep struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Status      string `json:"status"` // "pending", "in_progress", "completed", "failed"
	StartTime   time.Time
	EndTime     time.Time
}

// ProgressTracker tracks workflow progress
type ProgressTracker struct {
	Steps       []WorkflowStep `json:"steps"`
	CurrentStep int            `json:"current_step"`
	StartTime   time.Time      `json:"start_time"`
	TotalSteps  int            `json:"total_steps"`
}