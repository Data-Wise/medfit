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
3. In domain: find the task. Read the active plan named in CLAUDE.md ("Active plan") or the newest
   `planning/PLAN-*.md`; take the task the user named, else the first unchecked task whose dependencies are done.
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

## Phase 3: gates
Spawn `medfit-gates` with the worktree and the two reports. It follows `medfit-risk-tier`: risk tier, full suite
counts, lint, the drafted PR body.

## Phase 4: docs
If the task changes user-visible behavior, messages or defaults, spawn `medfit-docs`. Docs-only tasks start here.

## Phase 5: integrate
1. Push the branch and open the PR to `dev` with the gates' body: `gh pr create --base dev --body-file <file>`.
2. Tick the task in the plan file only when the plan lives on the same branch or after the PR merges; otherwise note
   it in the report.
3. GitHub Issues: if the task or the PR names an issue, link it in the PR body (`Refs #<n>`); otherwise do not touch
   issues. The plan file stays the single owner of task state.
4. Report to the user: PR link, evidence counts, planted defects, what is not done. Merging is the user's call.

## Data passing
Files, not messages: `_agents_workspace/<task>/{implementer,qa,gates,docs}.md` in the worktree. Each agent reads the
earlier reports and writes its own. Nothing in `_agents_workspace/` is committed.

## Error handling
- An agent fails or returns nothing: retry once with the error in the prompt; then continue without that stage and
  name the omission in the report.
- Conflicting results (QA says FAIL, implementer says PASS): keep both, with their sources; QA's evidence decides.
- A hook blocks a command: do not retry it; hand the command to the user.
- Never delete data, branches or worktrees without the user's request.

## Tools
Agents refer to tools by role; the registry is `references/tools.md`.

## Test scenarios
- "Start T4b" → triage in-domain → worktree → implement → QA → gates → PR.
- "Lint failed on #317" → follow-up → gates only, in the existing worktree → push.
- "What does `.sem_vcov()` do?" → answered directly, no agents.
- "Release 0.14.0" → out of this pipeline → stop and say so.
