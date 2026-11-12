# FI-B independent QA fixture addendum

Declared before QA execution. Statistical admission remains deferred.
The frozen six sources and twelve paired resamples per source remain unchanged:
156 public fit invocations total, seed911 row indices, source seeds271/613.
The matrix captures the production row-refit calls; it does not refit a second
native copy. Source and paired results are retained for subsequent contract tests.
Independent likelihood/score/Hessian checks use the six source fits and no extra
optimizer calls. Existing rowwise structural Gaussian helpers provide the oracle.

Additional small tests reuse these retained six source fits, with zero additional
real fits: supplied Gaussian normals seed123/B8; deterministic covariance matrices;
injected rank/constant/information/solver/nonfinite failures B3; source ledger and
argument corruption; stale finite result bounds; affine covariance transport and
row/column permutation of the independent likelihood. Mock refit tests compare
sequential/two-worker manifests. Legacy callback results are compared against the
base revision in a separate R environment without optimizer calls. Mutants operate
on retained inputs or mocked functions and never rerun the six-cell fit matrix.
