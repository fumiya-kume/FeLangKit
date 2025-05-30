package types

import (
	"sync"
	"time"
)

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
	HeaderContent        string
	ScrollRegionSet      bool
	CursorSaved          bool
	LastRender           time.Time
	ContentChanged       bool
	RenderCount          int64
	LastContentHash      string
	ConsecutiveNoChanges int
	AdaptiveInterval     time.Duration
	SkippedRenders       int
	DirtyRegions         []DirtyRegion
	ContentCache         *ContentCache
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
	// StopChannel removed - no longer needed for Bubble Tea message-driven updates
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
