# Docs proposal after the 0.14.0 work (2026-10-24)

Scope: new docs only. Existing pages already carry the 0.14.0 facts (NEWS, guide-changes row, troubleshooting
messages, refcard and guide setup chunks, lavaan-comparison `compare_lr()` scope).

## Recommended first

The "Native defaults in 0.15.0" migration article: every native user meets the warning, and today the answer is split
across a NEWS entry, one guide-changes row and two troubleshooting rows.

## Quick wins (< 30 min)

1. **Package authors: muffling medfit conditions by class** (accept, as a section of `guide-troubleshooting.qmd`).
   Reader: RMediation, probmed and other dependents. Why: the classes (`medfit_warning_default_change`,
   `medfit_message_fixed_x_lenient`, the `medfit_warning_engine_*` family) are documented one by one; a short
   `withCallingHandlers()` recipe in one place saves each dependent from rediscovering them. Not a separate page.
2. **Agent-harness contributor note** (reject as a site page). Reader: contributors using Claude Code. Why rejected:
   the harness is development tooling, not package behavior; the CLAUDE.md "Agent Harness" section and
   `.claude/` already document it. A pkgdown page would ship tooling detail to users.

## Medium effort (1-2 h)

1. **"Native defaults in 0.15.0" migration article** (accept; `vignettes/articles/native-defaults-0-15.qmd`, Guides
   menu and `_pkgdown.yml` articles index). Reader: anyone calling `fit_sem()` or `fit_mediation(engine = "native")`.
   Why: one page with what changes (`npar`, `logLik()`, AIC/BIC move; structural estimates, MBCO and `anova()`
   differences do not), the three ways to respond (pass both arguments, set the option, muffle by class), and a
   before/after table. Needs a `test-guide-*` entry for each quoted message.
2. **fixed_x semantics section** (accept, in `native-guide.qmd` or the native model page, not a new article).
   Reader: users with covariates. Why: the `~~`/`~1` pairing rule behind the lenient subset and the conditional
   likelihood are stated only in roxygen and a troubleshooting row. Formulas stay in `methods.qmd`; link there.

## Long-term (future sessions)

1. **Oracle matrix / QC article page** (defer). Reader: reviewers and method users judging trust. Why defer: the
   `quality-control` article exists, and the brainstorm plans a generated QC page from `qc-results` (R-4); a
   hand-written oracle matrix would drift from `tests/sim/gates.csv`. Build it as part of R-4, generated from the CSV.
