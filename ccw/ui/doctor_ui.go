package ui

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"ccw/config"
	"ccw/github"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Doctor UI states and models

type DoctorSection int

const (
	SectionSystemDeps DoctorSection = iota
	SectionUIConfig
	SectionGitRepo
	SectionEnvironment
	SectionConfiguration
)

type CheckStatus int

const (
	StatusPending CheckStatus = iota
	StatusChecking
	StatusPass
	StatusWarn
	StatusFail
)

type SystemCheck struct {
	Name        string
	Description string
	Status      CheckStatus
	Details     string
	Critical    bool
}

type DoctorModel struct {
	sections       []DoctorSection
	currentSection int
	currentCheck   int
	expanded       map[DoctorSection]bool
	checkExpanded  map[string]bool
	checks         map[DoctorSection][]SystemCheck
	windowSize     tea.WindowSizeMsg
	checking       bool
	allGood        bool
	config         *config.CCWConfig
	configErr      error
	navigationMode NavigationMode
}

type NavigationMode int

const (
	NavigationSections NavigationMode = iota
	NavigationChecks
)

// Doctor-specific styles
var (
	doctorHeaderStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFFFFF")).
				Background(lipgloss.Color("#0066CC")).
				Padding(1, 2).
				Bold(true).
				Width(80).
				Align(lipgloss.Center)

	sectionHeaderStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#0066CC")).
				Bold(true).
				Padding(0, 1).
				Border(lipgloss.NormalBorder(), false, false, false, true).
				BorderForeground(lipgloss.Color("#0066CC"))

	checkItemStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	statusPassStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00AA00")).
			Bold(true)

	statusWarnStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF6600")).
			Bold(true)

	statusFailStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CC0000")).
			Bold(true)

	statusCheckingStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#0066CC")).
				Bold(true)

	detailsStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#666666")).
			PaddingLeft(4)

	summaryBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#00AA00")).
			Foreground(lipgloss.Color("#00AA00")).
			Padding(1, 2).
			Margin(1, 0)

	tipsBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#0066CC")).
			Foreground(lipgloss.Color("#0066CC")).
			Padding(1, 2).
			Margin(1, 0)
)

// Initialize doctor model
func NewDoctorModel() DoctorModel {
	sections := []DoctorSection{
		SectionSystemDeps,
		SectionUIConfig,
		SectionGitRepo,
		SectionEnvironment,
		SectionConfiguration,
	}

	expanded := make(map[DoctorSection]bool)
	checkExpanded := make(map[string]bool)
	checks := make(map[DoctorSection][]SystemCheck)

	// Initialize all sections as expanded by default
	for _, section := range sections {
		expanded[section] = true
		checks[section] = []SystemCheck{}
	}

	// Load configuration
	ccwConfig, configErr := config.LoadConfiguration()

	return DoctorModel{
		sections:       sections,
		currentSection: 0,
		currentCheck:   0,
		expanded:       expanded,
		checkExpanded:  checkExpanded,
		checks:         checks,
		checking:       false,
		config:         ccwConfig,
		configErr:      configErr,
		navigationMode: NavigationSections,
	}
}

func (m DoctorModel) Init() tea.Cmd {
	// Start checking systems
	return tea.Batch(
		runSystemChecks(),
		tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
			return tickMsg(t)
		}),
	)
}

