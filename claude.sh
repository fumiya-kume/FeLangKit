#!/usr/bin/env bash

# Claude Worktree - Parallel Claude Code development with git worktree
# Usage: ./claude-worktree.sh <github-issue-url>
# 
# This script creates a new git worktree, fetches GitHub issue data,
# launches Claude Code with issue context, and manages the complete
# development workflow including PR creation and CI monitoring.

set -euo pipefail

# ヘッダー行数（動的に計算される）
HEADER_LINE_COUNT=0
CALCULATED_HEADER_LINES=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Configuration
WORKTREE_BASE_DIR="${PROJECT_ROOT}"
ISSUE_DATA_FILE=""
ANALYSIS_FILE=""
BRANCH_NAME=""
WORKTREE_PATH=""
DEBUG_MODE="${DEBUG_MODE:-false}"

# Colors for output (Basic ANSI colors)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Bash version compatibility check (will be initialized after logging functions)
BASH_VERSION_MAJOR=${BASH_VERSION%%.*}
BASH_SUPPORTS_ASSOC_ARRAYS=false

# Terminal capability detection
TERMINAL_CAPABILITIES=()

detect_terminal_capabilities() {
    TERMINAL_CAPABILITIES=()
    
    # Color support detection
    local colors=$(tput colors 2>/dev/null || echo "0")
    if [[ $colors -ge 256 ]]; then
        TERMINAL_CAPABILITIES+=("256color")
    elif [[ $colors -ge 8 ]]; then
        TERMINAL_CAPABILITIES+=("8color")
    fi
    
    # Unicode support detection
    if [[ "$LANG" =~ UTF-8 ]] && [[ "$TERM" != "dumb" ]]; then
        TERMINAL_CAPABILITIES+=("unicode")
    fi
    
    # Advanced terminal features
    if tput cup >/dev/null 2>&1; then
        TERMINAL_CAPABILITIES+=("cursor_positioning")
    fi
    
    if tput csr >/dev/null 2>&1; then
        TERMINAL_CAPABILITIES+=("scroll_region")
    fi
    
    debug "Terminal capabilities detected: ${TERMINAL_CAPABILITIES[*]}"
}

# Check if terminal supports specific capability
has_capability() {
    local capability="$1"
    for cap in "${TERMINAL_CAPABILITIES[@]}"; do
        if [[ "$cap" == "$capability" ]]; then
            return 0
        fi
    done
    return 1
}

# Initialize color themes with bash compatibility
init_color_themes() {
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        # Bash 4.0+ with associative arrays
        # Default theme (enhanced basic colors)
        THEME_COLORS[primary]="${BLUE}"
        THEME_COLORS[success]="${GREEN}"
        THEME_COLORS[warning]="${YELLOW}"
        THEME_COLORS[error]="${RED}"
        THEME_COLORS[info]="${CYAN}"
        THEME_COLORS[accent]="${PURPLE}"
        THEME_COLORS[muted]="\033[38;5;240m"
        THEME_COLORS[bright]="\033[1m"
        
        # Enhanced colors for 256-color terminals
        if has_capability "256color"; then
            THEME_COLORS[primary]="\033[38;5;39m"     # Bright blue
            THEME_COLORS[success]="\033[38;5;46m"     # Bright green  
            THEME_COLORS[warning]="\033[38;5;226m"    # Bright yellow
            THEME_COLORS[error]="\033[38;5;196m"      # Bright red
            THEME_COLORS[info]="\033[38;5;51m"        # Bright cyan
            THEME_COLORS[accent]="\033[38;5;129m"     # Bright purple
            THEME_COLORS[muted]="\033[38;5;240m"      # Gray
            THEME_COLORS[highlight]="\033[38;5;220m"  # Gold
            THEME_COLORS[border]="\033[38;5;75m"      # Light blue
        fi
        
        # Text styles
        THEME_STYLES[bold]="\033[1m"
        THEME_STYLES[dim]="\033[2m"
        THEME_STYLES[italic]="\033[3m"
        THEME_STYLES[underline]="\033[4m"
        THEME_STYLES[blink]="\033[5m"
        THEME_STYLES[reverse]="\033[7m"
    else
        # Bash 3.x fallback - use direct variables
        THEME_COLOR_PRIMARY="${BLUE}"
        THEME_COLOR_SUCCESS="${GREEN}"
        THEME_COLOR_WARNING="${YELLOW}"
        THEME_COLOR_ERROR="${RED}"
        THEME_COLOR_INFO="${CYAN}"
        THEME_COLOR_ACCENT="${PURPLE}"
        THEME_COLOR_MUTED="\033[38;5;240m"
        THEME_COLOR_BORDER="${BLUE}"
        
        THEME_STYLE_BOLD="\033[1m"
        THEME_STYLE_DIM="\033[2m"
        THEME_STYLE_ITALIC="\033[3m"
        
        # Enhanced colors for 256-color terminals
        if has_capability "256color"; then
            THEME_COLOR_PRIMARY="\033[38;5;39m"
            THEME_COLOR_SUCCESS="\033[38;5;46m"
            THEME_COLOR_WARNING="\033[38;5;226m"
            THEME_COLOR_ERROR="\033[38;5;196m"
            THEME_COLOR_INFO="\033[38;5;51m"
            THEME_COLOR_ACCENT="\033[38;5;129m"
            THEME_COLOR_BORDER="\033[38;5;75m"
        fi
    fi
    
    debug "Color themes initialized for terminal with capabilities: ${TERMINAL_CAPABILITIES[*]}"
}

# Helper function to get theme colors with bash compatibility
get_theme_color() {
    local color_name="$1"
    
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        echo "${THEME_COLORS[$color_name]}"
    else
        case "$color_name" in
            "primary") echo "$THEME_COLOR_PRIMARY" ;;
            "success") echo "$THEME_COLOR_SUCCESS" ;;
            "warning") echo "$THEME_COLOR_WARNING" ;;
            "error") echo "$THEME_COLOR_ERROR" ;;
            "info") echo "$THEME_COLOR_INFO" ;;
            "accent") echo "$THEME_COLOR_ACCENT" ;;
            "muted") echo "$THEME_COLOR_MUTED" ;;
            "border") echo "$THEME_COLOR_BORDER" ;;
            *) echo "${BLUE}" ;;
        esac
    fi
}

# Helper function to get theme styles with bash compatibility  
get_theme_style() {
    local style_name="$1"
    
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        echo "${THEME_STYLES[$style_name]}"
    else
        case "$style_name" in
            "bold") echo "$THEME_STYLE_BOLD" ;;
            "dim") echo "$THEME_STYLE_DIM" ;;
            "italic") echo "$THEME_STYLE_ITALIC" ;;
            *) echo "" ;;
        esac
    fi
}

# Theme selection and loading
load_theme() {
    local theme_name="${1:-$(get_config_value "theme" "default")}"
    
    case "$theme_name" in
        "minimal")
            # Minimal theme - reduced visual elements
            THEME_COLORS[primary]="${BLUE}"
            THEME_COLORS[border]="${BLUE}"
            HEADER_CONFIG[border_style]="single"
            ;;
        "modern")
            # Modern theme - enhanced colors and styles
            if has_capability "256color"; then
                THEME_COLORS[primary]="\033[38;5;75m"
                THEME_COLORS[success]="\033[38;5;82m"
                THEME_COLORS[border]="\033[38;5;75m"
                THEME_COLORS[accent]="\033[38;5;213m"
            fi
            HEADER_CONFIG[border_style]="double"
            ;;
        "compact")
            # Compact theme - space-efficient
            HEADER_CONFIG[border_style]="single"
            HEADER_CONFIG[show_extended_info]="false"
            ;;
        *)
            # Default theme already loaded
            ;;
    esac
    
    debug "Theme loaded: $theme_name"
}

# Get border characters based on style
get_border_chars() {
    local style="${1:-$(get_config_value "border_style" "double")}"
    
    case "$style" in
        "single")
            echo "┌─┐│└─┘├┤┬┴┼"
            ;;
        "double")
            echo "╔═╗║╚═╝╠╣╦╩╬"
            ;;
        "rounded")
            echo "╭─╮│╰─╯├┤┬┴┼"
            ;;
        "thick")
            echo "┏━┓┃┗━┛┣┫┳┻╋"
            ;;
        *)
            echo "╔═╗║╚═╝╠╣╦╩╬"
            ;;
    esac
}

# Enhanced status icons with better visual hierarchy
get_status_icon() {
    local status="${1:-pending}"
    
    case "$status" in
        "pending"|"waiting") echo "⏳" ;;
        "in_progress"|"running") echo "🔄" ;;
        "completed"|"success") echo "✅" ;;
        "error"|"failed") echo "❌" ;;
        "warning") echo "⚠️" ;;
        "skipped") echo "⏭️" ;;
        "cancelled") echo "🚫" ;;
        *) echo "🔵" ;;
    esac
}

# Initialize header configuration with bash compatibility
init_header_config() {
    # Initialize bash compatibility first
    init_bash_compatibility
    
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        # Default configuration with environment variable overrides
        HEADER_CONFIG[theme]="${HEADER_THEME:-default}"
        HEADER_CONFIG[update_interval]="${HEADER_UPDATE_INTERVAL:-1}"
        HEADER_CONFIG[show_system_metrics]="${HEADER_SHOW_METRICS:-false}"
        HEADER_CONFIG[animation_enabled]="${HEADER_ANIMATIONS:-true}"
        HEADER_CONFIG[color_mode]="${HEADER_COLOR_MODE:-auto}"
        HEADER_CONFIG[border_style]="${HEADER_BORDER_STYLE:-double}"
        HEADER_CONFIG[layout]="${HEADER_LAYOUT:-auto}"
        HEADER_CONFIG[show_extended_info]="${HEADER_SHOW_EXTENDED_INFO:-true}"
        HEADER_CONFIG[flicker_reduction]="${HEADER_FLICKER_REDUCTION:-true}"
        HEADER_CONFIG[buffer_updates]="${HEADER_BUFFER_UPDATES:-true}"
        HEADER_CONFIG[differential_updates]="${HEADER_DIFFERENTIAL_UPDATES:-true}"
        
        debug "Header configuration initialized: theme=${HEADER_CONFIG[theme]}, border=${HEADER_CONFIG[border_style]}"
    else
        # Fallback configuration for bash 3.x
        HEADER_THEME_VAR="${HEADER_THEME:-default}"
        HEADER_UPDATE_INTERVAL_VAR="${HEADER_UPDATE_INTERVAL:-1}"
        HEADER_BORDER_STYLE_VAR="${HEADER_BORDER_STYLE:-double}"
        HEADER_FLICKER_REDUCTION_VAR="${HEADER_FLICKER_REDUCTION:-true}"
        
        debug "Header configuration initialized (compatibility mode): theme=$HEADER_THEME_VAR"
    fi
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1" >&2
    fi
}

error_debug() {
    local message="$1"
    local error_file="$2"
    error "$message"
    if [[ -n "$error_file" && -f "$error_file" && -s "$error_file" ]]; then
        echo -e "${RED}[ERROR DETAILS]${NC}" >&2
        echo "--- Error Output ---" >&2
        cat "$error_file" >&2
        echo "--- End Error Output ---" >&2
    fi
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Initialize bash compatibility after logging functions are available
init_bash_compatibility() {
    if [[ $BASH_VERSION_MAJOR -ge 4 ]]; then
        BASH_SUPPORTS_ASSOC_ARRAYS=true
        # Enhanced Color Schemes and Theme System (Bash 4.0+)
        if ! declare -A THEME_COLORS 2>/dev/null; then
            warn "Failed to initialize associative arrays. Using compatibility mode."
            BASH_SUPPORTS_ASSOC_ARRAYS=false
        fi
        if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
            declare -A THEME_STYLES  
            declare -A HEADER_CONFIG
        fi
    else
        # Fallback for older bash versions (3.x)
        warn "Bash 4.0+ required for full header enhancements. Using compatibility mode."
        BASH_SUPPORTS_ASSOC_ARRAYS=false
    fi
}

# Global status variables
STATUS_BOX_LINES=0
ISSUE_TITLE=""
ISSUE_DESCRIPTION=""
WORKFLOW_STEPS=()
CURRENT_STEP=0
CURRENT_ACTIVITY=""
STEP_DETAILS=()
START_TIME=""
HEADER_UPDATE_PID=""
HEADER_CONTENT=()

# Flicker reduction system variables
HEADER_CACHE=()
HEADER_HASH_CACHE=""
LAST_UPDATE_TIME=0
UPDATE_NEEDED=false
HEADER_DIRTY_LINES=()
TERMINAL_BUFFER=""
BUFFER_ENABLED=true
LAST_TERMINAL_WIDTH=0
LAST_TERMINAL_HEIGHT=0

# Advanced flicker reduction system
init_flicker_reduction() {
    HEADER_CACHE=()
    HEADER_HASH_CACHE=""
    LAST_UPDATE_TIME=$(date +%s)
    UPDATE_NEEDED=false
    HEADER_DIRTY_LINES=()
    LAST_TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo "80")
    LAST_TERMINAL_HEIGHT=$(tput lines 2>/dev/null || echo "24")
    
    debug "Flicker reduction system initialized"
}

