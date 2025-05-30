package ui

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"ccw/types"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/progress"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Bubble Tea models for different UI screens

// Application states
type AppState int

const (
	StateMainMenu AppState = iota
	StateIssueSelection
	StateProgressTracking
	StateLogViewer
	StateDoctorCheck
	StateCompleted
)

// Main application model
type AppModel struct {
	state           AppState
	mainMenu        MainMenuModel
	issueSelection  IssueSelectionModel
	progressTracker ProgressModel
	logViewer       LogViewerModel
	doctorModel     DoctorModel
	windowSize      tea.WindowSizeMsg
	ui              *UIManager
	showLogs        bool
	logsPanelWidth  int
}

// Main menu model
type MainMenuModel struct {
	choices  []string
	cursor   int
	selected bool
}

// Issue selection model
type IssueSelectionModel struct {
	list         list.Model
	selected     []*types.Issue
	done         bool
	allIssues    []*types.Issue
	filtered     []list.Item
	sortBy       SortBy
	showDetails  bool
	detailsIndex int
	keys         KeyMap
}

// SortBy represents different sorting options
type SortBy int

const (
	SortByNumber SortBy = iota
	SortByTitle
	SortByState
	SortByDate
)

// KeyMap defines keyboard shortcuts
type KeyMap struct {
	ToggleSelect key.Binding
	Sort         key.Binding
	Details      key.Binding
	Search       key.Binding
	Back         key.Binding
	Start        key.Binding
}

// DefaultKeyMap returns default key bindings
func DefaultKeyMap() KeyMap {
	return KeyMap{
		ToggleSelect: key.NewBinding(
			key.WithKeys(" ", "enter"),
			key.WithHelp("space/enter", "toggle selection"),
		),
		Sort: key.NewBinding(
			key.WithKeys("s"),
			key.WithHelp("s", "cycle sort (number/title/state/date)"),
		),
		Details: key.NewBinding(
			key.WithKeys("d"),
			key.WithHelp("d", "toggle details"),
		),
		Search: key.NewBinding(
			key.WithKeys("/"),
			key.WithHelp("/", "search/filter"),
		),
		Back: key.NewBinding(
			key.WithKeys("esc"),
			key.WithHelp("esc", "back to main menu"),
		),
		Start: key.NewBinding(
			key.WithKeys("ctrl+s"),
			key.WithHelp("ctrl+s", "start workflow with selected"),
		),
	}
}

// Progress tracking model
type ProgressModel struct {
	progress    progress.Model
	steps       []types.WorkflowStep
	currentStep int
	startTime   time.Time
	done        bool
}

// Issue list item for Bubble Tea list component
type IssueItem struct {
	issue *types.Issue
}

func (i IssueItem) FilterValue() string { 
	// Include title, labels, and issue number for fuzzy search
	labels := make([]string, len(i.issue.Labels))
	for idx, label := range i.issue.Labels {
		labels[idx] = label.Name
	}
	return fmt.Sprintf("%s %d %s %s", i.issue.Title, i.issue.Number, strings.Join(labels, " "), i.issue.State)
}

func (i IssueItem) Title() string { 
	return fmt.Sprintf("#%d: %s", i.issue.Number, i.issue.Title) 
}

func (i IssueItem) Description() string {
	labels := make([]string, len(i.issue.Labels))
	for idx, label := range i.issue.Labels {
		labels[idx] = label.Name
	}
	labelStr := "No labels"
	if len(labels) > 0 {
		labelStr = strings.Join(labels, ", ")
		if len(labelStr) > 50 {
			labelStr = labelStr[:47] + "..."
		}
	}
	return fmt.Sprintf("State: %s | Labels: %s", i.issue.State, labelStr)
}

// Styles with improved visibility and contrast
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFFFF")).
			Background(lipgloss.Color("#0066CC")).
			Padding(0, 1).
			Bold(true)

	headerStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#0066CC")).
			Foreground(lipgloss.Color("#0066CC")).
			Padding(1, 2).
			Bold(true)

	menuItemStyle = lipgloss.NewStyle().
			PaddingLeft(4).
			Foreground(lipgloss.Color("#333333"))

	selectedMenuItemStyle = lipgloss.NewStyle().
				PaddingLeft(2).
				Foreground(lipgloss.Color("#FFFFFF")).
				Background(lipgloss.Color("#0066CC")).
				Bold(true)

	progressStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#00AA00")).
			Foreground(lipgloss.Color("#00AA00")).
			Padding(1, 2)

	// Additional styles for better visibility
	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00AA00")).
			Bold(true)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CC0000")).
			Bold(true)

	warningStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF6600")).
			Bold(true)

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#0066CC")).
			Bold(true)

	subtleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#666666"))
)

