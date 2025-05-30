# Claude.sh Header Enhancement Design

## Overview
This document outlines the comprehensive enhancement plan for the claude.sh dynamic header system, focusing on improved visual design, performance optimization, and enhanced user experience.

## Current State Analysis

### Existing Features
- Dynamic header with Unicode box drawing characters
- Real-time updates (every 1 second)
- Workflow progress tracking with emoji status indicators
- Terminal width adaptation
- Scroll region management
- Basic color support (limited to borders)

### Current Limitations
- **Performance**: Full header redraw every second causes flicker
- **Visual Design**: Limited color usage, fixed layout structure
- **Terminal Compatibility**: No capability detection or graceful degradation
- **Customization**: No configuration options for themes or layout
- **Responsiveness**: Basic terminal width support without smart content adaptation
- **Text Handling**: Simple truncation without intelligent word wrapping

## Enhanced Architecture Design

### 1. Terminal Capability Detection System

```bash
# Terminal capability detection
detect_terminal_capabilities() {
    local capabilities=()
    
    # Color support detection
    local colors=$(tput colors 2>/dev/null || echo "0")
    if [[ $colors -ge 256 ]]; then
        capabilities+=("256color")
    elif [[ $colors -ge 8 ]]; then
        capabilities+=("8color")
    fi
    
    # Unicode support detection
    if [[ "$LANG" =~ UTF-8 ]] && [[ "$TERM" != "dumb" ]]; then
        capabilities+=("unicode")
    fi
    
    # Advanced terminal features
    if [[ -n "$(tput cup 2>/dev/null)" ]]; then
        capabilities+=("cursor_positioning")
    fi
    
    if [[ -n "$(tput csr 2>/dev/null)" ]]; then
        capabilities+=("scroll_region")
    fi
    
    echo "${capabilities[@]}"
}
```

### 2. Enhanced Color Scheme System

```bash
# Color scheme definitions
declare -A THEME_COLORS
declare -A THEME_STYLES

# Default theme
THEME_COLORS[primary]="${BLUE}"
THEME_COLORS[success]="${GREEN}"
THEME_COLORS[warning]="${YELLOW}"
THEME_COLORS[error]="${RED}"
THEME_COLORS[info]="${CYAN}"
THEME_COLORS[accent]="${PURPLE}"
THEME_COLORS[muted]="${NC}"

# Dark theme
THEME_COLORS_DARK[primary]="\033[38;5;39m"   # Bright blue
THEME_COLORS_DARK[success]="\033[38;5;46m"   # Bright green
THEME_COLORS_DARK[warning]="\033[38;5;226m"  # Bright yellow
THEME_COLORS_DARK[error]="\033[38;5;196m"    # Bright red
THEME_COLORS_DARK[info]="\033[38;5;51m"      # Bright cyan
THEME_COLORS_DARK[accent]="\033[38;5;129m"   # Bright purple

# Style definitions
THEME_STYLES[bold]="\033[1m"
THEME_STYLES[dim]="\033[2m"
THEME_STYLES[italic]="\033[3m"
THEME_STYLES[underline]="\033[4m"
```

### 3. Performance Optimization - Differential Updates

```bash
# Header state tracking for differential updates
declare -A HEADER_STATE
declare -A HEADER_CACHE

# Only update changed sections
update_header_section() {
    local section="$1"
    local new_content="$2"
    local line_number="$3"
    
    # Check if content changed
    if [[ "${HEADER_CACHE[$section]}" != "$new_content" ]]; then
        HEADER_CACHE[$section]="$new_content"
        
        # Update only this line
        tput cup $line_number 0
        printf "%s" "$new_content"
        tput el  # Clear rest of line
    fi
}

# Smart redraw with change detection
smart_header_update() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local elapsed_time=""
    
    # Calculate elapsed time
    if [[ -n "$START_TIME" ]]; then
        local current_timestamp=$(date +%s)
        local elapsed=$((current_timestamp - START_TIME))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        elapsed_time=$(printf "⏱️  %02d:%02d" "$minutes" "$seconds")
    fi
    
    # Update time section (most frequently changing)
    local time_text="📅 Started: $(date -r ${START_TIME:-$(date +%s)} '+%Y-%m-%d %H:%M:%S') | Current: $current_time"
    if [[ -n "$elapsed_time" ]]; then
        time_text="$time_text | $elapsed_time"
    fi
    
    update_header_section "time" "$time_text" 2
    
    # Update progress section if changed
    if [[ "${HEADER_STATE[current_step]}" != "$CURRENT_STEP" ]]; then
        HEADER_STATE[current_step]="$CURRENT_STEP"
        redraw_progress_section
    fi
    
    # Update activity section if changed
    if [[ "${HEADER_STATE[current_activity]}" != "$CURRENT_ACTIVITY" ]]; then
        HEADER_STATE[current_activity]="$CURRENT_ACTIVITY"
        update_activity_section
    fi
}
```