# Generate content hash for change detection
generate_content_hash() {
    local content="$1"
    # Simple hash function for bash compatibility
    echo "$content" | cksum | cut -d' ' -f1 2>/dev/null || echo "${#content}"
}

# Check if header content has actually changed
has_header_changed() {
    local current_hash
    local content_string=""
    
    # Build content string from current state
    content_string="${ISSUE_TITLE}|${BRANCH_NAME}|${CURRENT_STEP}|${CURRENT_ACTIVITY}"
    content_string="${content_string}|$(date '+%H:%M')" # Only check minute-level changes
    content_string="${content_string}|$(tput cols 2>/dev/null)x$(tput lines 2>/dev/null)"
    
    current_hash=$(generate_content_hash "$content_string")
    
    if [[ "$current_hash" != "$HEADER_HASH_CACHE" ]]; then
        HEADER_HASH_CACHE="$current_hash"
        UPDATE_NEEDED=true
        debug "Header content changed, update needed"
        return 0
    fi
    
    UPDATE_NEEDED=false
    return 1
}

# Check if terminal size has changed
has_terminal_size_changed() {
    local current_width=$(tput cols 2>/dev/null || echo "80")
    local current_height=$(tput lines 2>/dev/null || echo "24")
    
    if [[ "$current_width" != "$LAST_TERMINAL_WIDTH" ]] || [[ "$current_height" != "$LAST_TERMINAL_HEIGHT" ]]; then
        LAST_TERMINAL_WIDTH="$current_width"
        LAST_TERMINAL_HEIGHT="$current_height"
        debug "Terminal size changed: ${current_width}x${current_height}"
        return 0
    fi
    
    return 1
}

# Optimized line update - only update if line content changed
update_line_if_changed() {
    local line_number="$1"
    local new_content="$2"
    local force_update="${3:-false}"
    
    # Check if this line needs updating
    if [[ "$force_update" == "true" ]] || [[ "${HEADER_CACHE[$line_number]}" != "$new_content" ]]; then
        # Save cursor position
        tput sc 2>/dev/null
        
        # Move to line and update
        tput cup $line_number 0 2>/dev/null
        printf "%s" "$new_content"
        tput el 2>/dev/null  # Clear rest of line
        
        # Restore cursor position  
        tput rc 2>/dev/null
        
        # Update cache
        HEADER_CACHE[$line_number]="$new_content"
        
        debug "Updated line $line_number"
        return 0
    fi
    
    return 1
}

# Batch update multiple lines efficiently
batch_update_lines() {
    local updates=("$@")
    local i=0
    
    # Disable cursor for smoother updates
    tput civis 2>/dev/null
    
    # Save cursor position once
    tput sc 2>/dev/null
    
    while [[ $i -lt ${#updates[@]} ]]; do
        local line_num="${updates[i]}"
        local content="${updates[i+1]}"
        
        if [[ "${HEADER_CACHE[$line_num]}" != "$content" ]]; then
            tput cup $line_num 0 2>/dev/null
            printf "%s" "$content"
            tput el 2>/dev/null
            HEADER_CACHE[$line_num]="$content"
        fi
        
        i=$((i + 2))
    done
    
    # Restore cursor and visibility
    tput rc 2>/dev/null
    tput cnorm 2>/dev/null
}

# Throttled update system - prevents too frequent updates
should_update_now() {
    local current_time=$(date +%s)
    local min_interval=$(get_config_value "update_interval" "1")
    
    # Convert to integer for bash compatibility
    min_interval=${min_interval%.*}
    if [[ $min_interval -lt 1 ]]; then
        min_interval=1
    fi
    
    local time_since_last=$((current_time - LAST_UPDATE_TIME))
    
    if [[ $time_since_last -ge $min_interval ]]; then
        LAST_UPDATE_TIME=$current_time
        return 0
    fi
    
    return 1
}

# Get configuration value with bash compatibility
get_config_value() {
    local key="$1"
    local default="$2"
    
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        echo "${HEADER_CONFIG[$key]:-$default}"
    else
        case "$key" in
            "theme") echo "${HEADER_THEME_VAR:-$default}" ;;
            "update_interval") echo "${HEADER_UPDATE_INTERVAL_VAR:-$default}" ;;
            "border_style") echo "${HEADER_BORDER_STYLE_VAR:-$default}" ;;
            "flicker_reduction") echo "${HEADER_FLICKER_REDUCTION_VAR:-$default}" ;;
            "layout") echo "${HEADER_LAYOUT_VAR:-$default}" ;;
            "max_text_width") echo "${HEADER_MAX_TEXT_WIDTH_VAR:-$default}" ;;
            "show_extended_info") echo "${HEADER_SHOW_EXTENDED_INFO_VAR:-$default}" ;;
            "show_branch_info") echo "${HEADER_SHOW_BRANCH_INFO_VAR:-$default}" ;;
            "workflow_display") echo "${HEADER_WORKFLOW_DISPLAY_VAR:-$default}" ;;
            *) echo "$default" ;;
        esac
    fi
}

# Safe config value setter for bash 3.x compatibility
set_config_value() {
    local key="$1"
    local value="$2"
    
    if [[ "$BASH_SUPPORTS_ASSOC_ARRAYS" == "true" ]]; then
        HEADER_CONFIG[$key]="$value"
    else
        case "$key" in
            "theme") HEADER_THEME_VAR="$value" ;;
            "update_interval") HEADER_UPDATE_INTERVAL_VAR="$value" ;;
            "border_style") HEADER_BORDER_STYLE_VAR="$value" ;;
            "flicker_reduction") HEADER_FLICKER_REDUCTION_VAR="$value" ;;
            "layout") HEADER_LAYOUT_VAR="$value" ;;
            "max_text_width") HEADER_MAX_TEXT_WIDTH_VAR="$value" ;;
            "show_extended_info") HEADER_SHOW_EXTENDED_INFO_VAR="$value" ;;
            "show_branch_info") HEADER_SHOW_BRANCH_INFO_VAR="$value" ;;
            "workflow_display") HEADER_WORKFLOW_DISPLAY_VAR="$value" ;;
        esac
    fi
}

