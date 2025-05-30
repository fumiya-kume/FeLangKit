package ui

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"ccw/platform"
	"ccw/types"
	"github.com/fatih/color"
)

// Terminal UI manager and core functionality

// UI manager
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
	progressTracker *ProgressTracker
	currentTheme    *ThemeConfig
	
	// Animation control
	animationRunning bool
	animationMutex   sync.Mutex
	
	// Advanced terminal control
	headerUpdateManager *HeaderUpdateManager
	uiState            *UIState
	terminalSize       TerminalSize
	updateInterval     time.Duration
	
	// Performance optimization
	performanceOptimizer *PerformanceOptimizer
	lastContentHash      string
	renderDebouncer      *time.Timer
}

// Create new UI manager
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
	ui.uiState = &UIState{
		LastRender:     time.Now(),
		ContentChanged: true,
		RenderCount:    0,
		AdaptiveInterval: ui.updateInterval,
	}
	ui.headerUpdateManager = &HeaderUpdateManager{
		interval:    ui.updateInterval,
		stopChannel: make(chan bool, 1),
		adaptiveMode: true,
		changeThreshold: 0.1,
	}
	
	// Initialize performance optimizer
	ui.performanceOptimizer = NewPerformanceOptimizer(getDefaultPerformanceConfig())
	ui.headerUpdateManager.performanceMetrics = ui.performanceOptimizer.metrics
	
	// Apply platform-specific terminal settings
	ui.applyPlatformSettings()
}

