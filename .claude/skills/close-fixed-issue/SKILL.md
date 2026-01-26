---
name: close-fixed-issue
description: >
  This skill should be used when the user asks to
  "find fixed issues that are still open",
  "close resolved issues",
  "check open issues against merged PRs",
  "clean up stale issues",
  or wants to detect GitHub issues already addressed by merged pull requests.
user-invocable: true
disable-model-invocation: true
context: fork
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# Close Fixed Issues

Detect open GitHub issues that have already been resolved by merged pull requests, and close them after user confirmation.

## Workflow

### Step 1: Gather Open Issues

Fetch all open issues from the repository:

```bash
gh issue list --state open --limit 100 --json number,title,labels
```

If no open issues exist, report that and stop.

### Step 2: Gather Merged PRs

Fetch recently merged pull requests:

```bash
gh pr list --state merged --limit 100 --json number,title,body,mergedAt
```

### Step 3: Cross-Reference Issues with PRs

For each open issue, check whether a merged PR addresses it. Use two detection methods:

#### Method A: PR Auto-Close Keyword Matching

Scan merged PR titles and bodies for GitHub's auto-close keywords followed by an issue reference (e.g., `#N` or `owner/repo#N`). GitHub treats these keywords case-insensitively in PR titles, bodies, and commit messages:
- `close #N`, `closes #N`, `closed #N`
- `fix #N`, `fixes #N`, `fixed #N`
- `resolve #N`, `resolves #N`, `resolved #N`

#### Method B: Timeline Event Analysis

Run the bundled script from the repository root to query GitHub GraphQL API for cross-referenced events:

```bash
bash .claude/skills/close-fixed-issue/scripts/check-issue-references.sh OWNER REPO ISSUE_NUMBER [ISSUE_NUMBER...]
```

Extract the repository owner and name from `gh repo view --json owner,name`.

This script returns, for each issue, any pull requests that reference it and their merge status.

### Step 4: Verify Fixes in Codebase

For each issue with a candidate merged PR, verify the fix exists in the codebase:

1. Read the issue body to understand the expected deliverable (test addition, bug fix, feature, etc.)
2. Search the codebase for the expected artifact:
   - For test issues: search for relevant test function names using `Grep`
   - For feature issues: search for the implemented functionality
   - For bug fixes: confirm the fix is present in the relevant source file
3. Mark the issue as **confirmed fixed** only when both a merged PR reference AND codebase evidence exist.

### Step 5: Present Findings

Format results as a markdown table:

```
| Issue | Title | Fixed By | Evidence |
|-------|-------|----------|----------|
| #N    | ...   | PR #M    | test function / file path |
```

Separately list issues where evidence is ambiguous or partial.

### Step 6: User Confirmation

Use `AskUserQuestion` to ask which issues to close. Present the confirmed-fixed issues as selectable options with `multiSelect: true`.

Never close issues without explicit user approval.

### Step 7: Close Confirmed Issues

For each approved issue, close with a descriptive comment linking to the PR:

```bash
gh issue close <NUMBER> --comment "Resolved by PR #<PR_NUMBER> (<brief description>)"
```

Report the final list of closed issues.

## Important Rules

- Never close an issue without user confirmation.
- Always provide codebase evidence, not just PR references.
- If an issue is only partially addressed, report it as ambiguous rather than confirmed.
- Include the PR number in every close comment for traceability.
