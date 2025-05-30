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
	viewport         viewport.Model
	validationResult *types.ValidationResult
	expandedSections map[string]bool // Track which sections are expanded
	cursor           int             // Current section cursor position
	width            int
	height           int
	ready            bool
}

// Section names for navigation and expansion
const (
	SectionLint   = "lint"
	SectionBuild  = "build"
	SectionTest   = "test"
	SectionErrors = "errors"
)

// NewValidationModel creates a new validation results model
func NewValidationModel(result *types.ValidationResult, width, height int) ValidationModel {
	vp := viewport.New(width, height-4) // Reserve space for header and controls
	vp.SetContent("")

	return ValidationModel{
		viewport:         vp,
		validationResult: result,
		expandedSections: make(map[string]bool),
		cursor:           0,
		width:            width,
		height:           height,
		ready:            false,
	}
}

// Init initializes the validation model
func (m ValidationModel) Init() tea.Cmd {
	return nil
}

// Update handles key presses and updates
func (m ValidationModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			sections := m.getSections()
			if m.cursor < len(sections)-1 {
				m.cursor++
			}
		case "enter", " ":
			// Toggle expansion of current section
			sections := m.getSections()
			if m.cursor < len(sections) {
				sectionName := sections[m.cursor]
				m.expandedSections[sectionName] = !m.expandedSections[sectionName]
			}
		case "e":
			// Expand all sections
			for _, section := range m.getSections() {
				m.expandedSections[section] = true
			}
		case "c":
			// Collapse all sections
			for _, section := range m.getSections() {
				m.expandedSections[section] = false
			}
		}
		
		// Update viewport content after navigation changes
		m.viewport.SetContent(m.generateContent())
		
	case tea.WindowSizeMsg:
		if !m.ready {
			m.viewport = viewport.New(msg.Width, msg.Height-4)
			m.viewport.SetContent(m.generateContent())
			m.ready = true
		} else {
			m.width = msg.Width
			m.height = msg.Height
			m.viewport.Width = msg.Width
			m.viewport.Height = msg.Height - 4
			m.viewport.SetContent(m.generateContent())
		}
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// View renders the validation results
func (m ValidationModel) View() string {
	if !m.ready {
		return "Loading validation results..."
	}

	header := m.renderHeader()
	content := m.viewport.View()
	footer := m.renderFooter()

	return lipgloss.JoinVertical(lipgloss.Left,
		header,
		content,
		footer,
	)
}

// renderHeader creates the header with title and summary
func (m ValidationModel) renderHeader() string {
	if m.validationResult == nil {
		return headerStyle.Render("🔍 Validation Results - No Data")
	}

	icon := "✅"
	status := "PASSED"
	statusColor := successStyle
	
	if !m.validationResult.Success {
		icon = "❌"
		status = "FAILED"
		statusColor = errorStyle
	}

	title := fmt.Sprintf("%s Validation Results - %s", icon, statusColor.Render(status))
	duration := fmt.Sprintf("Duration: %s", m.validationResult.Duration.Round(time.Millisecond))
	
	return headerStyle.Render(
		lipgloss.JoinHorizontal(lipgloss.Top,
			title,
			lipgloss.NewStyle().Width(m.width-lipgloss.Width(title)-lipgloss.Width(duration)-6).Render(""),
			subtleStyle.Render(duration),
		),
	)
}

// renderFooter creates the footer with navigation instructions
func (m ValidationModel) renderFooter() string {
	controls := []string{
		"↑/↓: Navigate",
		"Enter/Space: Expand/Collapse",
		"e: Expand All",
		"c: Collapse All",
		"q/Esc: Quit",
	}

	return subtleStyle.Render(strings.Join(controls, " • "))
}

// getSections returns the list of available sections
func (m ValidationModel) getSections() []string {
	sections := []string{}
	
	if m.validationResult.LintResult != nil {
		sections = append(sections, SectionLint)
	}
	if m.validationResult.BuildResult != nil {
		sections = append(sections, SectionBuild)
	}
	if m.validationResult.TestResult != nil {
		sections = append(sections, SectionTest)
	}
	if len(m.validationResult.Errors) > 0 {
		sections = append(sections, SectionErrors)
	}
	
	return sections
}

// generateContent creates the main content for the viewport
func (m ValidationModel) generateContent() string {
	if m.validationResult == nil {
		return "No validation results available."
	}

	var content strings.Builder
	sections := m.getSections()

	for i, section := range sections {
		// Add cursor indicator
		cursor := "  "
		if i == m.cursor {
			cursor = "▶ "
		}

		// Render section
		sectionContent := m.renderSection(section, i == m.cursor)
		content.WriteString(cursor + sectionContent)
		
		// Add spacing between sections
		if i < len(sections)-1 {
			content.WriteString("\n\n")
		}
	}

	return content.String()
}

