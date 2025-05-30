package ui

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"ccw/types"
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
	StateCompleted
)

// Main application model
type AppModel struct {
	state           AppState
	mainMenu        MainMenuModel
	issueSelection  IssueSelectionModel
	progressTracker ProgressModel
	logViewer       LogViewerModel
	windowSize      tea.WindowSizeMsg
	ui             *UIManager
	showLogs        bool
	logsPanelWidth  int
}

// Main menu model
type MainMenuModel struct {
	choices  []string
	cursor   int
	selected bool
}

// Issue selection model with enhanced features
type IssueSelectionModel struct {
	list             list.Model
	selected         []*types.Issue
	done             bool
	allIssues        []*types.Issue
	sortBy           SortBy
	showDetails      bool
	selectedIndex    int
	searchEnabled    bool
	originalItems    []list.Item
}

// Sorting options
type SortBy int

const (
	SortByNumber SortBy = iota
	SortByTitle
	SortByState
	SortByDate
	SortByUpdated
)

// Progress tracking model
type ProgressModel struct {
	progress    progress.Model
	steps       []types.WorkflowStep
	currentStep int
	startTime   time.Time
	done        bool
}

// Enhanced issue list item with detailed information
type IssueItem struct {
	issue *types.Issue
}

func (i IssueItem) FilterValue() string { 
	// Include title, labels, and state in filter for comprehensive search
	labels := make([]string, len(i.issue.Labels))
	for idx, label := range i.issue.Labels {
		labels[idx] = label.Name
	}
	return fmt.Sprintf("%s %s %s", i.issue.Title, i.issue.State, strings.Join(labels, " "))
}

func (i IssueItem) Title() string { 
	stateIcon := "⭕" // default
	switch i.issue.State {
	case "open":
		stateIcon = "🟢"
	case "closed":
		stateIcon = "🔴"
	case "draft":
		stateIcon = "📝"
	}
	
	return fmt.Sprintf("%s #%d: %s", stateIcon, i.issue.Number, i.issue.Title) 
}

func (i IssueItem) Description() string { 
	labels := make([]string, len(i.issue.Labels))
	for idx, label := range i.issue.Labels {
		labels[idx] = label.Name
	}
	
	labelStr := "none"
	if len(labels) > 0 {
		labelStr = strings.Join(labels, ", ")
		if len(labelStr) > 40 {
			labelStr = labelStr[:37] + "..."
		}
	}
	
	return fmt.Sprintf("State: %s | Labels: %s | Updated: %s", 
		i.issue.State, 
		labelStr,
		i.issue.UpdatedAt.Format("2006-01-02"))
}

// GetDetailedDescription returns full issue details for expanded view
func (i IssueItem) GetDetailedDescription() string {
	labels := make([]string, len(i.issue.Labels))
	for idx, label := range i.issue.Labels {
		labels[idx] = label.Name
	}
	
	assignees := make([]string, len(i.issue.Assignees))
	for idx, assignee := range i.issue.Assignees {
		assignees[idx] = assignee.Login
	}
	
	body := i.issue.Body
	if len(body) > 200 {
		body = body[:197] + "..."
	}
	
	details := fmt.Sprintf(
		"State: %s\nLabels: %s\nAssignees: %s\nCreated: %s\nUpdated: %s\nURL: %s\n\nDescription:\n%s",
		i.issue.State,
		strings.Join(labels, ", "),
		strings.Join(assignees, ", "),
		i.issue.CreatedAt.Format("2006-01-02 15:04"),
		i.issue.UpdatedAt.Format("2006-01-02 15:04"),
		i.issue.HTMLURL,
		body,
	)
	
	return details
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
	issueList.Title = "🔍 Enhanced Issue Selection"
	issueList.SetShowStatusBar(true)
	issueList.SetFilteringEnabled(true) // Enable fuzzy search/filtering
	issueList.SetShowHelp(true)
	
	issueSelection := IssueSelectionModel{
		list:          issueList,
		sortBy:        SortByNumber, // Default sort by issue number
		showDetails:   false,
		searchEnabled: true,
		originalItems: []list.Item{},
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

	return AppModel{
		state:           StateMainMenu,
		mainMenu:        mainMenu,
		issueSelection:  issueSelection,
		progressTracker: progressModel,
		logViewer:      logViewer,
		ui:             ui,
		showLogs:       true,
		logsPanelWidth: 40, // 40% of screen width for logs
	}
}

// Main application Init
func (m AppModel) Init() tea.Cmd {
	return nil
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
			case 3: // Exit
				return m.mainMenu, tea.Quit
			}
		}
	}
	return m.mainMenu, nil
}

