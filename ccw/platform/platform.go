package platform

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

// Cross-platform compatibility utilities

// Platform detection and capabilities
type PlatformInfo struct {
	OS              string
	Arch            string
	SupportsColor   bool
	SupportsUnicode bool
	DefaultShell    string
	PathSeparator   string
	LineEnding      string
	TempDir         string
	HomeDir         string
	ExecutableExt   string
	MaxPathLength   int
}

// Get current platform information
func GetPlatformInfo() *PlatformInfo {
	info := &PlatformInfo{
		OS:            runtime.GOOS,
		Arch:          runtime.GOARCH,
		PathSeparator: string(os.PathSeparator),
	}

	// Set platform-specific defaults
	switch runtime.GOOS {
	case "windows":
		info.DefaultShell = "cmd.exe"
		info.LineEnding = "\r\n"
		info.ExecutableExt = ".exe"
		info.MaxPathLength = 260 // Traditional Windows limit
		info.SupportsColor = checkWindowsColorSupport()
		info.SupportsUnicode = checkWindowsUnicodeSupport()
	case "darwin":
		info.DefaultShell = "/bin/bash"
		info.LineEnding = "\n"
		info.ExecutableExt = ""
		info.MaxPathLength = 1024
		info.SupportsColor = checkUnixColorSupport()
		info.SupportsUnicode = true
	case "linux":
		info.DefaultShell = "/bin/bash"
		info.LineEnding = "\n"
		info.ExecutableExt = ""
		info.MaxPathLength = 4096
		info.SupportsColor = checkUnixColorSupport()
		info.SupportsUnicode = checkUnixUnicodeSupport()
	default:
		// Default Unix-like behavior
		info.DefaultShell = "/bin/sh"
		info.LineEnding = "\n"
		info.ExecutableExt = ""
		info.MaxPathLength = 1024
		info.SupportsColor = false
		info.SupportsUnicode = false
	}

	// Set common directories
	if tempDir := os.Getenv("TMPDIR"); tempDir != "" {
		info.TempDir = tempDir
	} else if tempDir := os.Getenv("TEMP"); tempDir != "" {
		info.TempDir = tempDir
	} else {
		info.TempDir = os.TempDir()
	}

	if homeDir, err := os.UserHomeDir(); err == nil {
		info.HomeDir = homeDir
	}

	return info
}

// Check color support on Windows
func checkWindowsColorSupport() bool {
	// Windows 10 version 1511+ supports ANSI escape sequences
	if runtime.GOOS != "windows" {
		return false
	}

	// Check for Windows Terminal or ConEmu
	if os.Getenv("WT_SESSION") != "" || os.Getenv("ConEmuPID") != "" {
		return true
	}

	// Check TERM environment variable
	term := os.Getenv("TERM")
	return strings.Contains(term, "color") || strings.Contains(term, "ansi")
}

// Check Unicode support on Windows
func checkWindowsUnicodeSupport() bool {
	if runtime.GOOS != "windows" {
		return false
	}

	// Check code page - 65001 is UTF-8
	cmd := exec.Command("cmd", "/c", "chcp")
	if output, err := cmd.Output(); err == nil {
		return strings.Contains(string(output), "65001")
	}

	return false
}

// Check color support on Unix systems
func checkUnixColorSupport() bool {
	if runtime.GOOS == "windows" {
		return false
	}

	// Check TERM environment variable
	term := os.Getenv("TERM")
	if term == "" {
		return false
	}

	// Common terminals that support color
	colorTerms := []string{
		"xterm", "xterm-color", "xterm-256color",
		"screen", "screen-256color",
		"tmux", "tmux-256color",
		"rxvt", "rxvt-color", "rxvt-unicode",
		"linux", "cygwin",
	}

	termLower := strings.ToLower(term)
	for _, colorTerm := range colorTerms {
		if strings.Contains(termLower, colorTerm) {
			return true
		}
	}

	// Check for explicit color support
	return strings.Contains(termLower, "color") || strings.Contains(termLower, "ansi")
}

// Check Unicode support on Unix systems
func checkUnixUnicodeSupport() bool {
	if runtime.GOOS == "windows" {
		return false
	}

	// Check locale settings
	locale := os.Getenv("LC_ALL")
	if locale == "" {
		locale = os.Getenv("LC_CTYPE")
	}
	if locale == "" {
		locale = os.Getenv("LANG")
	}

	localeLower := strings.ToLower(locale)
	return strings.Contains(localeLower, "utf-8") || strings.Contains(localeLower, "utf8")
}

// Get terminal size in a cross-platform way
func GetTerminalSize() (width, height int, err error) {
	switch runtime.GOOS {
	case "windows":
		return getWindowsTerminalSize()
	default:
		return getUnixTerminalSize()
	}
}

