# medfit harness tools registry

Agents and skills name a **role**; this table says which tool fills it. Status as of 2026-10-24; no tool was
installed for the harness (tool discovery was declined), so every row is an existing tool.

| Role | Preferred tool | Alternative | Status |
|---|---|---|---|
| SEM oracle (unconstrained, fixed.x, meanstructure, `:=`) | lavaan (Suggests) | OpenMx | available |
| SEM oracle (constraints, bounds, nonlinear) | OpenMx (Suggests) | lavaan for linear constraints | available |
| Third-party oracle (Python) | semopy 2.3.11 via `uv run --with semopy==2.3.11` | lavaan | optional, not a QC oracle yet |
| Test runner | `devtools::test()` / `testthat::test_file()` | `R CMD check` | available |
| Local gate for `dev` | `scripts/check-local.sh` | `devtools::check()` | available |
| Lint | `lintr::lint_package()` | — | available |
| GitHub (PRs, checks, logs) | `gh` CLI | GitHub web | available |
| R package workflow helpers | rforge plugin (`/rforge:*`) | devtools directly | available |
| Adversarial design review | Codex (`/codex:adversarial-review`) | a fresh `general-purpose` reviewer agent | available |
| Spelling | `spelling::spell_check_package()` with `inst/WORDLIST` | — | available |
