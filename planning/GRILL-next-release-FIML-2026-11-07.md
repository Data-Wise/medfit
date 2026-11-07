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

## Open Questions

- Wall-clock limit for the pilot and the later per-stage/total caps (set after the pilot).
- Exact remediation method for G3 (declare before any stage-0 outcome exists).
- Named worktree and base commit for the FI-G0..G3 branch.
