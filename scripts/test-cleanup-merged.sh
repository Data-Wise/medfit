#!/bin/sh
# Exercise cleanup-merged.sh in a disposable repo with a fake gh. A planted branch with a commit after the PR head
# must not be offered for deletion, and the script must delete nothing itself.
set -eu
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(CDPATH='' cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

cd "$tmp"
git init -q -b dev repo && cd repo
git config user.email t@example.org && git config user.name t
git commit -q --allow-empty -m base
git branch merged-ok
git branch merged-moved
git branch unmerged
git checkout -q merged-moved && git commit -q --allow-empty -m later
ok_tip=$(git rev-parse merged-ok)
old_tip=$(git rev-parse dev)
git checkout -q dev
git worktree add -q "$tmp/wt-ok" merged-ok

mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<GH
#!/bin/sh
case "\$*" in
  *"--head merged-ok "*) echo "11 $ok_tip" ;;
  *"--head merged-moved "*) echo "12 $old_tip" ;;
esac
GH
chmod +x "$tmp/bin/gh"

out=$(PATH="$tmp/bin:$PATH" sh "$scripts/cleanup-merged.sh")
printf '%s\n' "$out" | grep -q 'branch -D merged-ok' || fail 'merged-ok was not offered'
printf '%s\n' "$out" | grep -q "worktree remove $tmp/wt-ok" || fail 'worktree line missing'
if printf '%s\n' "$out" | grep -q 'branch -D merged-moved'; then fail 'moved branch was offered'; fi
if printf '%s\n' "$out" | grep -q 'branch -D unmerged'; then fail 'unmerged branch was offered'; fi
printf '%s\n' "$out" | grep -q 'merged-moved (tip' || fail 'moved branch not reported'
git rev-parse --verify -q merged-ok >/dev/null || fail 'script deleted a branch'
printf 'cleanup-merged: all checks passed\n'
