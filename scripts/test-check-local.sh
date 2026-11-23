#!/bin/sh
# Exercise the local gate from disposable checkouts with a tiny testthat package.
set -eu
unset TESTTHAT_PARALLEL

scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fixture() {
  mkdir -p "$1/scripts" "$1/tests/testthat"
  cp "$scripts/check-local.sh" "$1/scripts/"
  if [ -f "$scripts/check-local-tests.R" ]; then
    cp "$scripts/check-local-tests.R" "$1/scripts/"
  fi
  cat > "$1/DESCRIPTION" <<'DESCRIPTION'
Package: medfitgatetest
Title: Local Gate Test Fixture
Version: 0.0.1
Authors@R: person("Gate", "Fixture", role = c("aut", "cre"), email = "gate@example.org")
Description: A fixture with ordinary and extended tests.
License: MIT
Suggests: testthat
Config/testthat/edition: 3
DESCRIPTION
  touch "$1/NAMESPACE"
  cat > "$1/tests/testthat/test-basic.R" <<'R'
test_that("ordinary tests run", expect_true(TRUE))
test_that("extended tests run off CRAN", {
  skip_on_cran()
  expect_true(TRUE)
})
R
  cat > "$1/tests/testthat/test-other.R" <<'R'
test_that("a second file runs", expect_equal(1 + 1, 2))
R
}

run() {
  dir=$1
  shift
  cd "$dir"
  TMPDIR="$tmp" sh scripts/check-local.sh "$@"
}

log_path() {
  sed -n 's/^check-local: .* log: //p' "$1"
}

require_text() {
  if ! grep -Eq "$1" "$2"; then
    printf 'Expected %s in %s\n' "$1" "$2" >&2
    cat "$2" >&2
    exit 1
  fi
}

fixture "$tmp/one"
fixture "$tmp/two"
(run "$tmp/one" --tests-only) > "$tmp/out1" 2>&1 &
first=$!
(run "$tmp/two" --tests-only) > "$tmp/out2" 2>&1 &
second=$!
wait "$first"
wait "$second"
log1=$(log_path "$tmp/out1")
log2=$(log_path "$tmp/out2")
if [ "$log1" = "$log2" ]; then
  echo "Concurrent local gates wrote to the same log: $log1" >&2
  exit 1
fi
(
  cd "$tmp/two"
  NOT_CRAN=false Rscript - <<'R'
    result <- as.data.frame(devtools::test(reporter = "silent", stop_on_failure = TRUE))
    for (file in unique(result$file)) cat(file, "\n", sep = "")
    cat(sprintf(
      "test_totals files=%d blocks=%d passed=%d failed=%d errors=%d warnings=%d skipped=%d\n",
      length(unique(result$file)), nrow(result), sum(result$passed), sum(result$failed),
      sum(result$error), sum(result$warning), sum(result$skipped)
    ))
R
) > "$tmp/baseline"
for log in "$log1" "$log2"; do
  require_text 'source_state=unknown' "$log"
  require_text '^source_end commit=unknown tree=unknown source_state=unknown source_eligible=no$' "$log"
  require_text 'NOT_CRAN=false' "$log"
  require_text 'test_setup .*seconds=' "$log"
  require_text 'test_file start .*test-basic.R' "$log"
  require_text 'test_file finish .*test-other.R.*seconds=[0-9.]+ user_seconds=[0-9.]+ system_seconds=[0-9.]+$' "$log"
  sed -n 's/^test_file start file="\(.*\)"$/\1/p; /^test_totals /p' "$log" > "$tmp/observed"
  diff -u "$tmp/baseline" "$tmp/observed"
  require_text 'run finish .*status=passed exit=0' "$log"
done

fixture "$tmp/clean"
echo initial > "$tmp/clean/source-marker"
cat >> "$tmp/clean/tests/testthat/test-other.R" <<'R'
fixture_change_target <- Sys.getenv("FIXTURE_CHANGE_TARGET")
if (nzchar(fixture_change_target)) writeLines("changed", fixture_change_target)
R
git -C "$tmp/clean" -c init.defaultBranch=fixture init -q
git -C "$tmp/clean" add DESCRIPTION NAMESPACE scripts source-marker tests
git -C "$tmp/clean" -c user.name='Gate Fixture' -c user.email=gate@example.org commit -qm 'test: add local gate fixture'
(run "$tmp/clean" --tests-only) > "$tmp/out-clean" 2>&1
log=$(log_path "$tmp/out-clean")
require_text '^commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=clean$' "$log"
require_text '^source_end commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=clean source_eligible=yes$' "$log"
require_text 'run finish .*status=passed exit=0' "$log"

(cd "$tmp/clean" && sh "$tmp/one/scripts/check-local.sh" --tests-only) > "$tmp/out-external-runner" 2>&1
log=$(log_path "$tmp/out-external-runner")
require_text '^commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=clean$' "$log"
require_text '^source_end commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=clean source_eligible=no$' "$log"
require_text 'run finish .*status=passed exit=0' "$log"

