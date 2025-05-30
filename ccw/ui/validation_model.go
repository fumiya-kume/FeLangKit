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

// ValidationModel provides interactive display of validation results
type ValidationModel struct {
	result     *types.ValidationResult
	viewport   viewport.Model
	width      int
	height     int
	ready      bool
	sections   []ValidationSection
	cursor     int
	ui         *UIManager
}

// ValidationSection represents an expandable section of validation results
type ValidationSection struct {
	Title     string
	Content   string
	Expanded  bool
	Type      string // "lint", "build", "test", "errors"
	Success   bool
	AutoFixed bool
}

// NewValidationModel creates a new validation model
func NewValidationModel(result *types.ValidationResult, ui *UIManager) ValidationModel {
	m := ValidationModel{
		result: result,
		ui:     ui,
		ready:  false,
		cursor: 0,
	}
	
	m.buildSections()
	return m
}

// buildSections creates the expandable sections from validation results
func (m *ValidationModel) buildSections() {
	m.sections = []ValidationSection{}
	
	// Add lint section
	if m.result.LintResult != nil {
		content := m.buildLintContent(m.result.LintResult)
		m.sections = append(m.sections, ValidationSection{
			Title:     "SwiftLint",
			Content:   content,
			Expanded:  !m.result.LintResult.Success, // Auto-expand if failed
			Type:      "lint",
			Success:   m.result.LintResult.Success,
			AutoFixed: m.result.LintResult.AutoFixed,
		})
	}
	
	// Add build section
	if m.result.BuildResult != nil {
		content := m.buildBuildContent(m.result.BuildResult)
		m.sections = append(m.sections, ValidationSection{
			Title:    "Build",
			Content:  content,
			Expanded: !m.result.BuildResult.Success, // Auto-expand if failed
			Type:     "build",
			Success:  m.result.BuildResult.Success,
		})
	}
	
	// Add test section
	if m.result.TestResult != nil {
		content := m.buildTestContent(m.result.TestResult)
		m.sections = append(m.sections, ValidationSection{
			Title:    "Tests",
			Content:  content,
			Expanded: !m.result.TestResult.Success, // Auto-expand if failed
			Type:     "test",
			Success:  m.result.TestResult.Success,
		})
	}
	
	// Add errors section if there are errors
	if len(m.result.Errors) > 0 {
		content := m.buildErrorsContent(m.result.Errors)
		m.sections = append(m.sections, ValidationSection{
			Title:    "Error Details",
			Content:  content,
			Expanded: true, // Always expand errors
			Type:     "errors",
			Success:  false,
		})
	}
}

// buildLintContent creates content for the lint section
func (m *ValidationModel) buildLintContent(lint *types.LintResult) string {
	var content strings.Builder
	
	if lint.Success {
		content.WriteString("✅ All lint checks passed successfully\n")
		if lint.AutoFixed {
			content.WriteString("🔧 Some issues were automatically fixed\n")
		}
	} else {
		content.WriteString("❌ Lint checks failed\n")
	}
	
	if len(lint.Errors) > 0 {
		content.WriteString("\n📋 Errors:\n")
		for i, err := range lint.Errors {
			content.WriteString(fmt.Sprintf("  %d. %s\n", i+1, err))
		}
	}
	
	if len(lint.Warnings) > 0 {
		content.WriteString("\n⚠️  Warnings:\n")
		for i, warning := range lint.Warnings {
			content.WriteString(fmt.Sprintf("  %d. %s\n", i+1, warning))
		}
	}
	
	if lint.Output != "" && lint.Output != strings.Join(lint.Errors, "\n") {
		content.WriteString("\n📄 Full Output:\n")
		content.WriteString(lint.Output)
	}
	
	return content.String()
}

// buildBuildContent creates content for the build section
func (m *ValidationModel) buildBuildContent(build *types.BuildResult) string {
	var content strings.Builder
	
	if build.Success {
		content.WriteString("✅ Build completed successfully\n")
	} else {
		content.WriteString("❌ Build failed\n")
	}
	
	if build.Error != "" {
		content.WriteString("\n🚫 Error:\n")
		content.WriteString(build.Error)
		content.WriteString("\n")
	}
	
	if build.Output != "" {
		content.WriteString("\n📄 Build Output:\n")
		content.WriteString(build.Output)
	}
	
	return content.String()
}

