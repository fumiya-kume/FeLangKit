package ui

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"

	"ccw/github"
	tea "github.com/charmbracelet/bubbletea"
)

// System check implementations

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

// Helper functions for command checking
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