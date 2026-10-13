# GRILL: native four-way plan (medfit 0.10.0)

| | |
|---|---|
| **Date** | 2026-10-12 |
| **Target** | [PLAN-native-four-way-2026-10-12.md](PLAN-native-four-way-2026-10-12.md) (revised after the Opus review) |
| **Contract** | [SPEC-sem-grammar-amendment-product-2026-10-12.md](SPEC-sem-grammar-amendment-product-2026-10-12.md) (APPROVED) |
| **Status** | 8 decisions (H1-H3 pre-answered from state; H4-H8 asked). Applied to the plan the same day; the plan's three "open decisions for the author" are closed by H5, H6, and H3. |

## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| H1 (pre-answered, shown for override) | U0 (lavaan-route worker fixes) as its own PR before U6? | **Yes, own PR.** The author started the worker-fix chip (`fix/four-way-worker`, task_8445f92b) in a separate session. Closes plan open decision 3. |
| H2 (pre-answered) | Why a native `:` operator rather than a user-supplied product column? | **The validity rules need it.** Without a parsed product term the engine cannot know a column is a product, so rules 8 and 9 and the model-test policy cannot be enforced on a user-supplied column. Keeps G5. |
| H3 (pre-answered) | Dependency order of U0-U10 | **Sound** (the review found no task depending on a later one). Changed only by H8 below. |
| H4 | Does native four-way earn its cost, since the lavaan route already gives four-way? (benefit honesty) | **Proceed, with a go/no-go demand check at Checkpoint A** (recommended): NEWS states the marginal value (no lavaan dependency, weights with the HC0 sandwich, constraints). If no concrete consumer exists at Checkpoint A, U5-U10 stop; the parser and rules stay usable. |
| H5 | When does mean structure switch on for four-way? (riskiest assumption; plan open decision 2) | **Any product term turns saturated mean structure on, in `fit_sem()` and `fit_mediation()`** (recommended, replacing the plan's "fit_mediation only, when four-way is requested"). Reason: `decomposition` is an extraction argument (`R/fit-sem.R:143`), so a fit-time trigger keyed on it fails the `fit_sem()` + `extract_mediation()` path; product models are new syntax, so no existing fit changes. Closes plan open decision 2. |
| H6 | Auto-added pure-outcome residual covariance in product models (blast radius; plan open decision 1) | **Completion fixes it at 0 in product models and prints one note** (recommended). Accepted cost: the product model differs from its no-product twin, visibly; a user who needs the covariance cannot have it with a product in 0.10.0 (same limit as rule 9). Closes plan open decision 1. |
| H7 | Where does U0's behavior change ship? (reversibility) | **Rides in the 0.9.0 release, listed first in NEWS** (recommended). Wrong values exist only in GitHub-only 0.8.0 (CRAN has 0.3.2). Satisfies the CLAUDE.md rule (NEWS behavior note, at least a minor bump). |
| H8 | Can U1-U2 start before 0.9.0 lands? (workflow discipline) | **No: U1+ wait for 0.9.0 T2 to merge** (recommended). 0.9.0 T2 and U1/U2 both edit `R/sem-model.R` (`.sem_to_ram`, the table) and T2 and U3 both touch `R/fit-sem.R`. Only U0 runs in parallel (different files). Supersedes the plan's "U1 may start earlier". |

## Open Questions

- Checkpoint A demand check: what counts as a concrete consumer (a probmed or RMediation request, the author's own use, an issue)? Decide before Checkpoint A, not at it.
- Pre-answered, not asked: in the native engine the default information is observed, so the expected-information refusal (U6) only matters when the user passes `information = "expected"` explicitly; refuse in that case with a product that has an endogenous factor.
- The U7 tolerance against the glm four-way path is derived in U8 (the SEs equal OLS up to `n` vs `n - k` scaling in the rule-9 class).
