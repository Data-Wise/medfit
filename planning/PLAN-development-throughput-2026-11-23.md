# Plan to speed up medfit development

**Source** — [Development throughput audit and proposal](specs/PROPOSAL-development-throughput-2026-11-23.md)

**Base** — `origin/dev` at `d8c83813` on 2026-11-23
**Branch** — `feature/development-throughput`
**Status** — T1 runner and T2 receipt guidance implemented. T3–T5 pilot evidence recorded below.

The audit found about an hour of local final verification on two docs branches. Across 35 recent dev PRs, the median longest hosted workflow took eight minutes. Measure and streamline the local path first. Keep required pre-PR, numerical, platform and release checks in force during the pilots.

| Task | Work | Acceptance and verification |
| --- | --- | --- |
| **T1. Instrument local verification** | In `scripts/check-local.sh`, preserve the gate sequence, default, `--tests-only` and exit behavior. Add per-attempt logs and time package loading, test files, build and check. Preserve testthat loading, helpers and skips. Correct the comment about hosted dev coverage. | Report tree and dirty state, test mode, R and library provenance, durations, counts and exit status. Verify concurrent worktrees have separate logs. Exercise test failure, build failure and interruption. Compare complete test registration and outcomes against the previous runner on the same tree. |
| **T2. Baseline and consolidate identical runs** | Use T1 on one representative docs change and one numerical change. Time the full `NOT_CRAN=true` suite, the `NOT_CRAN=false` quick check, and the strict installed-package check separately. Record exact flags and what each covers. Update guidance to share a successful receipt for repeated invocations with identical inputs. | Identify time and unique coverage in each mode, including examples, vignettes and dependency flavors. Verify a changed tree, fixture, toolchain, dependency or configuration invalidates the relevant receipt. Incomplete runs and unavailable prerequisites fail the gate. Retain distinct checks under current policy. |
| **T3. Pilot focused docs verification** | After T2, replay a prose/navigation diff, a shared-helper diff and a numerical diff. Compare focused results with existing verification. Define a conservative allowlist and escalation for executable examples, signatures, R code, dependencies and shared test infrastructure. | Demonstrate that affected docs guards, rendered links/anchors and redirects, executed examples and visual checks cover the change. Plant broken anchors and an executable-example regression. Shared helpers and numerical work must escalate. Target under 10 minutes for eligible docs work, excluding cold installs and review. |
| **T4. Profile and trial suite changes** | After T2, rank files on a complete serial baseline. Profile the slowest files. Trial reusable deterministic setup or two isolated workers with bounded subprocess and BLAS use. Preserve independent or state-sensitive fits. | Alternate serial and candidate runs on the same commit and machine. Record wall time, CPU and peak memory. Match named test results, warnings, skips and representative planted-defect detection. Adopt only with parity and at least 25% lower median wall time. |
| **T5. Trial hosted setup and release scheduling** | After T2, separate queue, setup, provisioning and execution time. Trial cache/provisioning only if timings justify it. Document checks that can overlap on the same release candidate. | Compare warm and cold runs with equivalent dependencies. Preserve required main checks, coverage, OpenBLAS, strict flavors, dependent checks, platform pins pending evidence and post-merge verification. |

## Checkpoints

- [x] Implement T1–T2 and review baseline receipts for both change types. Prioritize full suite runtime and repeated runs on identical inputs.
- [ ] Decide T3 with the maintainer. Continue the current pre-PR policy until the alternative is approved and written into the applicable global and medfit guidance.
- [ ] Decide T4 and T5 independently. Retain only changes that meet the stated acceptance criteria. Re-run required numerical and platform verification for affected paths.
- [ ] After five eligible docs PRs and five numerical PRs, compare time to first actionable failure, final local gate duration, longest hosted job and setup, and review intervals where available.

Keep raw timing and test fixtures in the worktree's ignored `_agents_workspace/development-throughput/`. Record concise receipts on the feature branch. T3–T5 may be trialed independently after T2. Before opening an implementation PR, run the required suite and lint on the final candidate and record counts and the exact tree. Preserve coverage targets, independent oracles, planted-defect checks and release/CRAN holds. Sync affected runner help and agent guidance as implementation lands.

## Milestone evidence

