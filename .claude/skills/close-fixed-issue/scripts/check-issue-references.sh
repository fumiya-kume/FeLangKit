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

for ISSUE_NUM in "$@"; do
  RESULT=$(gh api graphql -f query='
    {
      repository(owner: "'"$OWNER"'", name: "'"$REPO"'") {
        issue(number: '"$ISSUE_NUM"') {
          number
          title
          timelineItems(itemTypes: [CROSS_REFERENCED_EVENT, CLOSED_EVENT, REFERENCED_EVENT], first: 20) {
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
  ' 2>/dev/null)

  # Extract merged PRs referencing this issue
  echo "$RESULT" | jq -c '{
    issue: .data.repository.issue.number,
    title: .data.repository.issue.title,
    referenced_prs: [
      .data.repository.issue.timelineItems.nodes[]
      | if .source?.number then
          { number: .source.number, title: .source.title, state: .source.state, merged: .source.merged }
        elif .closer?.number then
          { number: .closer.number, title: .closer.title, merged: .closer.merged, state: "CLOSED_BY" }
        else empty end
    ]
  }'
done
