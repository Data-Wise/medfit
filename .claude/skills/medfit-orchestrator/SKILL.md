---
name: medfit-orchestrator
description: Entry point for medfit plan-task work - invoke before starting any task from a medfit PLAN (planning/PLAN-*.md), a native SEM engine fix, or a re-run of one. Triages the request, then runs the implement -> oracle QA -> gates -> docs pipeline with the medfit agents in a feature worktree and opens the PR. Triggers - "start T<n>", "next task", "implement the plan", "fix this engine bug", "re-run QA", "update the previous result", "redo the gates", "improve the PR", "supplement the tests".
---

# medfit orchestrator

Coordinates four agents (`.claude/agents/`): `medfit-implementer` (code and tests), `medfit-oracle-qa`
(independent-oracle verification), `medfit-gates` (risk tier, suite, lint, CI), `medfit-docs` (NEWS, roxygen,
articles). Execution mode: **subagents**, in sequence. The stages hand work forward through files and do not need to
talk mid-task, so a team would add coordination cost without benefit. Pattern: pipeline with a producer-reviewer loop
between implementer and QA.

## Phase 0: intake and triage
1. A question, a read-only explanation, a status check or a one-line edit: answer it directly and stop. Do not spin
   up agents for trivia.
2. Out of domain (another repo, release engineering, CRAN submission): say so and stop. Release work follows the
   user's release process, not this pipeline.
3. In domain: find the task. Read the active plan named under "Active plan" in `CLAUDE.md`. If that
   pointer is missing, stale, completed or names several plans, stop and ask; never pick by modification time.
   Take the task the user named, else the first unchecked task whose dependencies are done.
   Read the task's acceptance criteria, files and verification. The plan file is the source of task state.
4. Context check:
   - **initial run**: no worktree for the task → create one (step 1 below).
   - **follow-up / partial re-run** ("re-run QA", "fix the lint", a CI event): reuse the task's worktree and
     `_agents_workspace/<task>/`; run only the named stage and the stages after it.
5. State the plan to the user in one line (task, stages to run) and proceed. Ask only when the task is genuinely
   ambiguous.

## Phase 1: prepare
- Branch and worktree only on an explicit task request: `git fetch -q origin && git worktree add
  ~/.git-worktrees/medfit/<feature> -b feature/<name> origin/dev`. Never write code on `dev` or `main`.
- Create `<worktree>/_agents_workspace/<task>/` (git-ignored) for the agents' reports.

## Phase 2: implement → QA loop
1. Spawn `medfit-implementer` (type `general-purpose`) with: the task block, the worktree path, the workspace path.
2. Spawn `medfit-oracle-qa` (type `general-purpose`) with: the worktree, the acceptance criteria,
   `implementer.md`. It follows the `medfit-oracle-check` skill.
3. QA FAIL → send the failing cell back to the implementer; at most two loops, then stop and report to the user.
   Send the implementer every QA finding and flag in one message, not one at a time; a re-QA pass checks the changed
   behavior, numeric neutrality against `origin/dev`, and the planted defects, not the whole checklist again.

## Phase 3: gates
Spawn `medfit-gates` in `pre-docs` mode when a docs stage follows, else in `final` mode (the single pass), with the
worktree and the reports. It follows `medfit-risk-tier`. `pre-docs`: risk tier and checklist, lint, the focused tests
(test files the diff changes or that cover the changed `R/` files, plus `test-gate-coverage.R`, `test-adr-front-matter.R`
and the docs-consistency tests), and the `tests/sim` scripts whose covered paths the diff changes; no full suite. `final`:
everything in `pre-docs` plus the full suite, and the drafted PR body.

## Phase 4: docs, then final gates
If the task changes user-visible behavior, messages or defaults, spawn `medfit-docs` with the gates report (docs-only
tasks start here, with no earlier gates report). Then run `medfit-gates` in `final` mode on the final tree: the one full-suite run, plus lint and the
docs-consistency tests over the docs edits; a docs-caused failure goes back to `medfit-docs`. Skip this phase
only when no docs changed.

## Phase 5: integrate
Enter only when every report required for the run type states PASS: implementation runs need implementer, QA, docs
(when applicable) and final gates; docs-only runs need `docs.md` and final `gates.md`. Any other state stops here and
goes to the user.
A follow-up or CI-fix request never implies authorization to push or open a PR; ask each time.
Every stage that edits files (implementer, QA tests, gate fixes, docs) ends with a scoped commit on the feature branch.
Before pushing, `git status --short` must be empty and `git diff --name-only origin/dev...HEAD` must include every
file the reports cite; otherwise commit or investigate first.
1. Ask the user before pushing and before opening the PR; a task request alone does not authorize either. On
   approval, push the branch and open the PR to `dev` with the gates' body: `gh pr create --base dev --body-file
   <file>`.
2. Tick the task in the plan file only when the plan lives on the same branch or after the PR merges; otherwise note
   it in the report.
3. GitHub Issues: if the task or the PR names an issue, link it in the PR body (`Refs #<n>`); otherwise do not touch
   issues. The plan file stays the single owner of task state.
4. Report to the user: PR link, evidence counts, planted defects, what is not done. Merging is the user's call.

## Data passing
Files, not messages: `_agents_workspace/<task>/{implementer,qa,gates,docs}.md` in the worktree. Each agent reads the
earlier reports and writes its own. Nothing in `_agents_workspace/` is committed.
A report's verdict is its last line, exactly `Verdict: PASS` or `Verdict: FAIL`; a missing, duplicate or
differently worded verdict line is a failed stage, whatever else the report says.

## Error handling
- An agent fails or returns nothing: retry once with the error in the prompt; if it fails again, stop and report the
  stage and error to the user. Every stage is required; none is skipped, and Phase 5 is not reached without a PASS
  report from each.
- Conflicting results (QA says FAIL, implementer says PASS): keep both, with their sources; QA's evidence decides.
- A hook blocks a command: do not retry it; hand the command to the user.
- Never delete data, branches or worktrees without the user's request.

## Tools
Agents refer to tools by role; the registry is `references/tools.md`.

## Test scenarios
- "Start T4b" → triage in-domain → worktree → implement → QA → gates → docs → final gates → ask → PR.
- "Lint failed on #317" → follow-up → gates only, in the existing worktree → ask → push.
- "What does `.sem_vcov()` do?" → answered directly, no agents.
- "Release 0.14.0" → out of this pipeline → stop and say so.