func (m DoctorModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "esc":
			// For integrated mode, return a custom message to go back to main menu
			return m, func() tea.Msg { return BackToMainMenuMsg{} }
		case "up", "k":
			if m.navigationMode == NavigationSections {
				if m.currentSection > 0 {
					m.currentSection--
				}
			} else if m.navigationMode == NavigationChecks {
				if m.currentCheck > 0 {
					m.currentCheck--
				}
			}
		case "down", "j":
			if m.navigationMode == NavigationSections {
				if m.currentSection < len(m.sections)-1 {
					m.currentSection++
				}
			} else if m.navigationMode == NavigationChecks {
				currentSectionChecks := m.checks[m.sections[m.currentSection]]
				if m.currentCheck < len(currentSectionChecks)-1 {
					m.currentCheck++
				}
			}
		case "enter", " ":
			if m.navigationMode == NavigationSections {
				// Toggle current section
				section := m.sections[m.currentSection]
				m.expanded[section] = !m.expanded[section]
			} else if m.navigationMode == NavigationChecks {
				// Toggle current check details
				currentSectionChecks := m.checks[m.sections[m.currentSection]]
				if m.currentCheck < len(currentSectionChecks) {
					check := currentSectionChecks[m.currentCheck]
					checkKey := fmt.Sprintf("%d-%s", m.currentSection, check.Name)
					m.checkExpanded[checkKey] = !m.checkExpanded[checkKey]
				}
			}
		case "right", "l":
			// Enter check navigation mode if section is expanded
			section := m.sections[m.currentSection]
			if m.expanded[section] && len(m.checks[section]) > 0 {
				m.navigationMode = NavigationChecks
				m.currentCheck = 0
			}
		case "left", "h":
			// Return to section navigation mode
			if m.navigationMode == NavigationChecks {
				m.navigationMode = NavigationSections
			}
		case "r":
			// Refresh checks
			m.checking = true
			return m, runSystemChecks()
		}

	case tea.WindowSizeMsg:
		m.windowSize = msg

	case systemCheckResultMsg:
		m.checks[msg.Section] = msg.Checks
		if msg.Section == SectionSystemDeps {
			// Calculate overall health
			m.allGood = true
			for _, check := range msg.Checks {
				if check.Critical && check.Status == StatusFail {
					m.allGood = false
					break
				}
			}
		}

	case checksCompleteMsg:
		m.checking = false

	case tickMsg:
		// Continue ticking for animations
		return m, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
			return tickMsg(t)
		})
	}

	return m, nil
}

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

func (m DoctorModel) getSectionName(section DoctorSection) string {
	switch section {
	case SectionSystemDeps:
		return "System Dependencies"
	case SectionUIConfig:
		return "UI Configuration"
	case SectionGitRepo:
		return "Git Repository"
	case SectionEnvironment:
		return "Environment"
	case SectionConfiguration:
		return "Configuration"
	default:
		return "Unknown"
	}
}

// Messages for async operations
type systemCheckResultMsg struct {
	Section DoctorSection
	Checks  []SystemCheck
}

type checksCompleteMsg struct{}

type tickMsg time.Time

// Commands for running checks
func runSystemChecks() tea.Cmd {
	return tea.Batch(
		checkSystemDependencies(),
		checkUIConfiguration(),
		checkGitRepository(),
		checkEnvironment(),
		checkConfiguration(),
	)
}

