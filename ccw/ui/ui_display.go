package ui

import "fmt"

// DisplayHeader displays the static application header
func (ui *UIManager) DisplayHeader() {
	fmt.Print("\n")
	
	if ui.isConsoleMode() {
		// Console mode: use simple ASCII characters
		fmt.Println(ui.accentColor("================================================================"))
		fmt.Println(ui.accentColor("                    CCW - Claude Code Worktree                 "))
		fmt.Println(ui.accentColor("               Automated Issue Processing Tool                 "))
		fmt.Println(ui.accentColor("================================================================"))
	} else {
		// Interactive mode: use fancy Unicode characters
		if ui.currentTheme.BorderStyle == "double" {
			fmt.Println(ui.accentColor("╔══════════════════════════════════════════════════════════════╗"))
			fmt.Println(ui.accentColor("║                    CCW - Claude Code Worktree               ║"))
			fmt.Println(ui.accentColor("║               Automated Issue Processing Tool               ║"))
			fmt.Println(ui.accentColor("╚══════════════════════════════════════════════════════════════╝"))
		} else if ui.currentTheme.BorderStyle == "rounded" {
			fmt.Println(ui.accentColor("╭──────────────────────────────────────────────────────────────╮"))
			fmt.Println(ui.accentColor("│                    CCW - Claude Code Worktree               │"))
			fmt.Println(ui.accentColor("│               Automated Issue Processing Tool               │"))
			fmt.Println(ui.accentColor("╰──────────────────────────────────────────────────────────────╯"))
		} else { // single
			fmt.Println(ui.accentColor("┌──────────────────────────────────────────────────────────────┐"))
			fmt.Println(ui.accentColor("│                    CCW - Claude Code Worktree               │"))
			fmt.Println(ui.accentColor("│               Automated Issue Processing Tool               │"))
			fmt.Println(ui.accentColor("└──────────────────────────────────────────────────────────────┘"))
		}
	}
	
	fmt.Print("\n")
}