// renderSection renders an individual section
func (m ValidationModel) renderSection(section string, isSelected bool) string {
	expanded := m.expandedSections[section]
	
	switch section {
	case SectionLint:
		return m.renderLintSection(expanded, isSelected)
	case SectionBuild:
		return m.renderBuildSection(expanded, isSelected)
	case SectionTest:
		return m.renderTestSection(expanded, isSelected)
	case SectionErrors:
		return m.renderErrorsSection(expanded, isSelected)
	default:
		return ""
	}
}

// renderLintSection renders the SwiftLint results section
func (m ValidationModel) renderLintSection(expanded, isSelected bool) string {
	if m.validationResult.LintResult == nil {
		return ""
	}

	lint := m.validationResult.LintResult
	
	// Section header
	status := "✅ PASSED"
	statusStyle := successStyle
	if !lint.Success {
		status = "❌ FAILED"
		statusStyle = errorStyle
	}

	autoFixInfo := ""
	if lint.AutoFixed {
		autoFixInfo = infoStyle.Render(" (auto-fixed)")
	}

	expandIcon := "▼"
	if !expanded {
		expandIcon = "▶"
	}

	header := fmt.Sprintf("%s SwiftLint: %s%s", expandIcon, statusStyle.Render(status), autoFixInfo)
	
	if isSelected {
		header = selectedMenuItemStyle.Render(header)
	} else {
		header = menuItemStyle.Render(header)
	}

	if !expanded {
		return header
	}

	// Expanded content
	var details strings.Builder
	details.WriteString(header + "\n")

	if lint.Output != "" {
		details.WriteString(subtleStyle.Render("Output:\n"))
		details.WriteString(m.formatOutput(lint.Output))
		details.WriteString("\n")
	}

	if len(lint.Errors) > 0 {
		details.WriteString(errorStyle.Render(fmt.Sprintf("Errors (%d):\n", len(lint.Errors))))
		for _, err := range lint.Errors {
			details.WriteString(errorStyle.Render("  • " + err + "\n"))
		}
	}

	if len(lint.Warnings) > 0 {
		details.WriteString(warningStyle.Render(fmt.Sprintf("Warnings (%d):\n", len(lint.Warnings))))
		for _, warn := range lint.Warnings {
			details.WriteString(warningStyle.Render("  • " + warn + "\n"))
		}
	}

	return details.String()
}

// renderBuildSection renders the build results section
func (m ValidationModel) renderBuildSection(expanded, isSelected bool) string {
	if m.validationResult.BuildResult == nil {
		return ""
	}

	build := m.validationResult.BuildResult
	
	// Section header
	status := "✅ PASSED"
	statusStyle := successStyle
	if !build.Success {
		status = "❌ FAILED"
		statusStyle = errorStyle
	}

	expandIcon := "▼"
	if !expanded {
		expandIcon = "▶"
	}

	header := fmt.Sprintf("%s Build: %s", expandIcon, statusStyle.Render(status))
	
	if isSelected {
		header = selectedMenuItemStyle.Render(header)
	} else {
		header = menuItemStyle.Render(header)
	}

	if !expanded {
		return header
	}

	// Expanded content
	var details strings.Builder
	details.WriteString(header + "\n")

	if build.Output != "" {
		details.WriteString(subtleStyle.Render("Output:\n"))
		details.WriteString(m.formatOutput(build.Output))
		details.WriteString("\n")
	}

	if build.Error != "" {
		details.WriteString(errorStyle.Render("Error:\n"))
		details.WriteString(errorStyle.Render(m.formatOutput(build.Error)))
		details.WriteString("\n")
	}

	return details.String()
}

