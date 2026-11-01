# Proposed FIML admission grid and decision power

2026-11-01. **Proposal for independent review; no pilot or FIML study has been
run or authorized.** Code baseline: merged dev commit `0bd99134d61837c1b1efffddc01ef7bb3d739743`.
Implementation integration and numerical QA do not establish coverage.

## Owners

| Responsibility | Assigned owner | Deliverable |
| --- | --- | --- |
| Statistical design and deterministic power | Codex, current session | This proposed grid, assumptions and calculation |
| Study tooling | `medfit-implementer` | Runner and ledger, after design review |
| Independent statistical and numerical QA | `medfit-oracle-qa` | Independent design, power, code and result review |
| Documentation and status | `medfit-docs` | Reconcile current merged status and claims |
| Verification gates | `medfit-gates` | Applicable checks and evidence |
| Scope, budget and admission decisions | Davood, maintainer | Explicit decisions and execution authorizations |

Assignments identify responsibilities, not completed work or acceptance by
future reviewers. The actual QA reviewer must be independent of the designer.

## Scientific design

Aim: assess interval availability and coverage for the implemented random-X,
continuous Gaussian simple mediation model. Generate independent retained
datasets with `X ~ N(0,1)`, `M = a X + eM`, and `Y = c X + b M + eY`,
where `eM` and `eY` are independent standard normal and independent of X;
intercepts are zero. Truth: NIE = `a*b`, NDE = `c`, TE = `c+a*b`. The target
is conditional on retaining nonempty records, at fixed retained sample size.
These are statistical model effects; no broader causal claim is implied.

Cross the following factors: 2 retained sample sizes x 5 path regimes x 3
missingness regimes x 2 direct-path specifications = **60 data-generating
cells**. For each, propose 2,500 attempted datasets, 999 row refits and 20,000
joint Gaussian parameter draws per dataset, and report NIE, NDE and TE for both
methods. These counts and factor choices are proposals, not approvals.

| Factor | Proposed values |
| --- | --- |
| Retained n | 200, 500 |
| Paths (a,b) | (.4,.4); (0,.4); (.4,0); (0,0); (1/sqrt(n), 1/sqrt(n)) |
| Direct path | free with true c=.2; exactly fixed c=0 |
| Missingness | MCAR; observed-X MAR; all-empty MCAR, defined below |

For ordinary MCAR, X is observed and M and Y are independently missing with
probability .20 each, independently of full data. For MAR, X is observed and M
and Y are independently missing conditional on X, each with probability
`plogis(log(.2/.8) + .5*X)`; their marginal rates are not exactly .20. For
all-empty MCAR, first independently mark the entire record empty with
probability .10; otherwise apply the ordinary MCAR mechanism. Continue collecting
until n nonempty records are retained; record both collected and retained
counts, including all empty records. Independently generated rows and independent
whole-row deletion make the latter retention normalization parameter-independent;
the retained full-data distribution is unchanged in this proposed cell. Review
positivity, identification, ignorability and parameter distinctness explicitly;
do not generalize this argument to value-dependent deletion or MNAR.
Before any authorization, define one attempted dataset, a finite collection cap,
and the prespecified classification and denominator treatment if that cap is
reached before n rows are retained. The cap and seed policy are unresolved;
the current conceptual collection loop is not an executable protocol.

The local sequence is indexed by n and is a separate characterization regime,
despite nonzero gradients at each finite n. The axis nulls with nonzero other
path are regular. When c is free, NDE and TE have nonzero gradient in all five
path regimes; NIE is regular only in the first three. When c is fixed, NIE and
TE are regular only in the first three regimes, while NDE is the deterministic
zero functional. Pending independent review, classify joint-null and local NIE
(and TE when c is fixed) as characterization, and fixed-zero NDE as a structural
zero contract, not a regular stochastic gate. Check availability and exact-zero
behavior for the latter; do not manufacture a coverage success when an interval
is unavailable. Any change to this classification changes the family and
requires recalculation and approval.

