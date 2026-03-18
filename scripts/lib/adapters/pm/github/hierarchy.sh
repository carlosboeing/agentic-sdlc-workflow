#!/usr/bin/env bash
# hierarchy.sh — GitHub adapter: parent-child issue linking.
#
# Functions:
#   pm_link_child <parent-issue-number> <child-issue-number>
#     Establishes a sub-issue relationship via the addSubIssue GraphQL mutation.
#     Both arguments are GitHub issue numbers; node IDs are fetched internally.
#     Requires CFG_REPO (e.g., "owner/repo") to be set.

pm_link_child() {
  local parent_num="$1"
  local child_num="$2"

  local parent_id
  parent_id=$(gh issue view "$parent_num" --repo "$CFG_REPO" --json id -q '.id // empty' 2>/dev/null)
  if [ -z "$parent_id" ]; then
    echo "ERROR: Could not fetch node ID for issue #$parent_num" >&2
    return 1
  fi

  local child_id
  child_id=$(gh issue view "$child_num" --repo "$CFG_REPO" --json id -q '.id // empty' 2>/dev/null)
  if [ -z "$child_id" ]; then
    echo "ERROR: Could not fetch node ID for issue #$child_num" >&2
    return 1
  fi

  if ! gh api graphql -f query="mutation {
    addSubIssue(input: { issueId: \"$parent_id\", subIssueId: \"$child_id\" }) {
      subIssue { id }
    }
  }" > /dev/null; then
    echo "ERROR: GraphQL addSubIssue mutation failed for #$child_num → #$parent_num" >&2
    return 1
  fi

  echo "Linked #$child_num as sub-issue of #$parent_num"
}
