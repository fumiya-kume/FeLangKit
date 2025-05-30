package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

//-------------------------------------------------------------------------
// Utility & Types
//-------------------------------------------------------------------------

type IssueData struct {
	URL     string   `json:"url"`
	Owner   string   `json:"owner"`
	Repo    string   `json:"repo"`
	Number  int      `json:"issue_number"`
	Branch  string   `json:"branch_name"`
	Title   string   `json:"title"`
	Body    string   `json:"body"`
	Labels  []string `json:"labels"`
	State   string   `json:"state"`
	Author  string   `json:"author"`
	PrTitle string   `json:"pr_title"`
}

func cmd(ctx context.Context, stdout io.Writer, stderr io.Writer, stdin io.Reader, name string, args ...string) error {
	c := exec.CommandContext(ctx, name, args...)
	c.Stdout = stdout
	c.Stderr = stderr
	c.Stdin = stdin
	return c.Run()
}

func runQuiet(name string, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return cmd(ctx, io.Discard, io.Discard, nil, name, args...)
}

var (
	debugMode       bool
	cleanupAll      bool
	worktreeBaseDir string
	issueURL        string
	projectRoot     string
	owner, repo     string
	issueNumber     string
	branchName      string
	worktreePath    string
)

func init() {
	flag.BoolVar(&cleanupAll, "cleanup", false, "remove all existing worktrees and exit")
	flag.BoolVar(&debugMode, "debug", false, "enable verbose debugging output")
	flag.Usage = func() {
		fmt.Printf("Claude Worktree – Parallel Claude Code development in Go\n")
		fmt.Printf("Usage: %s [--cleanup] [--debug] <github-issue-url>\n", os.Args[0])
		flag.PrintDefaults()
	}
}

func main() {
	flag.Parse()
	if cleanupAll {
		cleanupAllWorktrees()
		return
	}
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(1)
	}
	issueURL = flag.Arg(0)
	exePath, _ := os.Executable()
	projectRoot = filepath.Dir(exePath)
	worktreeBaseDir = projectRoot
	must(validateURL(issueURL))
	extractIssueInfo(issueURL)
	validatePrerequisites()
	logInfo("Starting workflow for issue %s", issueURL)
	issueData := fetchIssueData()
	createWorktree()
	generateAnalysis(issueData)

	// 初回 Claude 実装
	launchClaudeCode(issueData)

	// 実装検証＋再実行ループ
	maxRetries := 2
	for i := 0; i <= maxRetries; i++ {
		if validateImplementation() {
			break
		}
		if i < maxRetries {
			logWarn("Validation failed, relaunching Claude Code for fixes (attempt %d/%d)", i+1, maxRetries)
			launchClaudeCodeForErrors(issueData)
		} else {
			logError("Validation failed after %d attempts", maxRetries)
			os.Exit(1)
		}
	}

	pushAndCreatePR(issueData)
	monitorCIChecks(issueData)
	logSuccess("All tasks completed – goodbye ✨")
}

var issueURLRe = regexp.MustCompile(`^https://github\.com/([^/]+)/([^/]+)/issues/(\d+)$`)

func validateURL(u string) error {
	if !issueURLRe.MatchString(u) {
		return fmt.Errorf("invalid GitHub issue URL: %s", u)
	}
	return nil
}

func extractIssueInfo(u string) {
	m := issueURLRe.FindStringSubmatch(u)
	owner, repo, issueNumber = m[1], m[2], m[3]
	branchName = fmt.Sprintf("issue-%s-%s-%04x", issueNumber, time.Now().Format("20060102-150405"), rand.Intn(0x10000))
	worktreePath = filepath.Join(worktreeBaseDir, branchName)
}

func validatePrerequisites() {
	must(runQuiet("git", "--version"))
	must(runQuiet("gh", "--version"))
	must(runQuiet("claude", "--help"))
	if err := runQuiet("swiftlint", "version"); err != nil {
		logWarn("SwiftLint not found – skipping quality checks")
	}
	logSuccess("Prerequisites validated")
}

func createWorktree() {
	_ = cleanupExistingWorktree()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	must(cmd(ctx, os.Stdout, os.Stderr, nil, "git", "fetch", "origin"))
	must(cmd(ctx, os.Stdout, os.Stderr, nil, "git", "worktree", "add", worktreePath, "-b", branchName, "origin/master"))
	logSuccess("Worktree created at %s", worktreePath)
}

func cleanupExistingWorktree() error {
	if _, err := os.Stat(worktreePath); err == nil {
		logWarn("Removing existing worktree %s", worktreePath)
		_ = cmd(context.Background(), os.Stdout, os.Stderr, nil, "git", "worktree", "remove", worktreePath, "--force")
		return os.RemoveAll(worktreePath)
	}
	return nil
}

func cleanupAllWorktrees() {
	logInfo("Cleaning all worktrees under %s", worktreeBaseDir)
	filepath.WalkDir(worktreeBaseDir, func(path string, d os.DirEntry, err error) error {
		if d == nil || !d.IsDir() || path == worktreeBaseDir {
			return nil
		}
		_ = cmd(context.Background(), os.Stdout, os.Stderr, nil, "git", "worktree", "remove", path, "--force")
		_ = os.RemoveAll(path)
		return nil
	})
}

