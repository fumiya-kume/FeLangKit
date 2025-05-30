package ui

import (
	"fmt"
	"time"

	"ccw/logging"
	"ccw/types"
)

// generateSampleLogs creates sample log entries for demo purposes
func generateSampleLogs() {
	// Create a sample logger to generate logs
	logger, err := logging.NewLogger("demo-session", false)
	if err != nil {
		return
	}
	defer logger.Close()

	// Generate various types of logs
	go func() {
		time.Sleep(1 * time.Second)
		logger.Info("ui", "Initializing Bubble Tea UI demo")

		time.Sleep(2 * time.Second)
		logger.Debug("ui", "Loading terminal configuration")

		time.Sleep(1 * time.Second)
		logger.Info("terminal", "Detected Ghostty terminal with light theme")

		time.Sleep(3 * time.Second)
		logger.Warn("ui", "TTY access not available in this environment")

		time.Sleep(2 * time.Second)
		logger.Info("ui", "Falling back to non-interactive mode")

		time.Sleep(4 * time.Second)
		logger.Error("demo", "Simulated error for demonstration purposes")

		time.Sleep(2 * time.Second)
		logger.Info("demo", "Recovering from simulated error")

		time.Sleep(3 * time.Second)
		logger.Debug("ui", "Updating log viewer content")

		time.Sleep(2 * time.Second)
		logger.Info("demo", "Demo log generation completed")
	}()
}

// DemoBubbleTeaUI demonstrates the new Bubble Tea UI functionality
func DemoBubbleTeaUI() error {
	// Create UI manager with new defaults (Bubble Tea enabled by default)
	ui := NewUIManagerWithDefaults()

	// Start generating sample logs for demonstration
	generateSampleLogs()

	fmt.Println("🫧 Bubble Tea UI Demo - Adaptive Color Scheme")
	fmt.Println("===========================================")

	// Show terminal detection results
	fmt.Println("🔍 Terminal Detection:")
	ShowTerminalDetectionInfo()
	fmt.Println()

	// Detect and apply optimal theme
	optimalTheme := GetOptimalTheme()
	fmt.Printf("🎯 Selected theme: %s\n", optimalTheme.Name)
	ApplyTheme(optimalTheme)

	// Show color test for the selected theme
	ShowColorTest(optimalTheme)

	// Show comparison with other themes
	fmt.Println("📊 Available themes:")
	themes := []ColorTheme{HighContrastTheme, DarkTheme, LightTheme}
	for _, theme := range themes {
		marker := "  "
		if theme.Name == optimalTheme.Name {
			marker = "→ "
		}
		fmt.Printf("%s%s - optimized for %s terminals\n", marker, theme.Name, theme.Name)
	}

	// Test if Bubble Tea is available (should be by default now)
	if ui.ShouldUseBubbleTea() {
		fmt.Println("\n✅ Bubble Tea UI is enabled by default!")
		fmt.Println("💡 Using adaptive color scheme with integrated logs!")

		// Demo 1: Main Menu
		fmt.Println("\n📋 Demo 1: Main Menu")
		fmt.Println("Press Ctrl+C to exit the menu")
		time.Sleep(3 * time.Second)

		err := ui.RunMainMenuEnhanced()
		if err != nil {
			fmt.Printf("⚠️  Bubble Tea demo failed (TTY access issue): %v\n", err)
			fmt.Println("💡 This is normal in some environments (CI, containers, etc.)")
			fmt.Println("✅ Color scheme detection and theming is working correctly!")
		}

		// Demo 2: Issue Selection
		fmt.Println("\n📝 Demo 2: Issue Selection")
		fmt.Println("Showing sample issues...")

		sampleIssues := []*types.Issue{
			{
				Number: 123,
				Title:  "Add Bubble Tea UI support",
				State:  "open",
				Labels: []types.Label{
					{Name: "enhancement"},
					{Name: "ui"},
				},
			},
			{
				Number: 124,
				Title:  "Fix terminal compatibility issues",
				State:  "open",
				Labels: []types.Label{
					{Name: "bug"},
					{Name: "terminal"},
				},
			},
			{
				Number: 125,
				Title:  "Improve progress tracking",
				State:  "closed",
				Labels: []types.Label{
					{Name: "enhancement"},
					{Name: "tracking"},
				},
			},
		}

		time.Sleep(2 * time.Second)
		selectedIssues, err := ui.DisplayIssueSelectionEnhanced(sampleIssues)
		if err != nil {
			fmt.Printf("⚠️  Issue selection demo failed: %v\n", err)
			fmt.Println("💡 Falling back to non-interactive display")
			fmt.Println("✅ Sample issues would be displayed in interactive mode:")
			for _, issue := range sampleIssues {
				fmt.Printf("   - #%d: %s (%s)\n", issue.Number, issue.Title, issue.State)
			}
		} else {
			fmt.Printf("✅ Selected %d issues\n", len(selectedIssues))
			for _, issue := range selectedIssues {
				fmt.Printf("   - #%d: %s\n", issue.Number, issue.Title)
			}
		}

		// Demo 3: Progress Tracking
		fmt.Println("\n⏳ Demo 3: Progress Tracking")
		fmt.Println("Showing workflow progress...")

		sampleSteps := []types.WorkflowStep{
			{ID: "setup", Name: "Setting up worktree", Description: "Creating isolated development environment", Status: "completed"},
			{ID: "fetch", Name: "Fetching issue data", Description: "Retrieving GitHub issue information", Status: "completed"},
			{ID: "analysis", Name: "Generating analysis", Description: "Preparing implementation context", Status: "in_progress"},
			{ID: "implementation", Name: "Running Claude Code", Description: "Automated implementation process", Status: "pending"},
			{ID: "validation", Name: "Validating implementation", Description: "Running quality checks", Status: "pending"},
		}

		time.Sleep(2 * time.Second)
		err = ui.DisplayProgressEnhanced(sampleSteps)
		if err != nil {
			fmt.Printf("⚠️  Progress tracking demo failed: %v\n", err)
			fmt.Println("💡 Showing static progress display instead:")
			for i, step := range sampleSteps {
				icon := "⏳"
				switch step.Status {
				case "completed":
					icon = "✅"
				case "in_progress":
					icon = "🔄"
				case "failed":
					icon = "❌"
				}
				fmt.Printf("   %s %d/%d %s - %s\n", icon, i+1, len(sampleSteps), step.Name, step.Description)
			}
		}

	} else {
		fmt.Println("❌ Bubble Tea is not available (TTY access required)")
		fmt.Println("   - Terminal compatibility:", ui.GetBubbleTeaManager().CanRunInteractive())
		fmt.Println("   - Animations enabled:", ui.GetAnimations())
		fmt.Println("💡 Use --console flag to force console mode, or CCW_CONSOLE_MODE=true environment variable")

		// Fallback to simple demonstrations
		fmt.Println("\n📋 Fallback: Simple Menu Demo")
		btm := ui.GetBubbleTeaManager()
		options := []string{"Option 1", "Option 2", "Option 3", "Exit"}
		choice, err := btm.RunSimpleMenu(options, "Sample Menu")
		if err != nil {
			fmt.Printf("Menu error: %v\n", err)
		} else {
			fmt.Printf("Selected: %s\n", options[choice])
		}
	}

	fmt.Println("\n🎉 Demo completed!")
	return nil
}