// buildTestContent creates content for the test section
func (m *ValidationModel) buildTestContent(test *types.TestResult) string {
	var content strings.Builder
	
	if test.Success {
		content.WriteString("✅ All tests passed\n")
	} else {
		content.WriteString("❌ Some tests failed\n")
	}
	
	if test.TestCount > 0 {
		content.WriteString(fmt.Sprintf("\n📊 Test Summary:\n"))
		content.WriteString(fmt.Sprintf("  Total:  %d\n", test.TestCount))
		content.WriteString(fmt.Sprintf("  Passed: %d\n", test.Passed))
		content.WriteString(fmt.Sprintf("  Failed: %d\n", test.Failed))
	}
	
	if test.Output != "" {
		content.WriteString("\n📄 Test Output:\n")
		content.WriteString(test.Output)
	}
	
	return content.String()
}

// buildErrorsContent creates content for the errors section
func (m *ValidationModel) buildErrorsContent(errors []types.ValidationError) string {
	var content strings.Builder
	
	for i, err := range errors {
		content.WriteString(fmt.Sprintf("⚠️  Error %d: [%s] %s\n", 
			i+1, strings.ToUpper(err.Type), err.Message))
		
		if err.Cause != nil {
			if err.Cause.Command != "" {
				content.WriteString(fmt.Sprintf("  🔧 Command: %s\n", err.Cause.Command))
			}
			
			if err.Cause.ExitCode != 0 {
				content.WriteString(fmt.Sprintf("  💥 Exit Code: %d\n", err.Cause.ExitCode))
			}
			
			if err.Cause.RootError != "" {
				content.WriteString(fmt.Sprintf("  🔍 Root Cause: %s\n", err.Cause.RootError))
			}
			
			if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
				content.WriteString(fmt.Sprintf("  📄 Error Output:\n    %s\n", 
					strings.ReplaceAll(err.Cause.Stderr, "\n", "\n    ")))
			}
			
			if len(err.Cause.Context) > 0 {
				content.WriteString("  📋 Context:\n")
				for key, value := range err.Cause.Context {
					content.WriteString(fmt.Sprintf("    %s: %s\n", key, value))
				}
			}
		}
		
		if err.Recoverable {
			content.WriteString("  🔄 This error may be automatically recoverable\n")
		}
		
		if i < len(errors)-1 {
			content.WriteString("\n")
		}
	}
	
	return content.String()
}

// Init implements tea.Model
func (m ValidationModel) Init() tea.Cmd {
	return nil
}

// Update implements tea.Model
func (m ValidationModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		if !m.ready {
			m.viewport = viewport.New(msg.Width, msg.Height-6) // Leave space for header and controls
			m.viewport.SetContent(m.generateContent())
			m.ready = true
		} else {
			m.viewport.Width = msg.Width
			m.viewport.Height = msg.Height - 6
		}
		m.width = msg.Width
		m.height = msg.Height
		
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.sections)-1 {
				m.cursor++
			}
		case "enter", " ":
			// Toggle expansion of current section
			if m.cursor < len(m.sections) {
				m.sections[m.cursor].Expanded = !m.sections[m.cursor].Expanded
				m.viewport.SetContent(m.generateContent())
			}
		case "e":
			// Expand all sections
			for i := range m.sections {
				m.sections[i].Expanded = true
			}
			m.viewport.SetContent(m.generateContent())
		case "c":
			// Collapse all sections
			for i := range m.sections {
				m.sections[i].Expanded = false
			}
			m.viewport.SetContent(m.generateContent())
		case "r":
			// Refresh content
			m.buildSections()
			m.viewport.SetContent(m.generateContent())
		}
	}
	
	// Update viewport
	m.viewport, cmd = m.viewport.Update(msg)
	
	return m, cmd
}