// renderTestSection renders the test results section
func (m ValidationModel) renderTestSection(expanded, isSelected bool) string {
	if m.validationResult.TestResult == nil {
		return ""
	}

	test := m.validationResult.TestResult
	
	// Section header
	status := "✅ PASSED"
	statusStyle := successStyle
	if !test.Success {
		status = "❌ FAILED"
		statusStyle = errorStyle
	}

	testInfo := ""
	if test.TestCount > 0 {
		testInfo = infoStyle.Render(fmt.Sprintf(" (%d passed, %d failed)", test.Passed, test.Failed))
	}

	expandIcon := "▼"
	if !expanded {
		expandIcon = "▶"
	}

	header := fmt.Sprintf("%s Tests: %s%s", expandIcon, statusStyle.Render(status), testInfo)
	
	if isSelected {
		header = selectedMenuItemStyle.Render(header)
	} else {
		header = menuItemStyle.Render(header)
	}

	if !expanded {
		return header
	}

	// Expanded content
	var details strings.Builder
	details.WriteString(header + "\n")

	if test.TestCount > 0 {
		details.WriteString(infoStyle.Render(fmt.Sprintf("Total Tests: %d\n", test.TestCount)))
		details.WriteString(successStyle.Render(fmt.Sprintf("Passed: %d\n", test.Passed)))
		details.WriteString(errorStyle.Render(fmt.Sprintf("Failed: %d\n", test.Failed)))
	}

	if test.Output != "" {
		details.WriteString(subtleStyle.Render("Output:\n"))
		details.WriteString(m.formatOutput(test.Output))
		details.WriteString("\n")
	}

	return details.String()
}

// renderErrorsSection renders the detailed errors section
func (m ValidationModel) renderErrorsSection(expanded, isSelected bool) string {
	if len(m.validationResult.Errors) == 0 {
		return ""
	}

	expandIcon := "▼"
	if !expanded {
		expandIcon = "▶"
	}

	header := fmt.Sprintf("%s Error Details (%d)", expandIcon, len(m.validationResult.Errors))
	
	if isSelected {
		header = selectedMenuItemStyle.Render(header)
	} else {
		header = menuItemStyle.Render(header)
	}

	if !expanded {
		return header
	}

	// Expanded content
	var details strings.Builder
	details.WriteString(header + "\n")

	for i, err := range m.validationResult.Errors {
		details.WriteString(m.renderValidationError(err, i+1))
		if i < len(m.validationResult.Errors)-1 {
			details.WriteString("\n")
		}
	}

	return details.String()
}

// renderValidationError renders a detailed validation error
func (m ValidationModel) renderValidationError(err types.ValidationError, errorNumber int) string {
	var details strings.Builder

	// Error header
	details.WriteString(errorStyle.Render(fmt.Sprintf("Error %d: [%s] %s\n",
		errorNumber,
		strings.ToUpper(err.Type),
		err.Message)))

	// Error details
	if err.Cause != nil {
		indent := "  "
		
		if err.Cause.Command != "" {
			details.WriteString(fmt.Sprintf("%s%s Command: %s\n",
				indent, infoStyle.Render("🔧"), err.Cause.Command))
		}
		
		if err.Cause.ExitCode != 0 {
			details.WriteString(fmt.Sprintf("%s%s Exit Code: %s\n",
				indent, errorStyle.Render("💥"), errorStyle.Render(fmt.Sprintf("%d", err.Cause.ExitCode))))
		}
		
		if err.Cause.RootError != "" {
			details.WriteString(fmt.Sprintf("%s%s Root Cause: %s\n",
				indent, infoStyle.Render("🔍"), err.Cause.RootError))
		}
		
		if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
			details.WriteString(fmt.Sprintf("%s%s Error Output:\n%s%s\n",
				indent, infoStyle.Render("📄"), indent+"  ", err.Cause.Stderr))
		}
		
		if len(err.Cause.Context) > 0 {
			details.WriteString(fmt.Sprintf("%s%s Context:\n", indent, infoStyle.Render("📋")))
			for key, value := range err.Cause.Context {
				details.WriteString(fmt.Sprintf("%s  %s: %s\n", indent, warningStyle.Render(key), value))
			}
		}
	}
	
	// Recovery suggestion
	if err.Recoverable {
		details.WriteString(fmt.Sprintf("  %s %s: This error may be automatically recoverable\n",
			successStyle.Render("🔄"), successStyle.Render("Recovery")))
	}

	return details.String()
}

// formatOutput formats command output for display
func (m ValidationModel) formatOutput(output string) string {
	lines := strings.Split(strings.TrimSpace(output), "\n")
	var formatted strings.Builder
	
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			formatted.WriteString(fmt.Sprintf("  %s\n", subtleStyle.Render(line)))
		}
	}
	
	return formatted.String()
}

// SetValidationResult updates the validation result and refreshes content
func (m *ValidationModel) SetValidationResult(result *types.ValidationResult) {
	m.validationResult = result
	m.cursor = 0
	m.expandedSections = make(map[string]bool)
	m.viewport.SetContent(m.generateContent())
}

// SetSize updates the model dimensions
func (m *ValidationModel) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.viewport.Width = width
	m.viewport.Height = height - 4
	m.viewport.SetContent(m.generateContent())
}