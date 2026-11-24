#!/bin/sh
# Run the quick local package gate. Hosted R-CMD-check and coverage target main.
# Usage: scripts/check-local.sh [--tests-only | --full-tests]
# The default uses NOT_CRAN=false, then checks a tarball without rerunning tests
# or building vignettes. --full-tests runs only the NOT_CRAN=true source suite.
# Follow the run.log path printed at startup for progress.
# Exit status: 0 = pass (notes allowed), 1 = gate failure, 2 = setup or usage error.

set -u

mode=${1:-check}
case "$mode:$#" in
  check:0 | --tests-only:1 | --full-tests:1) ;;
  *) echo "Usage: $0 [--tests-only | --full-tests]" >&2; exit 2 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
root=$(CDPATH='' cd -- "$root" && pwd -P) || exit 2
pkg=$(sed -n 's/^Package: *//p' "$root/DESCRIPTION")
[ -n "$pkg" ] || { echo "check-local: no DESCRIPTION in $root" >&2; exit 2; }
scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2

tmp=$(CDPATH='' cd -- "${TMPDIR:-/tmp}" && pwd) || exit 2
run=$(mktemp -d "${tmp%/}/${pkg}-check-local.XXXXXX") || exit 2
LOG="$run/run.log"
: > "$LOG" || exit 2
work="$run/work"
mkdir "$work" || exit 2

state=incomplete
child=''
started=$(date +%s)
initial_commit=unknown
initial_tree=unknown
initial_source_state=unknown

source_snapshot() {
  source_commit=$(git -C "$root" rev-parse --verify HEAD 2>/dev/null) || source_commit=unknown
  source_tree=unknown
  source_state=unknown
  [ "$source_commit" != unknown ] || return 0
  source_tree=$(git -C "$root" rev-parse --verify "$source_commit^{tree}" 2>/dev/null) || source_tree=unknown
  if [ "$source_tree" != unknown ] &&
    changes=$(git -C "$root" --no-optional-locks status --porcelain --untracked-files=normal --ignore-submodules=none) &&
    [ "$source_commit" = "$(git -C "$root" rev-parse --verify HEAD 2>/dev/null)" ]; then
    source_state=clean
    [ -z "$changes" ] || source_state=dirty
  fi
}

finish() {
  exit_status=$?
  trap - EXIT
  source_snapshot
  source_eligible=no
  if [ "$state" = passed ] && [ "$exit_status" -eq 0 ] &&
    [ "$scripts" = "$root/scripts" ] && [ ! -L "$0" ] && [ ! -L "$scripts/check-local-tests.R" ] &&
    [ "$initial_source_state" = clean ] && [ "$source_state" = clean ] &&
    [ "$source_commit" = "$initial_commit" ] && [ "$source_tree" = "$initial_tree" ]; then
    source_eligible=yes
  fi
  {
    printf 'source_end commit=%s tree=%s source_state=%s source_eligible=%s\n' \
      "$source_commit" "$source_tree" "$source_state" "$source_eligible"
    printf 'run finish time=%s seconds=%s status=%s exit=%s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(( $(date +%s) - started ))" "$state" "$exit_status"
  } >> "$LOG"
  rm -rf "$work"
  exit "$exit_status"
}

interrupt() {
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || :
  fi
  exit "$1"
}

trap finish EXIT
trap 'interrupt 129' HUP
trap 'interrupt 130' INT
trap 'interrupt 143' TERM

run_phase() {
  phase=$1
  dir=$2
  shift 2
  phase_start=$(date +%s)
  printf 'phase %s start time=%s\n' "$phase" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG"
  ( cd "$dir" && exec "$@" ) >> "$LOG" 2>&1 &
  child=$!
  wait "$child"
  phase_exit=$?
  child=''
  phase_seconds=$(( $(date +%s) - phase_start ))
  printf 'phase %s finish seconds=%s exit=%s\n' "$phase" "$phase_seconds" "$phase_exit" >> "$LOG"
  return "$phase_exit"
}

fail() {
  state=failed
  echo "check-local: FAIL ($1) -- see $LOG"
  exit 1
}

if [ "$mode" = --full-tests ]; then
  export NOT_CRAN=true
else
  export NOT_CRAN=false
  export _R_CHECK_FORCE_SUGGESTS_=false
fi
echo "check-local: $pkg (NOT_CRAN=$NOT_CRAN), log: $LOG"
source_snapshot
initial_commit=$source_commit
initial_tree=$source_tree
initial_source_state=$source_state
{
  printf 'run start time=%s mode=%s root=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$mode" "$root"
  printf 'commit=%s tree=%s source_state=%s\n' "$initial_commit" "$initial_tree" "$initial_source_state"
  printf 'runner=%s\n' "$scripts/check-local.sh"
  printf 'NOT_CRAN=%s R_CHECK_FORCE_SUGGESTS=%s\n' "$NOT_CRAN" "${_R_CHECK_FORCE_SUGGESTS_-unset}"
  printf 'Rscript=%s R=%s\n' "$(command -v Rscript)" "$(command -v R)"
} >> "$LOG"

# Parse the reporter before tests run so edits cannot add commands to this invocation.
run_phase tests "$root" Rscript -e 'source(commandArgs(TRUE)[1L])' "$scripts/check-local-tests.R" || fail "tests"
test_seconds=$phase_seconds
if [ "$mode" != check ]; then
  state=passed
  echo "check-local: PASS (tests only, ${test_seconds}s)"
  exit 0
fi

run_phase build "$work" R CMD build --no-manual --no-build-vignettes "$root" || fail "build"
build_seconds=$phase_seconds
tarball=''
for f in "$work"/"$pkg"_*.tar.gz; do [ -f "$f" ] && tarball=$f && break; done
[ -n "$tarball" ] || fail "build, no tarball"

check_exit=0
run_phase check "$work" R CMD check --no-manual --ignore-vignettes --no-tests --output="$work" "$tarball" ||
  check_exit=$?
check_log="$work/$pkg.Rcheck/00check.log"
status=$(grep '^Status:' "$check_log" 2>/dev/null | head -n 1)

case "$status" in
  *ERROR* | *WARNING* | '') check_exit=1 ;;
esac
if [ "$check_exit" -ne 0 ]; then
  if cp "$check_log" "$run/00check.log" 2>/dev/null; then
    echo "check-local: see $run/00check.log"
  fi
  fail "check, ${status:-no Status line}"
fi

state=passed
echo "check-local: PASS (tests ${test_seconds}s, check $((build_seconds + phase_seconds))s) $status"