// Apply platform-specific terminal settings
func (ui *UIManager) applyPlatformSettings() {
	platformInfo := GetPlatformInfo()
	
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
func (ui *UIManager) getTerminalSize() TerminalSize {
	platformInfo := GetPlatformInfo()
	
	// Try to get actual terminal size using cross-platform utilities
	width, height, err := GetTerminalSize()
	if err != nil {
		// Use fallback defaults
		width, height = 80, 24
	}
	
	return TerminalSize{
		Width:             width,
		Height:            height,
		SupportsColors:    platformInfo.SupportsColor,
		SupportsUnicode:   platformInfo.SupportsUnicode,
		SupportsScrolling: true,
		RefreshRate:       60 * time.Millisecond, // Assume 16 FPS capability
	}
}

// Initialize progress tracker
func (ui *UIManager) InitializeProgress() {
	ui.progressTracker = &ProgressTracker{
		Steps: []WorkflowStep{
			{ID: "setup", Name: "Setting up worktree", Description: "Creating isolated development environment", Status: "pending"},
			{ID: "fetch", Name: "Fetching issue data", Description: "Retrieving GitHub issue information", Status: "pending"},
			{ID: "analysis", Name: "Generating analysis", Description: "Preparing implementation context", Status: "pending"},
			{ID: "implementation", Name: "Running Claude Code", Description: "Automated implementation process", Status: "pending"},
			{ID: "validation", Name: "Validating implementation", Description: "Running quality checks", Status: "pending"},
			{ID: "pr_generation", Name: "Generating PR description", Description: "Creating comprehensive PR description", Status: "pending"},
			{ID: "pr_creation", Name: "Creating pull request", Description: "Submitting PR to GitHub", Status: "pending"},
			{ID: "complete", Name: "Workflow complete", Description: "Process finished successfully", Status: "pending"},
		},
		CurrentStep: 0,
		StartTime:   time.Now(),
		TotalSteps:  8,
	}
}

// Display static header
func (ui *UIManager) displayHeader() {
	fmt.Print("\n")
	
	if ui.currentTheme.BorderStyle == "double" {
		fmt.Println(ui.accentColor("╔══════════════════════════════════════════════════════════════╗"))
		fmt.Println(ui.accentColor("║                    CCW - Claude Code Worktree               ║"))
		fmt.Println(ui.accentColor("║               Automated Issue Processing Tool               ║"))
		fmt.Println(ui.accentColor("╚══════════════════════════════════════════════════════════════╝"))
	} else if ui.currentTheme.BorderStyle == "rounded" {
		fmt.Println(ui.accentColor("╭──────────────────────────────────────────────────────────────╮"))
		fmt.Println(ui.accentColor("│                    CCW - Claude Code Worktree               │"))
		fmt.Println(ui.accentColor("│               Automated Issue Processing Tool               │"))
		fmt.Println(ui.accentColor("╰──────────────────────────────────────────────────────────────╯"))
	} else { // single
		fmt.Println(ui.accentColor("┌──────────────────────────────────────────────────────────────┐"))
		fmt.Println(ui.accentColor("│                    CCW - Claude Code Worktree               │"))
		fmt.Println(ui.accentColor("│               Automated Issue Processing Tool               │"))
		fmt.Println(ui.accentColor("└──────────────────────────────────────────────────────────────┘"))
	}
	
	fmt.Print("\n")
}

// Display validation results with visual formatting
func (ui *UIManager) displayValidationResults(result *ValidationResult) {
	fmt.Println(ui.primaryColor("🔍 Validation Results"))
	fmt.Println(strings.Repeat("─", 50))

	if result.LintResult != nil {
		status := "✅ PASSED"
		color := ui.successColor
		if !result.LintResult.Success {
			status = "❌ FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("SwiftLint: %s", color(status))
		if result.LintResult.AutoFixed {
			fmt.Print(ui.infoColor(" (auto-fixed)"))
		}
		fmt.Println()
	}

	if result.BuildResult != nil {
		status := "✅ PASSED"
		color := ui.successColor
		if !result.BuildResult.Success {
			status = "❌ FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("Build:     %s\n", color(status))
	}

	if result.TestResult != nil {
		status := "✅ PASSED"
		color := ui.successColor
		if !result.TestResult.Success {
			status = "❌ FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("Tests:     %s", color(status))
		if result.TestResult.TestCount > 0 {
			fmt.Printf(ui.infoColor(" (%d passed, %d failed)"), result.TestResult.Passed, result.TestResult.Failed)
		}
		fmt.Println()
	}

	fmt.Printf("\nDuration: %s\n\n", ui.infoColor(result.Duration.Round(time.Millisecond)))
}

// Logging methods
func (ui *UIManager) info(msg string) {
	fmt.Printf("%s %s\n", ui.infoColor("[INFO]"), msg)
}

func (ui *UIManager) success(msg string) {
	fmt.Printf("%s %s\n", ui.successColor("[SUCCESS]"), msg)
}

func (ui *UIManager) warning(msg string) {
	fmt.Printf("%s %s\n", ui.warningColor("[WARNING]"), msg)
}

func (ui *UIManager) error(msg string) {
	fmt.Printf("%s %s\n", ui.errorColorFunc("[ERROR]"), msg)
}

func (ui *UIManager) debug(msg string) {
	if ui.debugMode {
		fmt.Printf("%s %s\n", ui.accentColor("[DEBUG]"), msg)
	}
}

// Enhanced progress header with background updates
func (ui *UIManager) displayProgressHeaderWithBackground() {
	if ui.progressTracker == nil {
		ui.displayHeader()
		return
	}

	// Initial render
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	ui.displayHeader()
	content := ui.generateHeaderContent()
	fmt.Print(content)
	fmt.Println()
	
	// Start background updates
	ui.startBackgroundHeaderUpdates()
}

// Setup scroll region for better terminal control
func (ui *UIManager) setupScrollRegion() {
	if !ui.uiState.ScrollRegionSet {
		// Set scroll region (leave top 15 lines for header)
		fmt.Print("\033[16;24r") // Scroll region from line 16 to 24
		ui.uiState.ScrollRegionSet = true
	}
}

// Restore normal terminal state
func (ui *UIManager) restoreTerminalState() {
	// Stop background updates
	ui.stopBackgroundHeaderUpdates()
	
	// Reset scroll region
	if ui.uiState.ScrollRegionSet {
		fmt.Print("\033[r") // Reset scroll region
		ui.uiState.ScrollRegionSet = false
	}
}