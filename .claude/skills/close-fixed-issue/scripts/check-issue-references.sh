#!/usr/bin/env bash
# check-issue-references.sh
#
# Query GitHub GraphQL API to find merged PRs that reference open issues.
#
# Usage:
#   bash check-issue-references.sh OWNER REPO ISSUE_NUMBER [ISSUE_NUMBER...]
#
# Output:
#   JSON lines, one per issue, with referenced PR number, title, and state.
#
# Requirements:
#   - gh CLI authenticated
#   - jq installed

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 OWNER REPO ISSUE_NUMBER [ISSUE_NUMBER...]" >&2
  exit 1
fi

OWNER="$1"
REPO="$2"
shift 2

# Validate that all ISSUE_NUMBER arguments are positive integers
for ISSUE_ARG in "$@"; do
  if ! [[ "$ISSUE_ARG" =~ ^[0-9]+$ ]] || [ "$ISSUE_ARG" -le 0 ]; then
    echo "Error: ISSUE_NUMBER must be a positive integer: '$ISSUE_ARG'" >&2
    exit 1
  fi
done

for ISSUE_NUM in "$@"; do
  # Use GraphQL variables via -F flag to prevent injection
  RESULT=$(gh api graphql \
    -F owner="$OWNER" \
    -F repo="$REPO" \
    -F issueNum:="$ISSUE_NUM" \
    -f query='
    query($owner: String!, $repo: String!, $issueNum: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $issueNum) {
          number
          title
          timelineItems(itemTypes: [CROSS_REFERENCED_EVENT, CLOSED_EVENT], first: 100) {
            nodes {
              ... on CrossReferencedEvent {
                source {
                  ... on PullRequest {
                    number
                    title
                    state
                    merged
                    mergedAt
                  }
                }
              }
              ... on ClosedEvent {
                closer {
                  ... on PullRequest {
                    number
                    title
                    merged
                  }
                }
              }
            }
          }
        }
      }
    }
  ')

  if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    echo "Error: Failed to fetch data for issue #$ISSUE_NUM" >&2
    continue
  fi

  # Extract merged PRs referencing this issue with null checking
  echo "$RESULT" | jq -c --arg issue_num "$ISSUE_NUM" '
    if .data.repository.issue == null then
      {
        issue: ($issue_num | tonumber),
        title: null,
        error: "Issue not found",
        referenced_prs: []
      }
    else
      {
        issue: .data.repository.issue.number,
        title: .data.repository.issue.title,
        referenced_prs: (
          (.data.repository.issue.timelineItems.nodes // [])
          | map(
              if .source?.number then
                { number: .source.number, title: .source.title, state: .source.state, merged: .source.merged }
              elif .closer?.number then
                { number: .closer.number, title: .closer.title, merged: .closer.merged, state: "CLOSED_BY" }
              else empty end
            )
        )
      }
    end
  '
done
