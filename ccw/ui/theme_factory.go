package ui

import (
	"fmt"
)

// CreateThemeFromTerminal creates a color theme based on terminal detection
func CreateThemeFromTerminal() ColorTheme {
	colorInfo := DetectTerminalColors()

	var theme ColorTheme

	// Use detected accent color if available
	accentColor := colorInfo.AccentColor
	if accentColor == "" {
		accentColor = "#0066CC" // fallback
	}

	switch colorInfo.ThemeType {
	case "dark":
		theme = ColorTheme{
			Name:               fmt.Sprintf("terminal-dark (%s)", colorInfo.DetectionMethod),
			Primary:            accentColor,
			Success:            "#50C878", // Lighter green for dark background
			Error:              "#FF6B6B", // Lighter red for dark background
			Warning:            "#FFD93D", // Lighter yellow for dark background
			Info:               accentColor,
			Subtle:             "#888888", // Light gray for dark background
			Background:         colorInfo.Background,
			SelectedBackground: accentColor,
			SelectedForeground: "#FFFFFF",
			BorderColor:        accentColor,
		}

	case "light":
		theme = ColorTheme{
			Name:               fmt.Sprintf("terminal-light (%s)", colorInfo.DetectionMethod),
			Primary:            darkenColor(accentColor, 0.3), // Darker for light background
			Success:            "#006600",                     // Darker green for light background
			Error:              "#CC0000",                     // Darker red for light background
			Warning:            "#B8860B",                     // Darker yellow for light background
			Info:               darkenColor(accentColor, 0.3),
			Subtle:             "#555555", // Dark gray for light background
			Background:         colorInfo.Background,
			SelectedBackground: darkenColor(accentColor, 0.3),
			SelectedForeground: "#FFFFFF",
			BorderColor:        darkenColor(accentColor, 0.3),
		}

	default: // auto or unknown
		// Use high contrast theme with detected accent color
		theme = ColorTheme{
			Name:               fmt.Sprintf("terminal-auto (%s)", colorInfo.DetectionMethod),
			Primary:            accentColor,
			Success:            "#00AA00",
			Error:              "#CC0000",
			Warning:            "#FF6600",
			Info:               accentColor,
			Subtle:             "#666666",
			Background:         colorInfo.Background,
			SelectedBackground: accentColor,
			SelectedForeground: "#FFFFFF",
			BorderColor:        accentColor,
		}
	}

	return theme
}

// GetOptimalTerminalTheme returns the best theme based on actual terminal detection
func GetOptimalTerminalTheme() ColorTheme {
	return CreateThemeFromTerminal()
}