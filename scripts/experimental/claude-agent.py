#!/usr/bin/env python3
"""
Claude Agent - Containerized AI Development Assistant
Replaces Claude Code CLI with API-based interaction for complete isolation.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Run: pip3 install anthropic", file=sys.stderr)
    sys.exit(1)


class ContainerizedClaude:
    def __init__(self, api_key: str, issue_data: Dict, analysis_data: Dict, workspace: Path):
        """Initialize the containerized Claude agent."""
        self.client = anthropic.Anthropic(api_key=api_key)
        self.issue = issue_data
        self.analysis = analysis_data
        self.workspace = workspace
        self.conversation_history = []
        
        # Extract key information
        self.issue_number = issue_data.get('issue_number')
        self.branch_name = issue_data.get('branch_name')
        self.repo_owner = issue_data.get('owner')
        self.repo_name = issue_data.get('repo')
        
    def log(self, message: str, level: str = "INFO"):
        """Log a message with timestamp."""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def run_command(self, command: str, check: bool = True) -> Tuple[int, str, str]:
        """Run a shell command and return (returncode, stdout, stderr)."""
        self.log(f"Executing: {command}")
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                cwd=self.workspace
            )
            
            if check and result.returncode != 0:
                self.log(f"Command failed with code {result.returncode}: {result.stderr}", "ERROR")
                raise subprocess.CalledProcessError(result.returncode, command, result.stdout, result.stderr)
                
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            self.log(f"Command execution failed: {e}", "ERROR")
            raise
            
    def send_message(self, message: str, system_prompt: Optional[str] = None) -> str:
        """Send a message to Claude and get response."""
        try:
            messages = self.conversation_history + [{"role": "user", "content": message}]
            
            response = self.client.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=8192,
                system=system_prompt or self.get_system_prompt(),
                messages=messages
            )
            
            assistant_message = response.content[0].text
            
            # Update conversation history
            self.conversation_history.append({"role": "user", "content": message})
            self.conversation_history.append({"role": "assistant", "content": assistant_message})
            
            return assistant_message
            
        except Exception as e:
            self.log(f"API call failed: {e}", "ERROR")
            raise
            
    def get_system_prompt(self) -> str:
        """Generate the system prompt for Claude."""
        return f"""You are a Swift development assistant working on the FeLangKit project. You are running inside a Docker container with complete isolation from the host system.

## Project Context
- Repository: {self.repo_owner}/{self.repo_name}
- Issue #{self.issue_number}: {self.issue.get('title', 'Unknown')}
- Working Branch: {self.branch_name}
- Workspace: /workspace (container-isolated)

## Your Capabilities
You can execute commands in the container using shell commands. Available tools:
- Swift build system (swift build, swift test)
- SwiftLint for code quality
- Git for version control (configured with token auth)
- GitHub CLI for API operations
- File system access within /workspace

## Development Guidelines
1. Follow the project conventions in CLAUDE.md
2. Run quality gates: swiftlint lint --fix && swiftlint lint && swift build && swift test
3. Use conventional commit format
4. Create meaningful, focused commits
5. Never expose sensitive information

## Ultra Think Analysis Context
Complexity: {self.analysis.get('complexity_assessment', {}).get('level', 'unknown')}
Risk Level: {self.analysis.get('risk_assessment', {}).get('overall_risk', 'unknown')}
Estimated Time: {self.analysis.get('implementation_roadmap', {}).get('total_estimated_time_minutes', 'unknown')} minutes
Affected Modules: {', '.join(self.analysis.get('codebase_impact', {}).get('affected_modules', []))}

## Current Task
{self.issue.get('body', 'No description available')}