// RunBubbleTeaDemo is a convenience function to run the demo
func RunBubbleTeaDemo() {
	err := DemoBubbleTeaUI()
	if err != nil {
		fmt.Printf("Demo error: %v\n", err)
	}
}

// TestColorThemes shows all available color themes for comparison
func TestColorThemes() {
	fmt.Println("🎨 Color Theme Comparison")
	fmt.Println("========================")

	// Show terminal detection first
	fmt.Println("🔍 Terminal Detection Results:")
	ShowTerminalDetectionInfo()
	fmt.Println()

	// Get terminal-aware theme
	terminalTheme := GetOptimalTerminalTheme()
	optimalTheme := GetOptimalTheme()

	fmt.Printf("🎯 Recommended theme: %s\n\n", optimalTheme.Name)

	// Show terminal-detected theme first
	fmt.Printf("Testing terminal-detected theme: %s\n", terminalTheme.Name)
	ShowColorTest(terminalTheme)
	fmt.Println()

	// Show standard themes
	themes := []ColorTheme{HighContrastTheme, DarkTheme, LightTheme}
	for _, theme := range themes {
		fmt.Printf("Testing standard theme: %s\n", theme.Name)
		ShowColorTest(theme)
		fmt.Println()
	}

	fmt.Println("💡 Theme Guide:")
	fmt.Println("  🖥️  terminal-* : Automatically adapts to your terminal's color scheme")
	fmt.Println("  🔧 high-contrast: Universal compatibility, works on any terminal")
	fmt.Println("  🌙 dark        : Optimized for dark backgrounds (iTerm, VS Code)")
	fmt.Println("  ☀️  light       : Optimized for light backgrounds (Terminal.app)")
	fmt.Println()
	fmt.Println("🧑‍💻 For developers:")
	fmt.Println("  // Use terminal-aware theme (recommended)")
	fmt.Println("  theme := ui.GetOptimalTerminalTheme()")
	fmt.Println("  ui.ApplyTheme(theme)")
	fmt.Println()
	fmt.Println("  // Or use a specific theme")
	fmt.Println("  theme := ui.DarkTheme // HighContrastTheme, LightTheme")
	fmt.Println("  ui.ApplyTheme(theme)")
}
