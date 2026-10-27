# The semopy oracle for the native engine (ADR D-13; tests/sim/semopy-oracle-gate.R). Generalizes
# tests/sim/oracles/semopy-simple.py (the crosswalk article's single-model fixture) to a list of jobs.
# Run through uv, pinned, isolated (no sibling imports, no user site):
#   uv run --with semopy==2.3.11 python -I tests/sim/semopy-oracle.py jobs.csv out.csv
# jobs.csv: id, model_file (semopy syntax), data (CSV). out.csv: one row per inspect() row, or one row per failed job.
# Conventions, matched on the R side: obj="MLW" (normal-theory ML, covariance with denominator N), ftol 1e-12 (the
# default SLSQP stop leaves estimates about 4e-5 from the optimum), observed-information SEs (semopy's default is
# expected information, about 3e-3 relative off on a latent model).
import csv
import platform
import sys

import numpy
import pandas as pd
import scipy
import semopy

VERSIONS = {"semopy": semopy.__version__, "python": platform.python_version(), "numpy": numpy.__version__,
            "scipy": scipy.__version__, "pandas": pd.__version__}
FIELDS = ["id", "fit_ok", "error", "lval", "op", "rval", "estimate", "se", "fixed"] + list(VERSIONS)


def fit_one(job):
    with open(job["model_file"]) as f:
        model = semopy.Model(f.read())
    data = pd.read_csv(job["data"])
    result = model.fit(data, obj="MLW", options={"ftol": 1e-12})
    if not getattr(result, "success", False):
        raise RuntimeError(f"semopy optimization failed: {getattr(result, 'message', 'no success result')}")
    tab = model.inspect(information="observed")
    rows = []
    for _, r in tab.iterrows():
        fixed = str(r["Std. Err"]).strip() == "-"
        rows.append({"lval": r["lval"], "op": r["op"], "rval": r["rval"], "estimate": repr(float(r["Estimate"])),
                     "se": "" if fixed else repr(float(r["Std. Err"])), "fixed": "TRUE" if fixed else "FALSE"})
    return rows


def main(jobs_csv, out_csv):
    with open(jobs_csv) as f:
        jobs = list(csv.DictReader(f))
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for job in jobs:
            base = {"id": job["id"], **VERSIONS}
            try:
                rows = fit_one(job)
            except Exception as e:  # a failed fit is a row, not a crash: the gate counts it as an error
                w.writerow({**base, "fit_ok": "FALSE", "error": f"{type(e).__name__}: {e}"[:300]})
                continue
            for r in rows:
                w.writerow({**base, "fit_ok": "TRUE", "error": "", **r})


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
