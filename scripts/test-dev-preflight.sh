#!/bin/sh
# Exercise dev-preflight.sh in a disposable clone: an up-to-date dev reports no STALE line, a dev behind origin/dev
# reports STALE with the right count, and the script moves no branch.
set -eu
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(CDPATH='' cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

git init -q --bare -b dev "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
git config user.email t@example.org && git config user.name t
git checkout -q -b dev
git commit -q --allow-empty -m one
git push -q origin dev

git clone -q "$tmp/origin.git" "$tmp/user" 2>/dev/null
cd "$tmp/user"
out=$(sh "$scripts/dev-preflight.sh")
if printf '%s\n' "$out" | grep -q 'STALE'; then fail 'up-to-date dev reported STALE'; fi

cd "$tmp/work"
git commit -q --allow-empty -m two
git commit -q --allow-empty -m three
git push -q origin dev

cd "$tmp/user"
before=$(git rev-parse dev)
out=$(sh "$scripts/dev-preflight.sh")
printf '%s\n' "$out" | grep -q 'STALE: local dev is 2 commit' || fail 'stale dev not reported with count 2'
[ "$(git rev-parse dev)" = "$before" ] || fail 'script moved the local dev branch'
printf 'dev-preflight: all checks passed\n'