(FIXTURE_CHANGE_TARGET="$tmp/clean/source-marker" run "$tmp/clean" --tests-only) > "$tmp/out-changed" 2>&1
log=$(log_path "$tmp/out-changed")
require_text '^commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=clean$' "$log"
require_text '^source_end commit=[0-9a-f]+ tree=[0-9a-f]+ source_state=dirty source_eligible=no$' "$log"
require_text 'run finish .*status=passed exit=0' "$log"

(run "$tmp/one" --full-tests) > "$tmp/out-full" 2>&1
log=$(log_path "$tmp/out-full")
require_text 'NOT_CRAN=true' "$log"
require_text 'test_totals files=2 blocks=3 passed=3 failed=0 errors=0 warnings=0 skipped=0' "$log"

echo 'options(Ncpus = 2L)' > "$tmp/parallel.Rprofile"
(TESTTHAT_PARALLEL=true R_PROFILE_USER="$tmp/parallel.Rprofile" run "$tmp/one" --full-tests) > "$tmp/out-parallel" 2>&1
log=$(log_path "$tmp/out-parallel")
require_text 'test_timing mode=parallel_requested file_wall_time=unavailable' "$log"
require_text 'test_file replay_finish .*test-basic.R' "$log"
require_text 'test_totals files=2 blocks=3 passed=3 failed=0 errors=0 warnings=0 skipped=0' "$log"
require_text 'run finish .*status=passed exit=0' "$log"
if grep -q '^test_file .*seconds=' "$log"; then
  echo 'Parallel file event playback was reported as wall time' >&2
  exit 1
fi

cat >> "$tmp/one/tests/testthat/test-basic.R" <<'R'
test_that("a test fails", expect_true(FALSE))
R
if (run "$tmp/one" --tests-only) > "$tmp/out-fail" 2>&1; then
  echo 'The runner accepted a failing test' >&2
  exit 1
fi
log=$(log_path "$tmp/out-fail")
require_text 'test_totals files=2 blocks=4 passed=2 failed=1 errors=0 warnings=0 skipped=1' "$log"
require_text 'run finish .*status=failed exit=1' "$log"

mkdir "$tmp/bin"
cat > "$tmp/bin/R" <<'SH'
#!/bin/sh
case "$*" in
  'CMD build --no-manual --no-build-vignettes '*) exit 37 ;;
  *) exit 38 ;;
esac
SH
chmod +x "$tmp/bin/R"
if (PATH="$tmp/bin:$PATH" run "$tmp/two") > "$tmp/out-build" 2>&1; then
  echo 'The runner accepted a failing build' >&2
  exit 1
fi
log=$(log_path "$tmp/out-build")
require_text 'phase build finish .*exit=37' "$log"
require_text 'run finish .*status=failed exit=1' "$log"

cat > "$tmp/bin/R" <<'SH'
#!/bin/sh
case "$*" in
  'CMD build --no-manual --no-build-vignettes '*) touch medfitgatetest_0.0.1.tar.gz ;;
  'CMD check --no-manual --ignore-vignettes --no-tests --output='*)
    mkdir medfitgatetest.Rcheck
    printf '%s\n' "${FIXTURE_CHECK_STATUS:-Status: OK}" > medfitgatetest.Rcheck/00check.log
    exit "${FIXTURE_CHECK_EXIT:-0}" ;;
  *) exit 38 ;;
esac
SH
(PATH="$tmp/bin:$PATH" run "$tmp/two") > "$tmp/out-pass" 2>&1
log=$(log_path "$tmp/out-pass")
require_text 'phase build finish .*exit=0' "$log"
require_text 'phase check finish .*exit=0' "$log"
require_text 'run finish .*status=passed exit=0' "$log"
if (FIXTURE_CHECK_EXIT=39 PATH="$tmp/bin:$PATH" run "$tmp/two") > "$tmp/out-check" 2>&1; then
  echo 'The runner accepted a nonzero check exit with a successful status line' >&2
  exit 1
fi
log=$(log_path "$tmp/out-check")
require_text 'phase check finish .*exit=39' "$log"
require_text 'run finish .*status=failed exit=1' "$log"
require_text '^Status: OK' "$(dirname "$log")/00check.log"

cat > "$tmp/bin/Rscript" <<'SH'
#!/bin/sh
echo test_subprocess_ready
exec sleep 30
SH
chmod +x "$tmp/bin/Rscript"
(
  cd "$tmp/two"
  PATH="$tmp/bin:$PATH" TMPDIR="$tmp" exec sh scripts/check-local.sh --tests-only
) > "$tmp/out-interrupt" 2>&1 &
runner=$!
log=''
for _ in 1 2 3 4 5; do
  log=$(log_path "$tmp/out-interrupt")
  if [ -n "$log" ] && grep -q test_subprocess_ready "$log"; then
    break
  fi
  sleep 1
done
require_text 'test_subprocess_ready' "$log"
kill -TERM "$runner"
status=0
wait "$runner" || status=$?
[ "$status" -eq 143 ]
require_text 'run finish .*status=incomplete exit=143' "$log"

echo 'Local gate fixture checks passed'
