#!/bin/bash

# Setup Claude Code permissions for a worktree directory
# Usage: ./setup-claude-permissions.sh /path/to/worktree

set -e

WORKTREE_DIR="$1"
if [ -z "$WORKTREE_DIR" ]; then
    echo "Usage: $0 /path/to/worktree"
    exit 1
fi

if [ ! -d "$WORKTREE_DIR" ]; then
    echo "Error: Directory $WORKTREE_DIR does not exist"
    exit 1
fi

CLAUDE_DIR="$WORKTREE_DIR/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.local.json"
TEMPLATE_FILE="$(dirname "$0")/.claude-settings-template.json"

# Create .claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Copy template if it exists, otherwise create default permissive settings
if [ -f "$TEMPLATE_FILE" ]; then
    cp "$TEMPLATE_FILE" "$SETTINGS_FILE"
    echo "✅ Applied Claude Code permissions template to $SETTINGS_FILE"
else
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "WebFetch(domain:github.com)"
    ],
    "deny": []
  },
  "enableAllProjectMcpServers": false
}
EOF
    echo "✅ Created default permissive Claude Code settings at $SETTINGS_FILE"
fi

echo "🎉 Claude Code will now be able to execute any command without confirmation in this worktree!"