func checkSystemDependencies() tea.Cmd {
	return func() tea.Msg {
		checks := []SystemCheck{
			{
				Name:        "Go Version",
				Description: "Go programming language runtime",
				Status:      StatusPass,
				Details:     runtime.Version(),
				Critical:    true,
			},
		}

		// Check Git
		if checkCommandAvailable("git") {
			if version := getCommandVersion("git", "--version"); version != "" {
				checks = append(checks, SystemCheck{
					Name:        "Git",
					Description: "Version control system",
					Status:      StatusPass,
					Details:     version,
					Critical:    true,
				})
			} else {
				checks = append(checks, SystemCheck{
					Name:        "Git",
					Description: "Version control system",
					Status:      StatusPass,
					Details:     "available",
					Critical:    true,
				})
			}
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Git",
				Description: "Version control system - REQUIRED",
				Status:      StatusFail,
				Details:     "not found",
				Critical:    true,
			})
		}

		// Check GitHub CLI
		if checkCommandAvailable("gh") {
			if version := getCommandVersion("gh", "--version"); version != "" {
				checks = append(checks, SystemCheck{
					Name:        "GitHub CLI",
					Description: "GitHub command line interface",
					Status:      StatusPass,
					Details:     strings.Split(version, "\n")[0],
					Critical:    true,
				})
			} else {
				checks = append(checks, SystemCheck{
					Name:        "GitHub CLI",
					Description: "GitHub command line interface",
					Status:      StatusPass,
					Details:     "available",
					Critical:    true,
				})
			}
		} else {
			checks = append(checks, SystemCheck{
				Name:        "GitHub CLI (gh)",
				Description: "GitHub command line interface - REQUIRED",
				Status:      StatusFail,
				Details:     "not found",
				Critical:    true,
			})
		}

		// Check Claude Code CLI
		if checkCommandAvailable("claude") {
			checks = append(checks, SystemCheck{
				Name:        "Claude Code CLI",
				Description: "AI-powered code assistant",
				Status:      StatusPass,
				Details:     "available",
				Critical:    false,
			})
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Claude Code CLI",
				Description: "AI-powered code assistant - optional",
				Status:      StatusWarn,
				Details:     "not found",
				Critical:    false,
			})
		}

		// Check SwiftLint
		if checkCommandAvailable("swiftlint") {
			if version := getCommandVersion("swiftlint", "--version"); version != "" {
				checks = append(checks, SystemCheck{
					Name:        "SwiftLint",
					Description: "Swift code linter",
					Status:      StatusPass,
					Details:     version,
					Critical:    false,
				})
			} else {
				checks = append(checks, SystemCheck{
					Name:        "SwiftLint",
					Description: "Swift code linter",
					Status:      StatusPass,
					Details:     "available",
					Critical:    false,
				})
			}
		} else {
			checks = append(checks, SystemCheck{
				Name:        "SwiftLint",
				Description: "Swift code linter - optional for Swift projects",
				Status:      StatusWarn,
				Details:     "not found",
				Critical:    false,
			})
		}

		return systemCheckResultMsg{
			Section: SectionSystemDeps,
			Checks:  checks,
		}
	}
}

func checkUIConfiguration() tea.Cmd {
	return func() tea.Msg {
		checks := []SystemCheck{}

		// Console mode detection
		if os.Getenv("CCW_CONSOLE_MODE") == "true" {
			checks = append(checks, SystemCheck{
				Name:        "Console Mode",
				Description: "Using traditional console output",
				Status:      StatusPass,
				Details:     "enabled (forced via CCW_CONSOLE_MODE)",
				Critical:    false,
			})
		} else {
			// Test Bubble Tea support
			testUI := NewUIManagerWithDefaults()
			if testUI.ShouldUseBubbleTea() {
				checks = append(checks, SystemCheck{
					Name:        "Bubble Tea UI",
					Description: "Interactive terminal user interface",
					Status:      StatusPass,
					Details:     "available and enabled",
					Critical:    false,
				})
			} else {
				checks = append(checks, SystemCheck{
					Name:        "Console Mode",
					Description: "Fallback to console mode",
					Status:      StatusWarn,
					Details:     "Bubble Tea UI not available",
					Critical:    false,
				})
			}
		}

		// Theme detection
		if envTheme := os.Getenv("CCW_THEME"); envTheme != "" {
			checks = append(checks, SystemCheck{
				Name:        "Theme",
				Description: "UI color theme",
				Status:      StatusPass,
				Details:     fmt.Sprintf("%s (from CCW_THEME)", envTheme),
				Critical:    false,
			})
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Theme",
				Description: "UI color theme",
				Status:      StatusPass,
				Details:     "auto-detected",
				Critical:    false,
			})
		}

		// Color support
		if os.Getenv("CCW_COLOR_OUTPUT") == "false" {
			checks = append(checks, SystemCheck{
				Name:        "Color Support",
				Description: "Terminal color capabilities",
				Status:      StatusWarn,
				Details:     "disabled (CCW_COLOR_OUTPUT=false)",
				Critical:    false,
			})
		} else if os.Getenv("NO_COLOR") != "" {
			checks = append(checks, SystemCheck{
				Name:        "Color Support",
				Description: "Terminal color capabilities",
				Status:      StatusWarn,
				Details:     "disabled (NO_COLOR set)",
				Critical:    false,
			})
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Color Support",
				Description: "Terminal color capabilities",
				Status:      StatusPass,
				Details:     "enabled",
				Critical:    false,
			})
		}

		return systemCheckResultMsg{
			Section: SectionUIConfig,
			Checks:  checks,
		}
	}
}

