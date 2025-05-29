#!/bin/bash

# Ultra Think Analysis - Deep Issue Analysis and Strategic Planning
# Usage: ./ultrathink-analysis.sh <issue-data-file> <output-analysis-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[ULTRATHINK $(date +'%H:%M:%S')]${NC} $1"
}

stage() {
    echo -e "${PURPLE}[STAGE]${NC} $1"
}

insight() {
    echo -e "${CYAN}[INSIGHT]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[RISK]${NC} $1"
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <issue-data-file> <output-analysis-file>"
    exit 1
fi

ISSUE_DATA_FILE="$1"
ANALYSIS_OUTPUT_FILE="$2"

if [[ ! -f "$ISSUE_DATA_FILE" ]]; then
    echo "Error: Issue data file not found: $ISSUE_DATA_FILE"
    exit 1
fi

# Extract issue information
ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_FILE")
ISSUE_BODY=$(jq -r '.body' "$ISSUE_DATA_FILE")
ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA_FILE")
ISSUE_LABELS=$(jq -r '.labels | join(",")' "$ISSUE_DATA_FILE")

log "Starting Ultra Think Analysis for Issue #$ISSUE_NUMBER"
log "Title: $ISSUE_TITLE"

# Initialize analysis JSON structure
cat > "$ANALYSIS_OUTPUT_FILE" << 'EOF'
{
  "metadata": {},
  "complexity_assessment": {},
  "codebase_impact": {},
  "strategic_analysis": {},
  "risk_assessment": {},
  "implementation_roadmap": {}
}
EOF

# Stage 1: Issue Complexity Assessment
stage "Stage 1: Issue Complexity Assessment"

COMPLEXITY_SCORE=0
COMPLEXITY_FACTORS=()

# Analyze issue text for complexity indicators
if echo "$ISSUE_BODY" | grep -qi "refactor\|architecture\|design\|restructure"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 3))
    COMPLEXITY_FACTORS+=("architectural_change")
    insight "Detected architectural/design changes"
fi

if echo "$ISSUE_BODY" | grep -qi "breaking\|compatibility\|migration"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
    COMPLEXITY_FACTORS+=("breaking_change")
    warn "Potential breaking changes detected"
fi

if echo "$ISSUE_BODY" | grep -qi "performance\|optimization\|benchmark"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
    COMPLEXITY_FACTORS+=("performance_critical")
    insight "Performance-related changes identified"
fi

if echo "$ISSUE_BODY" | grep -qi "test\|testing\|coverage"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
    COMPLEXITY_FACTORS+=("test_changes")
    insight "Testing modifications required"
fi

if echo "$ISSUE_LABELS" | grep -qi "bug\|fix"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
    COMPLEXITY_FACTORS+=("bug_fix")
fi

if echo "$ISSUE_LABELS" | grep -qi "enhancement\|feature"; then
    COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
    COMPLEXITY_FACTORS+=("feature_addition")
fi

# Determine complexity level
if [[ $COMPLEXITY_SCORE -ge 6 ]]; then
    COMPLEXITY_LEVEL="architectural"
elif [[ $COMPLEXITY_SCORE -ge 4 ]]; then
    COMPLEXITY_LEVEL="complex"
elif [[ $COMPLEXITY_SCORE -ge 2 ]]; then
    COMPLEXITY_LEVEL="moderate"
else
    COMPLEXITY_LEVEL="simple"
fi

log "Complexity Level: $COMPLEXITY_LEVEL (Score: $COMPLEXITY_SCORE)"

# Update analysis with complexity assessment
jq --argjson score "$COMPLEXITY_SCORE" \
   --arg level "$COMPLEXITY_LEVEL" \
   --argjson factors "$(printf '%s\n' "${COMPLEXITY_FACTORS[@]}" | jq -R . | jq -s .)" \
   '.complexity_assessment = {
     score: $score,
     level: $level,
     factors: $factors,
     estimated_effort_hours: (
       if $level == "architectural" then 8
       elif $level == "complex" then 4
       elif $level == "moderate" then 2
       else 1 end
     )
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

