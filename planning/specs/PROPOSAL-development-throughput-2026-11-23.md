# Speeding up medfit development

**Decision requested** — Approve measurement and consolidation of local verification first. Consider a focused verification policy for documentation PRs after the pilot establishes what it catches.

**Audit date and scope** — 2026-11-23. Local and remote `dev` at `d8c83813`, remote `main` at `2c334734`. Evidence comes from the local runner and agent instructions, current GitHub workflows and main branch protection, recent PR and job records, the docs worktree timeline, and a focused local test run.

## Where the time goes

| Stage | Observed evidence | Implication |
| --- | --- | --- |
| Local final verification | The docs currency and navbar final-gate stages took **62m 06s** and **59m 10s**. In #516 and #517, the `NOT_CRAN=false` test pass inside `check-local.sh` took **16m 31s** and **16m 07s**. Its subsequent build/check took **27s** and **28s**. The PRs also reported full `NOT_CRAN=true` runs. | The local package test pass dominates the quick check. The gate contract calls for the full suite, `check-local.sh`, and a separate strict installed-package check. The configurations serve different purposes and overlap substantially. [#516][p516] · [#517][p517] · [Agent contract][contract] · [Local runner][runner] |
| Local restarts and visibility | The SEM headings worktree rendered all **29** targeted articles. The full suite was restarted and its `reporter="silent"` invocation printed the final count only after returning. Multiple 9–13 minute waits looked for that count. The restarted log was updated after 25 minutes, with no final result when inspected. | Poll durations may overlap each other and the active test, so adding them would overstate lost time. The run had no per-file progress or verified completion at inspection. A fixed `medfit-check-local.log` pathname in the standard runner is also shared across concurrent worktrees using the same temp directory. BB thread `thr_gpyw5s6f7k` · [Local runner][runner] |
| Test growth | Test files increased from **174** in v0.16.0 to **214** in v0.17.0, **225** in v0.19.0, and **244** on audited `dev`. FIML-named files went from **4 to 30** between v0.16.0 and v0.17.0. The R-CMD-check workflow records FIML at **71% of a historical 22-minute** laptop run. | FIML is a candidate for timing analysis. File counts and the historical share do not establish the current slowest tests. Native/two-level numerical checks, repeated fits and bootstrap work also need measurement before changing fixtures. [R-CMD-check workflow][cmd] |
| `dev` CI | Across 35 recent merged PRs, the median longest successful hosted workflow on each final head was **8.0 min**. Median individual times were **7.4 min** pkgdown (28 PRs), **3.7 min** lint, and **0.9 min** risk-tier. PR open-to-merge was **28.4 min** median and **334 min** at the 90th percentile. #516 took **121 min** open-to-merge with a longest hosted run of **6.4 min**. | Typical hosted jobs are a smaller target than local final checks. Open-to-merge excludes pre-PR work and includes review, author availability and idle time. The gap cannot be assigned to any one cause. Regular `dev` merge pushes did not trigger a full suite on the inspected docs and code PRs. The labeled QC route is separate. [#516][p516] · [#513][p513] · [QC workflow][qc] |
| Hosted outliers | A **27.8 min** pkgdown run spent **23.0 min** in R setup/dependencies and **4.0 min** building the site. A **25.5 min** lint run spent **23.7 min** in the same setup steps and **1.3 min** linting. | For slow hosted checks, investigate dependency provisioning first. The workflows already pin the affected runners and cancel superseded PR runs. [pkgdown run][pkg-tail] · [lint run][lint-tail] |
| Release verification | For #472, the longest pre-merge matrix job was **55 min**, coverage **47 min**, and the OpenBLAS gate shards **21–25 min**, running concurrently. The post-merge Windows matrix job took **66 min**. The post-merge Ubuntu release job spent **51 min** in `testthat.R` with **114 skips**. | This is a separate release critical path. Hosted test configurations differ from local `NOT_CRAN=true`. Live main protection requires the Ubuntu release job and both OpenBLAS shards. [#472][p472] · [Pre-merge matrix][pr-matrix] · [Post-merge matrix][main-matrix] · [Release checklist][release] |
| Agent and review workflow | One docs audit hit a provider transport error after **5m 22s**. The retry took **2h 17m 14s**. Two docs implementation stages took about **4–5 min** apiece before their hour-long gate stages. | Give audit retries a progress checkpoint and save findings incrementally. Keep human-review time visible as its own stage. The timeline cannot attribute the entire retry to transport or compute. BB thread `thr_gpyw5s6f7k` |

## What a focused check can cover

On audited `dev`, a single local `NOT_CRAN=true` source-mode run of `docs-release`, `model-pages`, `cookbook-consistency`, and `refcard-coverage` took **15.63 seconds** including package loading. It ran **48 test blocks and 284 expectations** with zero failures, errors or skips. Environment was R 4.6.2, testthat 3.3.2, lavaan 0.7.3 and OpenMx 2.22.11. A second run spanning **16** docs checks took **39.69 seconds** with **136 test blocks, 1,362 expectations, and zero failures, errors or skips**. The largest sums of reported test time were cookbook consistency (**13.14s**), the troubleshooting guide (**8.36s**), and two-level docs (**7.25s**). These runs establish that focused checks can give fast feedback. Docs that change executable examples, navigation or cross-page references also need the relevant live docs tests and rendered link/anchor checks. [Docs release ADR][docs-adr]

## Proposal

### 1. Make each verification run observable

Instrument the existing local entry point before changing what runs. For each run, record the repository tree or commit, exact command and mode, source versus installed package, R/package version and library provenance, start and finish, and exit status. Give each worktree and attempt its own log. Report start/finish per test file and publish the slowest files plus failure/warning/skip totals. Time package loading, build, check and rendering separately. An interrupted run should have an explicit incomplete state. An environment failure such as an unavailable oracle should show the missing prerequisite.

