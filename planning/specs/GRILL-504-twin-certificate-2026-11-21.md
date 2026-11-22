# GRILL: the #504 twin certificate and the multilevel follow-ups (2026-11-21)

Redacted copy of the session ledger. Decisions 4, 7 and 8 concerned two private research proposals and are
summarized, not reproduced; the proposals live outside this repository. Outcomes are as of 2026-11-21: #504 shipped
as PR #510 (`706049f4`), the literature notes as PR #511 (`a4a8a8a1`).

## Decisions

1. **Ship order.** Ship the twin certificate (standard tier) before any structural fix; file D-start (a two-level
   start-set change, risk tier) as a follow-up gated on a cross-orbit counterexample. Reason: no cross-orbit win in
   84 stress cells, 114 QA cells with an all-orthant oracle and 715 constrained fits; the certificate is local and
   reversible. Risk accepted: the other sign orbit is covered by evidence, not proof; a counterexample would be a
   fifth #504 recurrence. Outcome: shipped in #510. D-start issue not filed.

2. **Traceability.** Add a minimal diagnostics field to the `twolevel_equal_indirect()` result recording a twin
   replacement or an unresolved-by-twin outcome; no `print()` change. Reason: 10 of 454 stress cells moved from a
   number to unresolved and 19 changed value; the object could not say why. Outcome: `twin = list(tried, replaced,
   flipped, f_gain, unresolved)`, experimental.

3. **Priority.** T8 (the 0.20.0 release gate) goes first. Follow-up research work is limited to cheap checks; no
   paper drafting ahead of T8. Reason: T8 and the few-clusters follow-up draw on the same T6 data, and the
   early-paper benefit was asserted, not measured.

4. **Publication risk.** medfit is a public repository, so research proposals stay private and only literature
   notes go in the repo. Outcome: the proposals are in a private vault; the notes are in `planning/specs/`.

5. **Cost versus benefit.** The certificate stays always on: no gate, no opt-out; revisit if users complain
   (bootstrap about 1.8 times longer elapsed, 2 to 4 times CPU per call). Reason: benefit measured at 6 to 8 of 84
   hard stress cells and 0 of 12 donttest seeds; a gate on opposite-sign free indirects rests on 8 cells, and a miss
   is a silent wrong LR.

6. **Covariance-stage twin error.** A better twin that fails only at the covariance stage is treated like an
   inadmissible better twin: unresolved, matching the documented contract, when its objective value is reachable
   without touching risk files. Outcome: shipped in #510 (`medfit_sem_covariance_error$partial$f`).

7. **Independent review verdicts on the proposals.** Summarized only: neither proposal was publishable stand-alone as
   written; one check order was fixed (read Zigler and Ye 2019 against T6 first). Detail is in the private proposals.

8. **Identification check for the boundary-product proposal.** Summarized only: a bounded derivation, the agent's own
   and unreviewed, reduced that proposal to a documented conjecture plus a calibration note. One side finding feeds
   T8 and is carried in decision 9.

9. **Weak-identification check on T6 (inference, 2026-11-21).** Data: `planning/studies/few-clusters/T6-cells.csv`,
   arm p0, NIE_B, medians over n and balance. T6 scales every between variance together
   (`s = ICC_X / (.7 (1 - ICC_X))`), so the level-2 mediator variance cannot be varied apart from the others. Result:
   consistent with, but not isolating, weak identification of the between-level mediator slope. At ICC_X .05 the
   unconditional coverage equals availability (for example .229 vs .229 at J = 10), conditional coverage is .96 to
   1.00, and the delta interval is about 5.7 wide at J = 10 against about 1.05 at ICC_X .40. Conditioning on a clean
   fit is a selection, so under-coverage among failed fits is invisible. At the alternative (NIE_B = .18, ICC_X .2
   and .4, J >= 20) delta conditional coverage is .915 to .939 against .951 to .961 for Monte Carlo.
   For T8: report conditional and unconditional coverage together, prefer Monte Carlo over delta for NIE_B, and add
   a grid that varies the level-2 mediator variance alone only if the T8 decision turns on it.

## Open

- D-start follow-up issue: not filed (decision 1).
- Single-level nonlinear constraints (`cp == a*b`, `a*b > k`) were not checked for the sign-twin structure.
- Not run for #510: the REPS = 2000 simulation baseline and the OpenBLAS runner (first hosted run is the 0.20.0
  release PR).
