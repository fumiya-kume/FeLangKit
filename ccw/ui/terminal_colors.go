package ui

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// TerminalColorInfo holds detected terminal color information
type TerminalColorInfo struct {
	Background      string
	Foreground      string
	AccentColor     string
	SupportsTrueColor bool
	Colors256       bool
	ThemeType       string // "light", "dark", "auto"
	DetectionMethod string
}

// DetectTerminalColors attempts to detect terminal color scheme from various sources
func DetectTerminalColors() *TerminalColorInfo {
	info := &TerminalColorInfo{
		SupportsTrueColor: false,
		Colors256:         false,
		ThemeType:         "auto",
		DetectionMethod:   "default",
	}

	// Check color support first
	info.SupportsTrueColor, info.Colors256 = detectColorSupport()

	// Try different detection methods in order of preference
	if detected := detectFromEnvironmentVars(); detected != nil {
		// Preserve color support detection from initial check
		detected.SupportsTrueColor = info.SupportsTrueColor
		detected.Colors256 = info.Colors256
		*info = *detected
		info.DetectionMethod = "environment"
		return info
	}

	if detected := detectFromTerminalQueries(); detected != nil {
		detected.SupportsTrueColor = info.SupportsTrueColor
		detected.Colors256 = info.Colors256
		*info = *detected
		info.DetectionMethod = "terminal-query"
		return info
	}

	if detected := detectFromCommonTerminals(); detected != nil {
		detected.SupportsTrueColor = info.SupportsTrueColor
		detected.Colors256 = info.Colors256
		*info = *detected
		info.DetectionMethod = "terminal-heuristics"
		return info
	}

	// Fallback to safe defaults
	info.ThemeType = "auto"
	info.DetectionMethod = "fallback"
	return info
}

// detectColorSupport checks what color capabilities the terminal has
func detectColorSupport() (trueColor bool, colors256 bool) {
	colorTerm := strings.ToLower(os.Getenv("COLORTERM"))
	term := strings.ToLower(os.Getenv("TERM"))

	// Check for true color support
	trueColor = strings.Contains(colorTerm, "truecolor") ||
		strings.Contains(colorTerm, "24bit") ||
		strings.Contains(term, "truecolor")

	// Check for 256 color support
	colors256 = strings.Contains(term, "256") ||
		strings.Contains(term, "color") ||
		trueColor // true color implies 256 color support

	return trueColor, colors256
}

// detectFromEnvironmentVars tries to detect theme from environment variables
func detectFromEnvironmentVars() *TerminalColorInfo {
	info := &TerminalColorInfo{}

	// Check for explicit theme variables
	if theme := os.Getenv("THEME"); theme != "" {
		info.ThemeType = strings.ToLower(theme)
		return info
	}

	if appearance := os.Getenv("APPEARANCE"); appearance != "" {
		info.ThemeType = strings.ToLower(appearance)
		return info
	}

	// Check macOS dark mode
	if os.Getenv("DARK_MODE") == "1" || os.Getenv("MACOS_DARK_MODE") == "1" {
		info.ThemeType = "dark"
		return info
	}

	// Check for terminal-specific theme variables
	if iterm := os.Getenv("ITERM_PROFILE"); iterm != "" {
		// iTerm2 profile names often indicate theme
		profileLower := strings.ToLower(iterm)
		if strings.Contains(profileLower, "dark") || strings.Contains(profileLower, "night") {
			info.ThemeType = "dark"
			return info
		}
		if strings.Contains(profileLower, "light") || strings.Contains(profileLower, "day") {
			info.ThemeType = "light"
			return info
		}
	}

	// Check Windows Terminal theme
	if wtTheme := os.Getenv("WT_PROFILE_ID"); wtTheme != "" {
		// Windows Terminal can set theme info
		if theme := os.Getenv("WT_THEME"); theme != "" {
			info.ThemeType = strings.ToLower(theme)
			return info
		}
	}

	// Check for VS Code integrated terminal
	if os.Getenv("TERM_PROGRAM") == "vscode" {
		if vscodeTheme := os.Getenv("VSCODE_THEME_KIND"); vscodeTheme != "" {
			info.ThemeType = strings.ToLower(vscodeTheme)
			return info
		}
		// VS Code usually defaults to dark
		info.ThemeType = "dark"
		return info
	}

	return nil
}

// detectFromTerminalQueries tries to query the terminal directly
func detectFromTerminalQueries() *TerminalColorInfo {
	info := &TerminalColorInfo{}

	// Try to query terminal background color using ANSI escape sequences
	if bg, fg := queryTerminalColors(); bg != "" || fg != "" {
		info.Background = bg
		info.Foreground = fg
		
		// Determine theme type based on background brightness
		if bg != "" {
			if isLightColor(bg) {
				info.ThemeType = "light"
			} else {
				info.ThemeType = "dark"
			}
			return info
		}
	}

	return nil
}