Respond with specific actions you'll take. When you need to execute commands, clearly state them. Always explain your reasoning for code changes."""

    def setup_git_authentication(self):
        """Configure git with token-based authentication."""
        self.log("Setting up Git authentication...")
        
        github_token = os.getenv('GITHUB_TOKEN')
        git_user_name = os.getenv('GIT_USER_NAME', 'Claude Agent')
        git_user_email = os.getenv('GIT_USER_EMAIL', 'claude-agent@anthropic.com')
        
        if not github_token:
            raise ValueError("GITHUB_TOKEN environment variable is required")
            
        # Configure git credentials
        self.run_command(f'git config --global user.name "{git_user_name}"')
        self.run_command(f'git config --global user.email "{git_user_email}"')
        self.run_command('git config --global credential.helper store')
        
        # Store GitHub token
        credentials_file = self.workspace / '.git-credentials'
        with open(credentials_file, 'w') as f:
            f.write(f"https://{github_token}:x-oauth-basic@github.com\\n")
        
        # Set proper permissions
        credentials_file.chmod(0o600)
        
        self.log("Git authentication configured successfully")
        
    def create_branch(self):
        """Create and switch to the issue branch."""
        self.log(f"Creating branch: {self.branch_name}")
        
        # Ensure we're on the base branch
        self.run_command('git checkout master || git checkout main')
        self.run_command('git pull origin master || git pull origin main')
        
        # Create and switch to new branch
        self.run_command(f'git checkout -b {self.branch_name}')
        
        self.log(f"Switched to branch: {self.branch_name}")
        
    def run_quality_gates(self) -> bool:
        """Run the project's quality gates."""
        self.log("Running quality gates...")
        
        commands = [
            "swiftlint lint --fix",
            "swiftlint lint",
            "swift build",
            "swift test"
        ]
        
        for cmd in commands:
            try:
                self.run_command(cmd)
                self.log(f"✓ {cmd}")
            except subprocess.CalledProcessError as e:
                self.log(f"✗ {cmd} failed: {e}", "ERROR")
                return False
                
        self.log("All quality gates passed!")
        return True
        
    def commit_changes(self, message: str):
        """Commit changes with conventional commit format."""
        self.log("Committing changes...")
        
        # Check if there are changes
        returncode, stdout, _ = self.run_command('git status --porcelain', check=False)
        if not stdout.strip():
            self.log("No changes to commit")
            return
            
        # Add all changes
        self.run_command('git add .')
        
        # Commit with message
        commit_message = f"{message}\\n\\nRefs #{self.issue_number}\\n\\n🤖 Generated with Claude Agent Automation"
        self.run_command(f'git commit -m "{commit_message}"')
        
        self.log(f"Committed: {message}")
        
    def push_branch(self):
        """Push the branch to remote."""
        self.log(f"Pushing branch: {self.branch_name}")
        self.run_command(f'git push -u origin {self.branch_name}')
        
    def create_pull_request(self) -> str:
        """Create a pull request and return the PR URL."""
        self.log("Creating pull request...")
        
        pr_title = self.issue.get('pr_title', f"Resolve #{self.issue_number}: {self.issue.get('title', 'Issue')}")
        pr_body = f"""## Summary
Resolves #{self.issue_number}

This PR addresses the issue: {self.issue.get('title', 'Unknown issue')}

## Changes
Implementation based on Ultra Think analysis:
- Complexity: {self.analysis.get('complexity_assessment', {}).get('level', 'unknown')}
- Risk Level: {self.analysis.get('risk_assessment', {}).get('overall_risk', 'unknown')}

## Test Plan
- [x] All existing tests pass
- [x] SwiftLint validation passes  
- [x] Code builds successfully

🤖 Generated with Claude Agent Automation"""

        # Create PR using GitHub CLI
        _, stdout, _ = self.run_command(f'gh pr create --title "{pr_title}" --body "{pr_body}"')
        
        # Extract PR URL from output
        pr_url = stdout.strip().split('\\n')[-1] if stdout.strip() else "PR URL not found"
        
        self.log(f"Pull request created: {pr_url}")
        return pr_url
        
    def execute_development_workflow(self) -> Dict:
        """Execute the complete development workflow."""
        execution_report = {
            "issue_number": self.issue_number,
            "branch_name": self.branch_name,
            "start_time": time.time(),
            "steps": [],
            "success": False,
            "error": None,
            "pr_url": None
        }
        
        try:
            # Step 1: Setup
            self.log("Starting development workflow...")
            execution_report["steps"].append("workflow_started")
            
            self.setup_git_authentication()
            execution_report["steps"].append("git_configured")
            
            self.create_branch()
            execution_report["steps"].append("branch_created")
            
            # Step 2: Get initial codebase understanding
            initial_message = f"""I need to implement the following GitHub issue:

**Issue #{self.issue_number}**: {self.issue.get('title', 'Unknown')}

**Description**:
{self.issue.get('body', 'No description')}

**Ultra Think Analysis Summary**:
- Complexity: {self.analysis.get('complexity_assessment', {}).get('level', 'unknown')}
- Estimated Time: {self.analysis.get('implementation_roadmap', {}).get('total_estimated_time_minutes', 'unknown')} minutes
- Affected Modules: {', '.join(self.analysis.get('codebase_impact', {}).get('affected_modules', []))}

Please analyze the codebase and provide a step-by-step implementation plan. Start by exploring the relevant files and understanding the current structure."""

            response = self.send_message(initial_message)
            execution_report["steps"].append("initial_analysis")
            self.log("Initial analysis completed")
            
            # Step 3: Interactive implementation
            max_iterations = 20
            iteration = 0
            
            while iteration < max_iterations:
                iteration += 1
                self.log(f"Implementation iteration {iteration}/{max_iterations}")
                
                # Check current status
                _, git_status, _ = self.run_command('git status --porcelain', check=False)
                
                status_message = f"""Current status (iteration {iteration}):
- Working directory: {'clean' if not git_status.strip() else 'has changes'}
- Git status: {git_status[:500] if git_status else 'No changes'}

Please continue with the implementation. If you need to run commands, state them clearly.
If the implementation is complete, respond with "IMPLEMENTATION_COMPLETE"."""

                response = self.send_message(status_message)
                
                if "IMPLEMENTATION_COMPLETE" in response.upper():
                    self.log("Implementation marked as complete by Claude")
                    break
                    
                # Parse response for commands (this is a simplified approach)
                # In a real implementation, you might use function calling or structured output
                if any(cmd in response.lower() for cmd in ['swift build', 'swift test', 'git', 'swiftlint']):
                    self.log("Claude suggested commands - manual execution needed")
                    
            execution_report["steps"].append("implementation_completed")
            
            # Step 4: Quality gates
            if not self.run_quality_gates():
                raise Exception("Quality gates failed")
            execution_report["steps"].append("quality_gates_passed")
            
            # Step 5: Commit changes
            commit_message = f"feat: implement {self.issue.get('title', f'issue #{self.issue_number}')}"
            self.commit_changes(commit_message)
            execution_report["steps"].append("changes_committed")
            
            # Step 6: Push and create PR
            self.push_branch()
            execution_report["steps"].append("branch_pushed")
            
            pr_url = self.create_pull_request()
            execution_report["pr_url"] = pr_url
            execution_report["steps"].append("pr_created")
            
            execution_report["success"] = True
            self.log("Development workflow completed successfully!")
            
        except Exception as e:
            self.log(f"Workflow failed: {e}", "ERROR")
            execution_report["error"] = str(e)
            
        finally:
            execution_report["end_time"] = time.time()
            execution_report["duration_seconds"] = execution_report["end_time"] - execution_report["start_time"]
            
        return execution_report


