#!/bin/sh
# List local branches whose tip equals the head of a merged pull request, and print the commands that remove them.
# Read-only: nothing is deleted. The user runs the printed lines (the force delete of a branch stays the user's call).
# A squash merge leaves the branch looking unmerged to the safe delete, so the check is the one the repo rules use:
# the branch tip must equal the PR's headRefOid. A branch with later commits is reported and never offered.
# Usage: scripts/cleanup-merged.sh   (needs git and an authenticated gh; run inside the main checkout or a worktree)
set -eu

keep='main dev'
cur=$(git branch --show-current 2>/dev/null || true)

# worktree path per branch, from the porcelain listing
wt=$(git worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10) }
  /^branch refs\/heads\// { print substr($2, 12) "\t" path }')

safe=0; moved=0; none=0
report_unsafe=''
report_none=''
printf 'Branches whose tip equals a merged PR head (safe to force-delete):\n'
list=$(git for-each-ref --format='%(refname:short) %(objectname)' refs/heads)
while read -r b tip; do
  [ -n "$b" ] || continue
  case " $keep $cur " in *" $b "*) continue ;; esac
  prs=$(gh pr list --head "$b" --state merged --json number,headRefOid \
    --jq '.[] | "\(.number) \(.headRefOid)"' 2>/dev/null || true)
  if [ -z "$prs" ]; then
    none=$((none + 1)); report_none="$report_none  $b\n"; continue
  fi
  hit=$(printf '%s\n' "$prs" | awk -v t="$tip" '$2 == t { print $1; exit }')
  if [ -n "$hit" ]; then
    safe=$((safe + 1))
    path=$(printf '%s\n' "$wt" | awk -F'\t' -v b="$b" '$1 == b { print $2 }')
    printf '  #%s  %s\n' "$hit" "$b"
    if [ -n "$path" ]; then printf '    git worktree remove %s\n' "$path"; fi
    printf '    git branch -D %s\n' "$b"
  else
    moved=$((moved + 1)); report_unsafe="$report_unsafe  $b (tip $tip is not a merged PR head)\n"
  fi
done <<LIST
$list
LIST

[ "$safe" -gt 0 ] || printf '  none\n'
if [ "$moved" -gt 0 ]; then
  printf '\nBranches with a merged PR but later or different commits (not offered):\n'
  printf '%b' "$report_unsafe"
fi
if [ "$none" -gt 0 ]; then
  printf '\nBranches with no merged PR (not offered): %s\n' "$none"
  printf '%b' "$report_none"
fi
