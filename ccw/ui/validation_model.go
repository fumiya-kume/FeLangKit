package ui

import (
	"fmt"
	"strings"
	"time"

	"ccw/types"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ValidationModel represents an interactive validation results display
type ValidationModel struct {
	result         *types.ValidationResult
	viewport       viewport.Model
	width          int
	height         int
	expandedSections map[string]bool  // Track which sections are expanded
	selectedSection  int              // Currently selected section for navigation
	sections        []string          // Available sections (lint, build, test, errors)
	ready           bool
}

// NewValidationModel creates a new validation model
func NewValidationModel(result *types.ValidationResult, width, height int) ValidationModel {
	vp := viewport.New(width, height-4) // Leave space for header and footer
	vp.YPosition = 2

	sections := []string{}
	expandedSections := make(map[string]bool)
	
	if result.LintResult != nil {
		sections = append(sections, "lint")
		expandedSections["lint"] = false
	}
	if result.BuildResult != nil {
		sections = append(sections, "build")
		expandedSections["build"] = false
	}
	if result.TestResult != nil {
		sections = append(sections, "test")
		expandedSections["test"] = false
	}
	if len(result.Errors) > 0 {
		sections = append(sections, "errors")
		expandedSections["errors"] = false
	}

	model := ValidationModel{
		result:          result,
		viewport:        vp,
		width:          width,
		height:         height,
		expandedSections: expandedSections,
		selectedSection: 0,
		sections:       sections,
		ready:          false,
	}

	model.updateContent()
	return model
}

// Init implements tea.Model
func (m ValidationModel) Init() tea.Cmd {
	return nil
}

// Update implements tea.Model
func (m ValidationModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.selectedSection > 0 {
				m.selectedSection--
			}
		case "down", "j":
			if m.selectedSection < len(m.sections)-1 {
				m.selectedSection++
			}
		case "enter", " ":
			// Toggle expanded state of selected section
			if m.selectedSection < len(m.sections) {
				section := m.sections[m.selectedSection]
				m.expandedSections[section] = !m.expandedSections[section]
				m.updateContent()
			}
		case "o":
			// Expand all sections
			for section := range m.expandedSections {
				m.expandedSections[section] = true
			}
			m.updateContent()
		case "c":
			// Collapse all sections
			for section := range m.expandedSections {
				m.expandedSections[section] = false
			}
			m.updateContent()
		}

	case tea.WindowSizeMsg:
		if !m.ready {
			m.viewport = viewport.New(msg.Width, msg.Height-4)
			m.viewport.YPosition = 2
			m.width = msg.Width
			m.height = msg.Height
			m.updateContent()
			m.ready = true
		} else {
			m.width = msg.Width
			m.height = msg.Height
			m.viewport.Width = msg.Width
			m.viewport.Height = msg.Height - 4
			m.updateContent()
		}
	}

	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// View implements tea.Model
func (m ValidationModel) View() string {
	if !m.ready {
		return "Loading validation results..."
	}

	header := m.renderHeader()
	footer := m.renderFooter()
	
	return lipgloss.JoinVertical(lipgloss.Left,
		header,
		m.viewport.View(),
		footer,
	)
}

// renderHeader creates the header with title and overall status
func (m ValidationModel) renderHeader() string {
	title := "🔍 Validation Results"
	
	var overallStatus string
	var statusStyle lipgloss.Style
	
	if m.result.Success {
		overallStatus = "✅ PASSED"
		statusStyle = successStyle
	} else {
		overallStatus = "❌ FAILED"
		statusStyle = errorStyle
	}
	
	duration := m.result.Duration.Round(time.Millisecond)
	
	header := lipgloss.JoinHorizontal(lipgloss.Top,
		titleStyle.Render(title),
		lipgloss.NewStyle().Width(5).Render(""), // Spacer
		statusStyle.Render(overallStatus),
		lipgloss.NewStyle().Width(5).Render(""), // Spacer
		subtleStyle.Render(fmt.Sprintf("⏱ %s", duration)),
	)
	
	return lipgloss.NewStyle().
		Width(m.width).
		Padding(0, 1).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#0066CC")).
		Render(header)
}

