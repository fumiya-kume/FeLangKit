package ui

import (
	"fmt"
	"strings"
	"time"

	"ccw/logging"
	"ccw/types"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/progress"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// CCWApp provides a unified Bubble Tea application entry point that manages all UI states
// and replaces the current mix of UIManager methods
type CCWApp struct {
	ui       *UIManager
	program  *tea.Program
	model    *UnifiedAppModel
	
	// Configuration
	config   AppConfig
	
	// State management
	currentState AppState
	stateHistory []AppState
	
	// Error handling
	lastError error
	fallbackMode bool
}

// AppConfig holds configuration for the unified app
type AppConfig struct {
	Theme            string
	EnableAnimations bool
	EnableLogs       bool
	LogsPanelWidth   int
	DebugMode        bool
	FallbackToConsole bool
}

// UnifiedAppModel is the main Bubble Tea model that handles all application states
// It extends the existing AppModel pattern but with centralized state management
type UnifiedAppModel struct {
	// Core components
	ui           *UIManager
	windowSize   tea.WindowSizeMsg
	
	// State management
	state        AppState
	stateHistory []AppState
	
	// Screen models (reusing existing models)
	mainMenu        MainMenuModel
	issueSelection  IssueSelectionModel
	progressTracker ProgressModel
	logViewer       LogViewerModel
	
	// UI layout
	showLogs        bool
	logsPanelWidth  int
	
	// Data
	issues          []*types.Issue
	selectedIssues  []*types.Issue
	workflowSteps   []types.WorkflowStep
	
	// Error handling
	errorMessage    string
	showError       bool
	
	// Configuration
	config          AppConfig
}

// NewCCWApp creates a new unified CCW application
func NewCCWApp(ui *UIManager) *CCWApp {
	config := AppConfig{
		Theme:             "modern",
		EnableAnimations:  true,
		EnableLogs:        true,
		LogsPanelWidth:    40,
		DebugMode:         ui.debugMode,
		FallbackToConsole: false,
	}
	
	model := NewUnifiedAppModel(ui, config)
	
	app := &CCWApp{
		ui:           ui,
		model:        model,
		config:       config,
		currentState: StateMainMenu,
		stateHistory: []AppState{},
		fallbackMode: false,
	}
	
	return app
}

// NewUnifiedAppModel creates the main Bubble Tea model
func NewUnifiedAppModel(ui *UIManager, config AppConfig) *UnifiedAppModel {
	// Apply optimal color theme
	optimalTheme := GetOptimalTheme()
	ApplyTheme(optimalTheme)
	
	// Initialize main menu
	mainMenu := MainMenuModel{
		choices: []string{
			"Select Issues to Process",
			"View Repository Issues",
			"Start Workflow",
			"Settings",
			"Exit",
		},
	}

	// Initialize issue selection with themed list
	issueList := createThemedIssueList(optimalTheme, 80, 20)
	
	issueSelection := IssueSelectionModel{
		list: issueList,
	}

	// Initialize progress tracker
	progressModel := createProgressModel()

	// Initialize log buffer and viewer
	InitLogBuffer(1000) // Keep last 1000 log entries
	logViewer := NewLogViewerModel(80, 20, GetLogBuffer())

	return &UnifiedAppModel{
		ui:              ui,
		state:           StateMainMenu,
		stateHistory:    []AppState{},
		mainMenu:        mainMenu,
		issueSelection:  issueSelection,
		progressTracker: progressModel,
		logViewer:      logViewer,
		showLogs:       config.EnableLogs,
		logsPanelWidth: config.LogsPanelWidth,
		config:         config,
	}
}

// Run starts the unified CCW application with a single entry point
func (app *CCWApp) Run() error {
	// Check if we can run interactive Bubble Tea
	if app.CanRunInteractive() && !app.config.FallbackToConsole {
		return app.runInteractive()
	}
	
	// Fallback to console mode
	app.fallbackMode = true
	return app.runConsole()
}

// RunWithState starts the app in a specific state (for directed workflows)
func (app *CCWApp) RunWithState(state AppState, data interface{}) error {
	app.currentState = state
	app.model.state = state
	
	// Set initial data based on state
	switch state {
	case StateIssueSelection:
		if issues, ok := data.([]*types.Issue); ok {
			app.model.SetIssues(issues)
		}
	case StateProgressTracking:
		if steps, ok := data.([]types.WorkflowStep); ok {
			app.model.SetProgressSteps(steps)
		}
	}
	
	return app.Run()
}

// RunMainMenu replaces RunMainMenuEnhanced with unified app approach
func (app *CCWApp) RunMainMenu() error {
	return app.RunWithState(StateMainMenu, nil)
}

// RunIssueSelection replaces DisplayIssueSelectionEnhanced
func (app *CCWApp) RunIssueSelection(issues []*types.Issue) ([]*types.Issue, error) {
	app.model.SetIssues(issues)
	
	err := app.RunWithState(StateIssueSelection, issues)
	if err != nil {
		return nil, err
	}
	
	return app.model.GetSelectedIssues(), nil
}

// RunProgressTracking replaces DisplayProgressEnhanced
func (app *CCWApp) RunProgressTracking(steps []types.WorkflowStep) error {
	return app.RunWithState(StateProgressTracking, steps)
}

// runInteractive executes the Bubble Tea interactive interface
func (app *CCWApp) runInteractive() error {
	// Enable UI mode to redirect logs to UI buffer
	logging.SetUIMode(true)
	defer logging.SetUIMode(false)
	
	// Set up logging integration
	logging.SetUILogFunction(AddLogToBuffer)
	
	// Create and run the Bubble Tea program
	app.program = tea.NewProgram(app.model, tea.WithAltScreen())
	
	finalModel, err := app.program.Run()
	if err != nil {
		// If Bubble Tea fails, try console fallback
		app.fallbackMode = true
		app.lastError = err
		return app.runConsole()
	}

	// Update our model with the final state
	if unifiedModel, ok := finalModel.(*UnifiedAppModel); ok {
		app.model = unifiedModel
	}

	return nil
}

// runConsole executes the console fallback interface
func (app *CCWApp) runConsole() error {
	switch app.currentState {
	case StateMainMenu:
		return app.runConsoleMainMenu()
	case StateIssueSelection:
		return app.runConsoleIssueSelection()
	case StateProgressTracking:
		return app.runConsoleProgressTracking()
	default:
		return app.runConsoleMainMenu()
	}
}

// runConsoleMainMenu provides console fallback for main menu
func (app *CCWApp) runConsoleMainMenu() error {
	app.ui.DisplayHeader()
	
	options := []string{
		"Select Issues to Process",
		"View Repository Issues", 
		"Start Workflow",
		"Settings",
		"Exit",
	}
	
	btm := app.ui.GetBubbleTeaManager()
	choice, err := btm.RunSimpleMenu(options, "CCW - Claude Code Worktree")
	if err != nil {
		return err
	}
	
	switch choice {
	case 0:
		app.ui.Info("Issue selection mode selected")
		app.currentState = StateIssueSelection
	case 1:
		app.ui.Info("Repository view mode selected")
	case 2:
		app.ui.Info("Starting workflow...")
		app.currentState = StateProgressTracking
	case 3:
		app.ui.Info("Settings...")
	case 4:
		app.ui.Info("Exiting...")
		return nil
	}
	
	return nil
}

// runConsoleIssueSelection provides console fallback for issue selection
func (app *CCWApp) runConsoleIssueSelection() error {
	if len(app.model.issues) == 0 {
		app.ui.Warning("No issues available for selection")
		return fmt.Errorf("no issues available")
	}
	
	selectedIssues, err := app.ui.DisplayIssueSelection(app.model.issues)
	if err != nil {
		return err
	}
	
	app.model.selectedIssues = selectedIssues
	app.ui.Success(fmt.Sprintf("Selected %d issues", len(selectedIssues)))
	
	return nil
}

// runConsoleProgressTracking provides console fallback for progress tracking
func (app *CCWApp) runConsoleProgressTracking() error {
	if len(app.model.workflowSteps) == 0 {
		app.ui.Warning("No workflow steps to track")
		return fmt.Errorf("no workflow steps available")
	}
	
	// Use existing progress display
	app.ui.InitializeProgress()
	app.ui.DisplayProgressHeaderWithBackground()
	
	return nil
}

// CanRunInteractive checks if interactive Bubble Tea mode is available
func (app *CCWApp) CanRunInteractive() bool {
	if app.config.FallbackToConsole {
		return false
	}
	
	btm := app.ui.GetBubbleTeaManager()
	return btm.CanRunInteractive()
}

// UpdateProgress sends progress updates to the running application
func (app *CCWApp) UpdateProgress(stepID, status string) {
	if app.program != nil && !app.fallbackMode {
		app.program.Send(ProgressUpdateMsg{StepID: stepID, Status: status})
	} else {
		// Fallback to UIManager progress updates
		app.ui.UpdateProgress(stepID, status)
	}
}

// CompleteProgress signals that progress is complete
func (app *CCWApp) CompleteProgress() {
	if app.program != nil && !app.fallbackMode {
		app.program.Send(ProgressCompleteMsg{})
	}
}

// ShowError displays an error message in the application
func (app *CCWApp) ShowError(err error) {
	if app.program != nil && !app.fallbackMode {
		app.program.Send(ErrorMsg{Error: err})
	} else {
		app.ui.Error(err.Error())
	}
}

// Quit the application gracefully
func (app *CCWApp) Quit() {
	if app.program != nil {
		app.program.Quit()
	}
}

// SetTheme updates the application theme
func (app *CCWApp) SetTheme(theme string) {
	app.config.Theme = theme
	if app.model != nil {
		app.model.config.Theme = theme
	}
}

// SetAnimations enables or disables animations
func (app *CCWApp) SetAnimations(enabled bool) {
	app.config.EnableAnimations = enabled
	if app.model != nil {
		app.model.config.EnableAnimations = enabled
	}
}

// ToggleLogs toggles the log panel visibility
func (app *CCWApp) ToggleLogs() {
	app.config.EnableLogs = !app.config.EnableLogs
	if app.model != nil {
		app.model.showLogs = app.config.EnableLogs
	}
}

// GetCurrentState returns the current application state
func (app *CCWApp) GetCurrentState() AppState {
	return app.currentState
}

// GetSelectedIssues returns the currently selected issues
func (app *CCWApp) GetSelectedIssues() []*types.Issue {
	if app.model != nil {
		return app.model.GetSelectedIssues()
	}
	return nil
}

// SetIssues sets the issues for selection
func (app *CCWApp) SetIssues(issues []*types.Issue) {
	if app.model != nil {
		app.model.SetIssues(issues)
	}
}

// SetProgressSteps sets the workflow steps for progress tracking
func (app *CCWApp) SetProgressSteps(steps []types.WorkflowStep) {
	if app.model != nil {
		app.model.SetProgressSteps(steps)
	}
}

// Custom messages for the unified app
type ErrorMsg struct {
	Error error
}

// StateTransitionMsg handles transitions between application states
type StateTransitionMsg struct {
	FromState AppState
	ToState   AppState
	Data      interface{}
}

// Bubble Tea implementation for UnifiedAppModel

// Init initializes the unified app model
func (m *UnifiedAppModel) Init() tea.Cmd {
	return nil
}

// Update handles all messages for the unified app model
func (m *UnifiedAppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		return m.handleKeyMsg(msg)
	case tea.WindowSizeMsg:
		return m.handleWindowSizeMsg(msg)
	case ProgressUpdateMsg:
		return m.handleProgressUpdateMsg(msg)
	case ProgressCompleteMsg:
		m.state = StateCompleted
		return m, nil
	case ErrorMsg:
		m.errorMessage = msg.Error.Error()
		m.showError = true
		return m, nil
	case StateTransitionMsg:
		return m.handleStateTransition(msg)
	}

	// Delegate to specific state handlers
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

// View renders the unified app model
func (m *UnifiedAppModel) View() string {
	// Show error overlay if there's an error
	if m.showError {
		return m.viewError()
	}
	
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

// Key message handling
func (m *UnifiedAppModel) handleKeyMsg(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		if m.state == StateMainMenu {
			return m, tea.Quit
		}
		// For other states, return to main menu
		m.state = StateMainMenu
		return m, nil
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
	case "esc":
		if m.showError {
			m.showError = false
			return m, nil
		}
		// Return to main menu from any state
		m.state = StateMainMenu
		return m, nil
	}
	
	return m, nil
}

// Window size message handling
func (m *UnifiedAppModel) handleWindowSizeMsg(msg tea.WindowSizeMsg) (tea.Model, tea.Cmd) {
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
	
	return m, nil
}

// Progress update message handling
func (m *UnifiedAppModel) handleProgressUpdateMsg(msg ProgressUpdateMsg) (tea.Model, tea.Cmd) {
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
	return m, nil
}

// State transition handling
func (m *UnifiedAppModel) handleStateTransition(msg StateTransitionMsg) (tea.Model, tea.Cmd) {
	// Add to history
	m.stateHistory = append(m.stateHistory, m.state)
	
	// Transition to new state
	m.state = msg.ToState
	
	// Handle state-specific data
	switch msg.ToState {
	case StateIssueSelection:
		if issues, ok := msg.Data.([]*types.Issue); ok {
			m.SetIssues(issues)
		}
	case StateProgressTracking:
		if steps, ok := msg.Data.([]types.WorkflowStep); ok {
			m.SetProgressSteps(steps)
		}
	}
	
	return m, nil
}

// Data management methods
func (m *UnifiedAppModel) SetIssues(issues []*types.Issue) {
	m.issues = issues
	items := make([]list.Item, len(issues))
	for i, issue := range issues {
		items[i] = IssueItem{issue: issue}
	}
	m.issueSelection.list.SetItems(items)
}

func (m *UnifiedAppModel) SetProgressSteps(steps []types.WorkflowStep) {
	m.workflowSteps = steps
	m.progressTracker.steps = steps
	m.progressTracker.startTime = time.Now()
}

func (m *UnifiedAppModel) GetSelectedIssues() []*types.Issue {
	return m.issueSelection.selected
}

// View methods for different states

func (m *UnifiedAppModel) viewError() string {
	errorContent := fmt.Sprintf("❌ Error: %s\n\nPress 'esc' to continue", m.errorMessage)
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#CC0000")).
		Foreground(lipgloss.Color("#CC0000")).
		Padding(2).
		Render(errorContent)
}

func (m *UnifiedAppModel) viewMainMenu() string {
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

func (m *UnifiedAppModel) viewIssueSelection() string {
	header := headerStyle.Render("📝 Issue Selection")
	
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

	footer := subtleStyle.Render("Enter: toggle selection • 's': start workflow • Esc: back to main menu")

	return header + "\n\n" + m.issueSelection.list.View() + selectedInfo + "\n\n" + footer
}

func (m *UnifiedAppModel) viewProgress() string {
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

func (m *UnifiedAppModel) layoutWithLogs(mainContent string) string {
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

func (m *UnifiedAppModel) createStatusBar() string {
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

func (m *UnifiedAppModel) getStateName() string {
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

// State update methods (reusing existing patterns from bubbletea_models.go)

func (m *UnifiedAppModel) updateMainMenu(msg tea.Msg) (MainMenuModel, tea.Cmd) {
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
			case 1: // View Issues
				return m.mainMenu, nil
			case 2: // Start Workflow
				m.state = StateProgressTracking
			case 3: // Settings
				return m.mainMenu, nil
			case 4: // Exit
				return m.mainMenu, tea.Quit
			}
		}
	}
	return m.mainMenu, nil
}

func (m *UnifiedAppModel) updateIssueSelection(msg tea.Msg) (IssueSelectionModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			m.state = StateMainMenu
			return m.issueSelection, nil
		case "enter":
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
		case "s":
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

func (m *UnifiedAppModel) updateProgress(msg tea.Msg) (ProgressModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			m.state = StateMainMenu
			return m.progressTracker, nil
		}
	case ProgressUpdateMsg:
		// This is handled in the main Update method
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

// Helper functions for creating component models with proper theming

// createThemedIssueList creates a themed list for issue selection
func createThemedIssueList(theme ColorTheme, width, height int) list.Model {
	delegate := list.NewDefaultDelegate()
	
	// Apply theme colors to delegate styles
	delegate.Styles.SelectedTitle = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(theme.Primary)).
		Foreground(lipgloss.Color(theme.Primary)).
		Bold(true).
		Padding(0, 0, 0, 1)
		
	delegate.Styles.SelectedDesc = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(theme.Primary)).
		Foreground(lipgloss.Color(theme.Subtle)).
		Padding(0, 0, 0, 1)
		
	delegate.Styles.NormalTitle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Subtle)).
		Padding(0, 0, 0, 1)
		
	delegate.Styles.NormalDesc = lipgloss.NewStyle().
		Foreground(lipgloss.Color(theme.Subtle)).
		Padding(0, 0, 0, 1)
	
	issueList := list.New([]list.Item{}, delegate, width, height)
	issueList.Title = "Select Issues to Process"
	issueList.SetShowStatusBar(false)
	issueList.SetFilteringEnabled(false)
	
	return issueList
}

// createProgressModel creates a new progress tracking model
func createProgressModel() ProgressModel {
	prog := progress.New(progress.WithDefaultGradient())
	return ProgressModel{
		progress:  prog,
		startTime: time.Now(),
	}
}