# Stage 2: Codebase Impact Analysis
stage "Stage 2: Codebase Impact Analysis"

AFFECTED_MODULES=()
POTENTIAL_FILES=()

# Analyze which modules might be affected based on issue content
if echo "$ISSUE_BODY" | grep -qi "token\|tokenizer\|lexer"; then
    AFFECTED_MODULES+=("Tokenizer")
    POTENTIAL_FILES+=("Sources/FeLangCore/Tokenizer/")
    insight "Tokenizer module likely affected"
fi

if echo "$ISSUE_BODY" | grep -qi "parser\|parsing\|syntax\|ast"; then
    AFFECTED_MODULES+=("Parser")
    POTENTIAL_FILES+=("Sources/FeLangCore/Parser/")
    insight "Parser module likely affected"
fi

if echo "$ISSUE_BODY" | grep -qi "expression\|operator\|precedence"; then
    AFFECTED_MODULES+=("Expression")
    POTENTIAL_FILES+=("Sources/FeLangCore/Expression/")
    insight "Expression module likely affected"
fi

if echo "$ISSUE_BODY" | grep -qi "visitor\|traversal\|walk"; then
    AFFECTED_MODULES+=("Visitor")
    POTENTIAL_FILES+=("Sources/FeLangCore/Visitor/")
    insight "Visitor pattern likely affected"
fi

if echo "$ISSUE_BODY" | grep -qi "error\|diagnostic\|message"; then
    AFFECTED_MODULES+=("Error Handling")
    POTENTIAL_FILES+=("Sources/FeLangCore/Parser/ParseError.swift")
    insight "Error handling likely affected"
fi

if echo "$ISSUE_BODY" | grep -qi "unicode\|string\|escape\|util"; then
    AFFECTED_MODULES+=("Utilities")
    POTENTIAL_FILES+=("Sources/FeLangCore/Utilities/")
    insight "Utilities module likely affected"
fi

# Count estimated files to change
FILE_COUNT=${#POTENTIAL_FILES[@]}
if [[ $FILE_COUNT -eq 0 ]]; then
    FILE_COUNT=1
fi

# Update analysis with codebase impact
jq --argjson modules "$(printf '%s\n' "${AFFECTED_MODULES[@]}" | jq -R . | jq -s .)" \
   --argjson files "$(printf '%s\n' "${POTENTIAL_FILES[@]}" | jq -R . | jq -s .)" \
   --argjson count "$FILE_COUNT" \
   '.codebase_impact = {
     affected_modules: $modules,
     potential_files: $files,
     estimated_files_changed: $count,
     requires_tests: true,
     backwards_compatible: (if (.complexity_assessment.factors | contains(["breaking_change"])) then false else true end)
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

# Stage 3: Strategic Analysis
stage "Stage 3: Strategic Analysis"

STRATEGIES=()

# Generate implementation strategies based on complexity and impact
case "$COMPLEXITY_LEVEL" in
    "architectural")
        STRATEGIES+=('{"name": "Phased Implementation", "description": "Break into multiple PRs to minimize risk", "effort": "high", "risk": "low"}')
        STRATEGIES+=('{"name": "Feature Flag Approach", "description": "Use feature flags to enable gradual rollout", "effort": "medium", "risk": "medium"}')
        ;;
    "complex")
        STRATEGIES+=('{"name": "Test-Driven Implementation", "description": "Write comprehensive tests first", "effort": "medium", "risk": "low"}')
        STRATEGIES+=('{"name": "Refactor-First Approach", "description": "Clean up existing code before adding features", "effort": "high", "risk": "medium"}')
        ;;
    "moderate"|"simple")
        STRATEGIES+=('{"name": "Direct Implementation", "description": "Straightforward implementation with existing patterns", "effort": "low", "risk": "low"}')
        STRATEGIES+=('{"name": "Pattern-Based Approach", "description": "Follow established codebase patterns", "effort": "low", "risk": "low"}')
        ;;