// renderFooter creates the footer with navigation instructions
func (m ValidationModel) renderFooter() string {
	controls := []string{
		"↑/↓: navigate",
		"Space/Enter: toggle details",
		"o: expand all",
		"c: collapse all",
		"q/Esc: quit",
	}
	
	return subtleStyle.Render(strings.Join(controls, " • "))
}

// updateContent generates the content for the viewport
func (m ValidationModel) updateContent() {
	var content strings.Builder
	
	for i, section := range m.sections {
		isSelected := i == m.selectedSection
		isExpanded := m.expandedSections[section]
		
		sectionContent := m.renderSection(section, isSelected, isExpanded)
		content.WriteString(sectionContent)
		content.WriteString("\n")
	}
	
	m.viewport.SetContent(content.String())
}

// renderSection renders a validation section (lint, build, test, or errors)
func (m ValidationModel) renderSection(section string, isSelected, isExpanded bool) string {
	var sectionStyle lipgloss.Style
	var headerContent string
	var detailContent string
	
	// Define base styles
	normalStyle := lipgloss.NewStyle().
		Padding(0, 1).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#666666"))
		
	selectedStyle := lipgloss.NewStyle().
		Padding(0, 1).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#0066CC")).
		Background(lipgloss.Color("#E6F3FF"))
	
	if isSelected {
		sectionStyle = selectedStyle
	} else {
		sectionStyle = normalStyle
	}
	
	switch section {
	case "lint":
		headerContent, detailContent = m.renderLintSection(isExpanded)
	case "build":
		headerContent, detailContent = m.renderBuildSection(isExpanded)
	case "test":
		headerContent, detailContent = m.renderTestSection(isExpanded)
	case "errors":
		headerContent, detailContent = m.renderErrorsSection(isExpanded)
	}
	
	// Add expansion indicator
	expandIcon := "▶"
	if isExpanded {
		expandIcon = "▼"
	}
	
	header := fmt.Sprintf("%s %s", expandIcon, headerContent)
	
	if isExpanded && detailContent != "" {
		content := lipgloss.JoinVertical(lipgloss.Left,
			header,
			"",
			detailContent,
		)
		return sectionStyle.Render(content)
	}
	
	return sectionStyle.Render(header)
}

// renderLintSection renders the lint validation section
func (m ValidationModel) renderLintSection(isExpanded bool) (string, string) {
	result := m.result.LintResult
	
	var statusIcon, statusText string
	var statusStyle lipgloss.Style
	
	if result.Success {
		statusIcon = "✅"
		statusText = "PASSED"
		statusStyle = successStyle
	} else {
		statusIcon = "❌"
		statusText = "FAILED"
		statusStyle = errorStyle
	}
	
	header := fmt.Sprintf("%s SwiftLint: %s", statusIcon, statusStyle.Render(statusText))
	
	if result.AutoFixed {
		header += infoStyle.Render(" (auto-fixed)")
	}
	
	if !isExpanded {
		return header, ""
	}
	
	var details strings.Builder
	
	if result.Output != "" {
		details.WriteString(subtleStyle.Render("Output:") + "\n")
		details.WriteString(result.Output + "\n")
	}
	
	if len(result.Errors) > 0 {
		details.WriteString(errorStyle.Render("Errors:") + "\n")
		for _, err := range result.Errors {
			details.WriteString("  • " + err + "\n")
		}
	}
	
	if len(result.Warnings) > 0 {
		details.WriteString(warningStyle.Render("Warnings:") + "\n")
		for _, warning := range result.Warnings {
			details.WriteString("  • " + warning + "\n")
		}
	}
	
	return header, details.String()
}

// renderBuildSection renders the build validation section
func (m ValidationModel) renderBuildSection(isExpanded bool) (string, string) {
	result := m.result.BuildResult
	
	var statusIcon, statusText string
	var statusStyle lipgloss.Style
	
	if result.Success {
		statusIcon = "✅"
		statusText = "PASSED"
		statusStyle = successStyle
	} else {
		statusIcon = "❌"
		statusText = "FAILED"
		statusStyle = errorStyle
	}
	
	header := fmt.Sprintf("%s Build: %s", statusIcon, statusStyle.Render(statusText))
	
	if !isExpanded {
		return header, ""
	}
	
	var details strings.Builder
	
	if result.Output != "" {
		details.WriteString(subtleStyle.Render("Output:") + "\n")
		details.WriteString(result.Output + "\n")
	}
	
	if result.Error != "" {
		details.WriteString(errorStyle.Render("Error:") + "\n")
		details.WriteString(result.Error + "\n")
	}
	
	return header, details.String()
}

