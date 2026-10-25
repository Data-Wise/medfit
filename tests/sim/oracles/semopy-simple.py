# The simple mediation model in semopy, for the syntax crosswalk article (vignettes/articles/syntax-crosswalk.qmd).
# Run from the package root:
#   Rscript -e 'write.csv(medfit::mediation_demo, "mediation_demo.csv", row.names = FALSE)'
#   uv run --with semopy==2.3.11 python -I tests/sim/oracles/semopy-simple.py mediation_demo.csv \
#     > tests/sim/oracles/semopy-simple.csv
# semopy's default SLSQP stop leaves the estimates about 4e-5 from the optimum; ftol = 1e-12 removes that.
import sys

import pandas as pd
import semopy

data = pd.read_csv(sys.argv[1])
model = semopy.Model("""
mediator1 ~ a*treatment
outcome ~ b*mediator1 + cp*treatment
""")
model.fit(data, obj="MLW", options={"ftol": 1e-12})
out = model.inspect()[["lval", "op", "rval", "Estimate", "Std. Err"]]
out.columns = ["lhs", "op", "rhs", "estimate", "std_error"]
out.insert(0, "semopy", semopy.__version__)
out.to_csv(sys.stdout, index=False, float_format="%.12g")