Thus the regular admission family contains **228** method/quantity/cell
decisions: free c: `(3 NIE + 5 NDE + 5 TE) x 2 n x 3 mechanisms x 2 methods =
156`; fixed c: `(3 NIE + 3 TE) x 2 n x 3 mechanisms x 2 methods = 72`.
The remaining 132 of 360 combinations are 72 nonregular characterization
decisions and 60 structural-zero checks. Characterization and structural-zero
results are reported separately; this proposal does not claim uniform validity.

### Proposed complete-stage decision

The complete first stage encompasses all 60 data-generating cells, both methods
and all three quantities. Its decision is **admit** only if all 228 regular
decisions meet all three existing Q10 gates, the structural-zero contract below
passes, the expected-record and source checks pass, and the prespecified joint-
null/local-to-joint-null characterization and limitations are reported and
reviewed. An unmet regular gate or structural-zero violation blocks admission;
missing evidence, no returned interval for a structural-zero combination, an
unresolved deviation, or an incomplete ledger makes the stage inconclusive.
Nothing is pooled away or automatically accepted. The maintainer makes the
recorded stage decision after independent QA. Later model variants retain their
own separately preregistered complete-stage decisions.

For each of the 60 fixed-direct-zero NDE/method/cell combinations, the
maintainer selected the same Q10 availability gate: its one-sided exact 95%
lower bound must be at least .95, using all attempted datasets as denominator.
The structural contract also requires exact zero for every returned NDE estimate
and both interval endpoints. Record unavailable intervals and every failure
against all attempts; never count them as coverage.
An observed nonzero or nonfinite value in a purported success fails the contract.
The exact-zero condition is a correctness check for a constant functional, not
an inference claim at a regular point. For M=2500, availability requires at
least 2394 returns; if all returned intervals are exactly zero, the Q10
conditional coverage and joint usable-and-covering bounds also pass. The joint-null and local
characterization results are reported as limitations, not subjected to a new
numerical acceptance threshold. Review and freeze this operational rule before
any outcomes; the availability interpretation and exact-zero check were selected
by the maintainer on 2026-11-01 and require independent verification before the
study design is frozen.

Both methods use the implemented type-7 2.5% and 97.5% quantiles. Row bootstrap
resamples retained rows and withholds an interval after any required failed
refit; parameter intervals use joint Gaussian draws from the fitted covariance.
Freeze the exact API, algorithm, fit-failure policy and whether draws/refits can
be shared across effects only after implementation review. Every dataset and
failure remains in the ledger. Pilot and confirmatory RNG streams must be
disjoint; seed allocation, workers, caps and environment remain to be frozen.

## Exact design calculations

For each regular combination Q10 requires one-sided exact 95% binomial lower
bounds of at least .925 for conditional coverage among returned intervals,
.95 for availability among attempted datasets, and .90 for joint availability
and coverage among attempted datasets. Zero returns cannot pass.

For independent attempted datasets at true availability `a` and conditional
coverage `c`, calculate `A ~ Bin(M,a)` and `C | A ~ Bin(A,c)`. Sum the exact
probability of meeting all three gates using the shared numerator C. For the 228
decisions use the union-bound lower limit `max(0, 1-228*(1-p))`; it does not
assume independence between decisions and is a bound for **regular gates only**,
not the full-stage decision, which also includes the structural-zero and
completeness requirements above.
The reference supposes each decision has `a=.98, c=.95`; these are design
assumptions, not observed performance. Q12 requires >=.90 per decision and
>=.80 complete-stage power under the reference.

| M | Per-decision reference pass probability | 228 regular-gate lower bound |
| ---: | ---: | ---: |
| 500 | .646571 | 0 |
| 1,000 | .929267 | 0 |
| 2,000 | .998245 | .599895 |
| 2,500 | .999766 | .946622 |
| 3,000 | .999970 | .993114 |

