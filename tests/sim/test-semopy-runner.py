"""Exercise the runner's optimizer boundary without installing semopy."""
import csv
import importlib.util
import pathlib
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

for name in ("numpy", "pandas", "scipy", "semopy"):
    sys.modules[name] = types.SimpleNamespace(__version__="test")

spec = importlib.util.spec_from_file_location("semopy_runner", pathlib.Path(__file__).with_name("semopy-oracle.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class OptimizerTest(unittest.TestCase):
    def test_nonconvergence_writes_failed_job(self):
        class Model:
            def __init__(self, text):
                pass

            def fit(self, data, **kwargs):
                return types.SimpleNamespace(success=False, message="planted nonconvergence")

            def inspect(self, **kwargs):
                raise AssertionError("inspection must not run after nonconvergence")

        with tempfile.TemporaryDirectory() as temp:
            model = pathlib.Path(temp, "model.txt")
            model.write_text("M ~ X")
            jobs = pathlib.Path(temp, "jobs.csv")
            out = pathlib.Path(temp, "out.csv")
            with jobs.open("w", newline="") as f:
                w = csv.DictWriter(f, fieldnames=["id", "model_file", "data"])
                w.writeheader()
                w.writerow({"id": "a", "model_file": model, "data": "unused"})
            with patch.object(runner.semopy, "Model", Model, create=True), \
                    patch.object(runner.pd, "read_csv", return_value=None, create=True):
                runner.main(jobs, out)
            with out.open() as f:
                rows = list(csv.DictReader(f))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["fit_ok"], "FALSE")
            self.assertIn("planted nonconvergence", rows[0]["error"])


if __name__ == "__main__":
    unittest.main()