- The serial `NOT_CRAN=true` docs-headings run at `a032b32c` recorded 22,877 passes across 244 files and 2,720 blocks, with zero failures or errors, five skips and five warnings. It took 47m 39s wall time and 33m 11s of R CPU in the tests. The laptop spent about 14m 09s asleep during `test-fiml-g2-parallel.R`, which took 14m 47s wall time and 45s R CPU. Rank files by both measures before selecting optimization candidates.
- FIML files used about half of R CPU in that run. The leading files by R CPU were `test-fiml-g3-serial-two-cov.R` (182s), `test-twolevel-equal-indirect.R` (159s), `test-sem-fiml-oracles.R` (158s), `test-twolevel-few-clusters-harness.R` (143s), and `test-twolevel-icc-h1-qa.R` (130s).
- The quick local gate uses `NOT_CRAN=false` and disables forced Suggests. It builds with `--no-build-vignettes` and checks examples on the installed package with `--ignore-vignettes --no-tests`. The full source run uses `NOT_CRAN=true` and preserves testthat helpers, fixtures and skip conditions. The separate strict command uses `R CMD build --no-manual` and `R CMD check --as-cran --no-manual --run-donttest`. The pilot sets `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_`, and `_R_CHECK_CRAN_INCOMING_REMOTE_` to `true`. This checks installed-package tests and examples with these settings. The package currently excludes vignettes from its source tarball. The hosted noSuggests job separately installs a hard-dependency library and testthat.

### Local pilot receipts

The docs sample is #517 at `19c44769`. The numerical sample is #513 at
`ce39a655`. The feature candidate at `f2a8f839` has identical package code,
test files and article sources to #517. The extracted strict tarballs for
#517 and the candidate matched apart from the generated packaging timestamp.
The corrected source trial used a frozen archive of the candidate with the
committed reporter launch from `7857692d`. Runs overlapped, so their wall
times are observations under load.

| Sample | Mode | Wall time | Result |
| --- | --- | ---: | --- |
| Docs candidate | Corrected full source, serial | 33m 47s | 244 files, 2,717 blocks, 22,858 passes, zero failures or errors, five warnings and five skips. |
| Docs candidate | Quick source, build and check | 30m 28s | 244 files, 2,669 blocks, 22,031 passes, 75 skipped blocks and zero failures or errors. Build and check took 45s and returned `Status: OK`. |
| Docs #517 | Strict installed | 14m 37s check | 15,351 passes, 531 reported skips, zero errors or warnings from R CMD check and one development-version NOTE. |
| Numerical #513 | Full source, serial | 42m 09s | 244 files, 2,713 blocks, 22,821 passes, three semopy failures, zero errors, five warnings and five skips. |
| Numerical #513 | Quick source, build and check | 28m 05s | 244 files, 2,665 blocks, 21,997 passes, 75 skipped blocks and zero failures or errors. Build and check took 55s and returned `Status: OK`. |
| Numerical #513 | Strict installed | 12m 55s check | 15,335 passes, 528 reported skips, zero errors or warnings from R CMD check and the same NOTE. |

Strict checks reported three test warnings per sample and skipped optional
oracles and source-only guards. Both initial full source runs hit a read-only
uv cache in the sandbox. The docs candidate ran for 38m 56s and the numerical
archive for 42m 09s. Each recorded three failed assertions in the same semopy
test and zero errors. The isolated semopy tests passed after setting a
writable `UV_CACHE_DIR`. The docs candidate's corrected full run also
passed with that cache. The numerical archive's repair was verified in
the affected test file. The frozen suites are timing evidence and have
no Git receipt marker.

The docs candidate's full and quick runs registered the same 244 test
files, with different block and skip counts. FIML files accounted for
56% of test-file R CPU in the corrected serial full run.

The first numerical quick replay completed all 244 test files without an
assertion failure, then exited during Rscript cleanup before build and check.
Editing the reporter while it was running reproduced the same exit. The
runner now parses the reporter before starting the tests, and the regression
fixture exercises a reporter edit during a real test. The frozen-runner retry
passed with the same source test counts and completed build and check.

### Follow-up probes

