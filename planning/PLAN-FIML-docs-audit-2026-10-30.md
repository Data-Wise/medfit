# Bounded FIML documentation audit

Status: active; local documentation work only.
Base: efbba665; branch codex/fiml-docs-audit.

## Scope and acceptance

Audit README, exported help/roxygen, website articles, cookbook, and minibook against current production capability guards. Record a file-by-file support matrix with source anchors: three continuous observed variables; Gaussian random-X simple mediation, free/zero direct path; ignorable missingness and model assumptions; exact opt-in/defaults; free means, observed/model SEs, no weights; supported entry points/extraction; retained/all-empty/unused-column policies; refusals and no global/inferential coverage guarantee. Preserve released-version historical statements. Fix confirmed discrepancies only, no production behavior or support expansion. Regenerate affected Rd from roxygen.

- [x] T1 Inventory public documentation and runtime contracts; record current/gap/not-applicable dispositions and fix confirmed gaps.
- [x] T2 Execute affected examples using an isolated current install; run Rforge static API audit, consistency/spelling checks; render affected pages and inspect final artifacts, recording source/package identity and exit status.
- [ ] T3 Run final local gates (required full suite, lint, package check and risk classification), reconcile status and commit scoped changes.

Docs report: _agents_workspace/fiml-docs-audit/docs.md. Final report: _agents_workspace/fiml-docs-audit/gates.md. Each ends with exactly one Verdict: PASS or Verdict: FAIL line. Failed stage may receive one corrective retry; then stop and request continuation.

No push, PR, deployment, release, main merge, workflow changes or expensive CI. Coverage remains hosted only for main PRs/main pushes. Preserve unrelated changes. Broad FIML features and missingmed adoption remain deferred.
