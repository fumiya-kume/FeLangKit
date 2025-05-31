package ui

import (
	"fmt"
	"os"
	"sync"
	"time"

	"ccw/platform"
	"ccw/types"
	"github.com/fatih/color"
)

// UIManager manages terminal UI functionality and core state
type UIManager struct {
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
	progressTracker *types.ProgressTracker
	currentTheme    *types.ThemeConfig
	
	// Animation control
	animationRunning bool
	animationMutex   sync.Mutex
	
	// Advanced terminal control
	headerUpdateManager *types.HeaderUpdateManager
	uiState            *types.UIState
	terminalSize       types.TerminalSize
	updateInterval     time.Duration
	
	// Performance optimization
	performanceOptimizer *types.PerformanceOptimizer
	lastContentHash      string
	renderDebouncer      *time.Timer
}

// NewUIManager creates a new UI manager with specified configuration
func NewUIManager(theme string, animations bool, debugMode bool) *UIManager {
	ui := &UIManager{
		theme:      theme,
		animations: animations,
		debugMode:  debugMode,
	}
	
	ui.initializeColors()
	ui.InitializeProgress()
	
	return ui
}

// NewUIManagerWithDefaults creates a UI manager with defaults optimized for Bubble Tea
func NewUIManagerWithDefaults() *UIManager {
	return NewUIManager("modern", true, false) // Enable animations by default for Bubble Tea
}

// Initialize color functions
func (ui *UIManager) initializeColors() {
	ui.primaryColor = color.New(color.FgBlue, color.Bold).SprintFunc()
	ui.successColor = color.New(color.FgGreen, color.Bold).SprintFunc()
	ui.warningColor = color.New(color.FgYellow, color.Bold).SprintFunc()
	ui.errorColorFunc = color.New(color.FgRed, color.Bold).SprintFunc()
	ui.infoColor = color.New(color.FgCyan).SprintFunc()
	ui.accentColor = color.New(color.FgMagenta).SprintFunc()
	
	// Set theme
	ui.setTheme(ui.theme)
	
	// Initialize advanced terminal features
	ui.initializeAdvancedTerminal()
}

// Initialize advanced terminal control
func (ui *UIManager) initializeAdvancedTerminal() {
	ui.updateInterval = 250 * time.Millisecond // 4 FPS for smooth updates
	ui.terminalSize = ui.getTerminalSize()
	ui.uiState = &types.UIState{
		LastRender:     time.Now(),
		ContentChanged: true,
		RenderCount:    0,
		AdaptiveInterval: ui.updateInterval,
	}
	ui.headerUpdateManager = &types.HeaderUpdateManager{
		Interval:        ui.updateInterval,
		AdaptiveMode:    true,
		ChangeThreshold: 0.1,
	}
	
	// Initialize performance optimizer
	ui.performanceOptimizer = types.NewPerformanceOptimizer(types.GetDefaultPerformanceConfig())
	ui.headerUpdateManager.PerformanceMetrics = ui.performanceOptimizer.Metrics
	
	// Apply platform-specific terminal settings
	ui.applyPlatformSettings()
}

// Apply platform-specific terminal settings
func (ui *UIManager) applyPlatformSettings() {
	platformInfo := platform.GetPlatformInfo()
	
	// Update terminal size detection
	ui.terminalSize.SupportsColors = platformInfo.SupportsColor
	ui.terminalSize.SupportsUnicode = platformInfo.SupportsUnicode
	
	// Disable colors if not supported
	if !platformInfo.SupportsColor {
		color.NoColor = true
		ui.initializeColorsPlain()
	}
	
	// Adjust animations based on platform capabilities
	if !platformInfo.SupportsUnicode {
		ui.animations = false // Disable animations if Unicode not supported
	}
	
	// Platform-specific refresh rates
	switch platformInfo.OS {
	case "windows":
		// Windows terminals are typically slower
		ui.updateInterval = 500 * time.Millisecond
	case "darwin", "linux":
		// Unix terminals are typically faster
		ui.updateInterval = 250 * time.Millisecond
	}
	
	if ui.debugMode {
		fmt.Printf("Platform: %s/%s, Colors: %v, Unicode: %v\n", 
			platformInfo.OS, platformInfo.Arch, 
			platformInfo.SupportsColor, platformInfo.SupportsUnicode)
	}
}

// Initialize plain color functions for non-color terminals
func (ui *UIManager) initializeColorsPlain() {
	plainFunc := func(a ...interface{}) string {
		return fmt.Sprint(a...)
	}
	
	ui.primaryColor = plainFunc
	ui.successColor = plainFunc
	ui.warningColor = plainFunc
	ui.errorColorFunc = plainFunc
	ui.infoColor = plainFunc
	ui.accentColor = plainFunc
}

// Get terminal size with enhanced capability detection
func (ui *UIManager) getTerminalSize() types.TerminalSize {
	platformInfo := platform.GetPlatformInfo()
	
	// Try to get actual terminal size using cross-platform utilities
	width, height, err := platform.GetTerminalSize()
	if err != nil {
		// Use fallback defaults
		width, height = 80, 24
	}
	
	return types.TerminalSize{
		Width:             width,
		Height:            height,
		SupportsColors:    platformInfo.SupportsColor,
		SupportsUnicode:   platformInfo.SupportsUnicode,
		SupportsScrolling: true,
		RefreshRate:       60 * time.Millisecond, // Assume 16 FPS capability
	}
}

// Setup scroll region for better terminal control
func (ui *UIManager) setupScrollRegion() {
	if !ui.uiState.ScrollRegionSet {
		// Set scroll region (leave top 15 lines for header)
		fmt.Print("\033[16;24r") // Scroll region from line 16 to 24
		ui.uiState.ScrollRegionSet = true
	}
}

// RestoreTerminalState restores normal terminal state
func (ui *UIManager) RestoreTerminalState() {
	// Stop background updates
	ui.stopBackgroundHeaderUpdates()
	
	// Reset scroll region
	if ui.uiState.ScrollRegionSet {
		fmt.Print("\033[r") // Reset scroll region
		ui.uiState.ScrollRegionSet = false
	}
}

// GetAnimations returns whether animations are enabled
func (ui *UIManager) GetAnimations() bool {
	return ui.animations
}

// GetBubbleTeaManager creates a new Bubble Tea manager for this UI
func (ui *UIManager) GetBubbleTeaManager() *BubbleTeaManager {
	return NewBubbleTeaManager(ui)
}

// ShouldUseBubbleTea determines if we should use Bubble Tea for interactive UIs
func (ui *UIManager) ShouldUseBubbleTea() bool {
	// Check if console mode is forced via environment variable
	if os.Getenv("CCW_CONSOLE_MODE") == "true" {
		return false
	}
	
	// Default to Bubble Tea if terminal supports it
	btm := NewBubbleTeaManager(ui)
	return btm.CanRunInteractive()
}

// isConsoleMode checks if we're running in console mode (CI-friendly)
func (ui *UIManager) isConsoleMode() bool {
	return os.Getenv("CCW_CONSOLE_MODE") == "true" || 
		   os.Getenv("CI") == "true" || 
		   os.Getenv("GITHUB_ACTIONS") == "true" ||
		   os.Getenv("GITLAB_CI") == "true" ||
		   os.Getenv("JENKINS_URL") != ""
}

// getConsoleChar returns console-safe characters based on mode
func (ui *UIManager) getConsoleChar(fancy, simple string) string {
	if ui.isConsoleMode() {
		return simple
	}
	return fancy
}