# FI-B final test correction 2: pre-execution work declaration

2026-11-01. No new source fixture, model, numerical tolerance or statistical study.
Reuse the previously frozen MAR/free and MCAR/zero sources in test-bootstrap-fiml.R.
Each focused package-test run creates two source fits and performs the existing two
actual row refits; added branch and mutation tests reuse the cached MAR/free fit and
mock all additional refits. No new test block invokes an actual fitter.

Authorized local commands, all through the budget runner, BLAS/OMP/MKL/VECLIB/NUMEXPR
one and maximum two fork workers:

1. Read the saved immutability diagnosis and class descriptors: zero fits.
2. Focused covr red reproduction with the original whole-serialization assertions
   and added automatic branch regressions: four existing native invocations.
3. After the snapshot correction, focused native test_file bootstrap-fiml and
   bootstrap-fiml-execution: four existing native invocations.
4. Focused covr instrumented installed-package test_package filter ^bootstrap-fiml:
   four existing native invocations. Enforce bootstrap-fiml.R 100 percent expression
   coverage and classes.R summary-label/status expressions covered; no exclusions.
5. Loaded-package lint of changed helpers/tests and staged whitespace/credential checks:
   zero fits.

Maximum newly declared correction work: twelve existing-fixture native source/refit
invocations across those three focused executions, zero lavaan calls. No matrix or
full-suite retry. Failed attempts count cumulatively. Actual completion/partial work
and command wall/CPU are recorded in implementer.md and verification.jsonl.

Attempt accounting and final retry declaration, before further verification: the
first two native snapshot attempts each used two existing source fits and zero row
refits before failing. An explicit NULL base case did not fix the actual cause:
recursively visiting attributes of a named attribute list creates another named
attribute list indefinitely. Capture names explicitly and omit only that redundant
names attribute from recursive traversal; preserve every named value and other
attribute. No production code changes.

The coordinator authorized exactly one retry within this QA correction loop. Its
helper/mutation proof must reuse saved qa-matrix.rds accepted sources (zero fits).
Then run ONE focused installed/instrumented green covr check with the two existing
sources and two existing row refits (four calls). No additional native focused file
run is authorized. Total correction limit remains twelve actual existing-fixture
native invocations (4 red covr +2 failed native +2 failed native +4 green covr), zero
lavaan/matrix calls. Earlier failed usage and receipts remain recorded, with no reset.

## Maintainer-authorized amendment, before execution

The maintainer explicitly authorized one further narrow helper correction and four
additional existing-fixture calls. Recursively describe calls/expressions and every
attribute value, including source-reference vectors; preserve constructor identity,
function bodies/formals/environment identity, named metadata and all mutation tests.
Do not serialize opaque language/source-reference objects whose environments expose
unrelated runtime closure header flags. Do not change production behavior or tests'
numeric tolerances/exclusions. Namespace and source-file environments are compared
by identity, rather than serializing their mutable runtime parent environments.

Before the one instrumented run, execute correction2-saved-proof.R against saved
accepted sources with mocked refits (zero actual fits), including the mutation
regression and both routes' invariance. Then run correction2-coverage.R with phase
amendment (same zero-failure/134-expression/summary-line assertions as green), exactly
two existing source fits and two existing row refits. No separate native focused
file run, matrix or full-suite retry. Loaded-package lint and staged checks add zero
fits. Total correction allowance becomes sixteen calls: twelve already used plus
at most four extra; prior failed evidence/time remains cumulative. Original four-hour
wall/eight-hour CPU caps and maximum two workers remain, with numerical threads one.
