package ui

import (
	"fmt"
	"strings"
	"time"
)

// UI components, themes, progress tracking, and animations

// Set UI theme
func (ui *UIManager) setTheme(themeName string) {
	switch themeName {
	case "minimal":
		ui.currentTheme = &ThemeConfig{
			Name:         "minimal",
			BorderStyle:  "single",
			PrimaryColor: "blue",
			AccentColor:  "cyan",
			SuccessColor: "green",
			WarningColor: "yellow",
			ErrorColor:   "red",
			InfoColor:    "white",
		}
	case "modern":
		ui.currentTheme = &ThemeConfig{
			Name:         "modern",
			BorderStyle:  "rounded",
			PrimaryColor: "blue",
			AccentColor:  "magenta",
			SuccessColor: "green",
			WarningColor: "yellow",
			ErrorColor:   "red",
			InfoColor:    "cyan",
		}
	case "compact":
		ui.currentTheme = &ThemeConfig{
			Name:         "compact",
			BorderStyle:  "single",
			PrimaryColor: "blue",
			AccentColor:  "blue",
			SuccessColor: "green",
			WarningColor: "yellow",
			ErrorColor:   "red",
			InfoColor:    "white",
		}
	default: // "default"
		ui.currentTheme = &ThemeConfig{
			Name:         "default",
			BorderStyle:  "double",
			PrimaryColor: "blue",
			AccentColor:  "magenta",
			SuccessColor: "green",
			WarningColor: "yellow",
			ErrorColor:   "red",
			InfoColor:    "cyan",
		}
	}
}

// Update progress step
func (ui *UIManager) UpdateProgress(stepID string, status string) {
	if ui.progressTracker == nil {
		return
	}

	for i, step := range ui.progressTracker.Steps {
		if step.ID == stepID {
			ui.progressTracker.Steps[i].Status = status
			if status == "in_progress" {
				ui.progressTracker.Steps[i].StartTime = time.Now()
				ui.progressTracker.CurrentStep = i
			} else if status == "completed" || status == "failed" {
				ui.progressTracker.Steps[i].EndTime = time.Now()
			}
			break
		}
	}
	
	if ui.animations {
		ui.displayProgressHeader()
	}
}

// Display dynamic header with progress
func (ui *UIManager) displayProgressHeader() {
	if ui.progressTracker == nil {
		ui.displayHeader()
		return
	}

	// Clear previous header
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	
	// Display main header
	ui.displayHeader()
	
	// Display progress
	fmt.Println(ui.accentColor("┌─ Workflow Progress ─────────────────────────────────────────┐"))
	
	for i, step := range ui.progressTracker.Steps {
		icon := ui.getStepIcon(step.Status)
		statusColor := ui.getStepColor(step.Status)
		stepNum := fmt.Sprintf("%d/%d", i+1, ui.progressTracker.TotalSteps)
		
		line := fmt.Sprintf("│ %s %s %-20s %s",
			stepNum,
			icon,
			step.Name,
			statusColor(step.Description))
		
		// Pad to fit width
		padding := 62 - len(stripAnsiCodes(line))
		if padding > 0 {
			line += strings.Repeat(" ", padding)
		}
		line += " │"
		
		fmt.Println(ui.accentColor(line))
	}
	
	// Display elapsed time
	elapsed := time.Since(ui.progressTracker.StartTime).Round(time.Second)
	timeLine := fmt.Sprintf("│ Elapsed: %-49s │", elapsed.String())
	fmt.Println(ui.accentColor(timeLine))
	
	fmt.Println(ui.accentColor("└─────────────────────────────────────────────────────────────┘"))
	fmt.Println()
}

// Get step icon based on status
func (ui *UIManager) getStepIcon(status string) string {
	switch status {
	case "completed":
		return ui.successColor("✅")
	case "in_progress":
		return ui.primaryColor("🔄")
	case "failed":
		return ui.errorColorFunc("❌")
	default: // pending
		return ui.infoColor("⏳")
	}
}

// Get step color based on status
func (ui *UIManager) getStepColor(status string) func(...interface{}) string {
	switch status {
	case "completed":
		return ui.successColor
	case "in_progress":
		return ui.primaryColor
	case "failed":
		return ui.errorColorFunc
	default: // pending
		return ui.infoColor
	}
}

// Enhanced update progress with flicker reduction and debouncing
func (ui *UIManager) UpdateProgressEnhanced(stepID string, status string) {
	ui.UpdateProgress(stepID, status)
	
	// Debounce rapid updates to prevent flickering
	if ui.renderDebouncer != nil {
		ui.renderDebouncer.Stop()
	}
	
	ui.renderDebouncer = time.AfterFunc(50*time.Millisecond, func() {
		// Mark content as changed for background update
		if ui.headerUpdateManager != nil {
			ui.headerUpdateManager.contentHash = "" // Force update on next cycle
			ui.uiState.ContentChanged = true
		}
	})
}

// Start loading animation for a specific operation
func (ui *UIManager) startLoadingAnimation(operation string) func() {
	if !ui.animations {
		return func() {} // No-op if animations disabled
	}

	ui.animationMutex.Lock()
	ui.animationRunning = true
	ui.animationMutex.Unlock()

	spinner := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	index := 0

	go func() {
		for {
			ui.animationMutex.Lock()
			if !ui.animationRunning {
				ui.animationMutex.Unlock()
				break
			}
			ui.animationMutex.Unlock()

			fmt.Printf("\r%s %s %s", ui.primaryColor(spinner[index]), ui.infoColor(operation), strings.Repeat(" ", 10))
			index = (index + 1) % len(spinner)
			time.Sleep(100 * time.Millisecond)
		}
		fmt.Print("\r" + strings.Repeat(" ", 50) + "\r") // Clear line
	}()

	return func() {
		ui.animationMutex.Lock()
		ui.animationRunning = false
		ui.animationMutex.Unlock()
	}
}