// Initialize application model
func NewAppModel(ui *UIManager) AppModel {
	// Apply optimal color theme
	optimalTheme := GetOptimalTheme()
	ApplyTheme(optimalTheme)

	// Initialize main menu
	mainMenu := MainMenuModel{
		choices: []string{
			"Select Issues to Process",
			"View Repository Issues",
			"Start Workflow",
			"Doctor (System Diagnostics)",
			"Exit",
		},
	}

	// Initialize issue selection with enhanced delegate
	delegate := list.NewDefaultDelegate()

	// Customize delegate styles using current theme colors
	delegate.Styles.SelectedTitle = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(optimalTheme.Primary)).
		Foreground(lipgloss.Color(optimalTheme.Primary)).
		Bold(true).
		Padding(0, 0, 0, 1)

	delegate.Styles.SelectedDesc = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(optimalTheme.Primary)).
		Foreground(lipgloss.Color(optimalTheme.Subtle)).
		Padding(0, 0, 0, 1)

	delegate.Styles.NormalTitle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(optimalTheme.Subtle)).
		Padding(0, 0, 0, 1)

	delegate.Styles.NormalDesc = lipgloss.NewStyle().
		Foreground(lipgloss.Color(optimalTheme.Subtle)).
		Padding(0, 0, 0, 1)

	issueList := list.New([]list.Item{}, delegate, 80, 20)
	issueList.Title = "Select Issues to Process"
	issueList.SetShowStatusBar(true)
	issueList.SetFilteringEnabled(true) // Enable filtering for enhanced search

	issueSelection := IssueSelectionModel{
		list:     issueList,
		allIssues: []*types.Issue{},
		filtered: []list.Item{},
		sortBy:   SortByNumber,
		keys:     DefaultKeyMap(),
	}

	// Initialize progress tracker
	prog := progress.New(progress.WithDefaultGradient())
	progressModel := ProgressModel{
		progress:  prog,
		startTime: time.Now(),
	}

	// Initialize log buffer and viewer
	InitLogBuffer(1000) // Keep last 1000 log entries
	logViewer := NewLogViewerModel(80, 20, GetLogBuffer())

	// Initialize doctor model
	doctorModel := NewDoctorModel()

	return AppModel{
		state:           StateMainMenu,
		mainMenu:        mainMenu,
		issueSelection:  issueSelection,
		progressTracker: progressModel,
		logViewer:       logViewer,
		doctorModel:     doctorModel,
		ui:              ui,
		showLogs:        true,
		logsPanelWidth:  40, // 40% of screen width for logs
	}
}

// Main application Init
func (m AppModel) Init() tea.Cmd {
	// Start periodic header updates for progress tracking
	return sendHeaderUpdate(250 * time.Millisecond)
}

// Main application Update
func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "ctrl+l":
			// Toggle log viewer state
			if m.state == StateLogViewer {
				m.state = StateMainMenu
			} else {
				m.state = StateLogViewer
			}
		case "tab":
			// Toggle logs panel
			m.showLogs = !m.showLogs
		}
	case BackToMainMenuMsg:
		// Return to main menu from any sub-state
		m.state = StateMainMenu

	case tea.WindowSizeMsg:
		m.windowSize = msg

		// Update component sizes based on log panel visibility
		mainWidth := msg.Width
		if m.showLogs {
			mainWidth = msg.Width * (100 - m.logsPanelWidth) / 100
			logWidth := msg.Width * m.logsPanelWidth / 100
			m.logViewer = NewLogViewerModel(logWidth, msg.Height, GetLogBuffer())
		}

		m.issueSelection.list.SetWidth(mainWidth)
		m.issueSelection.list.SetHeight(msg.Height - 10)

	case HeaderUpdateMsg:
		// Periodic header updates for progress tracking
		// The view will automatically update with current progress state
		
		// Continue periodic updates with adaptive interval based on current state
		var interval time.Duration
		switch m.state {
		case StateProgressTracking:
			// More frequent updates during active progress
			interval = 250 * time.Millisecond
		default:
			// Less frequent updates for other states
			interval = 1 * time.Second
		}
		return m, sendHeaderUpdate(interval)
	}

	var cmd tea.Cmd
	switch m.state {
	case StateMainMenu:
		m.mainMenu, cmd = m.updateMainMenu(msg)
	case StateIssueSelection:
		m.issueSelection, cmd = m.updateIssueSelection(msg)
	case StateProgressTracking:
		m.progressTracker, cmd = m.updateProgress(msg)
	case StateLogViewer:
		m.logViewer, cmd = m.logViewer.Update(msg)
	case StateDoctorCheck:
		updatedModel, doctorCmd := m.doctorModel.Update(msg)
		m.doctorModel = updatedModel.(DoctorModel)
		cmd = doctorCmd
	}

	// Always update log viewer in background for live updates
	if m.state != StateLogViewer {
		m.logViewer, _ = m.logViewer.Update(msg)
	}

	return m, cmd
}

