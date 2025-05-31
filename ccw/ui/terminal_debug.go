package ui

import (
	"fmt"
	"os"
)

// ShowTerminalDetectionInfo displays what was detected about the terminal
func ShowTerminalDetectionInfo() {
	colorInfo := DetectTerminalColors()

	fmt.Println("🖥️  Terminal Color Detection Results")
	fmt.Println("==================================")
	fmt.Printf("Detection method: %s\n", colorInfo.DetectionMethod)
	fmt.Printf("Theme type: %s\n", colorInfo.ThemeType)
	fmt.Printf("True color support: %v\n", colorInfo.SupportsTrueColor)
	fmt.Printf("256 color support: %v\n", colorInfo.Colors256)

	if colorInfo.AccentColor != "" {
		fmt.Printf("Detected accent color: %s\n", colorInfo.AccentColor)
	}

	if colorInfo.Background != "" {
		fmt.Printf("Background color: %s\n", colorInfo.Background)
	}

	if colorInfo.Foreground != "" {
		fmt.Printf("Foreground color: %s\n", colorInfo.Foreground)
	}

	fmt.Println("\nEnvironment variables:")
	relevantVars := []string{
		"TERM", "COLORTERM", "TERM_PROGRAM", "ITERM_PROFILE",
		"VSCODE_THEME_KIND", "THEME", "APPEARANCE", "DARK_MODE",
	}

	for _, varName := range relevantVars {
		if value := os.Getenv(varName); value != "" {
			fmt.Printf("  %s = %s\n", varName, value)
		}
	}
}