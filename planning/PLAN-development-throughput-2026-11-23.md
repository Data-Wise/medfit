# Plan to speed up medfit development

**Source** — [Development throughput audit and proposal](specs/PROPOSAL-development-throughput-2026-11-23.md)

**Base** — `origin/dev` at `d8c83813` on 2026-11-23
**Branch** — `feature/development-throughput`
**Status** — Planned. Start with T1 and T2.

The audit found about an hour of local final verification on two docs branches. Across 35 recent dev PRs, the median longest hosted workflow took eight minutes. Measure and streamline the local path first. Keep required pre-PR, numerical, platform and release checks in force during the pilots.

| Task | Work | Acceptance and verification |
| --- | --- | --- |
| **T1. Instrument local verification** | In `scripts/check-local.sh`, preserve the gate sequence, default, `--tests-only` and exit behavior. Add per-attempt logs and time package loading, test files, build and check. Preserve testthat loading, helpers and skips. Correct the comment about hosted dev coverage. | Report tree and dirty state, test mode, R and library provenance, durations, counts and exit status. Verify concurrent worktrees have separate logs. Exercise test failure, build failure and interruption. Compare complete test registration and outcomes against the previous runner on the same tree. |
| **T2. Baseline and consolidate identical runs** | Use T1 on one representative docs change and one numerical change. Time the full `NOT_CRAN=true` suite, the `NOT_CRAN=false` quick check, and the strict installed-package check separately. Record exact flags and what each covers. Update guidance to share a successful receipt for repeated invocations with identical inputs. | Identify time and unique coverage in each mode, including examples, vignettes and dependency flavors. Verify a changed tree, fixture, toolchain, dependency or configuration invalidates the relevant receipt. Incomplete runs and unavailable prerequisites fail the gate. Retain distinct checks under current policy. |
| **T3. Pilot focused docs verification** | After T2, replay a prose/navigation diff, a shared-helper diff and a numerical diff. Compare focused results with existing verification. Define a conservative allowlist and escalation for executable examples, signatures, R code, dependencies and shared test infrastructure. | Demonstrate that affected docs guards, rendered links/anchors and redirects, executed examples and visual checks cover the change. Plant broken anchors and an executable-example regression. Shared helpers and numerical work must escalate. Target under 10 minutes for eligible docs work, excluding cold installs and review. |
| **T4. Profile and trial suite changes** | After T2, rank files on a complete serial baseline. Profile the slowest files. Trial reusable deterministic setup or two isolated workers with bounded subprocess and BLAS use. Preserve independent or state-sensitive fits. | Alternate serial and candidate runs on the same commit and machine. Record wall time, CPU and peak memory. Match named test results, warnings, skips and representative planted-defect detection. Adopt only with parity and at least 25% lower median wall time. |
| **T5. Trial hosted setup and release scheduling** | After T2, separate queue, setup, provisioning and execution time. Trial cache/provisioning only if timings justify it. Document checks that can overlap on the same release candidate. | Compare warm and cold runs with equivalent dependencies. Preserve required main checks, coverage, OpenBLAS, strict flavors, dependent checks, platform pins pending evidence and post-merge verification. |

## Checkpoints

- [ ] Complete T1–T2. Review baseline receipts for both change types and prioritize the largest measured avoidable wait.
- [ ] Decide T3 with the maintainer. Continue the current pre-PR policy until the alternative is approved and written into the applicable global and medfit guidance.
- [ ] Decide T4 and T5 independently. Retain only changes that meet the stated acceptance criteria. Re-run required numerical and platform verification for affected paths.
- [ ] After five eligible docs PRs and five numerical PRs, compare time to first actionable failure, final local gate duration, longest hosted job and setup, and review intervals where available.

Keep raw timing and test fixtures in the worktree's ignored `_agents_workspace/development-throughput/`. Record concise receipts on the feature branch. T3–T5 may be trialed independently after T2. Before opening an implementation PR, run the required suite and lint on the final candidate and record counts and the exact tree. Preserve coverage targets, independent oracles, planted-defect checks and release/CRAN holds. Sync affected runner help and agent guidance as implementation lands.