// Main application View
func (m AppModel) View() string {
	var mainContent string

	switch m.state {
	case StateMainMenu:
		mainContent = m.viewMainMenu()
	case StateIssueSelection:
		mainContent = m.viewIssueSelection()
	case StateProgressTracking:
		mainContent = m.viewProgress()
	case StateLogViewer:
		return m.logViewer.View()
	case StateDoctorCheck:
		return m.doctorModel.View()
	case StateCompleted:
		mainContent = "Workflow completed! Press 'q' to quit.\n"
	default:
		mainContent = ""
	}

	// Show logs alongside main content if enabled
	if m.showLogs && m.state != StateLogViewer {
		return m.layoutWithLogs(mainContent)
	}

	return mainContent
}

// layoutWithLogs creates a side-by-side layout with main content and logs
func (m AppModel) layoutWithLogs(mainContent string) string {
	if m.windowSize.Width == 0 {
		return mainContent // No window size yet, return main content only
	}

	// Calculate widths
	mainWidth := m.windowSize.Width * (100 - m.logsPanelWidth) / 100
	logWidth := m.windowSize.Width * m.logsPanelWidth / 100

	// Create log viewer with proper sizing
	logViewer := NewLogViewerModel(logWidth, m.windowSize.Height, GetLogBuffer())
	logContent := logViewer.View()

	// Style the main content area
	styledMainContent := lipgloss.NewStyle().
		Width(mainWidth - 2).
		Height(m.windowSize.Height).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#666666")).
		Padding(1).
		Render(mainContent)

	// Style the log content area
	styledLogContent := lipgloss.NewStyle().
		Width(logWidth - 2).
		Height(m.windowSize.Height).
		Render(logContent)

	// Create horizontal layout
	layout := lipgloss.JoinHorizontal(lipgloss.Top,
		styledMainContent,
		styledLogContent,
	)

	// Add status bar at the bottom
	statusBar := m.createStatusBar()

	return lipgloss.JoinVertical(lipgloss.Left,
		layout,
		statusBar,
	)
}

// createStatusBar creates a status bar showing available controls
func (m AppModel) createStatusBar() string {
	controls := []string{
		"Ctrl+L: Full log view",
		"Tab: Toggle logs",
		"Ctrl+C/Q: Quit",
	}

	status := fmt.Sprintf("State: %s | Logs: %s",
		m.getStateName(),
		map[bool]string{true: "ON", false: "OFF"}[m.showLogs],
	)

	controlsText := subtleStyle.Render(strings.Join(controls, " • "))
	statusText := subtleStyle.Render(status)

	// Create full-width status bar
	width := m.windowSize.Width
	if width == 0 {
		width = 80 // Default width
	}

	return lipgloss.NewStyle().
		Width(width).
		Background(lipgloss.Color("#222222")).
		Foreground(lipgloss.Color("#CCCCCC")).
		Padding(0, 1).
		Render(
			lipgloss.JoinHorizontal(lipgloss.Top,
				controlsText,
				lipgloss.NewStyle().Width(width-lipgloss.Width(controlsText)-lipgloss.Width(statusText)).Render(""),
				statusText,
			),
		)
}

// getStateName returns a human-readable state name
func (m AppModel) getStateName() string {
	switch m.state {
	case StateMainMenu:
		return "Menu"
	case StateIssueSelection:
		return "Issues"
	case StateProgressTracking:
		return "Progress"
	case StateLogViewer:
		return "Logs"
	case StateDoctorCheck:
		return "Doctor"
	case StateCompleted:
		return "Complete"
	default:
		return "Unknown"
	}
}

