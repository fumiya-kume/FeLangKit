package claude

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Client represents a Claude Code CLI client
type Client struct {
	timeout time.Duration
}

// NewClient creates a new Claude client with specified timeout
func NewClient(timeout time.Duration) *Client {
	return &Client{
		timeout: timeout,
	}
}

// LaunchInteractive starts an interactive Claude Code session
func (c *Client) LaunchInteractive(workdir, contextContent string) error {
	// Create context file
	contextFile := filepath.Join(workdir, ".claude-context.md")
	if err := ioutil.WriteFile(contextFile, []byte(contextContent), 0644); err != nil {
		return fmt.Errorf("failed to write context file: %w", err)
	}
	defer os.Remove(contextFile) // Clean up after session

	// Prepare Claude Code command
	cmd := exec.Command("claude")
	cmd.Dir = workdir
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Set environment variables for context
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("CLAUDE_CONTEXT_FILE=%s", contextFile),
		"CLAUDE_MODE=interactive",
	)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()

	// Start the command
	if err := cmd.Start(); err != nil {
		// Enhanced error reporting for startup failures
		fmt.Printf("\n❌ Failed to start Claude Code: %v\n", err)
		
		// Provide specific troubleshooting based on error type
		fmt.Println("\n🔍 Troubleshooting suggestions:")
		if strings.Contains(err.Error(), "executable file not found") {
			fmt.Println("- Claude Code CLI is not installed or not in PATH")
			fmt.Println("- Install from: https://claude.ai/code")
			fmt.Println("- Verify installation: claude --version")
		} else if strings.Contains(err.Error(), "permission denied") {
			fmt.Println("- Check file permissions for Claude Code executable")
			fmt.Println("- Try: chmod +x $(which claude)")
		} else {
			fmt.Println("- Verify Claude Code is properly installed")
			fmt.Println("- Check system PATH configuration")
			fmt.Println("- Try: which claude")
		}
		
		return fmt.Errorf("failed to start Claude Code: %w", err)
	}

	// Wait for completion or timeout
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case err := <-done:
		if err != nil {
			// Enhanced error reporting for execution failures
			fmt.Printf("\n❌ Claude Code session failed: %v\n", err)
			
			// Get exit code if available
			if exitError, ok := err.(*exec.ExitError); ok {
				fmt.Printf("Exit code: %d\n", exitError.ExitCode())
			}
			
			// Provide troubleshooting suggestions
			fmt.Println("\n🔍 Troubleshooting suggestions:")
			if strings.Contains(err.Error(), "authentication") {
				fmt.Println("- Claude Code authentication may have expired")
				fmt.Println("- Try: claude auth login")
			} else if strings.Contains(err.Error(), "network") {
				fmt.Println("- Network connectivity issues")
				fmt.Println("- Check internet connection and proxy settings")
			} else {
				fmt.Println("- Check Claude Code logs for more details")
				fmt.Println("- Verify your Claude Code session")
				fmt.Println("- Try: claude --help")
			}
			
			return fmt.Errorf("Claude Code session failed: %w", err)
		}
		return nil
	case <-ctx.Done():
		// Timeout occurred, terminate the process
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
		fmt.Printf("\n⏰ Claude Code session timed out after %v\n", c.timeout)
		fmt.Println("\n🔍 Troubleshooting suggestions:")
		fmt.Println("- Session took longer than expected")
		fmt.Println("- Consider increasing timeout in configuration")
		fmt.Println("- Check if Claude Code is waiting for input")
		
		return fmt.Errorf("Claude Code session timed out after %v", c.timeout)
	}
}

// ExecuteNonInteractive runs Claude Code in non-interactive mode
func (c *Client) ExecuteNonInteractive(workdir, prompt string) (string, error) {
	// Use --print flag for non-interactive output
	cmd := exec.Command("claude", "--print")
	cmd.Dir = workdir
	
	// Write prompt to stdin
	cmd.Stdin = createPromptReader(prompt)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()

	// Execute with context
	output, err := cmd.Output()
	if err != nil {
		select {
		case <-ctx.Done():
			return "", fmt.Errorf("Claude Code timed out after %v", c.timeout)
		default:
			return "", fmt.Errorf("Claude Code execution failed: %w", err)
		}
	}

	return string(output), nil
}

