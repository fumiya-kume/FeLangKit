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

	// Display detailed error information if there are errors
	if len(result.Errors) > 0 {
		fmt.Printf("\n%s\n", ui.errorColorFunc("Error Details:"))
		for i, err := range result.Errors {
			ui.displayValidationError(err, i+1)
		}
	}

	fmt.Printf("\nDuration: %s\n\n", ui.infoColor(result.Duration.Round(time.Millisecond)))
}

// displayValidationError shows detailed information about a single validation error
func (ui *UIManager) displayValidationError(err types.ValidationError, errorNumber int) {
	errorIcon := ui.getConsoleChar("⚠️", "[ERR]")
	
	// Display error header
	fmt.Printf("%s %s %d: [%s] %s\n", 
		errorIcon, 
		ui.errorColorFunc("Error"), 
		errorNumber, 
		ui.warningColor(strings.ToUpper(err.Type)), 
		ui.primaryColor(err.Message))

	// Display cause information if available
	if err.Cause != nil {
		indent := "  "
		
		if err.Cause.Command != "" {
			cmdIcon := ui.getConsoleChar("🔧", "[CMD]")
			fmt.Printf("%s%s %s: %s\n", indent, cmdIcon, ui.infoColor("Command"), ui.accentColor(err.Cause.Command))
		}
		
		if err.Cause.ExitCode != 0 {
			exitIcon := ui.getConsoleChar("💥", "[EXIT]")
			fmt.Printf("%s%s %s: %s\n", indent, exitIcon, ui.infoColor("Exit Code"), ui.errorColorFunc(fmt.Sprintf("%d", err.Cause.ExitCode)))
		}
		
		if err.Cause.RootError != "" {
			causeIcon := ui.getConsoleChar("🔍", "[CAUSE]")
			fmt.Printf("%s%s %s: %s\n", indent, causeIcon, ui.infoColor("Root Cause"), ui.accentColor(err.Cause.RootError))
		}
		
		if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
			stderrIcon := ui.getConsoleChar("📄", "[STDERR]")
			fmt.Printf("%s%s %s:\n%s%s\n", indent, stderrIcon, ui.infoColor("Error Output"), indent+"  ", ui.accentColor(err.Cause.Stderr))
		}
		
		if len(err.Cause.Context) > 0 {
			ctxIcon := ui.getConsoleChar("📋", "[CTX]")
			fmt.Printf("%s%s %s:\n", indent, ctxIcon, ui.infoColor("Context"))
			for key, value := range err.Cause.Context {
				fmt.Printf("%s  %s: %s\n", indent, ui.warningColor(key), ui.accentColor(value))
			}
		}
	}
	
	// Add recovery suggestion if recoverable
	if err.Recoverable {
		recoveryIcon := ui.getConsoleChar("🔄", "[FIX]")
		fmt.Printf("  %s %s: This error may be automatically recoverable\n", recoveryIcon, ui.successColor("Recovery"))
	}
	
	fmt.Println() // Add spacing between errors
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
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	ui.DisplayHeader()
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
func (ui *UIManager) RestoreTerminalState() {
	// Stop background updates
	ui.stopBackgroundHeaderUpdates()
	
	// Reset scroll region
	if ui.uiState.ScrollRegionSet {
		fmt.Print("\033[r") // Reset scroll region
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