// Issue Selection Update with enhanced functionality
func (m AppModel) updateIssueSelection(msg tea.Msg) (IssueSelectionModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			if m.issueSelection.showDetails {
				// Exit detail view
				m.issueSelection.showDetails = false
				return m.issueSelection, nil
			}
			// Return to main menu
			m.state = StateMainMenu
			return m.issueSelection, nil
		case "enter", " ":
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
		case "d":
			// Toggle detailed view for selected issue
			m.issueSelection.showDetails = !m.issueSelection.showDetails
			m.issueSelection.selectedIndex = m.issueSelection.list.Index()
		case "ctrl+s":
			// Start workflow with selected issues
			if len(m.issueSelection.selected) > 0 {
				m.state = StateProgressTracking
				return m.issueSelection, nil
			}
		case "1":
			// Sort by number
			m.issueSelection.sortBy = SortByNumber
			m.issueSelection = m.applySorting(m.issueSelection)
		case "2":
			// Sort by title
			m.issueSelection.sortBy = SortByTitle
			m.issueSelection = m.applySorting(m.issueSelection)
		case "3":
			// Sort by state
			m.issueSelection.sortBy = SortByState
			m.issueSelection = m.applySorting(m.issueSelection)
		case "4":
			// Sort by creation date
			m.issueSelection.sortBy = SortByDate
			m.issueSelection = m.applySorting(m.issueSelection)
		case "5":
			// Sort by update date
			m.issueSelection.sortBy = SortByUpdated
			m.issueSelection = m.applySorting(m.issueSelection)
		case "ctrl+r":
			// Reset search/filter
			if len(m.issueSelection.originalItems) > 0 {
				m.issueSelection.list.SetItems(m.issueSelection.originalItems)
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

// Enhanced Issue Selection View
func (m AppModel) viewIssueSelection() string {
	header := headerStyle.Render("🔍 Enhanced Issue Selection")
	
	// Sort information
	sortInfo := fmt.Sprintf("Sort: %s", m.issueSelection.sortBy.String())
	sortLine := "\n" + infoStyle.Render("📊 ") + subtleStyle.Render(sortInfo)
	
	// Selected issues information
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
	
	// Enhanced footer with all available controls
	controls := []string{
		"Enter/Space: toggle selection",
		"D: details",
		"1-5: sort",
		"/: search",
		"Ctrl+S: start workflow",
		"Esc: back/exit details",
	}
	footer := subtleStyle.Render(strings.Join(controls, " • "))
	
	// Main content
	var content strings.Builder
	content.WriteString(header)
	content.WriteString(sortLine)
	content.WriteString("\n\n")
	
	// Show detailed view if enabled
	if m.issueSelection.showDetails {
		if selectedItem := m.issueSelection.list.SelectedItem(); selectedItem != nil {
			if item, ok := selectedItem.(IssueItem); ok {
				detailsHeader := infoStyle.Render("📋 Issue Details:")
				details := subtleStyle.Render(item.GetDetailedDescription())
				
				detailsBox := lipgloss.NewStyle().
					Border(lipgloss.RoundedBorder()).
					BorderForeground(lipgloss.Color("#666666")).
					Padding(1).
					Width(m.windowSize.Width - 4).
					Render(details)
				
				content.WriteString(detailsHeader)
				content.WriteString("\n")
				content.WriteString(detailsBox)
				content.WriteString("\n")
			}
		}
	} else {
		// Show normal list view
		content.WriteString(m.issueSelection.list.View())
	}
	
	content.WriteString(selectedInfo)
	content.WriteString("\n\n")
	content.WriteString(footer)
	
	return content.String()
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

// Set issues for selection with enhanced features
func (m *AppModel) SetIssues(issues []*types.Issue) {
	items := make([]list.Item, len(issues))
	for i, issue := range issues {
		items[i] = IssueItem{issue: issue}
	}
	
	// Store all issues and original items for sorting/filtering
	m.issueSelection.allIssues = issues
	m.issueSelection.originalItems = items
	
	// Apply initial sorting
	m.issueSelection.list.SetItems(items)
	m.issueSelection = m.applySorting(m.issueSelection)
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

// Apply sorting to issue selection model
func (m AppModel) applySorting(selection IssueSelectionModel) IssueSelectionModel {
	items := selection.list.Items()
	issueItems := make([]IssueItem, len(items))
	
	// Convert to IssueItem slice for sorting
	for i, item := range items {
		if issueItem, ok := item.(IssueItem); ok {
			issueItems[i] = issueItem
		}
	}
	
	// Sort based on selected criteria
	switch selection.sortBy {
	case SortByNumber:
		sort.Slice(issueItems, func(i, j int) bool {
			return issueItems[i].issue.Number < issueItems[j].issue.Number
		})
	case SortByTitle:
		sort.Slice(issueItems, func(i, j int) bool {
			return strings.ToLower(issueItems[i].issue.Title) < strings.ToLower(issueItems[j].issue.Title)
		})
	case SortByState:
		sort.Slice(issueItems, func(i, j int) bool {
			return issueItems[i].issue.State < issueItems[j].issue.State
		})
	case SortByDate:
		sort.Slice(issueItems, func(i, j int) bool {
			return issueItems[i].issue.CreatedAt.Before(issueItems[j].issue.CreatedAt)
		})
	case SortByUpdated:
		sort.Slice(issueItems, func(i, j int) bool {
			return issueItems[i].issue.UpdatedAt.After(issueItems[j].issue.UpdatedAt)
		})
	}
	
	// Convert back to list.Item slice
	sortedItems := make([]list.Item, len(issueItems))
	for i, issueItem := range issueItems {
		sortedItems[i] = issueItem
	}
	
	// Update the list with sorted items
	selection.list.SetItems(sortedItems)
	return selection
}

// Get sort name for display
func (s SortBy) String() string {
	switch s {
	case SortByNumber:
		return "Number"
	case SortByTitle:
		return "Title"
	case SortByState:
		return "State"
	case SortByDate:
		return "Created"
	case SortByUpdated:
		return "Updated"
	default:
		return "Unknown"
	}
}