# Restricted-block gate through the `:` path (0.10.0 plan U8): the same gate as exo-product-fixed-var.R with
# PRODUCT_PATH=colon, so the model writes `x:w` and medfit builds the product. Separate entry point so
# tests/sim/run-gates.R can run it as the gates.csv row "product-fixed-var-colon" (it writes
# exo-product-fixed-var-colon-<date>.csv). The `fixvar` configuration cannot be written on this path. MUTANT= passes
# through.
# Run from the package root:  Rscript tests/sim/exo-product-fixed-var-colon.R
Sys.setenv(PRODUCT_PATH = "colon")
source("tests/sim/exo-product-fixed-var.R")
