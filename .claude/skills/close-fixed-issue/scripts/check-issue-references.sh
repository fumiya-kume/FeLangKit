#!/usr/bin/env bash
# check-issue-references.sh
#
# Query GitHub GraphQL API to find merged PRs that reference open issues.
#
# Usage:
#   bash check-issue-references.sh OWNER REPO ISSUE_NUMBER [ISSUE_NUMBER...]
#
# Output:
#   JSON lines, one per issue, with structure:
#     {
#       "issue": <issue number>,
#       "title": <issue title or null>,
#       "error": <error message if issue not found, otherwise omitted>,
#       "referenced_prs": [
#         {
#           "number": <PR number>,
#           "title": <PR title>,
#           "state": <PR state: "MERGED" or "CLOSED">,
#           "merged": true
#         },
#         ...
#       ]
#     }
#
# Limitations:
#   - Only returns the first 100 timeline items per issue. Issues with more
#     cross-references may have some PRs missing from results.
#
# Requirements:
#   - gh CLI authenticated
#   - jq installed

set -uo pipefail

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
  # Use || true to allow error handling despite set -u
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
  ' 2>&1) || true

  if [ -z "$RESULT" ]; then
    echo "Error: Failed to fetch data for issue #$ISSUE_NUM" >&2
    continue
  fi

  # Check if result contains GraphQL errors
  if echo "$RESULT" | jq -e '.errors' > /dev/null 2>&1; then
    echo "Error: GraphQL error for issue #$ISSUE_NUM: $(echo "$RESULT" | jq -r '.errors[0].message // "Unknown error"')" >&2
    continue
  fi

  # Extract merged PRs referencing this issue with null checking
  # Only include PRs that are actually merged
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
              if .source != null and .source.number != null then
                { number: .source.number, title: .source.title, state: .source.state, merged: .source.merged }
              elif .closer != null and .closer.number != null then
                { number: .closer.number, title: .closer.title, merged: .closer.merged, state: (if .closer.merged == true then "MERGED" else "CLOSED" end) }
              else empty end
            )
          | map(select(.merged == true))
        )
      }
    end
  '
done
