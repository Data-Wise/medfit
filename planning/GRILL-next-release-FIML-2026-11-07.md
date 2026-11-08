# GRILL: next-release FIML plan, 2026-11-07

Target: `PLAN-FIML-next-release-model-expansion-2026-11-01.md` and the roadmap board.
Planning decisions only; nothing here authorizes a study, pilot or release by itself
(authorizations below are recorded intent and still need the plan's own activation step).

| # | Branch | Decision | Consequence recorded |
|---|---|---|---|
| G1 | What "next release" means | Goal is finishing FIML for the different models; the release is not decoupled or shrunk. | Critical path is stage-0 admission; expanded variants remain gated by Q13. |
| G2 | First authorization | Timing pilot plus stage-0 preregistration draft first; build FI-G0..FI-G3 in parallel on a branch kept off `dev`. | Affordability is measured before the design is frozen; G0 stays off `dev` until the stage-0 decision (finding R2). Long-lived branch must be kept rebased. |
| G3 | Stage-0 failure response | One pre-registered remediation round (declared now), fresh seeds, failed cells kept as evidence; defer if it also fails. | Program survives a marginal miss with clean provenance; adds one study's cost; the rule must not be stretched. |
| G4 | Cost bound | Hard compute and wall-clock cap set from the pilot's measured cost, per stage and in total; exceeding it forces an explicit rebudget or scope decision. | May show that all 11 variants are unaffordable; numbers chosen after the pilot. |
| G5 | Pilot host and owner | Local machine; `medfit-implementer` and `medfit-oracle-qa`; wall-clock limit set before the run. | Matches the no-expensive-CI rule; limit value still to be set by the maintainer. |
| G6 | Rebudget after the pilot | Pilot accepted as run (cells 11-12 untimed; one call suspended by lid-closed sleep, excluded). Stage-0 cap set to **25 core-days with a smaller design**. | At the preregistered B=999 (~114 s per refit call) 25 core-days buys about 315 datasets per cell (105 if effects need separate refit calls) across 60 cells; deterministic per-decision power at true coverage .95 / availability .98 is about 0.44 (0.09), far below the Q12 target of 0.90 per cell and 0.80 complete-stage. The smaller design must therefore shrink B, the cell count, or both, and be re-derived and independently QA'd before any preregistration; the budget alone cannot meet Q12. |
| G7 | Compute venue and cap (supersedes G6) | Run stage 0 on UNM CARC Hopper with the **full preregistered design** (60 cells, M=2,500, B=999) and a **250 core-day cap**. The 25 core-day cap and the 20-cell reduction are withdrawn. | Read-only look 2026-11-07: general partition 10 nodes x 32 cores, 2-day job limit, debug 2 nodes 4 h; R not on the default path (lmod present); fair-share 0.13. About 198 core-days if one set of refits serves NIE/NDE/TE, about 590 if not (then rebudget again). Nothing submitted: job submission needs the maintainer's approval, and a pinned Hopper R/BLAS/package environment is required before results count. |

## Open Questions

- Later per-stage and total study caps (set after the pilot). **Pilot limit set 2026-11-07: 2 h total wall-clock, 15 min per cell; a cell over 15 min is stopped and logged as a cost finding. Local, no authorization to start yet.**
- Exact remediation method for G3 (declare before any stage-0 outcome exists).
- Named worktree and base commit for the FI-G0..G3 branch.
