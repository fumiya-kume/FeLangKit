package ui

import (
	"fmt"
	"time"

	"ccw/logging"
	"ccw/types"
)

// DemoLogViewer demonstrates the log viewer functionality specifically
func DemoLogViewer() error {
	fmt.Println("📋 Log Viewer Demo - Integrated Log Display")
	fmt.Println("=========================================")

	// Initialize the log buffer
	InitLogBuffer(100)
	buffer := GetLogBuffer()

	// Set up logging to send to buffer
	logging.SetUILogFunction(AddLogToBuffer)

	// Create a sample logger
	logger, err := logging.NewLogger("log-demo", false)
	if err != nil {
		return fmt.Errorf("failed to create logger: %w", err)
	}
	defer logger.Close()

	// Generate sample logs
	fmt.Println("🔧 Generating sample logs...")

	// Add logs directly to buffer (bypassing console output)
	sampleLogs := []struct {
		level     string
		component string
		message   string
	}{
		{"INFO", "application", "CCW application initialized successfully"},
		{"DEBUG", "terminal", "Detecting terminal color capabilities"},
		{"INFO", "terminal", "Found Ghostty terminal with true color support"},
		{"INFO", "ui", "Initializing Bubble Tea interface"},
		{"WARN", "ui", "TTY access not available, using fallback mode"},
		{"DEBUG", "config", "Loading configuration from ccw.yaml"},
		{"INFO", "github", "Authenticating with GitHub API"},
		{"ERROR", "network", "Connection timeout while fetching issue data"},
		{"INFO", "network", "Retrying connection with exponential backoff"},
		{"INFO", "github", "Successfully fetched 25 issues from repository"},
		{"DEBUG", "workflow", "Starting issue processing workflow"},
		{"INFO", "git", "Creating new worktree for issue #123"},
		{"WARN", "git", "Working directory has uncommitted changes"},
		{"INFO", "claude", "Starting Claude Code session"},
		{"DEBUG", "claude", "Sending implementation context to Claude"},
		{"INFO", "claude", "Received implementation from Claude"},
		{"INFO", "validation", "Running SwiftLint checks"},
		{"ERROR", "validation", "Found 3 linting errors in implementation"},
		{"INFO", "validation", "Auto-fixing linting errors"},
		{"INFO", "validation", "All checks passed successfully"},
		{"INFO", "pr", "Creating pull request #456"},
		{"INFO", "workflow", "Workflow completed successfully"},
	}

	// Add logs to buffer with realistic timestamps
	now := time.Now()
	for i, log := range sampleLogs {
		entry := types.LogEntry{
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Level:     log.level,
			Component: log.component,
			Message:   log.message,
			SessionID: "log-demo",
		}
		buffer.AddEntry(entry)
		time.Sleep(100 * time.Millisecond) // Small delay for demonstration
	}

	fmt.Printf("✅ Generated %d log entries\n", len(sampleLogs))
	fmt.Println()

	// Display terminal detection info
	fmt.Println("🔍 Terminal Detection:")
	ShowTerminalDetectionInfo()
	fmt.Println()

	// Create and display log viewer
	fmt.Println("📊 Log Viewer Display:")
	fmt.Println("====================")

	// Create log viewer with reasonable size
	logViewer := NewLogViewerModel(80, 20, buffer)

	// Force update log content for static display
	logViewer.UpdateContent()

	// Render the log viewer
	fmt.Println(logViewer.View())

	fmt.Println()
	fmt.Println("💡 Interactive Features (available when TTY is accessible):")
	fmt.Println("   • ↑↓/j/k: Scroll through logs")
	fmt.Println("   • home/end: Jump to top/bottom")
	fmt.Println("   • d/i/w/e: Toggle debug/info/warn/error logs")
	fmt.Println("   • a: Toggle auto-scroll mode")
	fmt.Println("   • c: Clear log buffer")
	fmt.Println()

	// Show log statistics
	entries := buffer.GetEntries()
	levelCounts := make(map[string]int)
	for _, entry := range entries {
		levelCounts[entry.Level]++
	}

	fmt.Println("📈 Log Statistics:")
	for level, count := range levelCounts {
		var style string
		switch level {
		case "DEBUG":
			style = "🔍"
		case "INFO":
			style = "ℹ️ "
		case "WARN":
			style = "⚠️ "
		case "ERROR":
			style = "❌"
		default:
			style = "📝"
		}
		fmt.Printf("   %s %s: %d entries\n", style, level, count)
	}

	fmt.Println()
	fmt.Println("🎯 Integration Benefits:")
	fmt.Println("   ✅ Live log updates in UI")
	fmt.Println("   ✅ Filtering by log level")
	fmt.Println("   ✅ Scroll through history")
	fmt.Println("   ✅ Automatic color coding")
	fmt.Println("   ✅ Terminal-aware themes")
	fmt.Println("   ✅ Side-by-side with main UI")

	return nil
}

// RunLogViewerDemo is a convenience function to run the log viewer demo
func RunLogViewerDemo() {
	err := DemoLogViewer()
	if err != nil {
		fmt.Printf("Log viewer demo error: %v\n", err)
	}
}