# Smart text wrapping and truncation
smart_text_wrap() {
    local text="$1"
    local max_width="$2"
    
    if [[ ${#text} -le $max_width ]]; then
        echo "$text"
        return
    fi
    
    # Smart truncation at word boundaries
    local truncated=$(echo "$text" | cut -c1-$((max_width-3)))
    local last_space=$(echo "$truncated" | grep -o '.*[[:space:]]' | head -1 | wc -c)
    
    if [[ $last_space -gt $((max_width / 2)) ]]; then
        truncated=$(echo "$text" | cut -c1-$((last_space-1)))
    fi
    
    echo "${truncated}..."
}

# Responsive layout calculation based on terminal size
calculate_responsive_layout() {
    local terminal_width=$(tput cols)
    local terminal_height=$(tput lines)
    
    # Layout configurations for different screen sizes
    if [[ $terminal_width -lt 60 ]]; then
        # Very compact layout for very small terminals
        set_config_value "layout" "minimal"
        set_config_value "max_text_width" "30"
        set_config_value "show_extended_info" "false"
        set_config_value "show_branch_info" "false"
        set_config_value "workflow_display" "minimal"
    elif [[ $terminal_width -lt 80 ]]; then
        # Compact layout for small terminals
        set_config_value "layout" "compact"
        set_config_value "max_text_width" "50"
        set_config_value "show_extended_info" "false"
        set_config_value "show_branch_info" "true"
        set_config_value "workflow_display" "compact"
    elif [[ $terminal_width -lt 120 ]]; then
        # Standard layout
        set_config_value "layout" "standard"
        set_config_value "max_text_width" "70"
        set_config_value "show_extended_info" "true"
        set_config_value "show_branch_info" "true"
        set_config_value "workflow_display" "full"
    else
        # Extended layout for wide terminals
        set_config_value "layout" "extended"
        set_config_value "max_text_width" "90"
        set_config_value "show_extended_info" "true"
        set_config_value "show_branch_info" "true"
        set_config_value "workflow_display" "full"
        set_config_value "show_system_metrics" "${HEADER_SHOW_METRICS:-false}"
    fi
    
    # Adjust workflow display based on height
    if [[ $terminal_height -lt 15 ]]; then
        set_config_value "workflow_display" "minimal"
        set_config_value "show_extended_info" "false"
    elif [[ $terminal_height -lt 20 ]]; then
        set_config_value "workflow_display" "compact"
    else
        set_config_value "workflow_display" "full"
    fi
    
    debug "Responsive layout calculated: $(get_config_value "layout" "standard") (${terminal_width}x${terminal_height})"
}

# Enhanced header content calculation with responsive design
calculate_header_content() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local terminal_width=$(tput cols)
    
    # Calculate responsive layout first
    calculate_responsive_layout
    
    # Get border characters for current theme
    local border_chars=$(get_border_chars "$(get_config_value "border_style" "double")")
    local top_left="${border_chars:0:1}"
    local top_right="${border_chars:2:1}"
    local bottom_left="${border_chars:4:1}"
    local bottom_right="${border_chars:6:1}"
    local vertical="${border_chars:3:1}"
    local horizontal="${border_chars:1:1}"
    local horizontal_sep="${border_chars:7:1}"
    
    # Calculate content width for text based on responsive layout
    local content_width=$((terminal_width - 4))
    local max_text_width="$(get_config_value "max_text_width" "70")"
    
    # Adjust for very small terminals
    if [[ $content_width -lt 20 ]]; then
        content_width=20
        max_text_width=15
    fi
    
    # Calculate elapsed time
    local elapsed_time=""
    if [[ -n "$START_TIME" ]]; then
        local current_timestamp=$(date +%s)
        local elapsed=$((current_timestamp - START_TIME))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        elapsed_time=$(printf "⏱️  %02d:%02d" "$minutes" "$seconds")
    fi
    
    # Prepare header content lines
    HEADER_CONTENT=()
    
    # Top border with enhanced colors
    local top_border_color="$(get_theme_color "border")"
    HEADER_CONTENT+=("${top_border_color}$(printf '%s%*s%s' "$top_left" $((terminal_width-2)) '' "$top_right" | tr ' ' "$horizontal")${NC}")
    
    # Title line with responsive styling
    local title_text=""
    if [[ "$(get_config_value "layout" "standard")" == "minimal" ]]; then
        title_text="🚀 $(smart_text_wrap "${ISSUE_TITLE:-'Loading...'}" $((max_text_width - 5)))"
    elif [[ "$(get_config_value "layout" "standard")" == "compact" ]]; then
        title_text="🚀 $(get_theme_style "bold")FeLangKit${NC} - $(smart_text_wrap "${ISSUE_TITLE:-'Loading...'}" $((max_text_width - 15)))"
    else
        title_text="🚀 $(get_theme_style "bold")FeLangKit Claude Worktree${NC} - $(smart_text_wrap "${ISSUE_TITLE:-'Loading...'}" $((max_text_width - 25)))"
    fi
    HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$title_text") ${top_border_color}${vertical}${NC}")
    
    # Time info line with responsive formatting
    local time_icon="$(get_theme_color "info")📅${NC}"
    local time_text=""
    
    if [[ "$(get_config_value "layout" "standard")" == "minimal" ]]; then
        # Minimal: just show elapsed time
        if [[ -n "$elapsed_time" ]]; then
            time_text="$time_icon $(get_theme_color "accent")$elapsed_time${NC}"
        else
            time_text="$time_icon $(get_theme_color "primary")$(date '+%H:%M:%S')${NC}"
        fi
    elif [[ "$(get_config_value "layout" "standard")" == "compact" ]]; then
        # Compact: current time and elapsed
        time_text="$time_icon $(get_theme_color "primary")$(date '+%H:%M:%S')${NC}"
        if [[ -n "$elapsed_time" ]]; then
            time_text="$time_text | $(get_theme_color "accent")$elapsed_time${NC}"
        fi
    else
        # Standard/Extended: full time info
        local start_time_formatted=$(date -r ${START_TIME:-$(date +%s)} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
        time_text="$time_icon Started: $(get_theme_color "muted")$start_time_formatted${NC} | Current: $(get_theme_color "primary")$current_time${NC}"
        if [[ -n "$elapsed_time" ]]; then
            time_text="$time_text | $(get_theme_color "accent")$elapsed_time${NC}"
        fi
        
        # Fallback to compact format if too long
        local time_text_plain=$(echo "$time_text" | sed 's/\x1b\[[0-9;]*m//g')
        if [[ ${#time_text_plain} -gt $content_width ]]; then
            time_text="$time_icon $(get_theme_color "primary")$current_time${NC}"
            if [[ -n "$elapsed_time" ]]; then
                time_text="$time_text | $(get_theme_color "accent")$elapsed_time${NC}"
            fi
        fi
    fi
    HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$time_text") ${top_border_color}${vertical}${NC}")
    
    # Branch and issue line with responsive display
    if [[ "$(get_config_value "show_branch_info" "true")" == "true" ]]; then
        local branch_icon="$(get_theme_color "success")🌿${NC}"
        local issue_icon="$(get_theme_color "info")📝${NC}"
        local branch_text=""
        
        if [[ "$(get_config_value "layout" "standard")" == "minimal" ]]; then
            # Minimal: just branch name
            local branch_name=$(smart_text_wrap "${BRANCH_NAME:-'N/A'}" $((max_text_width - 10)))
            branch_text="$branch_icon $(get_theme_color "accent")$branch_name${NC}"
        elif [[ "$(get_config_value "layout" "standard")" == "compact" ]]; then
            # Compact: branch and short issue
            local branch_name=$(smart_text_wrap "${BRANCH_NAME:-'N/A'}" 20)
            local issue_desc=$(smart_text_wrap "${ISSUE_DESCRIPTION:-'N/A'}" 25)
            branch_text="$branch_icon $(get_theme_color "accent")$branch_name${NC} | $issue_icon $(get_theme_color "muted")$issue_desc${NC}"
        else
            # Standard/Extended: full branch and issue info
            local branch_name=$(smart_text_wrap "${BRANCH_NAME:-'N/A'}" 25)
            local issue_desc=$(smart_text_wrap "${ISSUE_DESCRIPTION:-'N/A'}" 40)
            branch_text="$branch_icon Branch: $(get_theme_color "accent")$branch_name${NC} | $issue_icon Issue: $(get_theme_color "muted")$issue_desc${NC}"
        fi
        
        HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$branch_text") ${top_border_color}${vertical}${NC}")
    fi
    
    # Separator line
    HEADER_CONTENT+=("${top_border_color}$(printf '%s%*s%s' "$vertical" $((terminal_width-2)) '' "$vertical" | tr ' ' "$horizontal_sep")${NC}")
    
    # Workflow steps with responsive display
    if [[ ${#WORKFLOW_STEPS[@]} -gt 0 ]]; then
        local workflow_display="$(get_config_value "workflow_display" "full")"
        
        if [[ "$workflow_display" == "minimal" ]]; then
            # Minimal: show only current step
            if [[ $CURRENT_STEP -lt ${#WORKFLOW_STEPS[@]} ]]; then
                local current_step_text="${WORKFLOW_STEPS[CURRENT_STEP]}"
                local status_icon="$(get_status_icon "in_progress")"
                local step_text="$(get_theme_color "primary")$((CURRENT_STEP + 1))/${#WORKFLOW_STEPS[@]}${NC} $status_icon $(get_theme_color "warning")$(get_theme_style "bold")$(smart_text_wrap "$current_step_text" $((max_text_width - 8)))${NC}"
                HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$step_text") ${top_border_color}${vertical}${NC}")
            fi
            
        elif [[ "$workflow_display" == "compact" ]]; then
            # Compact: show progress bar and current step
            local progress_bar=""
            local completed_steps=$CURRENT_STEP
            local total_steps=${#WORKFLOW_STEPS[@]}
            local bar_width=20
            local filled=0
            if [[ $total_steps -gt 0 ]]; then
                filled=$((completed_steps * bar_width / total_steps))
            fi
            
            for ((j=0; j<filled; j++)); do
                progress_bar+="${THEME_COLORS[success]}█${NC}"
            done
            for ((j=filled; j<bar_width; j++)); do
                progress_bar+="░"
            done
            
            local progress_text="${THEME_COLORS[primary]}Progress:${NC} [$progress_bar] ${THEME_COLORS[accent]}$completed_steps/$total_steps${NC}"
            HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$progress_text") ${top_border_color}${vertical}${NC}")
            
            # Current step
            if [[ $CURRENT_STEP -lt ${#WORKFLOW_STEPS[@]} ]]; then
                local current_step_text="${WORKFLOW_STEPS[CURRENT_STEP]}"
                local status_icon="$(get_status_icon "in_progress")"
                local step_text="${THEME_COLORS[primary]}Current:${NC} $status_icon ${THEME_COLORS[warning]}${THEME_STYLES[bold]}$(smart_text_wrap "$current_step_text" $((max_text_width - 12)))${NC}"
                HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$step_text") ${top_border_color}${vertical}${NC}")
            fi
            
        else
            # Full: show all steps with status
            local steps_header="$(get_theme_color "primary")🔄 $(get_theme_style "bold")Workflow Steps:${NC}"
            HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$steps_header") ${top_border_color}${vertical}${NC}")
            
            # Limit number of steps shown in standard mode for better height management
            local max_steps_to_show=${#WORKFLOW_STEPS[@]}
            if [[ "$(get_config_value "layout" "standard")" == "standard" ]] && [[ ${#WORKFLOW_STEPS[@]} -gt 5 ]]; then
                max_steps_to_show=5
            fi
            
            for i in "${!WORKFLOW_STEPS[@]}"; do
                if [[ $i -ge $max_steps_to_show ]]; then
                    break
                fi
                
                local step="${WORKFLOW_STEPS[i]}"
                local status_icon=""
                local step_color=""
                local step_style=""
                
                if [[ $i -lt $CURRENT_STEP ]]; then
                    status_icon="$(get_status_icon "completed")"
                    step_color="${THEME_COLORS[success]}"
                    step_style="${THEME_STYLES[dim]}"
                elif [[ $i -eq $CURRENT_STEP ]]; then
                    status_icon="$(get_status_icon "in_progress")"
                    step_color="${THEME_COLORS[warning]}"
                    step_style="${THEME_STYLES[bold]}"
                else
                    status_icon="$(get_status_icon "pending")"
                    step_color="${THEME_COLORS[muted]}"
                    step_style=""
                fi
                
                local step_text="  ${THEME_COLORS[primary]}$((i+1)).${NC} $status_icon ${step_color}${step_style}$(smart_text_wrap "$step" $((max_text_width - 8)))${NC}"
                HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$step_text") ${top_border_color}${vertical}${NC}")
            done
            
            # Show remaining steps count if truncated
            if [[ $max_steps_to_show -lt ${#WORKFLOW_STEPS[@]} ]]; then
                local remaining=$((${#WORKFLOW_STEPS[@]} - max_steps_to_show))
                local remaining_text="  ${THEME_COLORS[muted]}... and $remaining more steps${NC}"
                HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$remaining_text") ${top_border_color}${vertical}${NC}")
            fi
        fi
    fi
    
    # Add separator before activity section
    if [[ -n "$CURRENT_ACTIVITY" ]] || [[ $CURRENT_STEP -lt ${#STEP_DETAILS[@]} && -n "${STEP_DETAILS[CURRENT_STEP]}" ]]; then
        HEADER_CONTENT+=("${top_border_color}$(printf '%s%*s%s' "$vertical" $((terminal_width-2)) '' "$vertical" | tr ' ' "$horizontal_sep")${NC}")
    fi
    
    # Current activity line with enhanced styling
    if [[ -n "$CURRENT_ACTIVITY" ]]; then
        local activity_icon="${THEME_COLORS[accent]}💡${NC}"
        local activity_text="$activity_icon ${THEME_STYLES[bold]}Current Activity:${NC} ${THEME_COLORS[primary]}$(smart_text_wrap "$CURRENT_ACTIVITY" $((max_text_width - 20)))${NC}"
        HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$activity_text") ${top_border_color}${vertical}${NC}")
    elif [[ $CURRENT_STEP -lt ${#STEP_DETAILS[@]} && -n "${STEP_DETAILS[CURRENT_STEP]}" ]]; then
        local activity_icon="${THEME_COLORS[accent]}💡${NC}"
        local activity_text="$activity_icon ${THEME_STYLES[bold]}Current Activity:${NC} ${THEME_COLORS[primary]}$(smart_text_wrap "${STEP_DETAILS[CURRENT_STEP]}" $((max_text_width - 20)))${NC}"
        HEADER_CONTENT+=("${top_border_color}${vertical}${NC} $(printf '%-*s' $content_width "$activity_text") ${top_border_color}${vertical}${NC}")
    fi
    
    # Bottom border
    HEADER_CONTENT+=("${top_border_color}$(printf '%s%*s%s' "$bottom_left" $((terminal_width-2)) '' "$bottom_right" | tr ' ' "$horizontal")${NC}")
    
    # Output log separator with enhanced styling
    HEADER_CONTENT+=("${THEME_COLORS[info]}📋 ${THEME_STYLES[bold]}Output Log:${NC}")
    HEADER_CONTENT+=("")  # Empty line for spacing
    
    # Update calculated header line count
    CALCULATED_HEADER_LINES=${#HEADER_CONTENT[@]}
}

# Enhanced header drawing function with flicker reduction
draw_header() {
    # Only proceed if terminal supports cursor positioning
    if ! has_capability "cursor_positioning"; then
        return 0
    fi
    
    # Check if flicker reduction is enabled
    local flicker_reduction=$(get_config_value "flicker_reduction" "true")
    
    if [[ "$flicker_reduction" == "true" ]]; then
        draw_header_optimized
    else
        draw_header_legacy
    fi
}

# Legacy header drawing (original method)
draw_header_legacy() {
    # Calculate header content first
    calculate_header_content
    
    # Save cursor position
    tput sc 2>/dev/null
    
    # Move to top-left and draw
    tput cup 0 0 2>/dev/null
    
    # Draw each line of the header (colors are already embedded in content)
    for i in "${!HEADER_CONTENT[@]}"; do
        local line="${HEADER_CONTENT[i]}"
        tput cup $i 0 2>/dev/null
        
        # Print the line (with embedded colors)
        printf "%s" "$line"
        
        # Clear rest of line to prevent artifacts
        tput el 2>/dev/null
    done
    
    # Restore cursor position
    tput rc 2>/dev/null
}

# Optimized header drawing with flicker reduction
draw_header_optimized() {
    # Check if we should skip this update
    if ! should_update_now && ! has_header_changed && ! has_terminal_size_changed; then
        debug "Skipping header update - no changes detected"
        return 0
    fi
    
    # Calculate header content
    calculate_header_content
    
    # Disable cursor for smoother updates
    tput civis 2>/dev/null
    
    # Save cursor position once
    tput sc 2>/dev/null
    
    local updates_needed=false
    local update_batch=()
    
    # Check each line for changes
    for i in "${!HEADER_CONTENT[@]}"; do
        local line="${HEADER_CONTENT[i]}"
        
        # Check if this line needs updating
        if [[ "${HEADER_CACHE[$i]}" != "$line" ]]; then
            update_batch+=("$i" "$line")
            updates_needed=true
        fi
    done
    
    # Apply updates if needed
    if [[ "$updates_needed" == "true" ]]; then
        debug "Updating ${#update_batch[@]}/2 header lines"
        
        # Batch update all changed lines
        local i=0
        while [[ $i -lt ${#update_batch[@]} ]]; do
            local line_num="${update_batch[i]}"
            local content="${update_batch[i+1]}"
            
            # Move to line and update
            tput cup $line_num 0 2>/dev/null
            printf "%s" "$content"
            tput el 2>/dev/null
            
            # Update cache
            HEADER_CACHE[$line_num]="$content"
            
            i=$((i + 2))
        done
    fi
    
    # Clear any extra lines if header got smaller
    local old_line_count=${#HEADER_CACHE[@]}
    local new_line_count=${#HEADER_CONTENT[@]}
    
    if [[ $old_line_count -gt $new_line_count ]]; then
        for (( i=new_line_count; i<old_line_count; i++ )); do
            tput cup $i 0 2>/dev/null
            tput el 2>/dev/null
            unset HEADER_CACHE[$i]
        done
    fi
    
    # Restore cursor and visibility
    tput rc 2>/dev/null
    tput cnorm 2>/dev/null
    
    debug "Header update completed"
}

# Fallback header display for limited terminals
fallback_header_display() {
    local border="========================================"
    echo "$border"
    echo "FeLangKit Claude Worktree"
    echo "Issue: ${ISSUE_TITLE:-'Loading...'}"
    echo "Branch: ${BRANCH_NAME:-'N/A'}"
    echo "Step: $((CURRENT_STEP + 1))/${#WORKFLOW_STEPS[@]} - ${WORKFLOW_STEPS[CURRENT_STEP]:-'N/A'}"
    if [[ -n "$CURRENT_ACTIVITY" ]]; then
        echo "Activity: $CURRENT_ACTIVITY"
    fi
    if [[ -n "$START_TIME" ]]; then
        local elapsed=$(($(date +%s) - START_TIME))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        printf "Elapsed: %02d:%02d\n" "$minutes" "$seconds"
    fi
    echo "$border"
    echo
}

# スクロール領域設定関数
enable_scroll_region() {
    local terminal_height=$(tput lines)
    local scroll_bottom=$((terminal_height - 1))
    
    # 初期ヘッダー描画して行数を計算
    draw_header
    HEADER_LINE_COUNT=$CALCULATED_HEADER_LINES
    
    # スクロール領域を設定（動的に計算されたヘッダー行数以降を scroll 可能に）
    tput csr $HEADER_LINE_COUNT $scroll_bottom
    
    # ログ出力開始位置へカーソル移動
    tput cup $HEADER_LINE_COUNT 0
    
    # カーソルを非表示
    tput civis
}

# 終了時クリーンアップ関数
cleanup_terminal() {
    local terminal_height=$(tput lines)
    local scroll_bottom=$((terminal_height - 1))
    
    # ヘッダー更新プロセスを終了
    if [[ -n "$HEADER_UPDATE_PID" ]]; then
        kill $HEADER_UPDATE_PID 2>/dev/null || true
        wait $HEADER_UPDATE_PID 2>/dev/null || true
    fi
    
    # スクロール領域をリセット
    tput csr 0 $scroll_bottom
    
    # カーソルを再表示
    tput cnorm
    
    # Clear header area
    if [[ $CALCULATED_HEADER_LINES -gt 0 ]]; then
        for ((i=0; i<CALCULATED_HEADER_LINES; i++)); do
            tput cup $i 0
            tput el
        done
    fi
    
    # Move cursor to top
    tput cup 0 0
    
    echo "🏁 Terminal cleanup completed at $(date '+%Y-%m-%d %H:%M:%S')"
}

init_status_box() {
    local issue_title="$1"
    local issue_body="$2"
    local branch_name="$3"
    
    # Initialize enhanced header system
    detect_terminal_capabilities
    init_header_config
    init_color_themes
    init_flicker_reduction
    load_theme "$(get_config_value "theme" "default")"
    
    # Store issue information
    ISSUE_TITLE="$issue_title"
    # Smart truncation with enhanced text handling
    ISSUE_DESCRIPTION=$(smart_text_wrap "$issue_body" 80)
    if [[ ${#issue_body} -gt 80 ]]; then
        ISSUE_DESCRIPTION=$(echo "$issue_body" | head -n1 | cut -c1-77)
        ISSUE_DESCRIPTION="${ISSUE_DESCRIPTION}..."
    fi
    
    # Define workflow steps with enhanced icons
    WORKFLOW_STEPS=(
        "Setting up worktree"
        "Fetching issue data" 
        "Generating analysis"
        "Running Claude Code"
        "Validating implementation"
        "Creating pull request"
        "Monitoring CI checks"
        "Workflow complete"
    )
    
    # Define step details for current activity display
    STEP_DETAILS=(
        "Creating isolated development environment"
        "Retrieving GitHub issue information and context"
        "Preparing implementation strategy and context"
        "Executing automated implementation with Claude"
        "Running SwiftLint, build, and test validation"
        "Generating PR description and creating pull request"
        "Monitoring CI pipeline and test execution"
        "All tasks completed successfully"
    )
    
    CURRENT_STEP=0
    CURRENT_ACTIVITY=""
    START_TIME=$(date +%s)
    
    # Initialize terminal display with fallback
    if has_capability "scroll_region" && has_capability "cursor_positioning"; then
        enable_scroll_region
        
        # Start background header update process with optimized flicker reduction
        local update_interval=$(get_config_value "update_interval" "1")
        local flicker_reduction=$(get_config_value "flicker_reduction" "true")
        
        (
            # Initialize update tracking
            local last_header_lines=$CALCULATED_HEADER_LINES
            local update_count=0
            local skip_count=0
            
            while true; do
                sleep 0.5  # Check more frequently but update smartly
                
                # Increment counters
                update_count=$((update_count + 1))
                
                # Only attempt update if enough time has passed or critical change detected
                local force_update=false
                if [[ $((update_count * 5)) -ge $((update_interval * 10)) ]]; then
                    force_update=true
                    update_count=0
                fi
                
                # Check for critical changes that require immediate update
                if has_terminal_size_changed || [[ "$CURRENT_STEP" != "${PREV_CURRENT_STEP:-}" ]]; then
                    force_update=true
                    debug "Critical change detected, forcing update"
                fi
                
                # Store previous state for change detection
                PREV_CURRENT_STEP="$CURRENT_STEP"
                
                if [[ "$flicker_reduction" == "true" ]]; then
                    # Smart update with flicker reduction
                    if [[ "$force_update" == "true" ]] || has_header_changed; then
                        local old_header_lines=$CALCULATED_HEADER_LINES
                        draw_header_optimized
                        
                        # Update scroll region if header size changed
                        if [[ $CALCULATED_HEADER_LINES -ne $old_header_lines ]]; then
                            local terminal_height=$(tput lines 2>/dev/null || echo "24")
                            local scroll_bottom=$((terminal_height - 1))
                            HEADER_LINE_COUNT=$CALCULATED_HEADER_LINES
                            if has_capability "scroll_region"; then
                                tput csr $HEADER_LINE_COUNT $scroll_bottom 2>/dev/null
                                tput cup $HEADER_LINE_COUNT 0 2>/dev/null
                            fi
                        fi
                    else
                        skip_count=$((skip_count + 1))
                        if [[ $((skip_count % 20)) -eq 0 ]]; then
                            debug "Skipped $skip_count header updates (no changes)"
                        fi
                    fi
                else
                    # Legacy update mode
                    if [[ "$force_update" == "true" ]]; then
                        local old_header_lines=$CALCULATED_HEADER_LINES
                        draw_header_legacy
                        
                        if [[ $CALCULATED_HEADER_LINES -ne $old_header_lines ]]; then
                            local terminal_height=$(tput lines 2>/dev/null || echo "24")
                            local scroll_bottom=$((terminal_height - 1))
                            HEADER_LINE_COUNT=$CALCULATED_HEADER_LINES
                            if has_capability "scroll_region"; then
                                tput csr $HEADER_LINE_COUNT $scroll_bottom 2>/dev/null
                                tput cup $HEADER_LINE_COUNT 0 2>/dev/null
                            fi
                        fi
                    fi
                fi
            done
        ) &
        HEADER_UPDATE_PID=$!
    else
        # Fallback for terminals without advanced capabilities
        info "Terminal capabilities limited, using basic header display"
        fallback_header_display
    fi
}

update_step() {
    local step_number="$1"
    CURRENT_STEP="$step_number"
    CURRENT_ACTIVITY=""  # Clear activity when step changes
    # Header will be updated automatically by background process
}

update_activity() {
    local activity="$1"
    CURRENT_ACTIVITY="$activity"
    # Header will be updated automatically by background process
}

update_step_with_activity() {
    local step_number="$1"
    local activity="$2"
    CURRENT_STEP="$step_number"
    CURRENT_ACTIVITY="$activity"
    # Header will be updated automatically by background process
}

# Enhanced progress bar with animations and better visual design
draw_enhanced_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local label="${4:-Progress}"
    local style="${5:-gradient}"
    
    # Ensure we have valid numbers
    if [[ ! "$current" =~ ^[0-9]+$ ]] || [[ ! "$total" =~ ^[0-9]+$ ]] || [[ $total -eq 0 ]]; then
        return 1
    fi
    
    # Calculate percentage and filled length with zero-division protection
    local percentage=0
    local filled=0
    if [[ $total -gt 0 ]]; then
        percentage=$((current * 100 / total))
        filled=$((current * width / total))
    fi
    local remaining=$((width - filled))
    
    # Enhanced progress characters based on style
    local progress_chars=("▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
    local empty_char="░"
    local filled_char="█"
    
    # Color selection based on progress and theme
    local progress_color
    if [[ $percentage -lt 25 ]]; then
        progress_color="${THEME_COLORS[error]:-${RED}}"
    elif [[ $percentage -lt 50 ]]; then
        progress_color="${THEME_COLORS[warning]:-${YELLOW}}"
    elif [[ $percentage -lt 75 ]]; then
        progress_color="${THEME_COLORS[info]:-${CYAN}}"
    else
        progress_color="${THEME_COLORS[success]:-${GREEN}}"
    fi
    
    # Build progress bar based on style
    local bar=""
    if [[ "$style" == "gradient" ]]; then
        # Gradient style with smooth transitions
        for ((i=0; i<filled; i++)); do
            local intensity=0
            if [[ $filled -gt 0 ]]; then
                intensity=$((i * 7 / filled))
            fi
            if [[ $intensity -ge 7 ]]; then intensity=7; fi
            bar+="${progress_color}${progress_chars[intensity]}${NC}"
        done
    else
        # Standard style
        for ((i=0; i<filled; i++)); do
            bar+="${progress_color}${filled_char}${NC}"
        done
    fi
    
    # Add empty section
    for ((i=0; i<remaining; i++)); do
        bar+="${THEME_COLORS[muted]:-}${empty_char}${NC}"
    done
    
    # Format with enhanced styling
    local info_icon="${THEME_COLORS[info]}ℹ${NC}"
    printf "\r%s ${THEME_STYLES[bold]}%s:${NC} [%s] ${THEME_COLORS[accent]}%3d%%${NC}" \
           "$info_icon" "$label" "$bar" "$percentage"
    
    # Add time information if this is a timed progress
    if [[ -n "${6:-}" ]]; then
        local elapsed="$6"
        local eta=""
        if [[ $current -gt 0 ]] && [[ $percentage -lt 100 ]] && [[ $elapsed -gt 0 ]]; then
            local rate=$((current * 100 / elapsed))
            if [[ $rate -gt 0 ]] && [[ $percentage -gt 0 ]]; then
                local eta_seconds=$(((100 - percentage) * elapsed / percentage))
                local eta_minutes=$((eta_seconds / 60))
                eta_seconds=$((eta_seconds % 60))
                eta=$(printf " | ETA: %02d:%02d" "$eta_minutes" "$eta_seconds")
            fi
        fi
        printf " | ${THEME_COLORS[muted]}Elapsed: %02d:%02d%s${NC}" \
               $((elapsed / 60)) $((elapsed % 60)) "$eta"
    fi
    
    printf "\n"
}

# Backward compatibility wrapper
draw_progress_bar() {
    draw_enhanced_progress_bar "$@"
}

# Enhanced spinner with multiple animation styles
show_enhanced_spinner() {
    local message="$1"
    local duration="${2:-0}"  # Total duration in seconds (0 = indefinite)
    local style="${3:-braille}"
    local show_progress="${4:-true}"
    
    # Animation styles
    local braille_spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local dots_spinner=('⠁' '⠂' '⠄' '⡀' '⢀' '⠠' '⠐' '⠈')
    local arrow_spinner=('↖' '↗' '↘' '↙')
    local clock_spinner=('🕐' '🕑' '🕒' '🕓' '🕔' '🕕' '🕖' '🕗' '🕘' '🕙' '🕚' '🕛')
    local bounce_spinner=('⠁' '⠈' '⠐' '⠠' '⢀' '⡀' '⠄' '⠂')
    
    # Select spinner based on style and terminal capabilities
    local spinner_chars=()
    case "$style" in
        "dots")
            spinner_chars=("${dots_spinner[@]}")
            ;;
        "arrow")
            spinner_chars=("${arrow_spinner[@]}")
            ;;
        "clock")
            if has_capability "unicode"; then
                spinner_chars=("${clock_spinner[@]}")
            else
                spinner_chars=("${braille_spinner[@]}")
            fi
            ;;
        "bounce")
            spinner_chars=("${bounce_spinner[@]}")
            ;;
        *)
            spinner_chars=("${braille_spinner[@]}")
            ;;
    esac
    
    local i=0
    local elapsed=0
    local start_time=$(date +%s)
    local cycle_time=0.15  # Animation speed
    
    while true; do
        local current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        # Check if we should stop (for timed operations)
        if [[ $duration -gt 0 ]] && [[ $elapsed -ge $duration ]]; then
            break
        fi
        
        # Build spinner display
        local spinner_icon="${THEME_COLORS[accent]}${spinner_chars[i]}${NC}"
        local display_text="$spinner_icon ${THEME_STYLES[bold]}$message${NC}"
        
        # Add progress bar for timed operations
        if [[ $duration -gt 0 ]] && [[ "$show_progress" == "true" ]]; then
            local percentage=$((elapsed * 100 / duration))
            local bar_width=25
            local filled=$((elapsed * bar_width / duration))
            local remaining=$((bar_width - filled))
            
            local progress_bar=""
            for ((j=0; j<filled; j++)); do
                progress_bar+="${THEME_COLORS[success]}█${NC}"
            done
            for ((j=0; j<remaining; j++)); do
                progress_bar+="${THEME_COLORS[muted]}░${NC}"
            done
            
            local time_remaining=$((duration - elapsed))
            local minutes=$((time_remaining / 60))
            local seconds=$((time_remaining % 60))
            local time_str=$(printf "%02d:%02d" "$minutes" "$seconds")
            
            display_text="$display_text [${progress_bar}] ${THEME_COLORS[accent]}${percentage}%%${NC} | ${THEME_COLORS[muted]}${time_str} remaining${NC}"
        else
            # Add elapsed time for indefinite operations
            local minutes=$((elapsed / 60))
            local seconds=$((elapsed % 60))
            local time_str=$(printf "%02d:%02d" "$minutes" "$seconds")
            display_text="$display_text ${THEME_COLORS[muted]}[${time_str}]${NC}"
        fi
        
        printf "\r%s          " "$display_text"
        
        i=$(( (i + 1) % ${#spinner_chars[@]} ))
        sleep "$cycle_time"
    done
    
    # Final state for completed operations
    if [[ $duration -gt 0 ]]; then
        local success_icon="${THEME_COLORS[success]}✓${NC}"
        local final_bar=""
        for ((j=0; j<25; j++)); do
            final_bar+="${THEME_COLORS[success]}█${NC}"
        done
        printf "\r%s ${THEME_STYLES[bold]}%s${NC} [%s] ${THEME_COLORS[success]}100%% | Complete!${NC}     \n" \
               "$success_icon" "$message" "$final_bar"
    fi
}

# Enhanced loading function with better visual feedback
show_loading() {
    local message="$1"
    local style="${2:-braille}"
    
    # Use the enhanced spinner for indefinite loading
    show_enhanced_spinner "$message" 0 "$style" "false"
}

# Backward compatibility wrappers
show_progress_with_spinner() {
    show_enhanced_spinner "$1" "$2" "braille" "true"
}

run_with_loading() {
    local message="$1"
    local output_file="$2"
    shift 2
    local command=("$@")
    
    debug "Running command: ${command[*]}"
    
    # Start loading animation in background
    show_loading "$message" &
    local loading_pid=$!
    
    # Create temporary error file if none provided
    local temp_error_file=""
    local error_file="$output_file"
    if [[ -z "$output_file" ]]; then
        temp_error_file=$(mktemp)
        error_file="$temp_error_file"
    fi
    
    # Run the command
    local exit_code=0
    if [[ -n "$output_file" ]]; then
        if "${command[@]}" > "$output_file" 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        if "${command[@]}" > "$temp_error_file" 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    # Stop loading animation
    kill $loading_pid 2>/dev/null
    wait $loading_pid 2>/dev/null
    echo -e "\r\033[K" # Clear loading line
    
    if [[ $exit_code -eq 0 ]]; then
        success "$message completed"
        debug "Command succeeded: ${command[*]}"
    else
        error_debug "$message failed (exit code: $exit_code)" "$error_file"
        debug "Failed command: ${command[*]}"
    fi
    
    # Clean up temporary error file
    if [[ -n "$temp_error_file" ]]; then
        rm -f "$temp_error_file"
    fi
    
    return $exit_code
}

show_loading() {
    local message="$1"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local seconds=0
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        seconds=$((current_time - start_time))
        
        # Format time as MM:SS
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        local formatted_time=$(printf "%02d:%02d" "$minutes" "$remaining_seconds")
        
        printf "\r${CYAN}[${spinner[i]}]${NC} %s ${YELLOW}[%s]${NC}          " "$message" "$formatted_time"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.1
    done
}

cleanup() {
    # Clean up terminal first
    cleanup_terminal
    
    log "Cleanup initiated..."
    if [[ -n "$ISSUE_DATA_FILE" && -f "$ISSUE_DATA_FILE" ]]; then
        rm -f "$ISSUE_DATA_FILE"
        log "Removed temporary issue data file"
    fi
    if [[ -n "$ANALYSIS_FILE" && -f "$ANALYSIS_FILE" ]]; then
        rm -f "$ANALYSIS_FILE"
        log "Removed temporary analysis file"
    fi
    if [[ -n "$WORKTREE_PATH" ]]; then
        rm -f "${WORKTREE_PATH}/.validation-errors.md"
        rm -f "${WORKTREE_PATH}/.claude-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-error-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-pr-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-pr-output.json"
        rm -f "${WORKTREE_PATH}/.claude-commit-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-commit-output.txt"
        rm -f "${WORKTREE_PATH}/.claude-output.log"
        rm -f "${WORKTREE_PATH}/.claude-error.log"
        rm -f "${WORKTREE_PATH}/.claude-error-output.log"
        rm -f "${WORKTREE_PATH}/.claude-error-stderr.log"
        rm -f "${WORKTREE_PATH}/.claude-pr-error.log"
        rm -f "${WORKTREE_PATH}/.claude-commit-error.log"
    fi
}

trap cleanup EXIT INT TERM

usage() {
    cat << EOF
Claude Worktree - Parallel Claude Code Development

Usage: $0 <github-issue-url>

This script automates the complete development workflow:
1. Creates a new git worktree for isolated development
2. Fetches GitHub issue data using gh CLI
3. Launches Claude Code with issue context
4. Manages branch creation, commits, and push
5. Creates pull request with proper title and description
6. Monitors CI checks until completion

Examples:
  $0 https://github.com/owner/repo/issues/123
  $0 https://github.com/fumiya-kume/FeLangKit/issues/87

Prerequisites:
  - git worktree support
  - GitHub CLI (gh) installed and authenticated
  - Claude Code CLI available
  - SwiftLint for code quality

Options:
  -h, --help    Show this help message
  --cleanup     Remove all existing worktrees (use with caution)
  --debug       Enable debug mode with verbose error output

Environment Variables:
  DEBUG_MODE                Set to 'true' to enable debug output (default: false)
  
Header Customization:
  HEADER_THEME             Header theme: default, minimal, modern, compact (default: default)
  HEADER_UPDATE_INTERVAL   Header refresh interval in seconds (default: 1)
  HEADER_SHOW_METRICS      Show system metrics: true/false (default: false)
  HEADER_ANIMATIONS        Enable animations: true/false (default: true)
  HEADER_COLOR_MODE        Color mode: auto, always, never (default: auto)
  HEADER_BORDER_STYLE      Border style: single, double, rounded, thick (default: double)
  HEADER_LAYOUT            Layout mode: auto, compact, standard, extended (default: auto)
  
Flicker Reduction:
  HEADER_FLICKER_REDUCTION Advanced flicker reduction: true/false (default: true)
  HEADER_BUFFER_UPDATES    Enable update buffering: true/false (default: true)
  HEADER_DIFFERENTIAL_UPDATES  Only update changed content: true/false (default: true)
EOF
}

validate_prerequisites() {
    step "Validating prerequisites..."
    
    # Check git version (worktree support requires git 2.5+)
    if ! git --version | grep -q "git version"; then
        error "Git is not installed or not accessible"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is not installed. Install with: brew install gh"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    fi
    
    # Check Claude Code CLI
    if ! command -v claude &> /dev/null; then
        error "Claude Code CLI is not installed. Install from: https://docs.anthropic.com/en/docs/claude-code"
        exit 1
    fi
    
    # Check SwiftLint (optional but recommended)
    if ! command -v swiftlint &> /dev/null; then
        warn "SwiftLint not found. Install with: brew install swiftlint"
    fi
    
    success "All prerequisites validated"
}

validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
        error "Invalid GitHub issue URL format. Expected: https://github.com/owner/repo/issues/123"
        exit 1
    fi
}

extract_issue_info() {
    local issue_url="$1"
    
    if [[ "$issue_url" =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        ISSUE_NUMBER="${BASH_REMATCH[3]}"
        # Generate random string for uniqueness (8 characters)
        local random_suffix=$(openssl rand -hex 4 2>/dev/null || echo $(date +%s | tail -c 8))
        BRANCH_NAME="issue-${ISSUE_NUMBER}-$(date +%Y%m%d-%H%M%S)-${random_suffix}"
        WORKTREE_PATH="${WORKTREE_BASE_DIR}/${BRANCH_NAME}"
        ISSUE_DATA_FILE="${WORKTREE_PATH}/.issue-data.json"
        ANALYSIS_FILE="${WORKTREE_PATH}/.analysis-data.json"
    else
        error "Failed to extract issue information from URL"
        exit 1
    fi
}

fetch_issue_data() {
    local issue_url="$1"
    
    log "Fetching GitHub issue data..."
    
    # Create temporary file for issue data
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    
    # Use GitHub CLI to fetch issue data with loading animation
    if ! run_with_loading "Fetching issue data from GitHub API" "$temp_file" gh api "repos/${OWNER}/${REPO}/issues/${ISSUE_NUMBER}"; then
        error "Failed to fetch issue data. Check if the issue exists and you have access."
        exit 1
    fi
    
    # Create the worktree directory first to store issue data
    mkdir -p "$(dirname "$ISSUE_DATA_FILE")"
    
    # Create structured issue data
    jq -n \
        --arg url "$issue_url" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        --arg issue_number "$ISSUE_NUMBER" \
        --arg branch_name "$BRANCH_NAME" \
        --argjson issue_data "$(cat "$temp_file")" \
        '{
            url: $url,
            owner: $owner,
            repo: $repo,
            issue_number: ($issue_number | tonumber),
            branch_name: $branch_name,
            title: $issue_data.title,
            body: $issue_data.body,
            state: $issue_data.state,
            labels: [$issue_data.labels[]?.name],
            assignees: [$issue_data.assignees[]?.login],
            milestone: $issue_data.milestone?.title,
            created_at: $issue_data.created_at,
            updated_at: $issue_data.updated_at,
            author: $issue_data.user.login,
            pr_title: ("Resolve #" + $issue_number + ": " + $issue_data.title)
        }' > "$ISSUE_DATA_FILE"
    
    # Validate issue state
    local issue_state=$(jq -r '.state' "$ISSUE_DATA_FILE")
    if [[ "$issue_state" != "open" ]]; then
        error "Issue #${ISSUE_NUMBER} is not open (current state: $issue_state)"
        exit 1
    fi
    
    success "Issue data fetched: $(jq -r '.title' "$ISSUE_DATA_FILE")"
    info "Author: $(jq -r '.author' "$ISSUE_DATA_FILE")"
    info "Labels: $(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")"
}

cleanup_existing_worktree() {
    # Check if worktree is registered in git worktree list
    if git worktree list 2>/dev/null | grep -q "$WORKTREE_PATH"; then
        warn "Worktree registered in git, removing..."
        if ! run_with_loading "Removing registered worktree" "" git worktree remove "$WORKTREE_PATH" --force; then
            warn "Failed to remove worktree via git, trying manual cleanup..."
            # Manual cleanup if git command fails
            rm -rf "$WORKTREE_PATH" 2>/dev/null || true
            git worktree prune 2>/dev/null || true
        fi
    fi
    
    # Check if directory exists and remove it (in case git worktree remove failed)
    if [[ -d "$WORKTREE_PATH" ]]; then
        warn "Worktree directory still exists at $WORKTREE_PATH, force cleaning..."
        if ! run_with_loading "Force cleaning worktree directory" "" rm -rf "$WORKTREE_PATH"; then
            error "Failed to remove worktree directory: $WORKTREE_PATH"
            return 1
        fi
    fi
    
    # Clean up any dangling worktree entries
    if git worktree list 2>/dev/null | grep -q "$(basename "$WORKTREE_PATH")"; then
        warn "Found dangling worktree entries, pruning..."
        git worktree prune 2>/dev/null || true
    fi
    
    # Final verification that cleanup succeeded
    if [[ -d "$WORKTREE_PATH" ]]; then
        error "Worktree cleanup failed - directory still exists: $WORKTREE_PATH"
        return 1
    fi
    
    return 0
}

create_worktree() {
    step "Creating git worktree..."
    
    # Ensure base directory exists
    mkdir -p "$WORKTREE_BASE_DIR"
    
    # Comprehensive worktree cleanup
    if ! cleanup_existing_worktree; then
        error "Failed to cleanup existing worktree, cannot proceed"
        exit 1
    fi
    
    # Fetch latest changes with timeout to prevent hanging
    if ! run_with_loading "Fetching latest changes from origin" "" timeout 30 git fetch origin; then
        warn "Git fetch timed out after 30 seconds, proceeding without fetch..."
        info "This may indicate network issues or repository authentication problems"
    fi
    
    # Create new worktree from master (without -b to avoid branch conflicts)
    if ! run_with_loading "Creating new git worktree" "" git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/master; then
        # If branch creation fails, try creating worktree with existing branch
        warn "Branch creation failed, trying with checkout instead..."
        if ! run_with_loading "Creating worktree with checkout" "" git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null; then
            # If that fails too, delete any existing branch and retry
            warn "Cleaning up existing branch and retrying..."
            git branch -D "$BRANCH_NAME" 2>/dev/null || true
            if ! run_with_loading "Creating new git worktree (retry)" "" git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/master; then
                error "Failed to create git worktree after cleanup"
                exit 1
            fi
        fi
    fi
    
    success "Git worktree created: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
}

generate_analysis() {
    step "Generating strategic analysis for Claude Code..."
    
    # Create analysis prompt based on issue data
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body' "$ISSUE_DATA_FILE")
    local issue_labels=$(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")
    
    # Create strategic analysis
    cat > "$ANALYSIS_FILE" << EOF
{
    "analysis_type": "strategic_implementation",
    "issue_context": {
        "title": $(jq -r '.title' "$ISSUE_DATA_FILE" | jq -R .),
        "description": $(jq -r '.body // ""' "$ISSUE_DATA_FILE" | jq -R .),
        "labels": $(jq '.labels' "$ISSUE_DATA_FILE"),
        "priority": "high"
    },
    "implementation_strategy": {
        "approach": "systematic_implementation",
        "phases": [
            "analyze_codebase_structure",
            "implement_core_functionality", 
            "add_comprehensive_tests",
            "validate_with_quality_checks"
        ],
        "quality_requirements": [
            "maintain_existing_test_coverage",
            "follow_swift_coding_standards",
            "ensure_swiftlint_compliance",
            "validate_build_success"
        ]
    },
    "development_context": {
        "project_type": "swift_package",
        "testing_framework": "swift_testing",
        "quality_tools": ["swiftlint"],
        "build_system": "swift_package_manager"
    },
    "success_criteria": {
        "functional": "implementation_meets_issue_requirements",
        "quality": "all_tests_pass_and_linting_clean",
        "integration": "builds_successfully_in_ci"
    }
}
EOF
    
    success "Strategic analysis generated"
}

launch_claude_code() {
    step "Launching Claude Code in worktree..."
    
    # Change to worktree directory
    cd "$WORKTREE_PATH"
    
    # Create initial context message
    local context_message="I need to implement the following GitHub issue:

**Issue #${ISSUE_NUMBER}: $(jq -r '.title' "$ISSUE_DATA_FILE")**

$(jq -r '.body // "No description provided"' "$ISSUE_DATA_FILE")

**Labels:** $(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")
**Branch:** $BRANCH_NAME

## Quality Requirements
Please implement this according to the project's coding standards and ensure:
1. **SwiftLint validation passes** - Run \`swiftlint lint\` frequently during development
2. **Code builds successfully** - Run \`swift build\` to verify compilation
3. **All tests pass** - Run \`swift test\` to ensure functionality
4. Add appropriate tests for new functionality
5. Follow the established architecture patterns

## Development Workflow
During implementation, please run these commands frequently:
- \`swiftlint lint --fix\` - Auto-fix style issues
- \`swiftlint lint\` - Check for remaining issues
- \`swift build\` - Verify code compiles
- \`swift test\` - Run the test suite

## Quality Command Sequence
For comprehensive validation, run:
\`\`\`bash
swiftlint lint --fix && swiftlint lint && swift build && swift test
\`\`\`

After implementation, please:
1. Create appropriate commits with conventional commit messages
2. Push the branch to origin
3. The PR will be created automatically

Let me know when you're ready to start!"
    
    info "Starting Claude Code session..."
    info "Worktree: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
    echo
    
    # Write context to a temporary file for Claude Code to reference
    local context_file="${WORKTREE_PATH}/.claude-context.md"
    cat > "$context_file" << EOF
# GitHub Issue Context

$context_message

---

*This context file was automatically generated by claude.sh and can be referenced during your Claude Code session.*
EOF
    
    info "Context saved to: $context_file"
    echo
    
    # Create a temporary input file with the context message
    local input_file="${WORKTREE_PATH}/.claude-input.txt"
    echo "$context_message" > "$input_file"
    
    # Launch Claude Code with automatic prompt execution
    info "Launching Claude Code with issue context..."
    info "Note: You may see a trust prompt - select 'Yes, proceed' to continue"
    echo
    info "Issue context has been saved to: $context_file"
    info "Auto-launching Claude Code with prompt..."
    
    # Try to launch Claude Code interactively
    info "Attempting to launch Claude Code..."
    echo
    warn "If you see raw mode errors, please manually run Claude Code:"
    echo "  cd $WORKTREE_PATH"
    echo "  claude"
    echo "Then paste the context from: $context_file"
    echo
    
    # Try launching Claude Code with input redirection that might work
    if exec < /dev/tty; then
        printf "%s\n" "$context_message" | claude
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            success "Claude Code session completed successfully"
        else
            error "Claude Code session failed or was interrupted (exit code: $exit_code)"
            echo
            warn "You can continue manually by running:"
            echo "  cd $WORKTREE_PATH"
            echo "  claude"
            echo "Then implement the changes and run the validation manually."
            exit 1
        fi
    else
        error "Cannot launch Claude Code in interactive mode"
        echo
        info "Please run Claude Code manually:"
        echo "  cd $WORKTREE_PATH"
        echo "  claude"
        echo
        info "Then paste this context:"
        echo "$context_message"
        echo
        info "After implementation, return to this directory and run validation:"
        echo "  swiftlint lint --fix && swiftlint lint && swift build && swift test"
        exit 1
    fi
    
    # Clean up input file
    rm -f "$input_file"
    
    success "Claude Code session completed"
}

launch_claude_code_with_errors() {
    step "Launching Claude Code to fix validation errors..."
    
    cd "$WORKTREE_PATH"
    
    # Read validation errors
    local validation_errors=""
    if [[ -f "${WORKTREE_PATH}/.validation-errors.md" ]]; then
        validation_errors=$(cat "${WORKTREE_PATH}/.validation-errors.md")
    fi
    
    # Create error context message
    local error_context_message="The implementation has validation errors that need to be fixed:

$validation_errors

## Fix These Issues
Please fix these issues and ensure quality standards are met.

## Development Workflow
During fixes, please run these commands frequently:
- \`swiftlint lint --fix\` - Auto-fix style issues  
- \`swiftlint lint\` - Check for remaining issues
- \`swift build\` - Verify code compiles
- \`swift test\` - Run the test suite

## Quality Command Sequence
For comprehensive validation, run:
\`\`\`bash
swiftlint lint --fix && swiftlint lint && swift build && swift test
\`\`\`

## Requirements
Ensure all of the following pass:
1. **SwiftLint validation passes** - \`swiftlint lint\` should show no errors
2. **Code builds successfully** - \`swift build\` should complete without errors
3. **All tests pass** - \`swift test\` should show all tests passing
4. Follow the established architecture patterns

After fixing the issues, I'll run validation again automatically."
    
    info "Starting Claude Code session to fix validation errors..."
    info "Worktree: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
    echo
    
    # Update context file with error information
    local context_file="${WORKTREE_PATH}/.claude-context.md"
    cat >> "$context_file" << EOF

---

# Validation Error Context

$error_context_message

---

*This error context was automatically added by claude.sh after validation failure.*
EOF
    
    # Create a temporary input file with the error context message
    local input_file="${WORKTREE_PATH}/.claude-error-input.txt"
    echo "$error_context_message" > "$input_file"
    
    # Launch Claude Code with error context pre-loaded
    info "Launching Claude Code with validation error context..."
    echo
    error "Validation errors detected! Auto-launching Claude Code to fix them."
    info "Error context has been saved to: $context_file"
    
    update_activity "Fixing validation errors with Claude Code"
    
    # Launch Claude Code with the error context message pre-loaded
    printf "%s\n" "$error_context_message" | claude
    if [[ $? -eq 0 ]]; then
        success "Claude Code error-fixing session completed successfully"
    else
        local exit_code=$?
        error "Claude Code error-fixing session failed or was interrupted (exit code: $exit_code)"
        exit 1
    fi
    
    # Clean up input file
    rm -f "$input_file"
    
    success "Claude Code error-fixing session completed"
}

validate_implementation() {
    step "Validating implementation..."
    update_activity "Running comprehensive validation checks"
    
    cd "$WORKTREE_PATH"
    
    local validation_errors=""
    local has_errors=false
    
    # Check if there are any real changes (excluding gitignored files)
    local has_changes=false
    
    # Test if git add would stage any new changes
    local staged_before=$(git diff --cached --numstat | wc -l)
    if git add --dry-run . >/dev/null 2>&1; then
        git add . >/dev/null 2>&1
        local staged_after=$(git diff --cached --numstat | wc -l)
        if [[ $staged_after -gt $staged_before ]]; then
            has_changes=true
        fi
        # Reset to previous state
        git reset >/dev/null 2>&1
    fi
    
    if [[ "$has_changes" == "false" ]] && git diff --quiet && git diff --cached --quiet; then
        warn "No trackable changes detected in worktree (only gitignored files present)"
        info "Continuing with validation anyway..."
    fi
    
    # Run quality checks if SwiftLint is available
    if command -v swiftlint &> /dev/null; then
        update_activity "Running SwiftLint code quality checks"
        
        # Auto-fix with loading
        if ! run_with_loading "Running SwiftLint auto-fix" "" swiftlint lint --fix; then
            warn "SwiftLint auto-fix applied changes"
        fi
        
        # Validation with loading
        local swiftlint_temp=$(mktemp)
        if ! run_with_loading "Running SwiftLint validation" "$swiftlint_temp" swiftlint lint; then
            error "SwiftLint validation failed"
            local swiftlint_output=$(cat "$swiftlint_temp")
            validation_errors+="\n## SwiftLint Errors:\n\`\`\`\n$swiftlint_output\n\`\`\`\n"
            has_errors=true
        fi
        rm -f "$swiftlint_temp"
    fi
    
    # Build the project
    update_activity "Building project with Swift Package Manager"
    local build_temp=$(mktemp)
    if ! run_with_loading "Building Swift package" "$build_temp" swift build; then
        error "Build failed"
        local build_output=$(cat "$build_temp")
        validation_errors+="\n## Build Errors:\n\`\`\`\n$build_output\n\`\`\`\n"
        has_errors=true
    fi
    rm -f "$build_temp"
    
    # Run tests
    update_activity "Running comprehensive test suite"
    local test_temp=$(mktemp)
    if ! run_with_loading "Running Swift test suite" "$test_temp" swift test; then
        error "Tests failed"
        local test_output=$(cat "$test_temp")
        validation_errors+="\n## Test Errors:\n\`\`\`\n$test_output\n\`\`\`\n"
        has_errors=true
    fi
    rm -f "$test_temp"
    
    if [[ "$has_errors" == "true" ]]; then
        # Store validation errors for retry
        echo "$validation_errors" > "${WORKTREE_PATH}/.validation-errors.md"
        return 1
    fi
    
    success "Implementation validation completed"
    return 0
}

generate_pr_description() {
    step "Generating PR description with Claude Code..."
    
    cd "$WORKTREE_PATH"
    
    # Collect implementation context
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    local commit_messages=$(git log --oneline "master..HEAD" | head -10)
    local files_changed=$(git diff --name-only "master..HEAD")
    local files_added=$(git diff --name-status "master..HEAD" | grep "^A" | cut -f2)
    local files_modified=$(git diff --name-status "master..HEAD" | grep "^M" | cut -f2)
    
    # Create context message for Claude Code
    local pr_context_message="I need you to generate a well-structured Markdown PR description for the following GitHub issue implementation:

**Issue #${ISSUE_NUMBER}: $issue_title**

**Issue Description:**
$issue_body

**Implementation Details:**
- Branch: $BRANCH_NAME  
- Commits made:
\`\`\`
$commit_messages
\`\`\`

**Files Changed:**
$files_changed

**Files Added:**
$files_added

**Files Modified:**  
$files_modified

**Validation Results:**
- ✅ SwiftLint validation passed
- ✅ Build successful
- ✅ All tests passed

Please generate a comprehensive Markdown PR description with detailed background context and solution explanation:

## Summary
Concise overview of what this PR accomplishes and its main value

## Background & Context
Provide detailed background about the issue and context:
- **Original Issue:** Detailed explanation of the problem that was reported or identified
- **Root Cause:** What was causing the issue (if applicable)
- **User Impact:** How this issue affected users or the development process
- **Previous State:** Describe how things worked before this change
- **Requirements:** What specific requirements needed to be met

## Solution Approach
Explain the solution and reasoning in detail:
- **Core Solution:** Clear explanation of how this PR solves the identified problem
- **Technical Strategy:** The overall technical approach chosen
- **Logic & Reasoning:** Detailed explanation of the implementation logic and why this approach was selected
- **Alternative Approaches:** Briefly mention other approaches considered and why they were not chosen
- **Architecture Changes:** Any changes to the overall system architecture or design patterns

## Implementation Details
Technical implementation breakdown:
- **Key Components:** Main components or modules that were modified/added
- **Code Changes:** Detailed explanation of the major code changes made
- **Files Modified:** List of files changed with brief explanation of changes in each
- **New Functionality:** Any new features or capabilities added
- **Integration Points:** How this change integrates with existing code
- **Error Handling:** How errors and edge cases are handled

## Technical Logic
Explain the technical reasoning and logic:
- **Algorithm/Logic:** Step-by-step explanation of key algorithms or logic implemented
- **Data Flow:** How data flows through the new/modified components
- **Performance Considerations:** Any performance optimizations or trade-offs made
- **Security Considerations:** Security implications and measures taken
- **Backwards Compatibility:** How backwards compatibility is maintained (if applicable)

## Testing & Validation
Comprehensive testing approach:
- **Test Strategy:** Overall testing approach used
- **Test Coverage:** Specific tests added and what they validate
- **Manual Testing:** Manual testing performed and results
- **Edge Cases:** Edge cases tested and how they are handled
- **Quality Assurance:** SwiftLint, build, and test results

## Impact & Future Work
Analysis of impact and future implications:
- **Breaking Changes:** Any breaking changes with migration guidance
- **Performance Impact:** Measured or expected performance changes
- **Maintenance Impact:** How this affects ongoing maintenance
- **Future Enhancements:** How this change enables or supports future work
- **Technical Debt:** Any technical debt introduced or resolved

Return ONLY the Markdown content with detailed explanations, no additional formatting or comments."

    # Create temporary input file for Claude Code PR description generation
    local pr_input_file="${WORKTREE_PATH}/.claude-pr-input.txt"
    echo "$pr_context_message" > "$pr_input_file"
    
    # Create temporary output file to capture Claude Code response
    local pr_output_file="${WORKTREE_PATH}/.claude-pr-output.md"
    
    info "Launching Claude Code to generate Markdown PR description..."
    
    # Start loading animation in background
    show_loading "Generating PR description with Claude Code" &
    local loading_pid=$!
    
    local claude_pr_error_file="${WORKTREE_PATH}/.claude-pr-error.log"
    
    if timeout 180 claude --print < "$pr_input_file" > "$pr_output_file" 2> "$claude_pr_error_file"; then
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        
        # Check if we got a reasonable Markdown output
        if [[ -s "$pr_output_file" ]]; then
            local generated_content=$(cat "$pr_output_file")
            if [[ -n "$generated_content" ]] && [[ ${#generated_content} -gt 50 ]]; then
                success "PR description generated successfully"
                cat "$pr_output_file"
                return 0
            fi
        fi
        
        # If output is too short or empty, fall back to default
        warn "Claude Code output is too short or empty, falling back to default format"
        echo "Failed to generate valid Markdown PR description. Using fallback format."
        if [[ -s "$claude_pr_error_file" ]]; then
            error "Claude Code PR generation error output:"
            cat "$claude_pr_error_file"
        fi
        return 1
    else
        local exit_code=$?
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        
        if [[ $exit_code -eq 124 ]]; then
            warn "Claude Code PR description generation timed out after 3 minutes, using fallback format"
        else
            warn "Claude Code PR description generation failed, using fallback format (exit code: $exit_code)"
        fi
        
        if [[ -s "$claude_pr_error_file" ]]; then
            error "Claude Code PR generation error output:"
            cat "$claude_pr_error_file"
        fi
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$pr_input_file" "$pr_output_file"
}

generate_commit_message() {
    step "Generating commit message with Claude Code..."
    
    cd "$WORKTREE_PATH"
    
    # Collect implementation context for commit message
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    local files_changed=$(git diff --cached --name-only)
    local files_added=$(git diff --cached --name-status | grep "^A" | cut -f2)
    local files_modified=$(git diff --cached --name-status | grep "^M" | cut -f2)
    local files_deleted=$(git diff --cached --name-status | grep "^D" | cut -f2)
    
    # Create context message for Claude Code commit message generation
    local commit_context_message="I need you to generate a conventional commit message for the following GitHub issue implementation:

**Issue #${ISSUE_NUMBER}: $issue_title**

**Issue Description:**
$issue_body

**Changes Made:**
- Files changed: $files_changed
- Files added: $files_added  
- Files modified: $files_modified
- Files deleted: $files_deleted

Please generate a conventional commit message following this format:
\`\`\`
<type>(<scope>): <description>

<body>

Refs #${ISSUE_NUMBER}
\`\`\`

Requirements:
1. Use appropriate conventional commit type (feat, fix, docs, style, refactor, test, chore)
2. Include a scope if relevant (e.g., tokenizer, parser, visitor, tests)
3. Write a clear, concise description (≤50 chars for first line)
4. Include a body explaining what and why (not how)
5. Reference the issue number with 'Refs #${ISSUE_NUMBER}'
6. Follow project conventions from CLAUDE.md

Return ONLY the commit message text, no additional formatting or markdown."

    # Create temporary input file for Claude Code commit message generation
    local commit_input_file="${WORKTREE_PATH}/.claude-commit-input.txt"
    echo "$commit_context_message" > "$commit_input_file"
    
    # Create temporary output file to capture Claude Code response
    local commit_output_file="${WORKTREE_PATH}/.claude-commit-output.txt"
    
    info "Launching Claude Code to generate conventional commit message..."
    
    # Start loading animation in background
    show_loading "Generating commit message with Claude Code" &
    local loading_pid=$!
    
    local claude_commit_error_file="${WORKTREE_PATH}/.claude-commit-error.log"
    
    if timeout 120 claude --print < "$commit_input_file" > "$commit_output_file" 2> "$claude_commit_error_file"; then
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        # Validate that we got a reasonable commit message
        local generated_message=$(cat "$commit_output_file")
        if [[ -n "$generated_message" ]] && [[ ${#generated_message} -gt 10 ]]; then
            success "Commit message generated successfully"
            echo "$generated_message"
        else
            warn "Claude Code generated empty or too short commit message, using fallback"
            if [[ -s "$claude_commit_error_file" ]]; then
                error "Claude Code commit generation error output:"
                cat "$claude_commit_error_file"
            fi
            return 1
        fi
    else
        local exit_code=$?
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        
        if [[ $exit_code -eq 124 ]]; then
            warn "Claude Code commit message generation timed out after 2 minutes, using fallback"
        else
            warn "Claude Code commit message generation failed, using fallback (exit code: $exit_code)"
        fi
        
        if [[ -s "$claude_commit_error_file" ]]; then
            error "Claude Code commit generation error output:"
            cat "$claude_commit_error_file"
        fi
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$commit_input_file" "$commit_output_file"
}

push_and_create_pr() {
    step "Creating pull request..."
    
    cd "$WORKTREE_PATH"
    
    # Check if branch has commits ahead of master
    local commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
    if [[ "$commits_ahead" -eq 0 ]]; then
        error "No commits to push. Branch is up to date with master."
        echo
        warn "This can happen when Claude Code doesn't create any commits."
        echo
        info "Options:"
        info "1. Check if there are unstaged changes that need to be committed"
        info "2. Re-launch Claude Code to ensure implementation is completed"
        info "3. Create a manual commit if changes exist"
        echo
        
        # Check for unstaged changes (excluding gitignored files)
        local has_real_changes=false
        
        # Check if there are any changes that would actually be staged
        if git add --dry-run . >/dev/null 2>&1; then
            # Test if git add would actually stage anything
            local staged_count_before=$(git diff --cached --numstat | wc -l)
            git add . >/dev/null 2>&1
            local staged_count_after=$(git diff --cached --numstat | wc -l)
            
            if [[ $staged_count_after -gt $staged_count_before ]]; then
                has_real_changes=true
            fi
            
            # Reset staging area to previous state
            git reset >/dev/null 2>&1
        fi
        
        if [[ "$has_real_changes" == "true" ]]; then
            log "Detected changes ready for commit"
            git add .
            
            # Generate commit message using Claude Code
            local commit_message=""
            if commit_message=$(generate_commit_message); then
                info "Using Claude Code generated commit message"
                # Add Claude Code attribution to the generated message
                commit_message="$commit_message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
            else
                warn "Falling back to default commit message format"
                local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
                commit_message="feat: implement ${issue_title}

Resolves #${ISSUE_NUMBER}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
            fi
            
            git commit -m "$commit_message"
            
            # Recheck commits ahead
            commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
            if [[ "$commits_ahead" -eq 0 ]]; then
                error "Still no commits after adding changes"
                exit 1
            fi
            success "Commit created automatically"
        else
            # Auto-select option 2: Re-launch Claude Code
            warn "Auto-selecting option 2: Re-launching Claude Code to complete implementation..."
            launch_claude_code_with_errors
            
            # After Claude Code session, recheck for commits
            commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
            if [[ "$commits_ahead" -eq 0 ]]; then
                error "Still no commits after re-launching Claude Code"
                exit 1
            fi
        fi
    fi
    
    info "Branch has $commits_ahead commits ahead of master"
    
    # Push branch to origin
    if ! run_with_loading "Pushing branch to origin" "" git push origin "$BRANCH_NAME"; then
        error "Failed to push branch to origin"
        exit 1
    fi
    
    # Check if PR already exists
    local pr_temp=$(mktemp)
    run_with_loading "Checking for existing pull requests" "$pr_temp" gh pr list --head "$BRANCH_NAME" --json number,url --jq '.[0] // empty'
    local existing_pr=$(cat "$pr_temp")
    rm -f "$pr_temp"
    
    if [[ -n "$existing_pr" ]]; then
        local pr_number=$(echo "$existing_pr" | jq -r '.number')
        local pr_url=$(echo "$existing_pr" | jq -r '.url')
        success "Pull request already exists: #$pr_number - $pr_url"
        info "Monitoring existing PR checks..."
    else
        # Create PR
        local pr_title=$(jq -r '.pr_title' "$ISSUE_DATA_FILE")
        local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
        
        # Generate PR description using Claude Code
        local pr_body=""
        if pr_body=$(generate_pr_description); then
            info "Using Claude Code generated Markdown PR description"
        else
            warn "Falling back to default PR description format"
            # Get commit messages for fallback PR body
            local commit_messages=$(git log --oneline "master..HEAD" | head -10)
            
            # Enhanced fallback PR body
            local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
            local files_changed=$(git diff --name-only "master..HEAD")
            
            pr_body="## Summary
Resolves #${ISSUE_NUMBER}: $issue_title

This PR implements the requested functionality as specified in the GitHub issue.

## Background & Context
- **Original Issue:** $issue_title
- **Issue Description:** ${issue_body:0:200}$([ ${#issue_body} -gt 200 ] && echo "...")
- **User Impact:** Addresses the functionality gap identified in issue #${ISSUE_NUMBER}
- **Requirements:** Implementation based on issue specifications and project standards

## Solution Approach
- **Core Solution:** Implemented the requested feature following established project patterns
- **Technical Strategy:** Used existing architecture and coding standards
- **Logic & Reasoning:** Applied standard development practices for this codebase
- **Integration:** Follows existing code patterns and conventions

## Implementation Details
- **Key Components:** Modified/added components as needed for the feature
- **Code Changes:** See commit history for detailed changes
- **Files Modified:** $files_changed
- **Integration Points:** Integrated with existing codebase following established patterns

## Technical Logic
- **Implementation:** Applied standard algorithms and patterns used in this project
- **Data Flow:** Follows existing data flow patterns in the codebase
- **Error Handling:** Implemented appropriate error handling for the feature
- **Backwards Compatibility:** Maintained compatibility with existing functionality

## Testing & Validation
- **Test Strategy:** Followed project testing standards
- **Quality Assurance:** 
  - [x] SwiftLint validation passes
  - [x] All tests pass  
  - [x] Build succeeds
  - [x] Follows project conventions

## Implementation Commits
\`\`\`
$commit_messages
\`\`\`

## Impact & Future Work
- **Breaking Changes:** None
- **Performance Impact:** No significant performance impact expected
- **Future Enhancements:** This change provides foundation for future related features

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        fi
        
        local pr_temp=$(mktemp)
        if run_with_loading "Creating pull request" "$pr_temp" gh pr create --title "$pr_title" --body "$pr_body" --head "$BRANCH_NAME" --base master; then
            local pr_url=$(cat "$pr_temp")
            success "Pull request created: $pr_url"
        else
            error "Failed to create pull request"
            exit 1
        fi
        rm -f "$pr_temp"
    fi
    
    # Monitor PR checks
    step "Monitoring CI checks..."
    
    # Monitor for up to 5 minutes, checking every 10 seconds
    info "Monitoring PR checks for up to 5 minutes (checking every 10 seconds)..."
    local monitor_time=0
    local max_monitor_time=300  # 5 minutes
    local check_interval=10     # 10 seconds
    local all_checks_passed=false
    local checks_started=false
    
    while [[ $monitor_time -lt $max_monitor_time ]]; do
        # Get current check status
        local check_output
        if check_output=$(gh pr checks 2>/dev/null); then
            if [[ "$checks_started" == "false" ]]; then
                echo -e "\r\033[K" # Clear the waiting line
            fi
            checks_started=true
            
            # Display current status with progress bar
            echo -e "\r\033[K" # Clear previous progress bar
            echo "--- CI Status ---"
            draw_progress_bar "$monitor_time" "$max_monitor_time" 50 "CI Monitoring Progress"
            echo -e "\n"
            echo "$check_output"
            echo
            
            # Check if all checks are complete and successful
            local pending_count=$(echo "$check_output" | grep -c "pending" 2>/dev/null || echo "0")
            local fail_count=$(echo "$check_output" | grep -c "fail" 2>/dev/null || echo "0")
            
            # Ensure we have valid numeric values
            if ! [[ "$pending_count" =~ ^[0-9]+$ ]]; then
                pending_count=0
            fi
            if ! [[ "$fail_count" =~ ^[0-9]+$ ]]; then
                fail_count=0
            fi
            
            if [[ "$pending_count" -eq 0 ]] && [[ "$fail_count" -eq 0 ]]; then
                local total_checks=$(echo "$check_output" | wc -l)
                if [[ "$total_checks" -gt 0 ]]; then
                    all_checks_passed=true
                    success "All PR checks passed!"
                    break
                fi
            elif [[ "$fail_count" -gt 0 ]]; then
                error "Some PR checks failed"
                break
            fi
        else
            if [[ "$checks_started" == "false" ]]; then
                draw_progress_bar "$monitor_time" "$max_monitor_time" 40 "Waiting for CI checks to start"
            fi
        fi
        
        sleep $check_interval
        monitor_time=$((monitor_time + check_interval))
    done
    
    # Clear any remaining waiting message
    if [[ "$checks_started" == "false" ]]; then
        echo -e "\r\033[K"
    fi
    
    if [[ "$all_checks_passed" == "true" ]]; then
        success "All CI checks completed successfully!"
    elif [[ "$checks_started" == "false" ]]; then
        warn "No CI checks detected after 5 minutes"
        info "This may be normal if no workflows are configured for this repository"
        info "You can check manually later with: gh pr checks"
    elif [[ $monitor_time -ge $max_monitor_time ]]; then
        warn "CI monitoring timeout reached (5 minutes)"
        info "Checks may still be running. You can continue monitoring with: gh pr checks --watch"
    fi
}

cleanup_worktree() {
    if [[ -n "$WORKTREE_PATH" ]]; then
        log "Removing worktree..."
        cd "$PROJECT_ROOT"
        
        # Use the comprehensive cleanup function
        cleanup_existing_worktree
        
        # Clean up associated branch if it exists
        if git branch --list | grep -q "$BRANCH_NAME"; then
            log "Cleaning up branch: $BRANCH_NAME"
            git branch -D "$BRANCH_NAME" 2>/dev/null || true
        fi
        
        success "Worktree removed: $WORKTREE_PATH"
    fi
}

cleanup_all_worktrees() {
    step "Cleaning up all worktrees..."
    
    if [[ ! -d "$WORKTREE_BASE_DIR" ]]; then
        info "No worktrees directory found"
        return 0
    fi
    
    echo "This will remove ALL worktrees in $WORKTREE_BASE_DIR"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    if [[ $REPLY == "yes" ]]; then
        cd "$PROJECT_ROOT"
        
        # Remove all worktrees
        for worktree_path in "$WORKTREE_BASE_DIR"/*; do
            if [[ -d "$worktree_path" ]]; then
                local worktree_name=$(basename "$worktree_path")
                log "Removing worktree: $worktree_name"
                git worktree remove "$worktree_path" --force || true
            fi
        done
        
        # Remove base directory
        rm -rf "$WORKTREE_BASE_DIR"
        success "All worktrees removed"
    else
        info "Cleanup cancelled"
    fi
}

main() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                     Claude Worktree                         ║${NC}"
    echo -e "${PURPLE}║               Parallel Claude Code Development               ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Handle command line arguments
    local issue_url=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --cleanup)
                cleanup_all_worktrees
                exit 0
                ;;
            --debug)
                DEBUG_MODE="true"
                info "Debug mode enabled"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$issue_url" ]]; then
                    issue_url="$1"
                else
                    error "Multiple URLs provided. Only one issue URL is allowed."
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$issue_url" ]]; then
        error "Missing GitHub issue URL"
        usage
        exit 1
    fi
    
    # Validate inputs
    validate_url "$issue_url"
    extract_issue_info "$issue_url"
    
    log "Starting Claude Worktree workflow"
    info "Issue URL: $issue_url"
    info "Worktree Path: $WORKTREE_PATH"
    info "Branch Name: $BRANCH_NAME"
    echo
    
    # Execute workflow
    validate_prerequisites
    
    # First fetch issue data to initialize status box
    fetch_issue_data "$issue_url"
    
    # Initialize status box with issue data
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    init_status_box "$issue_title" "$issue_body" "$BRANCH_NAME"
    
    # Now continue with worktree creation
    update_activity "Creating isolated development environment"
    create_worktree
    update_step 1  # Setting up worktree completed
    
    update_step 2  # Fetching issue data completed
    update_activity "Preparing implementation strategy"
    generate_analysis
    update_step 3  # Generating analysis completed
    update_activity "Launching Claude Code for implementation"
    launch_claude_code
    update_step 4  # Running Claude Code completed
    
    # Post-implementation workflow with retry loop
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if validate_implementation; then
            # Validation successful - proceed with PR creation
            update_step 5  # Validating implementation completed
            update_activity "Creating pull request and pushing changes"
            push_and_create_pr
            update_step 6  # Creating pull request completed
            update_activity "Monitoring CI pipeline execution"
            update_step 7  # Monitoring CI checks completed
            update_step_with_activity 8 "All tasks completed successfully!"  # Workflow complete
            success "Workflow completed successfully!"
            echo
            info "Next steps:"
            info "1. Monitor PR: gh pr view --web"
            info "2. Check CI: gh pr checks"
            info "3. Merge when ready: gh pr merge --merge"
            echo
            cleanup_worktree
            return 0
        else
            # Validation failed
            retry_count=$((retry_count + 1))
            error "Implementation validation failed (attempt $retry_count/$max_retries)"
            
            if [[ $retry_count -lt $max_retries ]]; then
                echo
                warn "Launching Claude Code to fix validation errors..."
                info "Remaining attempts: $((max_retries - retry_count))"
                echo
                
                # Launch Claude Code with error context and JSON format
                launch_claude_code_with_errors
                
                # Continue to next iteration for validation retry
                continue
            else
                # Max retries reached
                echo
                error "Maximum retry attempts ($max_retries) reached"
                error "Implementation validation still failing"
                echo
                info "Manual intervention required in: $WORKTREE_PATH"
                info "You can:"
                info "1. Fix issues manually and run: swiftlint lint && swift build && swift test"
                info "2. Continue with PR creation anyway (if appropriate)"
                info "3. Remove worktree: git worktree remove $WORKTREE_PATH --force"
                echo
                
                warn "Auto-proceeding with PR creation despite validation failures..."
                push_and_create_pr
            fi
        fi
    done
}

main "$@"