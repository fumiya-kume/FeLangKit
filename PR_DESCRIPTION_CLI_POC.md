# Claude Code CLI PR Description Generator - POC

## Overview

This POC demonstrates using Claude Code CLI to automatically generate comprehensive PR descriptions following the FeLangKit project's standardized format. The script analyzes git context and generates detailed, well-structured PR descriptions that meet the project's documentation requirements.

## Features

✅ **Automated Git Context Collection**
- Recent commits and changes analysis
- File modification statistics
- Diff content for technical details
- GitHub issue integration (when available)

✅ **Claude Code CLI Integration**
- Timeout protection to prevent hanging
- Proper input handling for non-interactive mode
- Error handling and fallback mechanisms
- Cross-platform clipboard integration

✅ **Structured PR Description Format**
- Follows FeLangKit's comprehensive markdown structure
- Includes all required sections (Summary, Background, Solution, etc.)
- Technical implementation details
- Testing and validation coverage
- Future impact analysis

## Usage

### Basic Usage
```bash
# Generate PR description for current branch changes
./generate_pr_description.sh

# Generate with GitHub issue context
./generate_pr_description.sh 123
```

### Integration with Existing Workflow
```bash
# 1. Make your changes and commit them
git add . && git commit -m "feat(scope): implement feature"

# 2. Generate PR description
./generate_pr_description.sh 123

# 3. Create PR with generated description
gh pr create --title "Resolve #123: Feature Implementation" --body-file pr_description.md

# 4. Copy description is automatically copied to clipboard (macOS/Linux)
```

## Script Features

### 🔒 Safety & Reliability
- **Timeout Protection**: 5-minute timeout prevents Claude CLI hanging
- **Error Handling**: Comprehensive error capture and reporting
- **Process Management**: Proper cleanup of temporary files
- **Input Validation**: Git repository and branch validation

### 📊 Context Collection
- **Git Status**: Current branch state and modifications
- **Commit History**: Recent commits for context
- **Change Analysis**: File diffs and statistics
- **Issue Integration**: GitHub issue details (via `gh` CLI)

### 🎨 User Experience
- **Loading Indicators**: Visual feedback during generation
- **Color-coded Output**: Clear status indicators
- **Clipboard Integration**: Automatic copying (macOS/Linux)
- **Preview Mode**: Shows context being sent to Claude

### 🧠 Claude Integration
- **Structured Prompts**: Comprehensive context and format instructions
- **Non-interactive Mode**: Uses `claude --print` for automation
- **Template Compliance**: Ensures FeLangKit PR format requirements
- **Comprehensive Analysis**: Includes all required sections

## Example Output

The script generates PR descriptions with the following structure:

```markdown
## Summary
Concise overview of what this PR accomplishes...

## Background & Context
- **Original Issue:** Detailed problem explanation
- **Root Cause:** Technical analysis
- **User Impact:** Effect on users/development
- **Previous State:** How things worked before
- **Requirements:** Specific needs to be met

## Solution Approach
- **Core Solution:** How the problem is solved
- **Technical Strategy:** Overall approach
- **Logic & Reasoning:** Implementation decisions
- **Alternative Approaches:** Other options considered
- **Architecture Changes:** System design impacts

## Implementation Details
- **Key Components:** Modified/added components
- **Code Changes:** Major modifications explained
- **Files Modified:** List with change descriptions
- **New Functionality:** Added features/capabilities
- **Integration Points:** How changes integrate
- **Error Handling:** Edge case management

## Technical Logic
- **Algorithm/Logic:** Step-by-step technical explanation
- **Data Flow:** How data moves through components
- **Performance Considerations:** Optimizations/trade-offs
- **Security Considerations:** Security implications
- **Backwards Compatibility:** Compatibility maintenance

## Testing & Validation
- **Test Strategy:** Overall testing approach
- **Test Coverage:** Specific tests and validation
- **Manual Testing:** Manual verification performed
- **Edge Cases:** Edge case testing and handling
- **Quality Assurance:** SwiftLint, build, test results

## Impact & Future Work
- **Breaking Changes:** Any breaking changes with guidance
- **Performance Impact:** Performance effects
- **Maintenance Impact:** Ongoing maintenance effects
- **Future Enhancements:** Future work enablement
- **Technical Debt:** Debt introduced/resolved
```

## Integration with Existing Workflow

### CCW Tool Integration
The script can be integrated with the existing `claude.sh` CCW automation:

```bash
# In claude.sh, after making changes:
echo "🤖 Generating PR description..."
./generate_pr_description.sh "$issue_number"

# Use generated description for PR creation
gh pr create --title "$pr_title" --body-file pr_description.md
```

### Manual Development Workflow
```bash
# 1. Create feature branch
git checkout -b issue-123-feature-implementation

# 2. Make changes and commit
git add . && git commit -m "feat(parser): implement new parsing feature"

# 3. Generate PR description
./generate_pr_description.sh 123

# 4. Review and edit generated description
vim pr_description.md

# 5. Create PR
gh pr create --title "Resolve #123: New Parsing Feature" --body-file pr_description.md
```

## Technical Implementation

### Claude CLI Usage
- Uses `claude --print` for non-interactive mode
- Implements timeout protection with `timeout` command
- Captures both stdout and stderr for error handling
- Avoids interactive mode mixing that causes hanging

### Context Generation
- Collects comprehensive git context (status, log, diff)
- Integrates GitHub issue data when available
- Formats context for optimal Claude analysis
- Provides structured prompt with format requirements

### Error Prevention
- Addresses known Claude CLI hanging issues
- Implements proper timeout mechanisms
- Uses non-interactive mode consistently
- Provides fallback error reporting

## Requirements

- **Git**: Repository with commit history
- **Claude Code CLI**: Latest version with `--print` flag support
- **Optional**: `gh` CLI for GitHub issue integration
- **Optional**: `pbcopy` (macOS) or `xclip` (Linux) for clipboard

## Configuration

The script includes configurable parameters:

```bash
CLAUDE_TIMEOUT=300  # 5 minutes timeout
OUTPUT_FILE="pr_description.md"  # Output file name
```

## Testing Results

The POC successfully generated a comprehensive PR description for the recent cursor rules enhancement commit, demonstrating:

- ✅ Proper git context collection and analysis
- ✅ Claude CLI integration without hanging
- ✅ Comprehensive PR description following FeLangKit format
- ✅ All required sections with detailed technical content
- ✅ Proper error handling and user feedback
- ✅ Clipboard integration for easy use

## Next Steps

1. **Integration**: Add to CCW automation workflow
2. **Customization**: Add project-specific templates
3. **Enhancement**: Add more context sources (CI results, test coverage)
4. **Optimization**: Improve Claude prompt for better accuracy