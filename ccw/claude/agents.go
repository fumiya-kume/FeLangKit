package claude

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"

	"ccw/logging"
)

// AgentExecutor handles execution of Claude Code agents for the 8-step workflow
type AgentExecutor struct {
	claudeExecutable string
	workingDir       string
	logger           *logging.Logger
}

// NewAgentExecutor creates a new agent executor
func NewAgentExecutor(claudeExecutable, workingDir string, logger *logging.Logger) *AgentExecutor {
	if claudeExecutable == "" {
		claudeExecutable = "claude"
	}
	
	return &AgentExecutor{
		claudeExecutable: claudeExecutable,
		workingDir:       workingDir,
		logger:           logger,
	}
}

// ExecuteNonInteractiveAgent runs Claude Code in non-interactive mode with a prompt
func (ae *AgentExecutor) ExecuteNonInteractiveAgent(agentType, prompt string, maxTime time.Duration) (string, error) {
	ae.logger.Info("agent", fmt.Sprintf("Starting %s agent (non-interactive)", agentType), map[string]interface{}{
		"timeout": maxTime.String(),
	})

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), maxTime)
	defer cancel()

	// Create command with --print flag for non-interactive mode
	cmd := exec.CommandContext(ctx, ae.claudeExecutable, "--print", prompt)
	if ae.workingDir != "" {
		cmd.Dir = ae.workingDir
	}

	// Capture output
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Enhanced error reporting
		var errorDetails strings.Builder
		errorDetails.WriteString(fmt.Sprintf("%s agent execution failed: %v\n", agentType, err))
		errorDetails.WriteString(fmt.Sprintf("Command: %s --print <prompt>\n", ae.claudeExecutable))
		errorDetails.WriteString(fmt.Sprintf("Working Directory: %s\n", ae.workingDir))
		
		if exitError, ok := err.(*exec.ExitError); ok {
			errorDetails.WriteString(fmt.Sprintf("Exit Code: %d\n", exitError.ExitCode()))
		}
		
		if ctx.Err() == context.DeadlineExceeded {
			errorDetails.WriteString(fmt.Sprintf("Timeout: Agent exceeded %v limit\n", maxTime))
		}
		
		// Check for common issues
		if strings.Contains(err.Error(), "executable file not found") {
			errorDetails.WriteString("\nPossible Solution: Ensure Claude Code is properly installed\n")
		}
		
		if len(output) > 0 {
			errorDetails.WriteString(fmt.Sprintf("Output: %s\n", string(output)))
		}
		
		ae.logger.Error("agent", errorDetails.String(), map[string]interface{}{
			"agent_type": agentType,
			"timeout":    maxTime.String(),
		})
		
		return "", fmt.Errorf("%s", errorDetails.String())
	}

	ae.logger.Info("agent", fmt.Sprintf("%s agent completed successfully", agentType), map[string]interface{}{
		"output_length": len(output),
	})

	return string(output), nil
}

// ExecuteInteractiveAgent runs Claude Code in interactive mode with context from a file
func (ae *AgentExecutor) ExecuteInteractiveAgent(agentType, contextPath string, maxTime time.Duration) error {
	ae.logger.Info("agent", fmt.Sprintf("Starting %s agent (interactive)", agentType), map[string]interface{}{
		"context_path": contextPath,
		"timeout":      maxTime.String(),
	})

	// Read context from file
	contextData, err := os.ReadFile(contextPath)
	if err != nil {
		return fmt.Errorf("failed to read context file %s: %w", contextPath, err)
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), maxTime)
	defer cancel()

	// Create command for interactive mode
	// Pass context via stdin to avoid OS argument length limits (macOS ~256KB, Linux ~2MB)
	cmd := exec.CommandContext(ctx, ae.claudeExecutable)
	if ae.workingDir != "" {
		cmd.Dir = ae.workingDir
	}

	// Set up interactive mode with context piped first, then user input
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = io.MultiReader(strings.NewReader(string(contextData)+"\n"), os.Stdin)

	ae.logger.Info("agent", fmt.Sprintf("Launching %s agent in interactive mode...", agentType), nil)

	// Run in interactive mode
	if err := cmd.Run(); err != nil {
		// Enhanced error reporting
		var errorDetails strings.Builder
		errorDetails.WriteString(fmt.Sprintf("%s agent execution failed: %v\n", agentType, err))
		errorDetails.WriteString(fmt.Sprintf("Command: %s <context>\n", ae.claudeExecutable))
		errorDetails.WriteString(fmt.Sprintf("Working Directory: %s\n", ae.workingDir))
		errorDetails.WriteString(fmt.Sprintf("Context File: %s\n", contextPath))
		
		if exitError, ok := err.(*exec.ExitError); ok {
			errorDetails.WriteString(fmt.Sprintf("Exit Code: %d\n", exitError.ExitCode()))
		}
		
		if ctx.Err() == context.DeadlineExceeded {
			errorDetails.WriteString(fmt.Sprintf("Timeout: Agent exceeded %v limit\n", maxTime))
		}
		
		// Check for common issues
		if strings.Contains(err.Error(), "executable file not found") {
			errorDetails.WriteString("\nPossible Solution: Ensure Claude Code is properly installed\n")
		}
		
		ae.logger.Error("agent", errorDetails.String(), map[string]interface{}{
			"agent_type":   agentType,
			"context_path": contextPath,
			"timeout":      maxTime.String(),
		})
		
		return fmt.Errorf("%s", errorDetails.String())
	}

	ae.logger.Info("agent", fmt.Sprintf("%s agent completed successfully", agentType), nil)
	return nil
}

// SetWorkingDirectory updates the working directory for agent execution
func (ae *AgentExecutor) SetWorkingDirectory(workingDir string) {
	ae.workingDir = workingDir
	ae.logger.Info("agent", "Updated working directory", map[string]interface{}{
		"working_dir": workingDir,
	})
}