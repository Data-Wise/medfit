#!/bin/sh
# Session preflight (item A1 of planning/PLAN-speed-autonomy-2026-11-24.md): fetch, then say whether the local `dev`
# ref is behind origin/dev. A stale local dev made branch -d refuse squash-merged branches and gave a wrong .STATUS
# read, so new work branches from origin/dev. Read-only apart from `git fetch`; it never moves a branch or checks out.
# Usage: scripts/dev-preflight.sh   (run in any checkout or worktree of the repository)
set -eu

base=${PREFLIGHT_BASE:-dev}

git fetch -q origin 2>/dev/null || printf 'warning: git fetch origin failed; the counts below may be stale\n'

cur=$(git branch --show-current 2>/dev/null || true)
[ -n "$cur" ] || cur='(detached HEAD)'
printf 'branch:   %s\n' "$cur"

if ! git rev-parse --verify -q "origin/$base" >/dev/null; then
  printf 'origin/%s: not found; nothing to compare\n' "$base"
  exit 0
fi
printf 'origin/%s: %s\n' "$base" "$(git rev-parse --short "origin/$base")"

if git rev-parse --verify -q "$base" >/dev/null; then
  behind=$(git rev-list --count "$base..origin/$base")
  ahead=$(git rev-list --count "origin/$base..$base")
  printf 'local %s:  %s (behind %s, ahead %s)\n' "$base" "$(git rev-parse --short "$base")" "$behind" "$ahead"
  if [ "$behind" -gt 0 ]; then
    printf 'STALE: local %s is %s commit(s) behind origin/%s. Branch from origin/%s, not from local %s.\n' \
      "$base" "$behind" "$base" "$base" "$base"
  fi
  if [ "$ahead" -gt 0 ]; then
    printf 'NOTE: local %s has %s commit(s) not on origin/%s; check before using it as a base.\n' "$base" "$ahead" "$base"
  fi
else
  printf 'local %s: none; branch from origin/%s\n' "$base" "$base"
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  printf 'NOTE: the working tree has uncommitted changes.\n'
fi
printf 'worktrees: %s\n' "$(git worktree list | wc -l | tr -d ' ')"
