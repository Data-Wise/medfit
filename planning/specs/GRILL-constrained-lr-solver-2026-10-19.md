<!-- Copied from Data-Wise/mbco-lrt:docs/specs/GRILL-medfit-solver-v2-2026-10-19.md at f8d1f9d (2026-10-19). The authoritative copy is there; edit there first. -->

# GRILL: medfit solver plan v2 (2026-10-19)

Target: `docs/planning/PLAN-medfit-solver-2026-10-19.md` (v2, d39817a). Hardest first.

## Decision ledger

### 1. A failed branch fit

- **Decided:** report the statistic as unresolved: no p-value. Name the failed branch and the reason,
  and suggest a remedy (fix the identification; Tier 2 on that branch).
- **Also report the bound.** The minimum over the accepted branches is an **upper bound** on the LR
  statistic: LR = min_j LR_j ≤ min over accepted j.
- **The bound settles only non-rejection.** If the bound is below the critical value, the test does
  not reject. If it is above, the result stays unresolved. (Claude's note on the direction; the grill
  option said "often enough to decide".)

### 2. Which constraints Tier 1 accepts

- **Decided:** any user constraint that can be parsed as an expression. It is classified with
  `stats::D()`, and its singular strata are found automatically.
- **Recommended instead:** only the constraint types medfit generates itself. Rejected.
- Follow-up in branch 3 (guardrails).

### 3. Guardrails for parsed expressions

- **Decided:** a polynomial whitelist plus a cap on strata.
  - Accept only expressions built from `+`, `-`, `*`, numeric constants and free-parameter labels.
    This is checked on the parse tree, not with `D()`.
  - The constraint must be multilinear in the pivot.
  - Enumerated singular strata are capped (e.g. 64).
- Any other operator, or more strata than the cap, goes to Tier 2 with a message.
- `D()` is not relied on for classification.

### 4. Replacing SLSQP

- **Decided:** the new path becomes the default: Tier 0, then Tier 1, then AUGLAG.
- NEWS says constrained results may change, and why.
- `solver = "slsqp_legacy"` reproduces the old results, with a deprecation warning, for one or two
  releases.

### 5. Timing

- **Decided:** run the §5 benchmark now, in `docs/strategy/ideation-checks/`. It also supports the
  paper's point that optimizer choice does not fix the problem, and D6.
- Implement in medfit after M3 (D13).

### 6. The csolnp backup

- **Decided:** automatic when Rsolnp is installed. The result always records which solver produced
  it, with a message.
- When Rsolnp is absent, the unresolved result says "install Rsolnp to try the backup solver".

### 7. Report format

- **Decided:** all diagnostics go in a `diagnostics` slot of the S7 result, as one row per branch or
  stratum.
- `print()` shows one line (tier, solver, status, optima found) plus any warning.
- `summary()` shows the full table.

## Handoff

Plan v2 is approved with these decisions and recorded in D16, the plan (§7), `.STATUS` and the task
list.