### 4. Enhanced Visual Elements

```bash
# Advanced progress indicators with visual enhancements
draw_enhanced_progress_bar() {
    local current="$1"
    local total="$2"
    local width="$3"
    local label="$4"
    local color_scheme="${5:-default}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local remaining=$((width - filled))
    
    # Enhanced progress bar characters
    local progress_chars=("▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")
    local empty_char="░"
    local filled_char="█"
    
    # Color selection based on progress
    local progress_color
    if [[ $percentage -lt 25 ]]; then
        progress_color="${THEME_COLORS[error]}"
    elif [[ $percentage -lt 50 ]]; then
        progress_color="${THEME_COLORS[warning]}"
    elif [[ $percentage -lt 75 ]]; then
        progress_color="${THEME_COLORS[info]}"
    else
        progress_color="${THEME_COLORS[success]}"
    fi
    
    # Build progress bar with gradient effect
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${progress_color}${filled_char}${NC}"
    done
    
    for ((i=0; i<remaining; i++)); do
        bar+="${empty_char}"
    done
    
    # Enhanced formatting with percentage and ETA
    printf "${THEME_COLORS[info]}[%s]${NC} %s: [%s] ${THEME_STYLES[bold]}%3d%%${NC}\n" \
           "$(get_status_icon)" "$label" "$bar" "$percentage"
}

# Status icons with better visual hierarchy
get_status_icon() {
    case $1 in
        "pending") echo "⏳" ;;
        "in_progress") echo "🔄" ;;
        "completed") echo "✅" ;;
        "error") echo "❌" ;;
        "warning") echo "⚠️" ;;
        *) echo "🔵" ;;
    esac
}
```

### 5. Responsive Layout System

```bash
# Responsive header layout based on terminal size
calculate_responsive_layout() {
    local terminal_width=$(tput cols)
    local terminal_height=$(tput lines)
    
    # Layout configurations for different screen sizes
    if [[ $terminal_width -lt 80 ]]; then
        # Compact layout for small terminals
        HEADER_LAYOUT="compact"
        MAX_TEXT_WIDTH=40
        SHOW_EXTENDED_INFO=false
    elif [[ $terminal_width -lt 120 ]]; then
        # Standard layout
        HEADER_LAYOUT="standard"
        MAX_TEXT_WIDTH=60
        SHOW_EXTENDED_INFO=true
    else
        # Extended layout for wide terminals
        HEADER_LAYOUT="extended"
        MAX_TEXT_WIDTH=80
        SHOW_EXTENDED_INFO=true
        SHOW_SYSTEM_METRICS=true
    fi
    
    # Adjust workflow display based on height
    if [[ $terminal_height -lt 20 ]]; then
        WORKFLOW_DISPLAY="minimal"
    else
        WORKFLOW_DISPLAY="full"
    fi
}

# Smart text wrapping and truncation
smart_text_wrap() {
    local text="$1"
    local max_width="$2"
    local prefix="$3"
    
    if [[ ${#text} -le $max_width ]]; then
        echo "$text"
        return
    fi
    
    # Smart truncation at word boundaries
    local truncated=$(echo "$text" | cut -c1-$((max_width-3)))
    local last_space=$(echo "$truncated" | grep -o '.*[[:space:]]' | wc -c)
    
    if [[ $last_space -gt $((max_width / 2)) ]]; then
        truncated=$(echo "$text" | cut -c1-$((last_space-1)))
    fi
    
    echo "${truncated}..."
}
```

### 6. Theme Configuration System

```bash
# Configuration management
declare -A HEADER_CONFIG

# Default configuration
init_header_config() {
    HEADER_CONFIG[theme]="${HEADER_THEME:-default}"
    HEADER_CONFIG[update_interval]="${HEADER_UPDATE_INTERVAL:-1}"
    HEADER_CONFIG[show_system_metrics]="${HEADER_SHOW_METRICS:-false}"
    HEADER_CONFIG[animation_enabled]="${HEADER_ANIMATIONS:-true}"
    HEADER_CONFIG[color_mode]="${HEADER_COLOR_MODE:-auto}"
    HEADER_CONFIG[border_style]="${HEADER_BORDER_STYLE:-double}"
}

# Theme loading
load_theme() {
    local theme_name="$1"
    
    case "$theme_name" in
        "minimal")
            load_minimal_theme
            ;;
        "modern")
            load_modern_theme
            ;;
        "compact")
            load_compact_theme
            ;;
        *)
            load_default_theme
            ;;
    esac
}

# Border style variations
get_border_chars() {
    local style="${1:-double}"
    
    case "$style" in
        "single")
            echo "┌─┐│└─┘"
            ;;
        "double")
            echo "╔═╗║╚═╝"
            ;;
        "rounded")
            echo "╭─╮│╰─╯"
            ;;
        "thick")
            echo "┏━┓┃┗━┛"
            ;;
        *)
            echo "╔═╗║╚═╝"
            ;;
    esac
}
```

