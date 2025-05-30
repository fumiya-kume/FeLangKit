package ui

import (
	"os"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// ColorTheme represents a color theme for the UI
type ColorTheme struct {
	Name               string
	Primary            string
	Success            string
	Error              string
	Warning            string
	Info               string
	Subtle             string
	Background         string
	SelectedBackground string
	SelectedForeground string
	BorderColor        string
}

// Predefined color themes
var (
	// High contrast theme - good for both light and dark terminals
	HighContrastTheme = ColorTheme{
		Name:               "high-contrast",
		Primary:            "#0066CC", // Strong blue
		Success:            "#00AA00", // Strong green
		Error:              "#CC0000", // Strong red
		Warning:            "#FF6600", // Strong orange
		Info:               "#0066CC", // Strong blue
		Subtle:             "#666666", // Medium gray
		Background:         "",        // Use terminal default
		SelectedBackground: "#0066CC", // Blue background
		SelectedForeground: "#FFFFFF", // White text
		BorderColor:        "#0066CC", // Blue borders
	}

	// Dark theme - optimized for dark terminals
	DarkTheme = ColorTheme{
		Name:               "dark",
		Primary:            "#4A9EFF", // Lighter blue
		Success:            "#50C878", // Lighter green
		Error:              "#FF4444", // Lighter red
		Warning:            "#FFB347", // Lighter orange
		Info:               "#4A9EFF", // Lighter blue
		Subtle:             "#888888", // Lighter gray
		Background:         "",        // Use terminal default
		SelectedBackground: "#4A9EFF", // Light blue background
		SelectedForeground: "#000000", // Black text
		BorderColor:        "#4A9EFF", // Light blue borders
	}

	// Light theme - optimized for light terminals
	LightTheme = ColorTheme{
		Name:               "light",
		Primary:            "#003D82", // Darker blue
		Success:            "#006600", // Darker green
		Error:              "#990000", // Darker red
		Warning:            "#CC4400", // Darker orange
		Info:               "#003D82", // Darker blue
		Subtle:             "#555555", // Darker gray
		Background:         "",        // Use terminal default
		SelectedBackground: "#003D82", // Dark blue background
		SelectedForeground: "#FFFFFF", // White text
		BorderColor:        "#003D82", // Dark blue borders
	}
)

// DetectTerminalBackground attempts to detect if the terminal has a light or dark background
func DetectTerminalBackground() string {
	// Check common environment variables that might indicate terminal theme
	termProgram := strings.ToLower(os.Getenv("TERM_PROGRAM"))
	colorTerm := strings.ToLower(os.Getenv("COLORTERM"))
	terminalApp := strings.ToLower(os.Getenv("TERMINAL_APP"))

	// Some terminals set specific variables
	if strings.Contains(termProgram, "iterm") {
		// iTerm2 - default to dark but could be either
		return "dark"
	}

	if strings.Contains(termProgram, "vscode") {
		// VS Code terminal - often dark
		return "dark"
	}

	if strings.Contains(colorTerm, "truecolor") || strings.Contains(colorTerm, "24bit") {
		// Modern terminals often default to dark
		return "dark"
	}

	if strings.Contains(terminalApp, "terminal") {
		// macOS Terminal.app - could be either, default to light
		return "light"
	}

	// Default to high contrast which works well on both
	return "auto"
}

// GetOptimalTheme returns the best theme for the current terminal
func GetOptimalTheme() ColorTheme {
	// First try terminal-aware detection
	terminalTheme := GetOptimalTerminalTheme()

	// If terminal detection provided useful info, use it
	if terminalTheme.Name != "" && !strings.Contains(terminalTheme.Name, "fallback") {
		return terminalTheme
	}

	// Fallback to basic detection
	background := DetectTerminalBackground()

	switch background {
	case "dark":
		return DarkTheme
	case "light":
		return LightTheme
	default:
		return HighContrastTheme
	}
}

// ApplyTheme applies a color theme to the global styles
func ApplyTheme(theme ColorTheme) {
	// Update global styles with theme colors
	titleStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.SelectedForeground)).
		Background(lipgloss.Color(theme.Primary)).
		Padding(0, 1).
		Bold(true)

	headerStyle = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(theme.BorderColor)).
		Foreground(lipgloss.Color(theme.Primary)).
		Padding(1, 2).
		Bold(true)

	menuItemStyle = lipgloss.NewStyle().
		PaddingLeft(4).
		Foreground(lipgloss.Color(theme.Subtle))

	selectedMenuItemStyle = lipgloss.NewStyle().
		PaddingLeft(2).
		Foreground(lipgloss.Color(theme.SelectedForeground)).
		Background(lipgloss.Color(theme.SelectedBackground)).
		Bold(true)

	progressStyle = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(theme.Success)).
		Foreground(lipgloss.Color(theme.Success)).
		Padding(1, 2)

	successStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Success)).
		Bold(true)

	errorStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Error)).
		Bold(true)

	warningStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Warning)).
		Bold(true)

	infoStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Info)).
		Bold(true)

	subtleStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Subtle))
}

// ShowColorTest displays a color test to verify visibility
func ShowColorTest(theme ColorTheme) {
	println("🎨 Color Visibility Test for", theme.Name, "theme:")
	println("=" + strings.Repeat("=", 40+len(theme.Name)))

	// Apply theme temporarily
	ApplyTheme(theme)

	// Test each color
	println("  ", successStyle.Render("✓ Success"), "- Green text should be clearly visible")
	println("  ", errorStyle.Render("✗ Error"), "- Red text should be clearly visible")
	println("  ", warningStyle.Render("⚠ Warning"), "- Orange text should be clearly visible")
	println("  ", infoStyle.Render("ℹ Info"), "- Blue text should be clearly visible")
	println("  ", selectedMenuItemStyle.Render(" Selected "), "- White on blue should be clearly visible")
	println("  ", subtleStyle.Render("○ Subtle"), "- Gray text should be readable but not prominent")
	println()
}
