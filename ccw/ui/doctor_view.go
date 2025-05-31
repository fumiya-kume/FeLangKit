package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// View rendering and UI composition

func (m DoctorModel) View() string {
	var b strings.Builder

	// Header
	header := doctorHeaderStyle.Render("🩺 CCW Doctor - System Diagnostic")
	b.WriteString(header)
	b.WriteString("\n\n")

	// Status indicator
	if m.checking {
		b.WriteString(statusCheckingStyle.Render("🔄 Running diagnostics..."))
	} else {
		if m.allGood {
			b.WriteString(statusPassStyle.Render("✅ System healthy"))
		} else {
			b.WriteString(statusWarnStyle.Render("⚠️  Issues detected"))
		}
	}
	b.WriteString("\n\n")

	// Sections
	for i, section := range m.sections {
		sectionName := m.getSectionName(section)

		// Section header with cursor
		cursor := "  "
		if i == m.currentSection {
			if m.navigationMode == NavigationSections {
				cursor = "▶ "
			} else {
				cursor = "◆ " // Different indicator when in check navigation mode
			}
		}

		expandIcon := "▼"
		if !m.expanded[section] {
			expandIcon = "▶"
		}

		sectionHeader := fmt.Sprintf("%s%s %s", cursor, expandIcon, sectionName)
		b.WriteString(sectionHeaderStyle.Render(sectionHeader))
		b.WriteString("\n")

		// Section content
		if m.expanded[section] {
			checks := m.checks[section]
			for j, check := range checks {
				b.WriteString(m.renderCheckWithNavigation(check, i, j))
			}
			b.WriteString("\n")
		}
	}

	// Summary
	if !m.checking && len(m.checks[SectionSystemDeps]) > 0 {
		b.WriteString(m.renderSummary())
	}

	// Instructions
	b.WriteString(m.renderInstructions())

	return b.String()
}

func (m DoctorModel) renderCheckWithNavigation(check SystemCheck, sectionIdx, checkIdx int) string {
	var icon string
	var style lipgloss.Style

	switch check.Status {
	case StatusPass:
		icon = "✅"
		style = statusPassStyle
	case StatusWarn:
		icon = "⚠️ "
		style = statusWarnStyle
	case StatusFail:
		icon = "❌"
		style = statusFailStyle
	case StatusChecking:
		icon = "🔄"
		style = statusCheckingStyle
	default:
		icon = "⏳"
		style = subtleStyle
	}

	// Check navigation cursor
	checkCursor := "  "
	if sectionIdx == m.currentSection && checkIdx == m.currentCheck && m.navigationMode == NavigationChecks {
		checkCursor = "→ "
	}

	line := fmt.Sprintf("%s%s %s", checkCursor, icon, check.Name)
	if check.Details != "" {
		line += fmt.Sprintf(": %s", check.Details)
	}

	result := checkItemStyle.Render(style.Render(line)) + "\n"

	// Show description if check is expanded or if it's not pending
	checkKey := fmt.Sprintf("%d-%s", sectionIdx, check.Name)
	if m.checkExpanded[checkKey] && check.Description != "" {
		result += detailsStyle.Render("    📝 "+check.Description) + "\n"
	}

	return result
}

func (m DoctorModel) renderCheck(check SystemCheck) string {
	var icon string
	var style lipgloss.Style

	switch check.Status {
	case StatusPass:
		icon = "✅"
		style = statusPassStyle
	case StatusWarn:
		icon = "⚠️ "
		style = statusWarnStyle
	case StatusFail:
		icon = "❌"
		style = statusFailStyle
	case StatusChecking:
		icon = "🔄"
		style = statusCheckingStyle
	default:
		icon = "⏳"
		style = subtleStyle
	}

	line := fmt.Sprintf("  %s %s", icon, check.Name)
	if check.Details != "" {
		line += fmt.Sprintf(": %s", check.Details)
	}

	result := checkItemStyle.Render(style.Render(line)) + "\n"

	if check.Description != "" && check.Status != StatusPending {
		result += detailsStyle.Render(check.Description) + "\n"
	}

	return result
}

func (m DoctorModel) renderSummary() string {
	var summary strings.Builder

	if m.allGood {
		summary.WriteString("🎉 All critical dependencies are available!\n")
		summary.WriteString("CCW should work correctly in this environment.")
	} else {
		summary.WriteString("❌ Some critical dependencies are missing.\n")
		summary.WriteString("Please install missing tools before using CCW.")
	}

	style := summaryBoxStyle
	if !m.allGood {
		style = style.BorderForeground(lipgloss.Color("#CC0000")).
			Foreground(lipgloss.Color("#CC0000"))
	}

	return style.Render(summary.String()) + "\n"
}

func (m DoctorModel) renderInstructions() string {
	instructions := []string{
		"💡 Navigation:",
		"  ↑/↓ - Navigate sections/checks",
		"  ←/→ - Switch section/check mode",
		"  Enter/Space - Toggle expand",
		"  R - Refresh checks",
		"  Q - Quit | Esc - Back to menu",
	}

	tips := []string{
		"💡 Quick fixes:",
		"  brew install gh              # Install GitHub CLI",
		"  brew install swiftlint       # Install SwiftLint",
		"  export GH_TOKEN=your_token   # Set GitHub token",
		"  export CCW_CONSOLE_MODE=true # Force console mode",
		"  ccw --init-config            # Generate config file",
	}

	navBox := tipsBoxStyle.Render(strings.Join(instructions, "\n"))
	tipsBox := tipsBoxStyle.Render(strings.Join(tips, "\n"))

	return lipgloss.JoinHorizontal(lipgloss.Top, navBox, "  ", tipsBox)
}