### 7. System Metrics Integration

```bash
# Real-time system metrics (optional feature)
get_system_metrics() {
    if [[ "${HEADER_CONFIG[show_system_metrics]}" != "true" ]]; then
        return
    fi
    
    local cpu_usage=""
    local memory_usage=""
    local network_status=""
    
    # CPU usage (macOS/Linux compatible)
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "N/A")
    fi
    
    # Memory usage
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS
        local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local pages_total=$((pages_free * 4096 / 1024 / 1024))
        memory_usage="${pages_total}MB free"
    elif command -v free >/dev/null 2>&1; then
        # Linux
        memory_usage=$(free -h | awk 'NR==2{printf "%.1f%%\n", $3*100/$2}')
    fi
    
    # Network connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        network_status="🌐 Online"
    else
        network_status="🔴 Offline"
    fi
    
    echo "💻 CPU: ${cpu_usage}% | 🧠 Memory: ${memory_usage} | ${network_status}"
}
```

### 8. Error Handling and Graceful Degradation

```bash
# Graceful fallback for unsupported terminals
safe_header_operation() {
    local operation="$1"
    shift
    
    # Check terminal capabilities
    if [[ "$TERM" == "dumb" ]] || [[ -z "$TERM" ]]; then
        # Fallback to simple text output
        fallback_header_display "$@"
        return
    fi
    
    # Try operation with error handling
    if ! "$operation" "$@" 2>/dev/null; then
        warn "Header operation failed, falling back to basic display"
        fallback_header_display "$@"
    fi
}

# Minimal fallback header
fallback_header_display() {
    echo "=== FeLangKit Claude Worktree ==="
    echo "Issue: ${ISSUE_TITLE:-'Loading...'}"
    echo "Branch: ${BRANCH_NAME:-'N/A'}"
    echo "Step: $((CURRENT_STEP + 1))/${#WORKFLOW_STEPS[@]} - ${WORKFLOW_STEPS[CURRENT_STEP]:-'N/A'}"
    echo "Activity: ${CURRENT_ACTIVITY:-'N/A'}"
    echo "================================="
}
```

## Implementation Strategy

### Phase 1: Core Infrastructure (High Priority)
1. Implement terminal capability detection
2. Create the differential update system
3. Add enhanced color scheme support
4. Implement responsive layout system

### Phase 2: Visual Enhancements (Medium Priority)
1. Enhanced progress indicators and animations
2. Theme system with multiple built-in themes
3. Smart text wrapping and truncation
4. Improved visual hierarchy and typography

### Phase 3: Advanced Features (Low Priority)
1. System metrics integration
2. Configuration management system
3. Performance monitoring and optimization
4. Accessibility improvements

### Phase 4: Testing and Validation (High Priority)
1. Cross-platform testing (macOS, Linux)
2. Terminal compatibility testing (various TERM types)
3. Performance benchmarking
4. User experience validation

## Configuration Options

```bash
# Environment variables for customization
export HEADER_THEME="modern"              # Theme selection
export HEADER_UPDATE_INTERVAL="0.5"       # Update frequency in seconds
export HEADER_SHOW_METRICS="true"         # Show system metrics
export HEADER_ANIMATIONS="true"           # Enable animations
export HEADER_COLOR_MODE="auto"           # auto|always|never
export HEADER_BORDER_STYLE="double"       # single|double|rounded|thick
export HEADER_LAYOUT="auto"               # auto|compact|standard|extended
```

## Expected Benefits

1. **Improved Performance**: 60-80% reduction in screen flicker through differential updates
2. **Better Visual Design**: Modern, professional appearance with enhanced color schemes
3. **Enhanced User Experience**: Responsive design that adapts to different terminal environments
4. **Greater Compatibility**: Graceful degradation for various terminal types
5. **Customization**: User-configurable themes and layout options
6. **Better Information Density**: Smart text handling and system metrics
7. **Professional Polish**: Animation effects and smooth transitions

## Testing Plan

1. **Unit Testing**: Individual function testing for header components
2. **Integration Testing**: Full header system testing in various scenarios
3. **Terminal Compatibility**: Testing across different terminal emulators
4. **Performance Testing**: Benchmarking update frequency and resource usage
5. **User Experience Testing**: Validation with different screen sizes and use cases

This enhanced header architecture will transform the claude.sh script into a modern, professional tool with improved usability and visual appeal while maintaining backward compatibility and robust error handling.