// renderTestSection renders the test validation section
func (m ValidationModel) renderTestSection(isExpanded bool) (string, string) {
	result := m.result.TestResult
	
	var statusIcon, statusText string
	var statusStyle lipgloss.Style
	
	if result.Success {
		statusIcon = "✅"
		statusText = "PASSED"
		statusStyle = successStyle
	} else {
		statusIcon = "❌"
		statusText = "FAILED"
		statusStyle = errorStyle
	}
	
	header := fmt.Sprintf("%s Tests: %s", statusIcon, statusStyle.Render(statusText))
	
	if result.TestCount > 0 {
		header += infoStyle.Render(fmt.Sprintf(" (%d passed, %d failed)", result.Passed, result.Failed))
	}
	
	if !isExpanded {
		return header, ""
	}
	
	var details strings.Builder
	
	if result.TestCount > 0 {
		details.WriteString(infoStyle.Render("Test Summary:") + "\n")
		details.WriteString(fmt.Sprintf("  Total: %d\n", result.TestCount))
		details.WriteString(fmt.Sprintf("  Passed: %d\n", result.Passed))
		details.WriteString(fmt.Sprintf("  Failed: %d\n", result.Failed))
		details.WriteString("\n")
	}
	
	if result.Output != "" {
		details.WriteString(subtleStyle.Render("Output:") + "\n")
		details.WriteString(result.Output + "\n")
	}
	
	return header, details.String()
}

// renderErrorsSection renders the errors validation section
func (m ValidationModel) renderErrorsSection(isExpanded bool) (string, string) {
	errorCount := len(m.result.Errors)
	
	header := fmt.Sprintf("⚠️ Error Details: %s", errorStyle.Render(fmt.Sprintf("%d errors", errorCount)))
	
	if !isExpanded {
		return header, ""
	}
	
	var details strings.Builder
	
	for i, err := range m.result.Errors {
		details.WriteString(errorStyle.Render(fmt.Sprintf("Error %d: [%s] %s", i+1, strings.ToUpper(err.Type), err.Message)) + "\n")
		
		if err.File != "" {
			details.WriteString(subtleStyle.Render(fmt.Sprintf("  File: %s", err.File)))
			if err.Line > 0 {
				details.WriteString(subtleStyle.Render(fmt.Sprintf(":%d", err.Line)))
			}
			details.WriteString("\n")
		}
		
		if err.Cause != nil {
			if err.Cause.Command != "" {
				details.WriteString(subtleStyle.Render(fmt.Sprintf("  Command: %s", err.Cause.Command)) + "\n")
			}
			if err.Cause.ExitCode != 0 {
				details.WriteString(subtleStyle.Render(fmt.Sprintf("  Exit Code: %d", err.Cause.ExitCode)) + "\n")
			}
			if err.Cause.RootError != "" {
				details.WriteString(subtleStyle.Render(fmt.Sprintf("  Root Cause: %s", err.Cause.RootError)) + "\n")
			}
			if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
				details.WriteString(subtleStyle.Render("  Error Output:") + "\n")
				details.WriteString("    " + err.Cause.Stderr + "\n")
			}
			if len(err.Cause.Context) > 0 {
				details.WriteString(subtleStyle.Render("  Context:") + "\n")
				for key, value := range err.Cause.Context {
					details.WriteString(fmt.Sprintf("    %s: %s\n", key, value))
				}
			}
		}
		
		if err.Recoverable {
			details.WriteString(successStyle.Render("  ♻️ This error may be automatically recoverable") + "\n")
		}
		
		if i < len(m.result.Errors)-1 {
			details.WriteString("\n")
		}
	}
	
	return header, details.String()
}