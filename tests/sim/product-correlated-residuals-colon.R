# Rule 9 evidence through the `:` path (0.10.0 plan U8): the same gate as product-correlated-residuals.R with
# PRODUCT_PATH=colon. Rule 9 refuses every free residual covariance in a product model, and the gate checks both that
# refusal and that the refused fits would have leaked (`gap_column`). Separate entry point so tests/sim/run-gates.R can
# run it as the gates.csv row "product-corr-colon" (it writes product-correlated-residuals-colon-<date>.csv).
# MUTANT= passes through. Run from the package root:  Rscript tests/sim/product-correlated-residuals-colon.R
Sys.setenv(PRODUCT_PATH = "colon")
source("tests/sim/product-correlated-residuals.R")
