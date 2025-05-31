package ui

import (
	"fmt"
	"time"

	"ccw/config"
	tea "github.com/charmbracelet/bubbletea"
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

// Messages for async operations
type systemCheckResultMsg struct {
	Section DoctorSection
	Checks  []SystemCheck
}

type checksCompleteMsg struct{}

type tickMsg time.Time

type BackToMainMenuMsg struct{}

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