# Draft: missingmed D5 adapter change list (2026-10-25)

Plan item C1 of `PLAN-checkpoint2-missingmed-consumer-rerun-2026-10-25.md`. Draft only: read-only inspection of
missingmed `feature/lavaan-mbco-medfit` (`4a84e66`); nothing was edited there. Applying it is missingmed's D5 PR and needs
the author's explicit request.

## Finding
missingmed does not read any of the new D1-D4 names today. A grep of `R/` and `tests/` for `$ledger`,
`diagnostics$outcome`, `medfit_sem_unresolved`, `medfit_sem_covariance_error` and `medfit_error_no_convergence` finds none.
Its adapter (`R/mbco_sem.R`, `.mm_sem_provider`) infers failure from:

| Adapter reads | Where | On medfit `dev` |
|---|---|---|
| `tab$converged`, `tab$f`, `tab$diff_ll` of `mbco_sem()$tests` | `.mm_sem_provider` | still present (`R/sem-mbco.R:286`); unchanged |
| warnings matching `^improper solution:` | notice collector | still emitted (`R/sem-optim.R:549`) |
| `full$improper` from `diagnostics$improper` | improper-null logic | still stored (`R/sem-mbco.R:266`) |
| error message text of a failed full fit | `stop("The full model did not converge or is unresolved: ", ...)` | message unchanged (D-12 keeps the original text) |

So no consumer change is forced by the names. The naming-table rows only matter if D5 starts using the new evidence.

## Proposed D5 changes (all optional until the author says what D5 should consume)
1. Replace message-regex inference of a covariance-stage failure with the class `medfit_sem_covariance_error` and its `$partial`.
2. Read `fit@diagnostics$ledger` (and `$ledger` on `medfit_error_no_convergence`) instead of collecting warnings, for branch and null outcomes.
3. For over-cap models, catch the plain error and read `$ledger` and `not_enumerated`; do not wait for `medfit_sem_unresolved`.
4. Keep `tab$converged` checks as a second guard: MBCO now retains a covariance-failed null with `converged = FALSE`, which the existing check already treats as unresolved.
5. New missingmed tests: one per consumed field, each with a planted defect, plus the stored improper-null input (still missing; missingmed's blocker).

## Not verified
- The closure matrix's "dependency runner" (768) is the chain's medfit-side tests (legacy controls, expression, outcome, literal certificate, branch map, post-fit), not missingmed code. Those were ported as P1-P4 and pass in medfit's own suite, so there is no separate missingmed run to make.
- Whether the retained covariance-failed null changes any missingmed acceptance outcome beyond what the three consumer files cover.
