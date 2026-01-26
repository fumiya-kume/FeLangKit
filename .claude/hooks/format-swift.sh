#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

case "$FILE_PATH" in
    *.swift) ;;
    *) exit 0 ;;
esac

if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

if ! command -v swiftlint &>/dev/null; then
    exit 0
fi

swiftlint lint --fix --quiet --path "$FILE_PATH" &>/dev/null &
disown

exit 0
