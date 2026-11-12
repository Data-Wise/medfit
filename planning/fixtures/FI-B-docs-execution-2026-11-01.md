# FI-B documentation execution freeze

Declared before documentation verification on 2026-11-01. No matrix or study is rerun.

The changed FIML minibook chapter retains its existing deterministic seed271/n400
Gaussian source and fixed masks, appended one empty record and two existing source
entry-point fits. One new executed chunk reuses that accepted fit: exactly two row
resamples at seed911 and eight Gaussian parameter draws at seed123; zero additional
source fits and two additional native row-refit calls per chapter render. These
small counts illustrate execution only, not interval accuracy or calibration.
The chapter is rendered once as HTML. Its existing expected-information refusal
invokes no optimizer. No new model, missingness design or statistical study is added.

Changed existing articles bootstrap, native-guide, methods, models, guide-intervals
and extraction retain their pre-existing executable examples and fit counts. Render
each once as HTML with the current source package installed into a task-local library.
All existing example/test runs count toward the shared four-hour wall/eight-hour CPU
verification cap, at most two workers. Focused docs-consistency tests, roxygen/Rd,
spelling and loaded-package lint are allowed; no full-suite execution here. If a
render fails, stop and report its chunk/error rather than disabling execution.

Render amendment before retry: bootstrap parallel example returned NA from detectCores
and was refused before workers launched. The coordinator authorized explicit2L
workers for the example; product defaults stay unchanged. Repeat the failed article
then continue the remaining once-rendered articles/chapter. Retain failed attempt
usage and log; no FIML example or matrix was executed by that failed attempt.

Deviation record: both failed bootstrap renders executed a separate pre-existing
nonparametric example with ncores4 before the audited dynamic-worker chunk. This
briefly exceeded the two-worker bound; no matrix/study or FIML example ran. The
example is now explicit2L, and all changed render sources were searched for worker
settings. Both failed-attempt resource records remain in the cumulative ledger.
The second failure occurred after all chunks, at Quarto Sass-cache database access.
