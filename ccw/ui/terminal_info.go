package ui

// TerminalColorInfo holds detected terminal color information
type TerminalColorInfo struct {
	Background        string
	Foreground        string
	AccentColor       string
	SupportsTrueColor bool
	Colors256         bool
	ThemeType         string // "light", "dark", "auto"
	DetectionMethod   string
}