- A prose navigation edit in the troubleshooting guide passed six focused files and 324 expectations in 17s. A full local site render took 6m 01s with the isolated candidate package exposed to Quarto via `R_LIBS`. The rendered page had 15 resolving fragment links, and all nine legacy redirects preserved fragments. The new link label and destination heading were visually inspected in the desktop render. A broken cookbook link and a wrong joint p-value planted in a runnable recipe each failed a focused check.
- A serial profile of `test-fiml-g3-serial-two-cov.R` passed all 987 expectations. The native fitter accounted for about 58% of sampled time and the independent numerical Hessian for 37%. A paired one-file trial in disposable snapshots took 247s with the original setup and 181s with deterministic native-fit reuse. Both runs passed all 987 expectations across the same 29 test blocks. External load varied, and this measures one file. The whole-suite speed and coverage threshold still applies before adoption.
- An exploratory two-worker run of the frozen docs candidate finished in 16m 13s, compared with 33m 47s serial. It matched the serial run's file registration, aggregate counts, warning names and skip report. The launch set `TESTTHAT_PARALLEL=true`, `TESTTHAT_CPUS=2`, `options(Ncpus = 2L)`, and OpenBLAS and OpenMP thread limits of one. The runs overlapped. A controlled alternating comparison with matching thread limits, peak memory, per-block results and planted defects remains necessary before adopting a default.

### Docs pilot routing

Start with a manually reviewed allowlist for an existing article's prose or
link-label edit that leaves code blocks, signatures, targets, section IDs,
redirects, configuration, and test infrastructure intact. Require the
affected docs tests, executed examples in the local site render, and
checks of affected links and redirects. Inspect the rendered change if it
affects layout. Escalate ambiguous diffs and changes to executable claims,
configuration, dependencies, shared helpers, fixtures, or package code to
the existing gates.

| Replay | Route | Evidence |
| --- | --- | --- |
| Troubleshooting navigation label | Eligible for the focused pilot | The diff changes one link label. Its anchor and target heading are unchanged. |
| Headings and shared docs helper in #518 | Full validation | The diff adds `helper-docs-headings.R` and changes its guard tests. The 47m 39s serial baseline at `a032b32c` has the same Git tree as the merge commit. |
| Numerical ICC change in #513 | Full validation and numerical admission | The diff changes the estimation code, a shared helper and a numerical fixture. The quick, strict and full-mode timings are recorded above. |

These are pilot decisions. The current pre-PR policy applies until
the maintainer approves and records a replacement.

### Hosted timing sample

GitHub reported a zero-second run creation-to-start interval and a two-
to four-second run start-to-job start interval in these six runs. Times
are elapsed minutes and seconds from the job-step timestamps.

| Run | R setup | Dependencies | Main step | Job |
| --- | ---: | ---: | ---: | ---: |
| [#516 pkgdown, primary cache hit](https://github.com/Data-Wise/medfit/actions/runs/45114580653) | 0:38 | 0:42 | 4:21 | 6:18 |
| [Slow pkgdown, fallback cache hit](https://github.com/Data-Wise/medfit/actions/runs/44437541136) | 9:18 | 13:40 | 3:57 | 27:42 |
| [#516 lint, primary cache hit](https://github.com/Data-Wise/medfit/actions/runs/45114580702) | 0:45 | 0:43 | 1:28 | 3:08 |
| [Slow lint, fallback cache hit](https://github.com/Data-Wise/medfit/actions/runs/44378843981) | 11:02 | 12:42 | 1:20 | 25:25 |
| [#472 pre-merge Ubuntu oldrel](https://github.com/Data-Wise/medfit/actions/runs/44180036848) | 0:26 | 0:33 | 56:05 | 57:20 |
| [#472 post-merge Windows](https://github.com/Data-Wise/medfit/actions/runs/44189904049) | 0:20 | 0:47 | 63:49 | 65:59 |

R and dependency provisioning account for most of both slow development
jobs. Both already restored a fallback cache, and their main steps were
similar to the primary-hit runs. The inputs differ across runs, so a
controlled cache trial with the same dependency resolution is still
needed. The release matrix jobs spent most of their time running the
package checks. Use the frozen release candidate to overlap independent
pre-merge matrix, simulation, coverage and local dependent checks where
their prerequisites permit.