// GenerateCommitMessage generates a commit message using Claude
func (c *Client) GenerateCommitMessage(workdir string) (string, error) {
	prompt := `Please generate a conventional commit message for the staged changes in this repository. 
	
Analyze the git diff and create a concise commit message following the format:
<type>(<scope>): <description>

Where type is one of: feat, fix, docs, style, refactor, test, chore
Keep the description under 50 characters.`

	return c.ExecuteNonInteractive(workdir, prompt)
}

// GeneratePRDescription generates a PR description using Claude
func (c *Client) GeneratePRDescription(workdir, issueContext string) (string, error) {
	prompt := fmt.Sprintf(`Generate a comprehensive pull request description for the changes in this repository.

Issue Context:
%s

Please create a PR description with the following sections:
- Summary: Brief overview of the changes
- Changes Made: Detailed list of modifications
- Testing: How the changes were tested
- Notes: Any additional information

Make it professional and detailed.`, issueContext)

	return c.ExecuteNonInteractive(workdir, prompt)
}

// AnalyzeCode performs code analysis using Claude
func (c *Client) AnalyzeCode(workdir, filePath string) (string, error) {
	prompt := fmt.Sprintf(`Please analyze the code in %s and provide:

1. Code quality assessment
2. Potential issues or improvements
3. Adherence to best practices
4. Security considerations if applicable

Be specific and actionable in your feedback.`, filePath)

	return c.ExecuteNonInteractive(workdir, prompt)
}

// CheckAvailability verifies Claude Code CLI is available
func CheckAvailability() error {
	cmd := exec.Command("claude", "--version")
	if err := cmd.Run(); err != nil {
		fmt.Printf("\n❌ Claude Code CLI not found: %v\n", err)
		fmt.Println("\n🔧 Installation instructions:")
		fmt.Println("1. Visit: https://claude.ai/code")
		fmt.Println("2. Download and install Claude Code CLI")
		fmt.Println("3. Verify installation: claude --version")
		fmt.Println("4. Ensure Claude Code is in your PATH")
		
		if strings.Contains(err.Error(), "executable file not found") {
			fmt.Println("\n💡 Common solutions:")
			fmt.Println("- Add Claude Code to PATH: export PATH=$PATH:/path/to/claude")
			fmt.Println("- Restart terminal after installation")
			fmt.Println("- Check installation location: which claude")
		}
		
		return fmt.Errorf("Claude Code CLI not found. Please install it from https://claude.ai/code")
	}
	return nil
}

// Helper functions

func createPromptReader(prompt string) *os.File {
	// Create a temporary file with the prompt
	tmpFile, err := ioutil.TempFile("", "claude-prompt-*.txt")
	if err != nil {
		return nil
	}
	
	tmpFile.WriteString(prompt)
	tmpFile.Seek(0, 0) // Reset to beginning
	
	return tmpFile
}

// Response represents a structured response from Claude
type Response struct {
	Content   string    `json:"content"`
	Timestamp time.Time `json:"timestamp"`
	Success   bool      `json:"success"`
	Error     string    `json:"error,omitempty"`
}

// Session represents an ongoing Claude session
type Session struct {
	client    *Client
	workdir   string
	contextID string
	active    bool
}

// NewSession creates a new Claude session
func (c *Client) NewSession(workdir string) *Session {
	return &Session{
		client:    c,
		workdir:   workdir,
		contextID: generateSessionID(),
		active:    false,
	}
}

// Start begins the session
func (s *Session) Start(initialContext string) error {
	if s.active {
		return fmt.Errorf("session already active")
	}
	
	s.active = true
	return s.client.LaunchInteractive(s.workdir, initialContext)
}

// Stop ends the session
func (s *Session) Stop() {
	s.active = false
}

// IsActive returns whether the session is currently active
func (s *Session) IsActive() bool {
	return s.active
}

func generateSessionID() string {
	return fmt.Sprintf("claude-session-%d", time.Now().Unix())
}