esac

RECOMMENDED_STRATEGY=${STRATEGIES[0]}

# Update analysis with strategic analysis
jq --argjson strategies "[$(IFS=','; echo "${STRATEGIES[*]}")]" \
   --argjson recommended "$RECOMMENDED_STRATEGY" \
   '.strategic_analysis = {
     strategies: $strategies,
     recommended: $recommended,
     architectural_considerations: [
       "Follow existing module boundaries",
       "Maintain backwards compatibility where possible",
       "Ensure comprehensive test coverage",
       "Use established error handling patterns"
     ]
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

insight "Strategic recommendation: $(echo "$RECOMMENDED_STRATEGY" | jq -r '.name')"

# Stage 4: Risk Assessment
stage "Stage 4: Risk Assessment"

RISKS=()
RISK_LEVEL="low"

if [[ "$COMPLEXITY_LEVEL" == "architectural" ]]; then
    RISKS+=('{"category": "architecture", "description": "Large-scale changes may introduce subtle bugs", "mitigation": "Comprehensive testing and phased rollout"}')
    RISK_LEVEL="high"
fi

if echo "${COMPLEXITY_FACTORS[@]}" | grep -q "breaking_change"; then
    RISKS+=('{"category": "compatibility", "description": "Breaking changes may affect downstream users", "mitigation": "Clear migration guide and deprecation warnings"}')
    RISK_LEVEL="high"
fi

if echo "${COMPLEXITY_FACTORS[@]}" | grep -q "performance_critical"; then
    RISKS+=('{"category": "performance", "description": "Performance changes need careful benchmarking", "mitigation": "Before/after performance measurements"}')
    if [[ "$RISK_LEVEL" == "low" ]]; then
        RISK_LEVEL="medium"
    fi
fi

if [[ ${#AFFECTED_MODULES[@]} -gt 3 ]]; then
    RISKS+=('{"category": "scope", "description": "Changes affect multiple modules", "mitigation": "Careful integration testing"}')
    if [[ "$RISK_LEVEL" == "low" ]]; then
        RISK_LEVEL="medium"
    fi
fi

if [[ ${#RISKS[@]} -eq 0 ]]; then
    RISKS+=('{"category": "general", "description": "Standard development risks", "mitigation": "Follow established development practices"}')
fi

# Update analysis with risk assessment
jq --argjson risks "[$(IFS=','; echo "${RISKS[*]}")]" \
   --arg level "$RISK_LEVEL" \
   '.risk_assessment = {
     overall_risk: $level,
     identified_risks: $risks,
     quality_gates: [
       "All existing tests must pass",
       "SwiftLint validation required",
       "Code coverage should not decrease",
       "Manual testing for edge cases"
     ]
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

warn "Overall risk level: $RISK_LEVEL"

# Stage 5: Implementation Roadmap
stage "Stage 5: Implementation Roadmap"

# Generate implementation tasks based on complexity and modules
TASKS=()
TASK_ID=1

# Always start with planning and setup
TASKS+=("{\"id\": $TASK_ID, \"phase\": \"setup\", \"description\": \"Create feature branch and analyze existing code\", \"estimated_time\": \"15min\", \"dependencies\": []}")
TASK_ID=$((TASK_ID + 1))

# Add module-specific tasks
for MODULE in "${AFFECTED_MODULES[@]}"; do
    case "$MODULE" in
        "Tokenizer")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Update tokenizer logic and add token types if needed\", \"estimated_time\": \"30min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
        "Parser")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Modify parser rules and statement handling\", \"estimated_time\": \"45min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
        "Expression")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Update expression parsing and precedence rules\", \"estimated_time\": \"30min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
        "Visitor")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Implement visitor pattern methods\", \"estimated_time\": \"20min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
        "Error Handling")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Add error cases and improve diagnostics\", \"estimated_time\": \"25min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
        "Utilities")
            TASKS+=("{\"id\": $TASK_ID, \"phase\": \"implementation\", \"description\": \"Update utility functions and string handling\", \"estimated_time\": \"20min\", \"dependencies\": [$((TASK_ID - 1))]}")
            ;;
    esac
    TASK_ID=$((TASK_ID + 1))