func fetchIssueData() IssueData {
	var out strings.Builder
	must(cmd(context.Background(), &out, os.Stderr, nil, "gh", "api", fmt.Sprintf("repos/%s/%s/issues/%s", owner, repo, issueNumber)))
	var raw map[string]any
	must(json.Unmarshal([]byte(out.String()), &raw))
	if raw["state"] != "open" {
		must(errors.New("issue is not open"))
	}
	labels := []string{}
	if l, ok := raw["labels"].([]interface{}); ok {
		for _, v := range l {
			m := v.(map[string]any)
			labels = append(labels, m["name"].(string))
		}
	}
	return IssueData{
		URL:     issueURL,
		Owner:   owner,
		Repo:    repo,
		Number:  mustInt(issueNumber),
		Branch:  branchName,
		Title:   rawString(raw, "title"),
		Body:    rawString(raw, "body"),
		Labels:  labels,
		State:   rawString(raw, "state"),
		Author:  rawString(raw, "user", "login"),
		PrTitle: fmt.Sprintf("Resolve #%s: %s", issueNumber, rawString(raw, "title")),
	}
}

func rawString(m map[string]any, keys ...string) string {
	cur := any(m)
	for _, k := range keys {
		if mm, ok := cur.(map[string]any); ok {
			cur = mm[k]
		} else {
			return ""
		}
	}
	return cur.(string)
}

func mustInt(s string) int {
	i, _ := strconv.Atoi(s)
	return i
}

func generateAnalysis(data IssueData) {
	path := filepath.Join(worktreePath, ".analysis-data.json")
	f, err := os.Create(path)
	must(err)
	defer f.Close()
	analysis := map[string]any{
		"analysis_type": "strategic_implementation",
		"issue_context": map[string]any{
			"title":       data.Title,
			"description": data.Body,
			"labels":      data.Labels,
			"priority":    "high",
		},
		"implementation_strategy": map[string]any{
			"approach":             "systematic_implementation",
			"phases":               []string{"analyze_codebase_structure", "implement_core_functionality", "add_comprehensive_tests", "validate_with_quality_checks"},
			"quality_requirements": []string{"maintain_existing_test_coverage", "follow_swift_coding_standards", "ensure_swiftlint_compliance", "validate_build_success"},
		},
	}
	must(json.NewEncoder(f).Encode(analysis))
	logSuccess("Analysis written to %s", path)
}

// launchClaudeCode はコンテキストを標準入力で渡し、claude を起動します。
func launchClaudeCode(data IssueData) {
	ctxMsg := fmt.Sprintf(`# GitHub Issue Context

**Issue #%d: %s**

%s

**Labels:** %s
**Branch:** %s
`, data.Number, data.Title, data.Body, strings.Join(data.Labels, ","), data.Branch)
	reader := strings.NewReader(ctxMsg)
	logInfo("Launching Claude Code with initial prompt…")
	must(cmd(context.Background(), os.Stdout, os.Stderr, reader, "claude"))
}

// launchClaudeCodeForErrors はエラー修正用に再度 claude を起動
func launchClaudeCodeForErrors(data IssueData) {
	errCtx := fmt.Sprintf("Validation errors detected. Please fix and exit.")
	reader := strings.NewReader(errCtx)
	logInfo("Relaunching Claude Code for fixes…")
	must(cmd(context.Background(), os.Stdout, os.Stderr, reader, "claude"))
}

func validateImplementation() bool {
	logInfo("Running swift build…")
	if err := cmd(context.Background(), os.Stdout, os.Stderr, nil, "swift", "build"); err != nil {
		logError("Build failed")
		return false
	}
	logInfo("Running swift test…")
	if err := cmd(context.Background(), os.Stdout, os.Stderr, nil, "swift", "test"); err != nil {
		logError("Tests failed")
		return false
	}
	if err := runQuiet("swiftlint", "lint"); err == nil {
		logInfo("SwiftLint passed")
	}
	logSuccess("Validation passed")
	return true
}

func pushAndCreatePR(data IssueData) {
	ctx := context.Background()
	must(cmd(ctx, os.Stdout, os.Stderr, nil, "git", "add", "."))
	commitMsg := fmt.Sprintf("feat: %s\n\nResolves #%d", data.Title, data.Number)
	must(cmd(ctx, os.Stdout, os.Stderr, nil, "git", "commit", "-m", commitMsg))
	must(cmd(ctx, os.Stdout, os.Stderr, nil, "git", "push", "-u", "origin", data.Branch))
	existing := capture(ctx, "gh", "pr", "list", "--head", data.Branch, "--json", "url", "--jq", ".[0].url")
	if strings.TrimSpace(existing) != "" {
		logSuccess("PR exists: %s", existing)
		return
	}
	body := fmt.Sprintf("Resolves #%d", data.Number)
	url := capture(ctx, "gh", "pr", "create", "--title", data.PrTitle, "--body", body)
	logSuccess("Created PR: %s", strings.TrimSpace(url))
}

func monitorCIChecks(data IssueData) {
	logInfo("Monitoring CI checks…")
	timeout := time.After(5 * time.Minute)
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-timeout:
			logWarn("CI monitoring timed out")
			return
		case <-ticker.C:
			status := capture(context.Background(), "gh", "pr", "checks")
			if !strings.Contains(status, "pending") && !strings.Contains(status, "fail") {
				logSuccess("All CI checks passed")
				return
			}
			logInfo("CI status: \n%s", status)
		}
	}
}

func capture(ctx context.Context, name string, args ...string) string {
	var out strings.Builder
	_ = cmd(ctx, &out, os.Stderr, nil, name, args...)
	return out.String()
}

func logInfo(format string, a ...any)    { fmt.Printf("\033[36m[INFO]\033[0m "+format+"\n", a...) }
func logWarn(format string, a ...any)    { fmt.Printf("\033[33m[WARN]\033[0m "+format+"\n", a...) }
func logError(format string, a ...any)   { fmt.Printf("\033[31m[ERR ]\033[0m "+format+"\n", a...) }
func logSuccess(format string, a ...any) { fmt.Printf("\033[32m[SUCCESS]\033[0m "+format+"\n", a...) }

func must(err error) {
	if err != nil {
		logError("%v", err)
		os.Exit(1)
	}
}
