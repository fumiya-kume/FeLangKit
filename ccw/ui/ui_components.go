package ui

import (
	"fmt"
	"strconv"
	"strings"
	"time"
	"ccw/types"
)

// UI components, themes, progress tracking, and animations

// Set UI theme
func (ui *UIManager) setTheme(themeName string) {
	switch themeName {
	case "minimal":
		ui.currentTheme = &types.ThemeConfig{
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
		ui.currentTheme = &types.ThemeConfig{
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
		ui.currentTheme = &types.ThemeConfig{
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
		ui.currentTheme = &types.ThemeConfig{
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
		ui.DisplayHeader()
		return
	}

	// Clear previous header
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	
	// Display main header
	ui.DisplayHeader()
	
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
			ui.headerUpdateManager.ContentHash = "" // Force update on next cycle
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

	ui.headerUpdateManager.Mutex.Lock()
	defer ui.headerUpdateManager.Mutex.Unlock()

	if ui.headerUpdateManager.IsRunning {
		return
	}

	ui.headerUpdateManager.IsRunning = true
	
	go func() {
		ticker := time.NewTicker(ui.headerUpdateManager.Interval)
		defer ticker.Stop()
		
		// Performance monitoring
		lastPerformanceCheck := time.Now()
		performanceCheckInterval := 10 * time.Second

		for {
			select {
			case <-ui.headerUpdateManager.StopChannel:
				ui.headerUpdateManager.Mutex.Lock()
				ui.headerUpdateManager.IsRunning = false
				ui.headerUpdateManager.Mutex.Unlock()
				return
			case <-ticker.C:
				ui.updateHeaderIfChanged()
				
				// Adaptive interval adjustment
				if ui.headerUpdateManager.AdaptiveMode {
					currentInterval := ui.performanceOptimizer.GetOptimalRefreshInterval()
					if currentInterval != ui.headerUpdateManager.Interval {
						ui.headerUpdateManager.Interval = currentInterval
						ticker.Stop()
						ticker = time.NewTicker(currentInterval)
					}
				}
				
				// Periodic performance stats logging
				if ui.debugMode && time.Since(lastPerformanceCheck) > performanceCheckInterval {
					stats := ui.performanceOptimizer.GetPerformanceStats()
					ui.Debug(fmt.Sprintf("Performance stats: %s", stats.String()))
					lastPerformanceCheck = time.Now()
				}
			}
		}
	}()
}

// Stop background header updates
func (ui *UIManager) stopBackgroundHeaderUpdates() {
	ui.headerUpdateManager.Mutex.Lock()
	defer ui.headerUpdateManager.Mutex.Unlock()

	if !ui.headerUpdateManager.IsRunning {
		return
	}

	// Send stop signal
	select {
	case ui.headerUpdateManager.StopChannel <- true:
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
		// Call the public method instead
		_, _ = ui.performanceOptimizer.DetectContentChange(content)
		// Fall back to simple hash for consistency
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
	
	if hasChanged && changeMagnitude >= ui.headerUpdateManager.ChangeThreshold {
		ui.renderHeaderWithFlickerReduction(currentContent)
		ui.uiState.LastRender = time.Now()
		ui.uiState.RenderCount++
		ui.uiState.ContentChanged = false
	}
}

// Display interactive issue selection interface
func (ui *UIManager) DisplayIssueSelection(issues []*types.Issue) ([]*types.Issue, error) {
	if len(issues) == 0 {
		ui.Warning("No issues found to display")
		return nil, fmt.Errorf("no issues available for selection")
	}

	ui.DisplayHeader()
	ui.Info(fmt.Sprintf("Found %d issues. Commands: w/s=up/down, SPACE=select/deselect, number=direct select, ENTER=confirm, q=quit.", len(issues)))
	fmt.Println()

	// Display selectable issue list
	selected := make([]bool, len(issues))
	currentIndex := 0
	
	for {
		// Clear the selection area and redraw
		fmt.Print("\033[2K") // Clear current line
		fmt.Print("\033[J")  // Clear from cursor to end of screen
		
		// Display issues with selection indicators
		for i, issue := range issues {
			cursor := "  "
			checkbox := "[ ]"
			
			if i == currentIndex {
				cursor = ui.primaryColor("→ ")
			}
			
			if selected[i] {
				checkbox = ui.successColor("[✓]")
			} else {
				checkbox = ui.infoColor("[ ]")
			}
			
			// Truncate title if too long
			title := issue.Title
			if len(title) > 60 {
				title = title[:57] + "..."
			}
			
			// Format issue line
			stateColor := ui.successColor
			if issue.State != "open" {
				stateColor = ui.infoColor
			}
			
			fmt.Printf("%s%s %d) #%-4d %s %s\n", 
				cursor, 
				checkbox, 
				i+1, // Display 1-based index for user selection
				issue.Number, 
				stateColor(fmt.Sprintf("%-6s", issue.State)),
				title)
		}
		
		fmt.Println()
		ui.Info("w/s: navigate, SPACE: select/deselect, number: direct select, ENTER: confirm, q: quit")
		
		// Read input using platform-specific character reading
		input, err := ui.readInput()
		if err != nil {
			return nil, fmt.Errorf("failed to read input: %w", err)
		}
		
		switch {
		case input == "esc":
			return nil, fmt.Errorf("selection cancelled by user")
		case input == "enter":
			selectedIssues := []*types.Issue{}
			for i, isSelected := range selected {
				if isSelected {
					selectedIssues = append(selectedIssues, issues[i])
				}
			}
			if len(selectedIssues) == 0 {
				ui.Warning("No issues selected. Please select at least one issue.")
				continue
			}
			return selectedIssues, nil
		case input == "space":
			selected[currentIndex] = !selected[currentIndex]
		case input == "up":
			if currentIndex > 0 {
				currentIndex--
			}
		case input == "down":
			if currentIndex < len(issues)-1 {
				currentIndex++
			}
		case strings.HasPrefix(input, "select_"):
			// Handle direct number selection
			indexStr := strings.TrimPrefix(input, "select_")
			if index, err := strconv.Atoi(indexStr); err == nil && index >= 0 && index < len(issues) {
				currentIndex = index
				selected[currentIndex] = !selected[currentIndex]
			}
		}
		
		// Move cursor back up to redraw
		fmt.Printf("\033[%dA", len(issues)+3)
	}
}

// Read input with proper arrow key handling
func (ui *UIManager) readInput() (string, error) {
	// Use a simplified approach that works with standard input
	var input string
	fmt.Scanln(&input)
	
	// Convert common inputs
	switch strings.ToLower(input) {
	case "q", "quit", "exit":
		return "esc", nil
	case "":
		return "enter", nil // Empty input treated as enter
	case " ":
		return "space", nil
	case "w", "up":
		return "up", nil
	case "s", "down":
		return "down", nil
	case "a", "left":
		return "left", nil
	case "d", "right":
		return "right", nil
	}
	
	// Try to parse as number for direct selection
	if num, err := strconv.Atoi(input); err == nil && num >= 1 {
		return fmt.Sprintf("select_%d", num-1), nil // Convert to 0-based index
	}
	
	return "", nil // Unknown input, continue
}

// Display issue summary
func (ui *UIManager) DisplayIssueSummary(issues []*types.Issue) {
	ui.DisplayHeader()
	
	if len(issues) == 0 {
		ui.Warning("No issues to display")
		return
	}
	
	ui.Info(fmt.Sprintf("Repository Issues (%d total)", len(issues)))
	fmt.Println()
	
	// Display issues in a table format
	fmt.Printf("%s%-6s %-8s %-50s %-12s%s\n", 
		ui.accentColor("│ "), "NUMBER", "STATE", "TITLE", "LABELS", ui.accentColor(" │"))
	fmt.Printf("%s%s%s\n", 
		ui.accentColor("├─"), strings.Repeat("─", 80), ui.accentColor("─┤"))
	
	for _, issue := range issues {
		title := issue.Title
		if len(title) > 48 {
			title = title[:45] + "..."
		}
		
		labels := ""
		if len(issue.Labels) > 0 {
			labelNames := make([]string, len(issue.Labels))
			for i, label := range issue.Labels {
				labelNames[i] = label.Name
			}
			labels = strings.Join(labelNames, ",")
			if len(labels) > 10 {
				labels = labels[:7] + "..."
			}
		}
		
		stateColor := ui.successColor
		if issue.State != "open" {
			stateColor = ui.infoColor
		}
		
		fmt.Printf("%s#%-5d %s %-50s %-12s%s\n",
			ui.accentColor("│ "),
			issue.Number,
			stateColor(fmt.Sprintf("%-8s", issue.State)),
			title,
			labels,
			ui.accentColor(" │"))
	}
	
	fmt.Printf("%s%s%s\n", 
		ui.accentColor("└─"), strings.Repeat("─", 80), ui.accentColor("─┘"))
	fmt.Println()
}

// Utility function to strip ANSI color codes for length calculation
func stripAnsiCodes(s string) string {
	// Simple regex to remove ANSI escape sequences
	ansiRegex := `\x1b\[[0-9;]*m`
	return strings.ReplaceAll(s, ansiRegex, "")
}