// Main Menu Update
func (m AppModel) updateMainMenu(msg tea.Msg) (MainMenuModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.mainMenu.cursor > 0 {
				m.mainMenu.cursor--
			}
		case "down", "j":
			if m.mainMenu.cursor < len(m.mainMenu.choices)-1 {
				m.mainMenu.cursor++
			}
		case "enter", " ":
			switch m.mainMenu.cursor {
			case 0: // Select Issues
				m.state = StateIssueSelection
			case 1: // View Issues (could implement issue browsing)
				return m.mainMenu, nil
			case 2: // Start Workflow
				m.state = StateProgressTracking
			case 3: // Doctor
				m.state = StateDoctorCheck
				// Initialize doctor model and start checks
				m.doctorModel = NewDoctorModel()
				return m.mainMenu, m.doctorModel.Init()
			case 4: // Exit
				return m.mainMenu, tea.Quit
			}
		}
	}
	return m.mainMenu, nil
}

// Issue Selection Update
func (m AppModel) updateIssueSelection(msg tea.Msg) (IssueSelectionModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.issueSelection.keys.Back):
			m.state = StateMainMenu
			return m.issueSelection, nil
			
		case key.Matches(msg, m.issueSelection.keys.ToggleSelect):
			// Toggle selection
			selectedItem := m.issueSelection.list.SelectedItem()
			if item, ok := selectedItem.(IssueItem); ok {
				// Check if already selected
				found := false
				for i, selected := range m.issueSelection.selected {
					if selected.Number == item.issue.Number {
						// Remove from selection
						m.issueSelection.selected = append(
							m.issueSelection.selected[:i],
							m.issueSelection.selected[i+1:]...)
						found = true
						break
					}
				}
				if !found {
					// Add to selection
					m.issueSelection.selected = append(m.issueSelection.selected, item.issue)
				}
			}
			
		case key.Matches(msg, m.issueSelection.keys.Sort):
			// Cycle through sort options
			m.issueSelection.sortBy = (m.issueSelection.sortBy + 1) % 4
			m.issueSelection = m.sortIssues(m.issueSelection)
			
		case key.Matches(msg, m.issueSelection.keys.Details):
			// Toggle details view
			m.issueSelection.showDetails = !m.issueSelection.showDetails
			if m.issueSelection.showDetails {
				// Set details index to current selection
				m.issueSelection.detailsIndex = m.issueSelection.list.Index()
			}
			
		case key.Matches(msg, m.issueSelection.keys.Start):
			// Start workflow with selected issues
			if len(m.issueSelection.selected) > 0 {
				m.state = StateProgressTracking
				return m.issueSelection, nil
			}
		}
	}

	var cmd tea.Cmd
	m.issueSelection.list, cmd = m.issueSelection.list.Update(msg)
	return m.issueSelection, cmd
}

// Progress Update
func (m AppModel) updateProgress(msg tea.Msg) (ProgressModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			m.state = StateMainMenu
			return m.progressTracker, nil
		}
	case ProgressUpdateMsg:
		// Update step status
		for i, step := range m.progressTracker.steps {
			if step.ID == msg.StepID {
				m.progressTracker.steps[i].Status = msg.Status
				if msg.Status == "in_progress" {
					m.progressTracker.currentStep = i
				}
				break
			}
		}
	case ProgressCompleteMsg:
		m.state = StateCompleted
	case HeaderUpdateMsg:
		// Progress header updates are handled automatically by the main Update
		// This ensures elapsed time and progress status stay current
	}

	// Update progress bar
	var cmd tea.Cmd
	if m.progressTracker.currentStep < len(m.progressTracker.steps) {
		percent := float64(m.progressTracker.currentStep) / float64(len(m.progressTracker.steps))
		cmd = m.progressTracker.progress.SetPercent(percent)
	}

	return m.progressTracker, cmd
}

// Main Menu View
func (m AppModel) viewMainMenu() string {
	s := headerStyle.Render("🚀 CCW - Claude Code Worktree") + "\n\n"

	for i, choice := range m.mainMenu.choices {
		cursor := " "
		if m.mainMenu.cursor == i {
			cursor = "▶"
			choice = selectedMenuItemStyle.Render(" " + choice + " ")
		} else {
			choice = menuItemStyle.Render(choice)
		}
		s += fmt.Sprintf("%s %s\n", infoStyle.Render(cursor), choice)
	}

	s += "\n" + subtleStyle.Render("Use ↑/↓ arrow keys to navigate, Enter to select, Ctrl+C to quit")

	return s
}