// Start background header updates with adaptive refresh
func (ui *UIManager) startBackgroundHeaderUpdates() {
	if !ui.animations {
		return
	}

	ui.headerUpdateManager.mutex.Lock()
	defer ui.headerUpdateManager.mutex.Unlock()

	if ui.headerUpdateManager.isRunning {
		return
	}

	ui.headerUpdateManager.isRunning = true
	
	go func() {
		ticker := time.NewTicker(ui.headerUpdateManager.interval)
		defer ticker.Stop()
		
		// Performance monitoring
		lastPerformanceCheck := time.Now()
		performanceCheckInterval := 10 * time.Second

		for {
			select {
			case <-ui.headerUpdateManager.stopChannel:
				ui.headerUpdateManager.mutex.Lock()
				ui.headerUpdateManager.isRunning = false
				ui.headerUpdateManager.mutex.Unlock()
				return
			case <-ticker.C:
				ui.updateHeaderIfChanged()
				
				// Adaptive interval adjustment
				if ui.headerUpdateManager.adaptiveMode {
					currentInterval := ui.performanceOptimizer.GetOptimalRefreshInterval()
					if currentInterval != ui.headerUpdateManager.interval {
						ui.headerUpdateManager.interval = currentInterval
						ticker.Stop()
						ticker = time.NewTicker(currentInterval)
					}
				}
				
				// Periodic performance stats logging
				if ui.debugMode && time.Since(lastPerformanceCheck) > performanceCheckInterval {
					stats := ui.performanceOptimizer.GetPerformanceStats()
					ui.debug(fmt.Sprintf("Performance stats: %+v", stats))
					lastPerformanceCheck = time.Now()
				}
			}
		}
	}()
}

// Stop background header updates
func (ui *UIManager) stopBackgroundHeaderUpdates() {
	ui.headerUpdateManager.mutex.Lock()
	defer ui.headerUpdateManager.mutex.Unlock()

	if !ui.headerUpdateManager.isRunning {
		return
	}

	// Send stop signal
	select {
	case ui.headerUpdateManager.stopChannel <- true:
	default:
		// Channel might be full, try non-blocking
	}
}

// Generate header content as string
func (ui *UIManager) generateHeaderContent() string {
	if ui.progressTracker == nil {
		return ""
	}

	var content strings.Builder
	
	// Header
	content.WriteString(ui.accentColor("┌─ Workflow Progress ─────────────────────────────────────────┐\n"))
	
	// Progress steps
	for i, step := range ui.progressTracker.Steps {
		icon := ui.getStepIcon(step.Status)
		statusColor := ui.getStepColor(step.Status)
		stepNum := fmt.Sprintf("%d/%d", i+1, ui.progressTracker.TotalSteps)
		
		line := fmt.Sprintf("│ %s %s %-20s %s",
			stepNum,
			icon,
			step.Name,
			statusColor(step.Description))
		
		// Pad to fit width
		padding := 62 - len(stripAnsiCodes(line))
		if padding > 0 {
			line += strings.Repeat(" ", padding)
		}
		line += " │\n"
		
		content.WriteString(ui.accentColor(line))
	}
	
	// Elapsed time
	elapsed := time.Since(ui.progressTracker.StartTime).Round(time.Second)
	timeLine := fmt.Sprintf("│ Elapsed: %-49s │\n", elapsed.String())
	content.WriteString(ui.accentColor(timeLine))
	
	content.WriteString(ui.accentColor("└─────────────────────────────────────────────────────────────┘\n"))
	
	return content.String()
}

// Calculate simple content hash for change detection (legacy method)
func (ui *UIManager) calculateContentHash(content string) string {
	// Use performance optimizer for better hash calculation
	if ui.performanceOptimizer != nil {
		return ui.performanceOptimizer.calculateContentHash(content)
	}
	
	// Fallback to simple hash based on content length and first/last chars
	if len(content) == 0 {
		return "empty"
	}
	
	return fmt.Sprintf("%d-%c-%c", len(content), content[0], content[len(content)-1])
}

// Render header with flicker reduction techniques
func (ui *UIManager) renderHeaderWithFlickerReduction(content string) {
	// Save cursor position
	fmt.Print("\033[s")
	
	// Move to top of screen
	fmt.Print("\033[H")
	
	// Output content
	fmt.Print(content)
	
	// Restore cursor position
	fmt.Print("\033[u")
}

// Update header if content has changed (with performance optimization)
func (ui *UIManager) updateHeaderIfChanged() {
	currentContent := ui.generateHeaderContent()
	
	// Use performance optimizer to detect changes
	hasChanged, changeMagnitude := ui.performanceOptimizer.DetectContentChange(currentContent)
	
	if hasChanged && changeMagnitude >= ui.headerUpdateManager.changeThreshold {
		ui.renderHeaderWithFlickerReduction(currentContent)
		ui.uiState.LastRender = time.Now()
		ui.uiState.RenderCount++
		ui.uiState.ContentChanged = false
	}
}

// Utility function to strip ANSI color codes for length calculation
func stripAnsiCodes(s string) string {
	// Simple regex to remove ANSI escape sequences
	ansiRegex := `\x1b\[[0-9;]*m`
	return strings.ReplaceAll(s, ansiRegex, "")
}