The orchestrator already specifies a single final full-suite pass after docs. Run that pass against the final tree and point each report at the same receipt when it needs the same evidence. Continue to run distinct installed, strict or platform checks where the current policy requires them. Review rerun validity using the tree and full configuration. An R, test, helper, dependency, configuration or fixture change invalidates an affected receipt. A log with no successful exit cannot satisfy a gate. Batch findings by stage and use checkpointed progress for provider retries.

**Pilot check** — Record one docs PR and one numerical PR under the current gates. Demonstrate that simultaneous worktrees produce separate logs, failures return nonzero, and incomplete runs cannot be accepted. Collect baseline local full-suite, strict and package-check time for each verified configuration. Update the stale `check-local.sh` comment about hosted `dev` coverage when synchronizing instructions.

### 2. Remove redundant package work by explicit policy

After the pilot, compare source-mode and installed-package results by test identity, test mode, skips and failure class. Inventory what the strict command exercises separately, including examples, vignettes, dependency flavors and installed layout. Use that inventory to decide which repeated invocations can share a successful receipt or be replaced by a package-check-only invocation that retains the corresponding checks. Do not treat `NOT_CRAN=false` as equivalent to `NOT_CRAN=true` or assume every strict run uses the same flags and dependencies.

Propose a separate, **maintainer-approved** route for prose and navigation PRs. Start with a fail-closed allowlist of reviewed changes and require docs consistency, executed examples for affected pages, link/anchor and redirect preservation, and visual inspection for layout changes. Escalate when a diff changes R code, public signatures, dependencies, executable examples, shared test helpers, test infrastructure, or uncertain/render-sensitive content. Changes to documentation claims still need substantive review. Demonstrate the route on representative docs changes while running the current full gate in parallel for comparison. Until approved and written into both global and medfit guidance, run the existing pre-PR suite and local checks. Prefer one coherent reviewable docs PR when several edits share the same rollback boundary and approvals allow batching.

**Pilot check** — Replay one docs navigation change, one shared-helper change, and one numerical change. Plant a broken anchor and an executable example regression to verify the expected gates catch them. Show the time gained and verify that escalation defaults to full validation. If adopted, aim for **under 10 minutes** of local verification for eligible docs PRs, excluding human review and cold dependency installs.

### 3. Shorten the full suite without losing test cases

Rank files by wall time from a complete current serial run. Profile the top files before changing any fixtures. First look for identical deterministic fit setup within a file, and keep separate fits where repeatability, independent starts, RNG, failures or oracle independence are the behavior under test. In a disposable environment, compare serial with two isolated workers or explicit file shards. Keep worker counts bounded for bootstrap, BLAS and subprocess-heavy tests. Compare named test results, skips and warnings, and run representative planted defects in both modes. If the runner cannot prove complete test registration or either mode changes the evidence, keep serial authoritative.

**Pilot check** — On the same commit, libraries and machine, alternate serial and candidate runs and report median wall time, aggregate CPU and peak memory. Aim for **at least 25% lower median wall time** with equivalent coverage and defect detection. Preserve the current suite until that threshold and parity are shown.

### 4. Address cold CI and release scheduling after local gains

Record cold/warm R setup, dependency and job times. Trial one dependency-cache or provisioning change in a disposable workflow context using the same dependency resolution; compare warm and cold runs before adopting it. Keep existing platform pins pending evidence. On release candidates, overlap independent, authorized checks on the same exact candidate when dependencies permit, including the hosted matrix, simulation gates, coverage, and local dependent checks. Re-run checks affected by any candidate change and preserve required main checks, post-merge verification, coverage targets, independent oracle/mutation checks, OpenBLAS, strict package/dependency checks, and release/CRAN holds. [Release checklist][release]

## How to evaluate the changes

Record time to first actionable failure, local final-gate wall time, longest hosted job and its setup time, and review/approval intervals where timestamps exist. Review results after **five eligible docs PRs and five numerical PRs**, with docs and numerical work reported separately. The reduction targets are acceptance criteria for trials. The audit did not rerun the whole suite, infer active working time from open-to-merge duration, or measure a current per-file full-suite profile. It sampled 35 merged `dev` PRs returned by `gh pr list --state merged --limit 35` (Nov 18–23 UTC), matched successful pull-request workflow runs from the latest 150 runs by each PR's final head SHA, and used workflow started-to-updated durations. These timings omit the wait before workflow start and omit unsuccessful attempts. The release example is one observed release, and the BB timeline comes from one session.

[contract]: ../../.claude/agents/medfit-gates.md
[runner]: ../../scripts/check-local.sh
[cmd]: ../../.github/workflows/R-CMD-check.yaml
[qc]: ../../.github/workflows/qc-monthly.yaml
[docs-adr]: ADR-docs-release-pipeline-2026-11-12.md
[release]: ../PLAN-0.20.0-release-checklist-2026-11-21.md
[p516]: https://github.com/Data-Wise/medfit/pull/516
[p517]: https://github.com/Data-Wise/medfit/pull/517
[p513]: https://github.com/Data-Wise/medfit/pull/513
[p472]: https://github.com/Data-Wise/medfit/pull/472
[pkg-tail]: https://github.com/Data-Wise/medfit/actions/runs/44437541136
[lint-tail]: https://github.com/Data-Wise/medfit/actions/runs/44378843981
[pr-matrix]: https://github.com/Data-Wise/medfit/actions/runs/44180036848
[main-matrix]: https://github.com/Data-Wise/medfit/actions/runs/44189904049