// Get terminal size on Windows
func getWindowsTerminalSize() (width, height int, err error) {
	// Try PowerShell first
	cmd := exec.Command("powershell", "-Command", "& {$Host.UI.RawUI.WindowSize.Width; $Host.UI.RawUI.WindowSize.Height}")
	if output, err := cmd.Output(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(output)), "\n")
		if len(lines) >= 2 {
			if w, err := strconv.Atoi(strings.TrimSpace(lines[0])); err == nil {
				if h, err := strconv.Atoi(strings.TrimSpace(lines[1])); err == nil {
					return w, h, nil
				}
			}
		}
	}

	// Fallback to mode command
	cmd = exec.Command("cmd", "/c", "mode", "con")
	if output, err := cmd.Output(); err == nil {
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Columns:") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					if w, err := strconv.Atoi(parts[1]); err == nil {
						width = w
					}
				}
			}
			if strings.Contains(line, "Lines:") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					if h, err := strconv.Atoi(parts[1]); err == nil {
						height = h
					}
				}
			}
		}
		if width > 0 && height > 0 {
			return width, height, nil
		}
	}

	// Default fallback
	return 80, 24, fmt.Errorf("could not determine terminal size")
}

// Get terminal size on Unix systems
func getUnixTerminalSize() (width, height int, err error) {
	// Try tput first
	if cmd := exec.Command("tput", "cols"); cmd.Err == nil {
		if output, err := cmd.Output(); err == nil {
			if w, err := strconv.Atoi(strings.TrimSpace(string(output))); err == nil {
				width = w
			}
		}
	}

	if cmd := exec.Command("tput", "lines"); cmd.Err == nil {
		if output, err := cmd.Output(); err == nil {
			if h, err := strconv.Atoi(strings.TrimSpace(string(output))); err == nil {
				height = h
			}
		}
	}

	if width > 0 && height > 0 {
		return width, height, nil
	}

	// Try stty
	if cmd := exec.Command("stty", "size"); cmd.Err == nil {
		if output, err := cmd.Output(); err == nil {
			parts := strings.Fields(strings.TrimSpace(string(output)))
			if len(parts) >= 2 {
				if h, err := strconv.Atoi(parts[0]); err == nil {
					if w, err := strconv.Atoi(parts[1]); err == nil {
						return w, h, nil
					}
				}
			}
		}
	}

	// Try syscall on Unix systems (requires cgo)
	if runtime.GOOS == "linux" || runtime.GOOS == "darwin" {
		if w, h, err := getTerminalSizeSyscall(); err == nil {
			return w, h, nil
		}
	}

	// Default fallback
	return 80, 24, fmt.Errorf("could not determine terminal size")
}

// Get terminal size using syscalls (Unix only)
func getTerminalSizeSyscall() (width, height int, err error) {
	// This would require cgo and platform-specific syscalls
	// For now, return error to fall back to command-based methods
	return 0, 0, fmt.Errorf("syscall method not implemented")
}

// Cross-platform command execution with proper shell handling
func ExecuteCommand(command string, args []string, workingDir string) *exec.Cmd {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		// Use cmd.exe on Windows
		cmdArgs := []string{"/c", command}
		cmdArgs = append(cmdArgs, args...)
		cmd = exec.Command("cmd", cmdArgs...)
	default:
		// Use the command directly on Unix systems
		cmd = exec.Command(command, args...)
	}

	if workingDir != "" {
		cmd.Dir = workingDir
	}

	return cmd
}

// Check if a command exists in PATH
func CommandExists(command string) bool {
	switch runtime.GOOS {
	case "windows":
		// Try with .exe extension first
		if _, err := exec.LookPath(command + ".exe"); err == nil {
			return true
		}
		// Try without extension
		_, err := exec.LookPath(command)
		return err == nil
	default:
		_, err := exec.LookPath(command)
		return err == nil
	}
}

// Get appropriate file permissions for the platform
func GetFilePermissions(executable bool) os.FileMode {
	switch runtime.GOOS {
	case "windows":
		// Windows doesn't use Unix-style permissions
		if executable {
			return 0755
		}
		return 0644
	default:
		// Unix-style permissions
		if executable {
			return 0755
		}
		return 0644
	}
}

// Check if running with elevated privileges
func IsElevated() bool {
	switch runtime.GOOS {
	case "windows":
		// Check if running as administrator
		cmd := exec.Command("net", "session")
		err := cmd.Run()
		return err == nil
	default:
		// Check if running as root (UID 0)
		return os.Geteuid() == 0
	}
}

// Get platform-specific temporary file prefix
func GetTempFilePrefix() string {
	switch runtime.GOOS {
	case "windows":
		return "ccw_temp_"
	default:
		return ".ccw_temp_"
	}
}

// Handle platform-specific signal handling
func SetupSignalHandler() {
	// This would be implemented with platform-specific signal handling
	// For now, just a placeholder for the interface
}

// Kill process tree (cross-platform)
func KillProcessTree(pid int) error {
	switch runtime.GOOS {
	case "windows":
		// Use taskkill on Windows to kill process tree
		cmd := exec.Command("taskkill", "/F", "/T", "/PID", strconv.Itoa(pid))
		return cmd.Run()
	default:
		// Use kill on Unix systems
		return syscall.Kill(pid, syscall.SIGTERM)
	}
}
