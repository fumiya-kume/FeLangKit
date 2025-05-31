package ui

import "github.com/charmbracelet/lipgloss"

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