# CCW Debug Mode Documentation

## Overview

CCW now includes comprehensive debugging and error reporting capabilities to help diagnose issues, especially when the CLI crashes during PR creation or other critical operations.

## Debug Modes

### 1. Debug Mode (`--debug`)
- Enables detailed logging for all operations
- Captures command execution details, error messages, and stack traces
- Logs are saved to `.ccw/logs/` directory
- Best for general troubleshooting

```bash
ccw --debug https://github.com/owner/repo/issues/123
```

### 2. Verbose Mode (`--verbose`)
- Includes all debug mode features
- Adds comprehensive context logging for every operation
- Shows detailed GitHub API responses and git command outputs
- Best for detailed analysis of workflow execution

```bash
ccw --verbose https://github.com/owner/repo/issues/123
```

### 3. Trace Mode (`--trace`)
- Includes all verbose mode features
- Adds function call tracing with stack traces
- Logs every function entry/exit with parameters
- Best for deep debugging and crash analysis

```bash
ccw --trace https://github.com/owner/repo/issues/123
```

## Environment Variables

You can also enable debug modes using environment variables:

```bash
# Enable debug mode
export DEBUG_MODE=true

# Enable verbose logging
export VERBOSE_MODE=true

# Enable trace mode with stack traces
export TRACE_MODE=true

# Force enable file logging
export CCW_LOG_FILE=true

# Run with environment variables
ccw https://github.com/owner/repo/issues/123
```

## Crash Recovery

When CCW crashes, it now:

1. **Captures the crash** with full stack trace
2. **Saves crash report** to `.ccw/crashes/crash-{session-id}.json`
3. **Logs environment details** (Go version, OS, architecture)
4. **Records command line arguments** and working directory
5. **Shows user-friendly error** with crash report location

### Crash Report Location
```
.ccw/crashes/crash-{timestamp}-{session-id}.json
```

### Crash Report Contents
```json
{
  "timestamp": "2025-01-30T12:34:56Z",
  "session_id": "1738234567-abc12345",
  "panic_value": "runtime error: ...",
  "stack_trace": "goroutine 1 [running]:\n...",
  "issue_url": "https://github.com/owner/repo/issues/123",
  "environment": {
    "go_version": "go1.21.5",
    "goos": "darwin",
    "goarch": "arm64",
    "num_cpu": 8,
    "debug_mode": true
  },
  "command_line": ["ccw", "--debug", "..."],
  "working_dir": "/path/to/repo"
}
```

## Log Files

### Log Directory Structure
```
.ccw/
├── logs/
│   ├── ccw-{session-id}.log     # Main application log
│   └── errors.json              # Persistent error store
├── crashes/
│   └── crash-{session-id}.json  # Crash reports
└── config/
    └── ccw.yaml                 # Configuration file
```

### Log Format
Each log entry includes:
- **Timestamp**: ISO 8601 format
- **Level**: DEBUG, INFO, WARN, ERROR, FATAL
- **Component**: Which part of CCW generated the log
- **Message**: Human-readable description
- **Context**: Structured data (JSON)

## GitHub API Debug Logging

Enhanced GitHub operations now log:

### Issue Fetching
```
[DEBUG] [GitHub:GetIssue] Fetching issue data | Context: {
  "owner": "owner",
  "repo": "repo", 
  "issue_number": 123,
  "api_endpoint": "repos/owner/repo/issues/123"
}
```

### PR Creation (Critical for Crash Diagnosis)
```
[DEBUG] [GitHub:CreatePR] Creating pull request | Context: {
  "owner": "owner",
  "repo": "repo",
  "title": "Fix: Resolve #123",
  "head": "issue-123-20250130-123456",
  "base": "master",
  "body_len": 1234,
  "repo_str": "owner/repo"
}

[DEBUG] [GitHub:CreatePR] Executing gh command | Context: {
  "command": "gh",
  "args": ["pr", "create", "--title", "...", "--body", "...", "--head", "...", "--base", "...", "--repo", "..."]
}
```