// Issue Selection View
func (m AppModel) viewIssueSelection() string {
	header := headerStyle.Render("📝 Issue Selection")

	// Sort indicator
	sortIndicator := m.getSortIndicator()
	
	// Selected issues info
	selectedInfo := ""
	if len(m.issueSelection.selected) > 0 {
		selectedNums := make([]string, len(m.issueSelection.selected))
		for i, issue := range m.issueSelection.selected {
			selectedNums[i] = fmt.Sprintf("#%d", issue.Number)
		}
		selectedInfo = "\n" + successStyle.Render("✓ Selected: ") + infoStyle.Render(strings.Join(selectedNums, ", "))
	} else {
		selectedInfo = "\n" + subtleStyle.Render("No issues selected yet")
	}

	// Main list view
	mainView := m.issueSelection.list.View()
	
	// Details view if enabled
	detailsView := ""
	if m.issueSelection.showDetails {
		detailsView = m.getIssueDetails()
	}

	// Help footer
	helpText := []string{
		"space/enter: toggle",
		"s: sort (" + m.getSortName() + ")",
		"d: details",
		"/: search",
		"ctrl+s: start workflow",
		"esc: back",
	}
	footer := subtleStyle.Render(strings.Join(helpText, " • "))

	if m.issueSelection.showDetails && detailsView != "" {
		// Split view: list on left, details on right
		leftWidth := (m.windowSize.Width - 4) / 2
		rightWidth := m.windowSize.Width - leftWidth - 4
		
		leftPanel := lipgloss.NewStyle().Width(leftWidth).Render(mainView)
		rightPanel := lipgloss.NewStyle().Width(rightWidth).Render(detailsView)
		
		content := lipgloss.JoinHorizontal(lipgloss.Top, leftPanel, rightPanel)
		return header + "\n" + sortIndicator + content + selectedInfo + "\n\n" + footer
	}

	return header + "\n" + sortIndicator + "\n" + mainView + selectedInfo + "\n\n" + footer
}

// Progress View
func (m AppModel) viewProgress() string {
	header := headerStyle.Render("⏳ Workflow Progress")

	var stepsView strings.Builder
	for i, step := range m.progressTracker.steps {
		var icon string
		var statusStyle lipgloss.Style

		switch step.Status {
		case "completed":
			icon = "✅"
			statusStyle = successStyle
		case "in_progress":
			icon = "🔄"
			statusStyle = infoStyle
		case "failed":
			icon = "❌"
			statusStyle = errorStyle
		default:
			icon = "⏳"
			statusStyle = subtleStyle
		}

		stepLine := fmt.Sprintf("%s %s %s - %s\n",
			icon,
			infoStyle.Render(fmt.Sprintf("%d/%d", i+1, len(m.progressTracker.steps))),
			statusStyle.Render(step.Name),
			subtleStyle.Render(step.Description))
		stepsView.WriteString(stepLine)
	}

	elapsed := time.Since(m.progressTracker.startTime).Round(time.Second)
	timeInfo := "\n" + infoStyle.Render("⏱ Elapsed: ") + subtleStyle.Render(elapsed.String())

	progressBar := m.progressTracker.progress.View()

	footer := subtleStyle.Render("Esc: back to main menu")

	return header + "\n\n" + progressBar + "\n\n" +
		progressStyle.Render(stepsView.String()) + timeInfo + "\n\n" + footer
}

// Custom messages for progress updates
type ProgressUpdateMsg struct {
	StepID string
	Status string
}

type ProgressCompleteMsg struct{}

// HeaderUpdateMsg is sent periodically to refresh progress header
type HeaderUpdateMsg struct{}

// sendHeaderUpdate returns a command that sends a HeaderUpdateMsg after a delay
func sendHeaderUpdate(interval time.Duration) tea.Cmd {
	return tea.Tick(interval, func(t time.Time) tea.Msg {
		return HeaderUpdateMsg{}
	})
}

// Set issues for selection
func (m *AppModel) SetIssues(issues []*types.Issue) {
	m.issueSelection.allIssues = issues
	m.issueSelection = m.sortIssues(m.issueSelection)
}