// queryTerminalColors attempts to query terminal for actual colors
func queryTerminalColors() (background, foreground string) {
	// This is a simplified version - in practice, you'd need to handle
	// terminal responses more carefully and with timeouts
	
	// Query background color: ESC ] 11 ; ? BEL
	// Query foreground color: ESC ] 10 ; ? BEL
	
	// For now, return empty as this requires complex terminal I/O
	// In a full implementation, you'd:
	// 1. Send the query
	// 2. Read response with timeout
	// 3. Parse the color response
	
	return "", ""
}

// detectFromCommonTerminals uses heuristics for common terminals
func detectFromCommonTerminals() *TerminalColorInfo {
	info := &TerminalColorInfo{}

	termProgram := strings.ToLower(os.Getenv("TERM_PROGRAM"))
	term := strings.ToLower(os.Getenv("TERM"))

	switch {
	case termProgram == "iterm.app":
		// iTerm2 - check for common profile indicators
		info.ThemeType = "dark" // iTerm2 commonly uses dark themes
		info.AccentColor = "#007AFF" // macOS system blue
		return info

	case termProgram == "apple_terminal":
		// macOS Terminal.app - often light by default
		info.ThemeType = "light"
		info.AccentColor = "#007AFF" // macOS system blue
		return info

	case termProgram == "vscode":
		// VS Code integrated terminal
		info.ThemeType = "dark"
		info.AccentColor = "#007ACC" // VS Code blue
		return info

	case strings.Contains(termProgram, "gnome"):
		// GNOME Terminal
		info.ThemeType = "light" // GNOME often defaults to light
		info.AccentColor = "#3584E4" // GNOME blue
		return info

	case termProgram == "ghostty":
		// Ghostty terminal
		info.ThemeType = "light" // Ghostty often defaults to light
		info.AccentColor = "#0066CC" // Nice blue
		return info

	case strings.Contains(termProgram, "alacritty"):
		// Alacritty
		info.ThemeType = "dark" // Alacritty commonly uses dark themes
		info.AccentColor = "#F38BA8" // Alacritty pink/orange
		return info

	case strings.Contains(termProgram, "kitty"):
		// Kitty terminal
		info.ThemeType = "dark" // Kitty commonly uses dark themes
		info.AccentColor = "#89B4FA" // Kitty blue
		return info

	case strings.Contains(term, "xterm"):
		// Generic xterm
		info.ThemeType = "light" // Traditional xterm is light
		info.AccentColor = "#0066CC"
		return info

	case os.Getenv("WSLENV") != "":
		// Windows Subsystem for Linux
		info.ThemeType = "dark" // WSL terminals are often dark
		info.AccentColor = "#0078D4" // Windows blue
		return info
	}

	return nil
}

// isLightColor determines if a color is light or dark
func isLightColor(colorHex string) bool {
	// Remove # if present
	colorHex = strings.TrimPrefix(colorHex, "#")
	
	// Parse RGB values
	if len(colorHex) != 6 {
		return false
	}

	r, err1 := strconv.ParseInt(colorHex[0:2], 16, 0)
	g, err2 := strconv.ParseInt(colorHex[2:4], 16, 0)
	b, err3 := strconv.ParseInt(colorHex[4:6], 16, 0)

	if err1 != nil || err2 != nil || err3 != nil {
		return false
	}

	// Calculate perceived brightness using standard formula
	brightness := (0.299*float64(r) + 0.587*float64(g) + 0.114*float64(b)) / 255.0
	return brightness > 0.5
}

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
			Success:            "#006600", // Darker green for light background
			Error:              "#CC0000", // Darker red for light background
			Warning:            "#B8860B", // Darker yellow for light background
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

// darkenColor darkens a hex color by a given factor (0.0 to 1.0)
func darkenColor(colorHex string, factor float64) string {
	colorHex = strings.TrimPrefix(colorHex, "#")
	
	if len(colorHex) != 6 {
		return colorHex // Return original if invalid
	}

	r, err1 := strconv.ParseInt(colorHex[0:2], 16, 0)
	g, err2 := strconv.ParseInt(colorHex[2:4], 16, 0)
	b, err3 := strconv.ParseInt(colorHex[4:6], 16, 0)

	if err1 != nil || err2 != nil || err3 != nil {
		return colorHex // Return original if parse fails
	}

	// Darken by reducing each component
	r = int64(float64(r) * (1.0 - factor))
	g = int64(float64(g) * (1.0 - factor))
	b = int64(float64(b) * (1.0 - factor))

	// Ensure values stay in valid range
	if r < 0 { r = 0 }
	if g < 0 { g = 0 }
	if b < 0 { b = 0 }
	if r > 255 { r = 255 }
	if g > 255 { g = 255 }
	if b > 255 { b = 255 }

	return fmt.Sprintf("#%02X%02X%02X", r, g, b)
}

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

// GetOptimalTerminalTheme returns the best theme based on actual terminal detection
func GetOptimalTerminalTheme() ColorTheme {
	return CreateThemeFromTerminal()
}