### Error Capture
```
[DEBUG] [GitHub:CreatePR] gh pr create command failed | Context: {
  "error": "exit status 1",
  "stderr": "GraphQL error: ...",
  "exit_code": 1,
  "command": "gh pr create ...",
  "owner": "owner",
  "repo": "repo",
  "head": "issue-123-...",
  "base": "master"
}
```

## Workflow Step Debug Logging

Each workflow step is logged with context:

### Step 1: Issue Extraction
```
[DEBUG] [workflow] [step1] Extracting issue information | Context: {
  "issue_url": "https://github.com/owner/repo/issues/123"
}
```

### Step 2: GitHub API
```
[DEBUG] [workflow] [step2] Fetching GitHub issue data | Context: {
  "owner": "owner",
  "repo": "repo",
  "issue_number": 123
}
```

### Step 3: Worktree Creation
```
[DEBUG] [workflow] [step3] Generated worktree configuration | Context: {
  "branch_name": "issue-123-20250130-123456",
  "worktree_path": "/tmp/ccw-worktrees/issue-123-...",
  "base_path": "/tmp/ccw-worktrees"
}
```

### Step 5: Claude Code Execution
```
[DEBUG] [workflow] [step5] Executing Claude Code with context | Context: {
  "claude_context": {
    "project_path": "/tmp/ccw-worktrees/...",
    "task_type": "implementation",
    "issue_title": "Add debug mode support"
  }
}
```

### Step 6: Validation
```
[DEBUG] [workflow] [step6] Validation completed | Context: {
  "success": true,
  "errors": 0,
  "lint_success": true,
  "build_success": true,
  "test_success": true
}
```

### Step 7: Git Push
```
[DEBUG] [workflow] [step7] Pushing changes to remote | Context: {
  "branch_name": "issue-123-20250130-123456",
  "worktree_path": "/tmp/ccw-worktrees/..."
}
```

## Troubleshooting Common Issues

### PR Creation Crashes

1. **Enable trace mode** to capture detailed execution:
   ```bash
   ccw --trace https://github.com/owner/repo/issues/123
   ```

2. **Check crash report** in `.ccw/crashes/`

3. **Look for GitHub API errors** in logs:
   - Authentication issues
   - Branch conflicts
   - Repository permissions
   - Rate limiting

### GitHub CLI Issues

Debug mode captures:
- `gh` command execution
- Exit codes and error messages
- Authentication status
- API responses

### Git Operations

Enhanced logging for:
- Worktree creation/removal
- Branch operations
- Push failures
- Remote configuration

## Performance Impact

- **Debug mode**: Minimal overhead (~5% performance impact)
- **Verbose mode**: Moderate overhead (~10-15% performance impact)
- **Trace mode**: Higher overhead (~20-25% performance impact)

Use debug modes only when troubleshooting issues.

## Examples

### Basic Debug Session
```bash
# Enable debug mode and run workflow
ccw --debug https://github.com/owner/repo/issues/123

# Check logs if something goes wrong
ls -la .ccw/logs/
cat .ccw/logs/ccw-*.log
```

### Comprehensive Crash Investigation
```bash
# Enable full tracing
ccw --trace https://github.com/owner/repo/issues/123

# If it crashes, check crash report
ls -la .ccw/crashes/
cat .ccw/crashes/crash-*.json

# Review detailed logs
grep "ERROR\|FATAL" .ccw/logs/ccw-*.log
grep "GitHub:CreatePR" .ccw/logs/ccw-*.log
```

### Environment Variable Usage
```bash
# Set debug environment
export DEBUG_MODE=true
export VERBOSE_MODE=true
export CCW_LOG_FILE=true

# Run normal workflow
ccw list
# or
ccw https://github.com/owner/repo/issues/123
```

## Integration with CI/CD

For automated debugging in CI environments:

```bash
# Enable debug mode in CI
export DEBUG_MODE=true
export CCW_LOG_FILE=true

# Run CCW with error capture
if ! ccw --debug https://github.com/owner/repo/issues/123; then
  echo "CCW failed - uploading debug logs"
  tar -czf ccw-debug.tar.gz .ccw/
  # Upload ccw-debug.tar.gz as CI artifact
fi
```

This comprehensive debug system should help you diagnose the PR creation crash and any other issues that occur during CCW execution.