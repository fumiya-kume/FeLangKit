package ui

import (
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"ccw/platform"
	"ccw/types"
	"github.com/fatih/color"
	tea "github.com/charmbracelet/bubbletea"
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
		Interval:    ui.updateInterval,
		StopChannel: make(chan bool, 2), // Larger buffer to prevent blocking
		AdaptiveMode: true,
		ChangeThreshold: 0.1,
	}
	
	// Initialize performance optimizer
	ui.performanceOptimizer = types.NewPerformanceOptimizer(types.GetDefaultPerformanceConfig())
	ui.headerUpdateManager.PerformanceMetrics = ui.performanceOptimizer.Metrics
	
	// Apply platform-specific terminal settings
	ui.applyPlatformSettings()
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

// Initialize progress tracker
func (ui *UIManager) InitializeProgress() {
	ui.progressTracker = &types.ProgressTracker{
		Steps: []types.WorkflowStep{
			{ID: "setup", Name: "Setting up worktree", Description: "Creating isolated development environment", Status: "pending"},
			{ID: "fetch", Name: "Fetching issue data", Description: "Retrieving GitHub issue information", Status: "pending"},
			{ID: "analysis", Name: "Generating analysis", Description: "Preparing implementation context", Status: "pending"},
			{ID: "implementation", Name: "Running Claude Code", Description: "Automated implementation process", Status: "pending"},
			{ID: "validation", Name: "Validating implementation", Description: "Running quality checks", Status: "pending"},
			{ID: "commit", Name: "Committing changes", Description: "Creating git commit with all changes", Status: "pending"},
			{ID: "pr_generation", Name: "Generating PR description", Description: "Creating comprehensive PR description", Status: "pending"},
			{ID: "pr_creation", Name: "Creating pull request", Description: "Submitting PR to GitHub", Status: "pending"},
			{ID: "complete", Name: "Workflow complete", Description: "Process finished successfully", Status: "pending"},
		},
		CurrentStep: 0,
		StartTime:   time.Now(),
		TotalSteps:  9,
	}
}

// Display static header
func (ui *UIManager) DisplayHeader() {
	fmt.Print("\n")
	
	if ui.isConsoleMode() {
		// Console mode: use simple ASCII characters
		fmt.Println(ui.accentColor("================================================================"))
		fmt.Println(ui.accentColor("                    CCW - Claude Code Worktree                 "))
		fmt.Println(ui.accentColor("               Automated Issue Processing Tool                 "))
		fmt.Println(ui.accentColor("================================================================"))
	} else {
		// Interactive mode: use fancy Unicode characters
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
	}
	
	fmt.Print("\n")
}

// Display validation results with visual formatting
func (ui *UIManager) DisplayValidationResults(result *types.ValidationResult) {
	title := ui.getConsoleChar("🔍 Validation Results", "Validation Results")
	separator := ui.getConsoleChar("─", "-")
	
	fmt.Println(ui.primaryColor(title))
	fmt.Println(strings.Repeat(separator, 50))

	if result.LintResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.LintResult.Success {
			status = failedIcon + " FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("SwiftLint: %s", color(status))
		if result.LintResult.AutoFixed {
			fmt.Print(ui.infoColor(" (auto-fixed)"))
		}
		fmt.Println()
	}

	if result.BuildResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.BuildResult.Success {
			status = failedIcon + " FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("Build:     %s\n", color(status))
	}

	if result.TestResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.TestResult.Success {
			status = failedIcon + " FAILED"
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
func (ui *UIManager) Info(msg string) {
	fmt.Printf("%s %s\n", ui.infoColor("[INFO]"), msg)
}

func (ui *UIManager) Success(msg string) {
	fmt.Printf("%s %s\n", ui.successColor("[SUCCESS]"), msg)
}

func (ui *UIManager) Warning(msg string) {
	fmt.Printf("%s %s\n", ui.warningColor("[WARNING]"), msg)
}

func (ui *UIManager) Error(msg string) {
	fmt.Printf("%s %s\n", ui.errorColorFunc("[ERROR]"), msg)
}

func (ui *UIManager) Debug(msg string) {
	if ui.debugMode {
		fmt.Printf("%s %s\n", ui.accentColor("[DEBUG]"), msg)
	}
}

// Enhanced progress header with background updates
func (ui *UIManager) DisplayProgressHeaderWithBackground() {
	if ui.progressTracker == nil {
		ui.DisplayHeader()
		return
	}

	// Initial render
	// Use proper screen clearing method
	ui.ClearScreen()
	ui.DisplayHeader()
	content := ui.generateHeaderContent()
	fmt.Print(content)
	fmt.Println()
	
	// Start background updates
	ui.startBackgroundHeaderUpdates()
}

// Setup scroll region for better terminal control
// Note: This method is deprecated in favor of Bubble Tea viewport management
func (ui *UIManager) setupScrollRegion() {
	if !ui.uiState.ScrollRegionSet && ui.ShouldUseBubbleTea() {
		// In Bubble Tea mode, viewport management is handled by models
		// Mark as set to avoid legacy ANSI scroll region commands
		ui.uiState.ScrollRegionSet = true
	} else if !ui.uiState.ScrollRegionSet && !ui.isConsoleMode() {
		// Legacy mode: only set scroll regions in interactive terminals that support it
		// This is deprecated and should be replaced with Bubble Tea viewport
		ui.uiState.ScrollRegionSet = true
	}
	// In console mode, do not set scroll regions to preserve output
}

// Restore normal terminal state
func (ui *UIManager) RestoreTerminalState() {
	// Stop background updates
	ui.stopBackgroundHeaderUpdates()
	
	// Reset scroll region - only in legacy mode
	if ui.uiState.ScrollRegionSet && !ui.ShouldUseBubbleTea() && !ui.isConsoleMode() {
		// In Bubble Tea mode, terminal state restoration is handled by the program lifecycle
		// Only reset scroll regions in legacy interactive mode
		ui.uiState.ScrollRegionSet = false
	} else if ui.uiState.ScrollRegionSet {
		// Mark as reset without sending ANSI codes
		ui.uiState.ScrollRegionSet = false
	}
}

// Getter for animations field
func (ui *UIManager) GetAnimations() bool {
	return ui.animations
}

// Enhanced UI methods that can use Bubble Tea
// Note: Enhanced methods are defined in bubbletea_manager.go to avoid circular dependencies

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

// ClearScreen clears the screen using Bubble Tea when available, fallback to console mode
func (ui *UIManager) ClearScreen() {
	if ui.ShouldUseBubbleTea() && ui.animations {
		// Use Bubble Tea screen clearing for better cross-platform compatibility
		// Note: In Bubble Tea applications, screen clearing is handled by the program lifecycle
		// This method is for compatibility when transitioning between modes
		if program := tea.NewProgram(nil); program != nil {
			// Send a clear screen command to stdout
			fmt.Print(tea.ClearScreen())
		}
	} else if !ui.isConsoleMode() {
		// Fallback: only clear in interactive mode, not in CI/console mode
		// Use platform-safe clearing that respects terminal capabilities
		ui.clearScreenSafe()
	}
	// In console mode, do nothing - preserve scrollable output
}

// clearScreenSafe provides a safer alternative to direct ANSI codes
func (ui *UIManager) clearScreenSafe() {
	// Only clear if we detect good terminal support
	if ui.terminalSize.SupportsColors && !ui.isConsoleMode() {
		// Use Bubble Tea's screen clearing which handles platform differences
		fmt.Print(tea.ClearScreen())
	}
}