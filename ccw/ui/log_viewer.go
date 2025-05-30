package ui

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"ccw/types"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// LogBuffer holds logs in memory for UI display
type LogBuffer struct {
	entries []types.LogEntry
	maxSize int
	mutex   sync.RWMutex
}

// NewLogBuffer creates a new log buffer
func NewLogBuffer(maxSize int) *LogBuffer {
	return &LogBuffer{
		entries: make([]types.LogEntry, 0, maxSize),
		maxSize: maxSize,
	}
}

// AddEntry adds a log entry to the buffer
func (lb *LogBuffer) AddEntry(entry types.LogEntry) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()

	lb.entries = append(lb.entries, entry)
	
	// Keep only the last maxSize entries
	if len(lb.entries) > lb.maxSize {
		lb.entries = lb.entries[len(lb.entries)-lb.maxSize:]
	}
}

// GetEntries returns all log entries
func (lb *LogBuffer) GetEntries() []types.LogEntry {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	// Return a copy to avoid race conditions
	entries := make([]types.LogEntry, len(lb.entries))
	copy(entries, lb.entries)
	return entries
}

// GetEntriesAfter returns entries after a specific time
func (lb *LogBuffer) GetEntriesAfter(after time.Time) []types.LogEntry {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	var filtered []types.LogEntry
	for _, entry := range lb.entries {
		if entry.Timestamp.After(after) {
			filtered = append(filtered, entry)
		}
	}
	return filtered
}

// Clear clears all entries
func (lb *LogBuffer) Clear() {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	lb.entries = lb.entries[:0]
}

// LogViewerModel represents the log viewer component
type LogViewerModel struct {
	viewport     viewport.Model
	buffer       *LogBuffer
	width        int
	height       int
	showLevel    map[string]bool
	autoScroll   bool
	lastUpdate   time.Time
	filterTerm   string
}

// NewLogViewerModel creates a new log viewer model
func NewLogViewerModel(width, height int, buffer *LogBuffer) LogViewerModel {
	vp := viewport.New(width, height-4) // Reserve space for header and controls
	vp.Style = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#666666"))

	return LogViewerModel{
		viewport: vp,
		buffer:   buffer,
		width:    width,
		height:   height,
		showLevel: map[string]bool{
			"DEBUG": true,
			"INFO":  true,
			"WARN":  true,
			"ERROR": true,
			"FATAL": true,
		},
		autoScroll: true,
		lastUpdate: time.Now(),
	}
}

// LogUpdateMsg is sent when logs are updated
type LogUpdateMsg struct{}

// Init implements tea.Model
func (m LogViewerModel) Init() tea.Cmd {
	return tea.Batch(
		m.viewport.Init(),
		tea.Tick(time.Millisecond*500, func(t time.Time) tea.Msg {
			return LogUpdateMsg{}
		}),
	)
}

// Update implements tea.Model
func (m LogViewerModel) Update(msg tea.Msg) (LogViewerModel, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.viewport.Width = msg.Width
		m.viewport.Height = msg.Height - 4

	case LogUpdateMsg:
		// Update log content
		m.updateLogContent()
		
		// Schedule next update
		return m, tea.Tick(time.Millisecond*500, func(t time.Time) tea.Msg {
			return LogUpdateMsg{}
		})

	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			m.viewport.LineUp(1)
			m.autoScroll = false
		case "down", "j":
			m.viewport.LineDown(1)
		case "pgup":
			m.viewport.HalfViewUp()
			m.autoScroll = false
		case "pgdown":
			m.viewport.HalfViewDown()
		case "home":
			m.viewport.GotoTop()
			m.autoScroll = false
		case "end":
			m.viewport.GotoBottom()
			m.autoScroll = true
		case "c":
			// Clear logs
			m.buffer.Clear()
			m.updateLogContent()
		case "a":
			// Toggle auto-scroll
			m.autoScroll = !m.autoScroll
			if m.autoScroll {
				m.viewport.GotoBottom()
			}
		case "d":
			// Toggle debug logs
			m.showLevel["DEBUG"] = !m.showLevel["DEBUG"]
			m.updateLogContent()
		case "i":
			// Toggle info logs
			m.showLevel["INFO"] = !m.showLevel["INFO"]
			m.updateLogContent()
		case "w":
			// Toggle warn logs
			m.showLevel["WARN"] = !m.showLevel["WARN"]
			m.updateLogContent()
		case "e":
			// Toggle error logs
			m.showLevel["ERROR"] = !m.showLevel["ERROR"]
			m.updateLogContent()
		}
	}

	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// View implements tea.Model
func (m LogViewerModel) View() string {
	header := m.renderHeader()
	content := m.viewport.View()
	footer := m.renderFooter()
	
	return lipgloss.JoinVertical(lipgloss.Left,
		header,
		content,
		footer,
	)
}

