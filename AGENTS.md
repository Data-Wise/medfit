# AGENTS.md for medfit Package

## Working contract

S7 mediation infrastructure, not an effect-size package. Preserve supported data classes and extraction contracts; validate inputs/..., covariance/path aliases and unsupported products explicitly. Central effect-gradient builder is authoritative. Serial total effects include every path; cluster mediation uses b_between with documented approximation warnings; parallel lm/glm covariance limitations must be disclosed.
R >=4.1; native pipe, explicit namespaces, checkmate/S7 validation, on.exit cleanup. Export generics/constructors, not S7 methods; register classes before methods and preserve load order. Generate Rd via roxygen; use ASCII alternatives for math. All public topics belong in pkgdown.
Required: document/test/check, relevant numerical oracles, reproducible bootstrap/parallel tests, failure/edge cases and docs verification. Coverage >90% overall and 100% critical paths. Native SEM changes additionally require the reference's full constraint/Jacobian/Hessian, all-row acceptance, zero-product branch and restart gates; never replace them with optimizer success alone.
Before CRAN work read the strict CRAN checklist: depends/suggests-only flags, URL/spelling checks, platform checks, reverse dependencies and fresh cran-comments. Maintainer/manual submission only; preserve current GitHub-only/submission holds and consult .STATUS. Breaking changes require documented migration/deprecation; correctness exceptions still require dependent checks.

## On-demand requirements

The exact pre-condensation instructions are preserved in `/Users/davood/.codex/reference/repos/r-packages-active-medfit/AGENTS-detail-2026-10-12.md`. Before a task, read only its applicable sections: scientific/model changes, builds/tests, source conventions, dependency/API changes, packaging/releases, configuration/imports, deployment, or workflow cleanup. Every applicable requirement and verification gate there remains binding; this shorter file does not waive any. Do not load the whole reference for unrelated tasks. Historical versions, counts, results and completed-work snapshots are not live status: check the owning source and .STATUS. Current user instructions and project holds take precedence.

Preserve unrelated changes and concurrent sessions. Required checks must pass before claiming completion; inspect actual rendered artifacts where applicable. Author review/submission holds remain active until explicitly lifted. Passing checks never authorizes submission, merge, release, deployment, email sending or privacy changes.