// View implements tea.Model
func (m ValidationModel) View() string {
	if !m.ready {
		return "Loading validation results..."
	}
	
	// Header with overall status
	header := m.renderHeader()
	
	// Main content (viewport)
	content := m.viewport.View()
	
	// Footer with controls
	footer := m.renderFooter()
	
	return lipgloss.JoinVertical(lipgloss.Left,
		header,
		content,
		footer,
	)
}

// renderHeader creates the validation results header
func (m ValidationModel) renderHeader() string {
	// Overall status indicator
	var overallIcon string
	var overallStatus string
	var statusStyle lipgloss.Style
	
	if m.result.Success {
		overallIcon = "✅"
		overallStatus = "PASSED"
		statusStyle = successStyle
	} else {
		overallIcon = "❌"
		overallStatus = "FAILED"
		statusStyle = errorStyle
	}
	
	title := fmt.Sprintf("%s Validation Results - %s", overallIcon, overallStatus)
	duration := fmt.Sprintf("Duration: %s", m.result.Duration.Round(time.Millisecond))
	
	headerContent := lipgloss.JoinHorizontal(lipgloss.Top,
		statusStyle.Render(title),
		lipgloss.NewStyle().Width(m.width-lipgloss.Width(title)-lipgloss.Width(duration)-2).Render(""),
		subtleStyle.Render(duration),
	)
	
	return headerStyle.Render(headerContent) + "\n"
}

// renderFooter creates the controls footer
func (m ValidationModel) renderFooter() string {
	controls := []string{
		"↑/↓ Navigate",
		"Enter/Space Toggle",
		"e Expand All",
		"c Collapse All",
		"r Refresh",
		"q Quit",
	}
	
	footerText := subtleStyle.Render(strings.Join(controls, " • "))
	
	return "\n" + lipgloss.NewStyle().
		Width(m.width).
		Background(lipgloss.Color("#222222")).
		Foreground(lipgloss.Color("#CCCCCC")).
		Padding(0, 1).
		Render(footerText)
}

// generateContent creates the scrollable content for the viewport
func (m ValidationModel) generateContent() string {
	var content strings.Builder
	
	for i, section := range m.sections {
		// Section header with cursor indicator
		cursor := "  "
		if i == m.cursor {
			cursor = "▶ "
		}
		
		// Status indicator
		var statusIcon string
		var titleStyle lipgloss.Style
		if section.Type == "errors" {
			statusIcon = "❌"
			titleStyle = errorStyle
		} else if section.Success {
			statusIcon = "✅"
			titleStyle = successStyle
		} else {
			statusIcon = "❌"
			titleStyle = errorStyle
		}
		
		// Auto-fixed indicator
		autoFixedIndicator := ""
		if section.AutoFixed {
			autoFixedIndicator = " 🔧"
		}
		
		// Expansion indicator
		expandIcon := "▼"
		if !section.Expanded {
			expandIcon = "▶"
		}
		
		sectionHeader := fmt.Sprintf("%s%s %s %s%s",
			cursor, expandIcon, statusIcon, section.Title, autoFixedIndicator)
		
		if i == m.cursor {
			content.WriteString(selectedMenuItemStyle.Render(sectionHeader))
		} else {
			content.WriteString(titleStyle.Render(sectionHeader))
		}
		content.WriteString("\n")
		
		// Section content (if expanded)
		if section.Expanded {
			// Indent content
			lines := strings.Split(section.Content, "\n")
			for _, line := range lines {
				if line != "" {
					content.WriteString("    " + line + "\n")
				} else {
					content.WriteString("\n")
				}
			}
		}
		
		// Add spacing between sections
		if i < len(m.sections)-1 {
			content.WriteString("\n")
		}
	}
	
	return content.String()
}

// SetSize updates the model dimensions
func (m *ValidationModel) SetSize(width, height int) {
	m.width = width
	m.height = height
	if m.ready {
		m.viewport.Width = width
		m.viewport.Height = height - 6
	}
}

// GetResult returns the validation result
func (m *ValidationModel) GetResult() *types.ValidationResult {
	return m.result
}

// SetResult updates the validation result and rebuilds sections
func (m *ValidationModel) SetResult(result *types.ValidationResult) {
	m.result = result
	m.buildSections()
	if m.ready {
		m.viewport.SetContent(m.generateContent())
	}
}