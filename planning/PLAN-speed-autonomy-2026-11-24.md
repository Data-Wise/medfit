# PLAN: speed up and make medfit development more autonomous (2026-11-24)

Status: **planned, nothing implemented.** Builds on `PLAN-development-throughput-2026-11-23.md` (timings, T1 to T5
pilots, the #526 release-scheduling findings) and `specs/PROPOSAL-development-throughput-2026-11-23.md`; it does not
repeat their evidence. Adds an external-practice review and an autonomy track.
Evidence labels: **measured** (from run logs or local runs in the throughput plan), **agent-reported** (from a web
research pass whose source links were not independently opened), **inference**, **UNCONFIRMED**.

## 1. Key finding

`ubuntu-latest` migrated from Ubuntu 24.04 to 26.04 gradually from 2026-10-19 to 2026-11-19 (GitHub changelog,
agent-reported). `gates.yaml` is already pinned to `ubuntu-24.04` because the full gates job timed out at 75 minutes on
26.04 in PR #307 (comment in the workflow, **measured**). `R-CMD-check.yaml` still runs its Ubuntu jobs on
`ubuntu-latest`, and the 0.20.0 release matrix jobs ran about 87 minutes and hit the 90-minute cap (**measured**).
The image change is the leading candidate for that slowdown. **Inference** until one run on a pinned image compares
against one on `latest`.

## 2. Speed

Ranked by saving per PR, then risk.

| # | Item | Expected saving | Evidence | Risk | Decision needed |
|---|---|---|---|---|---|
| S1 | Pin R-CMD-check Ubuntu jobs to `ubuntu-24.04`; compare one pinned run with one on `latest` | none measured (done in #536 for image stability; see section 8) | two paired runs found no consistent speed difference | low | done |
| S2 | Focused docs-route pilot (T3): fail-closed allowlist, escalate by default | about 60 min to 17 s to 6 min per docs PR | measured, single samples | low | approve the pilot |
| S3 | Two-worker local suite (T4): `Config/testthat/parallel: true`, `Ncpus = 2`, FIML files in `start-first`, BLAS threads capped | 33 to 48 min to about 16 min | one exploratory run; the proposal's bar is 25% median gain with parity | medium: testthat does not reset state between files, so seeds and options in oracle tests can leak | approve an alternating trial against serial |
| S4 | `concurrency` with `cancel-in-progress` on R-CMD-check and gates (neither has a block; lint, pkgdown and test-coverage do) | removes wasted restarts on repeated head changes | workflow read; restarts measured | low | none; a small diff |
| S5 | `cache: always` on `setup-r-dependencies` | up to 23 of 25 min on the two slow-setup runs | agent-reported docs; two runs with different inputs | low | a controlled cold/warm trial (T5) |
| S6 | Env-gated test tier (`skip_if_not(nzchar(Sys.getenv("MEDFIT_FULL")))`) on FIML-heavy files for dev work; full tier stays on main and release | FIML is about 56% of test CPU | measured | medium: must not drop release coverage | which files may be tiered |

Not recommended: change-based test selection for R. No mature tool found (**UNCONFIRMED** for any covr-based mapper);
with oracle tests a hand-kept file-to-test map is safer.
Hosted note: a `paths-ignore` skip leaves a required check pending only for required checks. `dev` has none; `main`
requires `ubuntu-latest (release)`, which runs there.

## 3. Autonomy

Target: a task runs from plan to a reviewed, CI-green PR with the user only at push, PR creation and merge.

| # | Item | What it fixes | Notes |
|---|---|---|---|
| A1 | Preflight at session start: fetch and warn when local `dev` is behind `origin/dev` | a stale local `dev` caused the `-d` refusals and a wrong `.STATUS` read | read-only script |
| A2 | `scripts/cleanup-merged.sh`, run by the user: lists branches whose tip equals a merged PR head, prints the `-D` lines | eleven branches took many turns because `-D` stays the user's | dry-run by default |
| A3 | PR watch and merge-on-green through Auto-fix and Monitor | manual polling | merge stays the user's call |
| A4 | An ask rule for `git push *` | agent-reported: auto mode allows push to any branch, including the default | keeps the user at push; `main` is also branch-protected |
| A5 | Headless runs (`claude -p`) with `--max-budget-usd` and `--max-turns` for scheduled jobs | runaway cost | `--bare` recommended in CI; a retry-loop failure mode is UNCONFIRMED |

The auto-mode classifier denials and the branch-guard confirms stay as they are. The plan batches the user-run steps
instead of routing around them.

## 4. Split

- **0.21.0 window (cheap, no result changes):** S1, S4, A1, A2.
- **Pilots (each needs approval):** S2, S3, S5.
- **Later:** S6, A5.
- First three actions: dispatch the paired R-CMD-check run (S1), draft the `concurrency` diff (S4), draft the A1 and A2
  scripts.

## 5. Rules

No required check is removed without a pilot that includes planted defects. High-risk files keep the seven-item
checklist. Push, PR creation, merge, worktree creation and `git branch -D` stay the user's decisions. CRAN is on hold.
Every number is re-measured by the task that adopts its item.

## 6. Gaps

Most timings are single samples; the proposal's own target is five docs PRs and five numerical PRs. Hosted runner
size, job-timeout maximums and larger-runner pricing are UNCONFIRMED. Public repositories get 4 CPUs on Linux and
Windows (agent-reported), which makes two to four test workers plausible.

## 7. Ledger

| Date | Event |
|---|---|
| 2026-11-24 | written from the throughput plan, the workflows on `dev` and an agent web-research pass |

## 8. Corrected evidence (2026-11-25)

The first paired run (45505691085: 24.04 50 min, `ubuntu-latest` 65 min) was read as an image effect. A second run
(45573883028, four jobs started together on one commit, `R CMD check` test phase, `proc.time()` user / system /
elapsed) did not repeat it:

| Job | user (s) | system (s) | elapsed (s) |
|---|---|---|---|
| control, 24.04 | 3,450 | 2,442 | 2,773 |
| control, `ubuntu-latest` | 5,450 | 9 | 2,546 |
| BLAS and OpenMP threads = 1, 24.04 | 4,115 | 12 | 4,120 |
| BLAS and OpenMP threads = 1, `ubuntu-latest` | 4,037 | 12 | 4,043 |

- The image is not the cause of the slowdown: control jobs differ by 8% in the opposite direction, and one configuration
  varied from 42 to 62 min between runs (runner variance is large; every number here is a single sample).
- The suite does about 4,040 s of single-thread CPU work in one R process; default threading spreads it over about two
  cores (elapsed about 2,550 to 2,770 s), and capping threads makes it 50 to 60% slower. Threads are not oversubscribed.
- This supports S3: parallel test workers with BLAS threads capped per worker could use all four cores. It is a pilot
  still to run, with the proposal's parity bar, not a measured gain.
- S1 stays merged for image stability. Its "speed" rationale is withdrawn.