`M=2500` meets the per-decision target and gives a .946622 lower bound for the
regular gates under these assumptions. That does **not** establish the Q12
complete-stage power target: the probabilities of passing structural-zero and
completeness checks must also be specified and bounded, with their dependence
accounted for, before a complete-stage power conclusion is possible. The
reference probabilities alone do not supply those probabilities. `M=2500` is
not yet a feasible or approved study. It costs
at least 150,000 source datasets, 149,850,000 row refits and 3 billion parameter
draws if one draw/refit set can be shared among effects. Separate API calls,
optimizer starts and failures can increase cost; exact sharing, compute budget
and feasibility are unresolved. Increasing B may reduce availability under the
strict all-refit rule. Do not infer availability from pooled refit failure rates.

The IID dataset calculation uses `c = P(cover | interval returned)`, not
unconditional coverage. It permits failure and a potential coverage outcome to
be associated: `a`, `a*c` and `a*(1-c)` define the observed dataset categories.
It does not establish that coverage among returned intervals represents all
datasets. Independence across attempted datasets and common category
probabilities within a cell are assumptions to justify; the union bound does
not require independence across methods or cells. Under a hypothetical fixed
dataset with IID refit failures, 98% all-refit success at B=999 implies an
individual-refit failure probability of about 0.0000202. This is not empirical
evidence for the reference availability; dataset heterogeneity and dependence
can invalidate that illustration. Assess feasibility only in a separately
specified and authorized pilot, retaining every failure and timeout.

**Maintainer-selected planning reference, 2026-11-01:** additionally assume
98% availability for each structural-zero combination, exact-zero correctness
whenever an interval is returned, and complete, valid records and execution.
For independent datasets, a structural-zero availability gate then fails with
probability approximately 9.21e-13 at M=2500. A union bound over 228 regular
decisions and 60 structural-zero availability decisions gives a conditional
lower bound of approximately .946622 for all those gates together, without
assuming independence across methods, quantities or cells. Completeness,
correctness and the review decision are assumed to pass in this calculation;
they have not been established as certain. Therefore this is not an
unconditional complete-stage power guarantee or independent QA sign-off.
The reference assumptions must be justified and the complete-stage decision
reviewed before Q12 can be considered satisfied.

The maintainer also selected one complete stage covering both methods and all
prespecified effects; characterization without a new numerical threshold for
joint/local nulls, subject to the existing correctness hold; and study claims
limited to observed-X retained-row regimes without changing the implemented
scope. M=2500 remains provisional. If unaffordable, defer admission pending a
separately reviewed budget or pre-outcome design decision; do not silently
weaken thresholds or drop cells. Timing pilots and studies require separate
authorization.

Sensitivity for M=2500, probability of all three gates passing per decision:

| Conditional coverage | availability .97 | availability .98 | availability .99 |
| ---: | ---: | ---: | ---: |
| .93 | .086468 | .227319 | .229932 |
| .94 | .637240 | .897183 | .900953 |
| .95 | .983665 | .999766 | .999799 |
| .96 | .999744 | ~1 | ~1 |

These are sensitivity results, not high-power guarantees away from the chosen
reference. The CSV gives all computed combinations and family bounds.
`Rscript --vanilla planning/studies/fiml-admission-design/power.R` reproduces the
deterministic results; it runs no model fits or simulations. It cross-checks the
reference probability by independently conditioning on the covering count
instead of the available count, and checks critical counts by binomial-tail
inversion, both to `1e-10` or tighter. This is a computational cross-check by
the design author, not independent QA sign-off.

## Before any run

Independent QA must review the grid, retention argument, method availability,
regularity classification, complete-stage rule, structural-zero contract,
complete-stage power and computational cost. The maintainer must agree the
design and budget. Freeze the final source,
expected-record ledger, seeds and decision rules before outcomes. A bounded,
separately authorized timing pilot may then assess feasibility only. A
confirmatory study requires its own separate authorization; no pilot or study is
authorized by this proposal.
