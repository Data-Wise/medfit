# Native-guide bounded FIML fixture correction

Status: active; authorized local documentation correction only.

## Scope and acceptance

- [ ] T1 Docs: replace binary-X FIML data with reproducible continuous Gaussian
  random-X data and independent disturbances. Preserve RNG state, explicit opt-in,
  defaults, ignorable missingness and support boundaries. Keep unrelated examples
  unchanged. Add an executable article-code regression guard; verify both entry
  points and detection of a binary-X substitution.
- [ ] T2 Render the changed article with this checkout in an isolated library;
  inspect actual HTML and record provenance. Run docs consistency and spelling
  checks. Inventory related help/site prose and correct only real gaps.
- [ ] T3 Final local gates: focused checks, full suite, lint, risk classification
  and docs checks. Save exact counts. Reconcile status and commit locally.

## Pipeline and limits

Docs-only: medfit-docs -> medfit-gates (final). Reports:
`_agents_workspace/fiml-native-guide-fixture/{docs,gates}.md`.
Each ends with exactly one `Verdict: PASS` or `Verdict: FAIL`.
One corrective retry after a failed stage, then stop for authorization.
Track new files before rendering. No production R edits or support expansion.
No push, PR, deployment, release, dev-to-main merge, or expensive CI.
Coverage stays main PRs/main pushes only. Preserve unrelated changes.