// Set progress steps
func (m *AppModel) SetProgressSteps(steps []types.WorkflowStep) {
	m.progressTracker.steps = steps
	m.progressTracker.startTime = time.Now()
}

// Get selected issues
func (m *AppModel) GetSelectedIssues() []*types.Issue {
	return m.issueSelection.selected
}

// Send progress update
func SendProgressUpdate(stepID, status string) tea.Cmd {
	return func() tea.Msg {
		return ProgressUpdateMsg{StepID: stepID, Status: status}
	}
}

// Send progress complete
func SendProgressComplete() tea.Cmd {
	return func() tea.Msg {
		return ProgressCompleteMsg{}
	}
}

// Helper methods for issue selection enhancements

// sortIssues sorts the issues based on current sort criteria
func (m AppModel) sortIssues(issueModel IssueSelectionModel) IssueSelectionModel {
	issues := make([]*types.Issue, len(issueModel.allIssues))
	copy(issues, issueModel.allIssues)
	
	switch issueModel.sortBy {
	case SortByNumber:
		sort.Slice(issues, func(i, j int) bool {
			return issues[i].Number < issues[j].Number
		})
	case SortByTitle:
		sort.Slice(issues, func(i, j int) bool {
			return strings.ToLower(issues[i].Title) < strings.ToLower(issues[j].Title)
		})
	case SortByState:
		sort.Slice(issues, func(i, j int) bool {
			// Sort open issues first
			if issues[i].State != issues[j].State {
				return issues[i].State == "open"
			}
			return issues[i].Number < issues[j].Number
		})
	case SortByDate:
		// Note: This would require CreatedAt field in types.Issue
		// For now, sort by number as fallback
		sort.Slice(issues, func(i, j int) bool {
			return issues[i].Number > issues[j].Number // Reverse for newest first
		})
	}
	
	// Convert to list items
	items := make([]list.Item, len(issues))
	for i, issue := range issues {
		items[i] = IssueItem{issue: issue}
	}
	
	issueModel.filtered = items
	issueModel.list.SetItems(items)
	return issueModel
}

// getSortIndicator returns a visual indicator for current sort
func (m AppModel) getSortIndicator() string {
	sortName := m.getSortName()
	return subtleStyle.Render(fmt.Sprintf("Sorted by: %s", sortName))
}

// getSortName returns the current sort method name
func (m AppModel) getSortName() string {
	switch m.issueSelection.sortBy {
	case SortByNumber:
		return "number"
	case SortByTitle:
		return "title"
	case SortByState:
		return "state"
	case SortByDate:
		return "date"
	default:
		return "unknown"
	}
}

// getIssueDetails returns detailed view of the selected issue
func (m AppModel) getIssueDetails() string {
	if len(m.issueSelection.filtered) == 0 {
		return ""
	}
	
	index := m.issueSelection.list.Index()
	if index < 0 || index >= len(m.issueSelection.filtered) {
		return ""
	}
	
	if item, ok := m.issueSelection.filtered[index].(IssueItem); ok {
		issue := item.issue
		
		var details strings.Builder
		details.WriteString(headerStyle.Render("Issue Details") + "\n\n")
		
		// Basic info
		details.WriteString(infoStyle.Render("Number: ") + fmt.Sprintf("#%d\n", issue.Number))
		details.WriteString(infoStyle.Render("Title: ") + issue.Title + "\n")
		details.WriteString(infoStyle.Render("State: "))
		if issue.State == "open" {
			details.WriteString(successStyle.Render(issue.State))
		} else {
			details.WriteString(subtleStyle.Render(issue.State))
		}
		details.WriteString("\n\n")
		
		// Labels
		if len(issue.Labels) > 0 {
			details.WriteString(infoStyle.Render("Labels:\n"))
			for _, label := range issue.Labels {
				details.WriteString(fmt.Sprintf("  • %s\n", label.Name))
			}
		} else {
			details.WriteString(subtleStyle.Render("No labels\n"))
		}
		
		// Selection status
		details.WriteString("\n")
		isSelected := false
		for _, selected := range m.issueSelection.selected {
			if selected.Number == issue.Number {
				isSelected = true
				break
			}
		}
		if isSelected {
			details.WriteString(successStyle.Render("✓ SELECTED"))
		} else {
			details.WriteString(subtleStyle.Render("○ Not selected"))
		}
		
		return details.String()
	}
	
	return ""
}