done

# Add testing phase
TASKS+=("{\"id\": $TASK_ID, \"phase\": \"testing\", \"description\": \"Write comprehensive tests for new functionality\", \"estimated_time\": \"30min\", \"dependencies\": [$(seq -s, 2 $((TASK_ID - 1)))]}")
TASK_ID=$((TASK_ID + 1))

# Add quality assurance
TASKS+=("{\"id\": $TASK_ID, \"phase\": \"qa\", \"description\": \"Run quality gates: swiftlint, build, and test\", \"estimated_time\": \"10min\", \"dependencies\": [$((TASK_ID - 1))]}")
TASK_ID=$((TASK_ID + 1))

# Add finalization
TASKS+=("{\"id\": $TASK_ID, \"phase\": \"finalization\", \"description\": \"Review changes and create commit\", \"estimated_time\": \"10min\", \"dependencies\": [$((TASK_ID - 1))]}")

# Calculate total estimated time
TOTAL_MINUTES=0
for TASK in "${TASKS[@]}"; do
    TIME=$(echo "$TASK" | jq -r '.estimated_time' | sed 's/min//')
    TOTAL_MINUTES=$((TOTAL_MINUTES + TIME))
done

# Update analysis with implementation roadmap
jq --argjson tasks "[$(IFS=','; echo "${TASKS[*]}")]" \
   --argjson total_time "$TOTAL_MINUTES" \
   '.implementation_roadmap = {
     tasks: $tasks,
     total_estimated_time_minutes: $total_time,
     parallel_execution_possible: false,
     acceptance_criteria: [
       "All tests pass",
       "SwiftLint validation passes", 
       "Code builds successfully",
       "Documentation updated if needed",
       "No regression in existing functionality"
     ]
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

# Add metadata
jq --arg issue_number "$ISSUE_NUMBER" \
   --arg title "$ISSUE_TITLE" \
   --arg analysis_timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
   --arg analysis_version "1.0" \
   '.metadata = {
     issue_number: ($issue_number | tonumber),
     issue_title: $title,
     analysis_timestamp: $analysis_timestamp,
     analysis_version: $analysis_version,
     analyzer: "ultrathink-analysis.sh"
   }' "$ANALYSIS_OUTPUT_FILE" > temp.json && mv temp.json "$ANALYSIS_OUTPUT_FILE"

# Final summary
stage "Ultra Think Analysis Complete"
log "Analysis saved to: $ANALYSIS_OUTPUT_FILE"
log "Complexity: $COMPLEXITY_LEVEL | Risk: $RISK_LEVEL | Est. Time: ${TOTAL_MINUTES}min"
log "Affected Modules: $(IFS=', '; echo "${AFFECTED_MODULES[*]}")"

echo
echo -e "${GREEN}=== ULTRA THINK SUMMARY ===${NC}"
echo "📊 Complexity Level: $COMPLEXITY_LEVEL"
echo "⚠️  Risk Assessment: $RISK_LEVEL"
echo "⏱️  Estimated Time: ${TOTAL_MINUTES} minutes"
echo "🎯 Affected Modules: ${#AFFECTED_MODULES[@]}"
echo "📋 Implementation Tasks: ${#TASKS[@]}"
echo "💡 Strategic Approach: $(echo "$RECOMMENDED_STRATEGY" | jq -r '.name')"
echo

insight "Ultra Think Analysis ready for implementation phase"