def main():
    parser = argparse.ArgumentParser(description="Claude Agent - Containerized AI Development Assistant")
    parser.add_argument("--issue-data", required=True, help="Path to issue data JSON file")
    parser.add_argument("--analysis-data", required=True, help="Path to Ultra Think analysis JSON file")
    parser.add_argument("--workspace", required=True, help="Workspace directory path")
    parser.add_argument("--output", required=True, help="Output file for execution report")
    
    args = parser.parse_args()
    
    # Validate inputs
    issue_data_path = Path(args.issue_data)
    analysis_data_path = Path(args.analysis_data)
    workspace_path = Path(args.workspace)
    output_path = Path(args.output)
    
    if not issue_data_path.exists():
        print(f"Error: Issue data file not found: {issue_data_path}", file=sys.stderr)
        sys.exit(1)
        
    if not analysis_data_path.exists():
        print(f"Error: Analysis data file not found: {analysis_data_path}", file=sys.stderr)
        sys.exit(1)
        
    if not workspace_path.exists():
        print(f"Error: Workspace directory not found: {workspace_path}", file=sys.stderr)
        sys.exit(1)
        
    # Load data
    with open(issue_data_path) as f:
        issue_data = json.load(f)
        
    with open(analysis_data_path) as f:
        analysis_data = json.load(f)
        
    # Check for required environment variables
    api_key = os.getenv('ANTHROPIC_API_KEY')
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable is required", file=sys.stderr)
        sys.exit(1)
        
    # Initialize and run Claude agent
    agent = ContainerizedClaude(api_key, issue_data, analysis_data, workspace_path)
    
    try:
        execution_report = agent.execute_development_workflow()
        
        # Save execution report
        with open(output_path, 'w') as f:
            json.dump(execution_report, f, indent=2)
            
        # Print summary
        print(f"\\nExecution completed: {'SUCCESS' if execution_report['success'] else 'FAILED'}")
        print(f"Steps completed: {len(execution_report['steps'])}")
        print(f"Duration: {execution_report.get('duration_seconds', 0):.2f} seconds")
        
        if execution_report['success']:
            print(f"PR URL: {execution_report.get('pr_url', 'Not available')}")
        else:
            print(f"Error: {execution_report.get('error', 'Unknown error')}")
            
        sys.exit(0 if execution_report['success'] else 1)
        
    except Exception as e:
        print(f"Fatal error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()