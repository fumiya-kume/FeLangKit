package ui

import (
	"os"
	"strings"
)

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
		info.ThemeType = "dark"      // iTerm2 commonly uses dark themes
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
		info.ThemeType = "light"     // GNOME often defaults to light
		info.AccentColor = "#3584E4" // GNOME blue
		return info

	case termProgram == "ghostty":
		// Ghostty terminal
		info.ThemeType = "light"     // Ghostty often defaults to light
		info.AccentColor = "#0066CC" // Nice blue
		return info

	case strings.Contains(termProgram, "alacritty"):
		// Alacritty
		info.ThemeType = "dark"      // Alacritty commonly uses dark themes
		info.AccentColor = "#F38BA8" // Alacritty pink/orange
		return info

	case strings.Contains(termProgram, "kitty"):
		// Kitty terminal
		info.ThemeType = "dark"      // Kitty commonly uses dark themes
		info.AccentColor = "#89B4FA" // Kitty blue
		return info

	case strings.Contains(term, "xterm"):
		// Generic xterm
		info.ThemeType = "light" // Traditional xterm is light
		info.AccentColor = "#0066CC"
		return info

	case os.Getenv("WSLENV") != "":
		// Windows Subsystem for Linux
		info.ThemeType = "dark"      // WSL terminals are often dark
		info.AccentColor = "#0078D4" // Windows blue
		return info
	}

	return nil
}