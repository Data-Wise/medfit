# GRILL: medfit 0.5.0 release decisions (2026-09-24)

Target: how to release the unreleased `dev` work since 0.4.0 (#62-#82), which
includes two result-changing fixes: #81 (serial `te()`/`pm()` sum every path)
and #82 (`confint(parm = "paths")` finds rows by name, errors instead of guessing).

## Evidence gathered before asking

- No dependent calls `te()`, `pm()` or `confint()` on medfit objects
  (read-only grep of RMediation, probmed, medsim, mediationverse `R/`).
  RMediation reads `@vcov` by name via its own lookup and errors on a miss.
- CRAN 0.3.2 carries both bugs:
  - `te(SerialMediationData)` is `a * prod(d) * b + c_prime`, which omits
    skip paths (e.g. M1 -> Y) and so is not the total effect.
  - `confint()` path SEs fall back to `diag(vcov)[1:3]` with a warning when
    names are not found.
- Last CRAN acceptance 2026-07-23 (> 2 months ago; cadence not a constraint).

## Decision ledger

### D1. Deprecation protocol for #81/#82 — **bug fixes, no deprecation**

The `[BREAKING]` issue + 2-month deprecation period protects behavior users
rely on; the old outputs were wrong and no dependent uses them. NEWS
behavior-change notes plus the minor bump to 0.5.0 are the notice.
Action: add a `CLAUDE.md` line exempting correctness fixes from the
deprecation period.
Rejected: full protocol (keeps wrong answers for 2 months); issue-only record.

### D2. Release channel — **0.5.0 on GitHub only**

Keeps the 2026-09-23 "no CRAN release yet" decision.
Recommended but rejected: CRAN 0.5.0 now (would fix CRAN users' silent wrong
answers). Also rejected: 0.3.3 CRAN backport of #81/#82 (second branch, new
untested code).
Consequence accepted: CRAN 0.3.2 keeps both bugs until the next CRAN release.

### D3. Notice for CRAN 0.3.2 users — **GitHub issue + README note**

One "Known issues in CRAN 0.3.2" GitHub issue (serial `te()`/`pm()` omit skip
paths; `confint()` path SEs may be position-guessed, with a warning), giving
the fix version and workarounds (`remotes::install_github("data-wise/medfit")`;
total effect from `lm(Y ~ X + C)`), plus a one-line README pointer.

## Open Questions

- What triggers the next CRAN submission? Candidate: probmed's own CRAN
  submission needing medfit >= 0.4.0 features, or a user report of the 0.3.2
  serial bug.

## Next

1. Post the known-issues GitHub issue (needs explicit OK — public content).
2. README note + `CLAUDE.md` exemption line (dev, docs-only).
3. 0.5.0 release checklist in `planning/TODOS.md`, GitHub-only path.