// renderHeader renders the log viewer header
func (m LogViewerModel) renderHeader() string {
	title := headerStyle.Render("📋 Live Logs")
	
	// Show active filters
	var filters []string
	for level, active := range m.showLevel {
		if active {
			style := subtleStyle
			switch level {
			case "ERROR", "FATAL":
				style = errorStyle
			case "WARN":
				style = warningStyle
			case "INFO":
				style = infoStyle
			case "DEBUG":
				style = subtleStyle
			}
			filters = append(filters, style.Render(level))
		}
	}
	
	filterInfo := fmt.Sprintf("Showing: %s", strings.Join(filters, " "))
	
	return lipgloss.JoinHorizontal(lipgloss.Top,
		title,
		lipgloss.NewStyle().Width(m.width-lipgloss.Width(title)-lipgloss.Width(filterInfo)).Render(""),
		subtleStyle.Render(filterInfo),
	)
}

// renderFooter renders the log viewer footer with controls
func (m LogViewerModel) renderFooter() string {
	controls := []string{
		"↑↓/j/k: scroll",
		"home/end: top/bottom",
		"a: auto-scroll",
		"c: clear",
		"d/i/w/e: toggle debug/info/warn/error",
	}
	
	scrollInfo := fmt.Sprintf("%3.f%%", m.viewport.ScrollPercent()*100)
	if m.autoScroll {
		scrollInfo += " (auto)"
	}
	
	controlsText := subtleStyle.Render(strings.Join(controls, " • "))
	scrollText := subtleStyle.Render(scrollInfo)
	
	return lipgloss.JoinHorizontal(lipgloss.Top,
		controlsText,
		lipgloss.NewStyle().Width(m.width-lipgloss.Width(controlsText)-lipgloss.Width(scrollText)).Render(""),
		scrollText,
	)
}

// UpdateContent forces an update of the log content (public method for external use)
func (m *LogViewerModel) UpdateContent() {
	m.updateLogContent()
}

// updateLogContent updates the viewport content with latest logs
func (m *LogViewerModel) updateLogContent() {
	entries := m.buffer.GetEntriesAfter(m.lastUpdate.Add(-time.Second * 30)) // Show last 30 seconds plus new
	if len(entries) == 0 {
		entries = m.buffer.GetEntries() // Get all if none recent
	}
	
	var lines []string
	for _, entry := range entries {
		if !m.showLevel[entry.Level] {
			continue
		}
		
		line := m.formatLogEntry(entry)
		lines = append(lines, line)
	}
	
	content := strings.Join(lines, "\n")
	m.viewport.SetContent(content)
	
	// Auto-scroll to bottom if enabled
	if m.autoScroll {
		m.viewport.GotoBottom()
	}
	
	m.lastUpdate = time.Now()
}

// formatLogEntry formats a single log entry for display
func (m LogViewerModel) formatLogEntry(entry types.LogEntry) string {
	timestamp := entry.Timestamp.Format("15:04:05")
	
	// Style based on log level
	var levelStyle lipgloss.Style
	switch entry.Level {
	case "DEBUG":
		levelStyle = subtleStyle
	case "INFO":
		levelStyle = infoStyle
	case "WARN":
		levelStyle = warningStyle
	case "ERROR", "FATAL":
		levelStyle = errorStyle
	default:
		levelStyle = subtleStyle
	}
	
	// Format: [15:04:05] LEVEL [component] message
	levelText := levelStyle.Render(fmt.Sprintf("%-5s", entry.Level))
	componentText := subtleStyle.Render(fmt.Sprintf("[%s]", entry.Component))
	
	// Truncate long messages to fit viewport
	maxMessageWidth := m.viewport.Width - 25 // Account for timestamp, level, component
	message := entry.Message
	if len(message) > maxMessageWidth {
		message = message[:maxMessageWidth-3] + "..."
	}
	
	return fmt.Sprintf("%s %s %s %s",
		subtleStyle.Render(timestamp),
		levelText,
		componentText,
		message,
	)
}

// Global log buffer for the application
var globalLogBuffer *LogBuffer

// InitLogBuffer initializes the global log buffer
func InitLogBuffer(maxSize int) {
	globalLogBuffer = NewLogBuffer(maxSize)
}

// GetLogBuffer returns the global log buffer
func GetLogBuffer() *LogBuffer {
	if globalLogBuffer == nil {
		InitLogBuffer(1000) // Default size
	}
	return globalLogBuffer
}

// AddLogToBuffer adds a log entry to the global buffer
func AddLogToBuffer(entry types.LogEntry) {
	buffer := GetLogBuffer()
	buffer.AddEntry(entry)
}