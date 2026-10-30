"""Local regressions for the coverage scope decision (standard library only)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import coverage_scope


class CoverageScopeTests(unittest.TestCase):
    def test_only_explicit_metadata_is_skipped(self):
        self.assertFalse(coverage_scope.requires_coverage(
            [".STATUS", "CLAUDE.md", "AGENTS.md", "planning/nested/plan.md"]))
        for path in ("R/model.R", "tests/testthat/test-model.R", "tests/sim/gate.R",
                     "DESCRIPTION", "NAMESPACE", ".Rbuildignore", "renv.lock",
                     ".github/workflows/test-coverage.yaml", ".github/scripts/coverage_scope.py",
                     "vignettes/tutorial.qmd", "README.md", "planning/study.R",
                     "planning/results.csv", "unknown", "nested/CLAUDE.md"):
            with self.subTest(path=path):
                self.assertTrue(coverage_scope.requires_coverage([".STATUS", path]))
        self.assertTrue(coverage_scope.requires_coverage([]))

    def test_main_and_unknown_events_always_run(self):
        for event_name, ref in (("push", "refs/heads/main"), ("release", ""),
                                ("workflow_dispatch", "refs/heads/dev")):
            self.assertTrue(coverage_scope.decide(event_name, ref, {}))

    def test_missing_zero_or_invalid_revisions_run(self):
        for before in (None, "0" * 40, "not-a-sha", "--help"):
            self.assertTrue(coverage_scope.decide("push", "refs/heads/dev",
                                                 {"before": before, "after": "a" * 40}))
        self.assertTrue(coverage_scope.decide("pull_request", "refs/pull/1/merge", {}))

    def test_unavailable_history_runs(self):
        with patch.object(coverage_scope.subprocess, "run", side_effect=OSError("missing git")):
            self.assertTrue(coverage_scope.decide("push", "refs/heads/dev",
                                                 {"before": "a" * 40, "after": "b" * 40}))

    def test_real_event_ranges_deletions_and_renames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*args):
                return subprocess.check_output(["git", "-C", directory, *args], text=True).strip()

            def commit(path, text):
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text)
                git("add", "--all")
                git("commit", "-qm", "fixture")
                return git("rev-parse", "HEAD")

            git("init", "-q", "-b", "dev")
            (root / ".git/info/exclude").write_text("/event.json\n/output\n")
            git("config", "user.name", "Coverage fixture")
            git("config", "user.email", "fixture@example.invalid")
            base = commit(".STATUS", "initial")
            code = commit("R/model.R", "code")
            head = commit(".STATUS", "metadata")
            script = Path(coverage_scope.__file__).resolve()

            def decision(event_name, event, expected, ref="refs/heads/dev"):
                event_path = root / "event.json"
                output = root / "output"
                event_path.write_text(json.dumps(event))
                output.write_text("")
                env = dict(os.environ, GITHUB_EVENT_NAME=event_name, GITHUB_REF=ref,
                           GITHUB_EVENT_PATH=str(event_path), GITHUB_OUTPUT=str(output))
                subprocess.run(["python3", str(script)], cwd=root, env=env, check=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                self.assertEqual(output.read_text().strip(), f"run_coverage={str(expected).lower()}")

            # The last commit alone is metadata; the complete push/PR includes code.
            decision("push", {"before": base, "after": head}, True)
            decision("pull_request", {"pull_request": {"base": {"sha": base},
                                                        "head": {"sha": head}}}, True)
            decision("push", {"before": code, "after": head}, False)
            decision("push", {"before": code, "after": head}, True, "refs/heads/main")
            decision("push", {"before": head, "after": head}, True)
            decision("push", {"before": "a" * 40, "after": head}, True)
            # A PR excludes changes made only on its base branch after divergence.
            git("checkout", "-qb", "feature", base)
            feature = commit("planning/plan.md", "metadata")
            decision("pull_request", {"pull_request": {"base": {"sha": head},
                                                        "head": {"sha": feature}}}, False)
            git("checkout", "-q", "dev")
            (root / "planning").mkdir(exist_ok=True)
            git("mv", "R/model.R", "planning/renamed.md")
            git("commit", "-qm", "rename")
            renamed = git("rev-parse", "HEAD")
            decision("push", {"before": head, "after": renamed}, True)
            odd = commit("R/odd\nname.R", "code")
            decision("push", {"before": renamed, "after": odd}, True)
            git("rm", "R/odd\nname.R")
            git("commit", "-qm", "delete")
            decision("push", {"before": odd, "after": git("rev-parse", "HEAD")}, True)
            # A truncated event file must not suppress coverage.
            (root / "event.json").write_text("{")
            env = dict(os.environ, GITHUB_EVENT_NAME="push", GITHUB_REF="refs/heads/dev",
                       GITHUB_EVENT_PATH=str(root / "event.json"), GITHUB_OUTPUT=str(root / "output"))
            (root / "output").write_text("")
            subprocess.run(["python3", str(script)], cwd=root, env=env, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual((root / "output").read_text().strip(), "run_coverage=true")


if __name__ == "__main__":
    unittest.main()