func checkGitRepository() tea.Cmd {
	return func() tea.Msg {
		checks := []SystemCheck{}

		// Check if current directory is a Git repository
		if isGitRepository() {
			if repoURL, err := github.GetCurrentRepoURL(); err == nil {
				checks = append(checks, SystemCheck{
					Name:        "Git Repository",
					Description: "Current directory is a valid Git repository",
					Status:      StatusPass,
					Details:     repoURL,
					Critical:    false,
				})
			} else {
				checks = append(checks, SystemCheck{
					Name:        "Git Repository",
					Description: "Current directory is a local Git repository",
					Status:      StatusPass,
					Details:     "local repository",
					Critical:    false,
				})
			}
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Git Repository",
				Description: "Current directory is not a Git repository",
				Status:      StatusFail,
				Details:     "not a Git repository",
				Critical:    true,
			})
		}

		return systemCheckResultMsg{
			Section: SectionGitRepo,
			Checks:  checks,
		}
	}
}

func checkEnvironment() tea.Cmd {
	return func() tea.Msg {
		checks := []SystemCheck{}

		// Check GitHub token
		if os.Getenv("GITHUB_TOKEN") != "" || os.Getenv("GH_TOKEN") != "" {
			checks = append(checks, SystemCheck{
				Name:        "GitHub Token",
				Description: "Authentication for GitHub API access",
				Status:      StatusPass,
				Details:     "configured",
				Critical:    false,
			})
		} else {
			checks = append(checks, SystemCheck{
				Name:        "GitHub Token",
				Description: "Authentication for GitHub API access",
				Status:      StatusWarn,
				Details:     "not configured (GH_TOKEN or GITHUB_TOKEN)",
				Critical:    false,
			})
		}

		// System info
		checks = append(checks, SystemCheck{
			Name:        "Operating System",
			Description: "System platform information",
			Status:      StatusPass,
			Details:     fmt.Sprintf("%s %s", runtime.GOOS, runtime.GOARCH),
			Critical:    false,
		})

		checks = append(checks, SystemCheck{
			Name:        "CPU Cores",
			Description: "Available CPU cores",
			Status:      StatusPass,
			Details:     fmt.Sprintf("%d cores", runtime.NumCPU()),
			Critical:    false,
		})

		return systemCheckResultMsg{
			Section: SectionEnvironment,
			Checks:  checks,
		}
	}
}

func checkConfiguration() tea.Cmd {
	return func() tea.Msg {
		checks := []SystemCheck{}

		// Check config file
		if _, err := os.Stat("ccw.yaml"); err == nil {
			checks = append(checks, SystemCheck{
				Name:        "Configuration File",
				Description: "CCW configuration file",
				Status:      StatusPass,
				Details:     "ccw.yaml found",
				Critical:    false,
			})
		} else if _, err := os.Stat("ccw.json"); err == nil {
			checks = append(checks, SystemCheck{
				Name:        "Configuration File",
				Description: "CCW configuration file",
				Status:      StatusPass,
				Details:     "ccw.json found",
				Critical:    false,
			})
		} else {
			checks = append(checks, SystemCheck{
				Name:        "Configuration File",
				Description: "CCW will use default configuration",
				Status:      StatusWarn,
				Details:     "no config file found",
				Critical:    false,
			})
		}

		return systemCheckResultMsg{
			Section: SectionConfiguration,
			Checks:  checks,
		}
	}
}

// Helper functions (moved from commands.go)
func checkCommandAvailable(command string) bool {
	_, err := exec.LookPath(command)
	return err == nil
}

func getCommandVersion(command string, versionFlag string) string {
	cmd := exec.Command(command, versionFlag)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func isGitRepository() bool {
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	err := cmd.Run()
	return err == nil
}

// RunDoctorUI starts the Bubble Tea doctor interface
func RunDoctorUI() error {
	model := NewDoctorModel()
	p := tea.NewProgram(model, tea.WithAltScreen())

	_, err := p.Run()
	return err
}
