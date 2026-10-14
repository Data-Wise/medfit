# Null gate through the `:` path (0.10.0 plan U6): the same gate as exo-product-null.R with PRODUCT_PATH=colon, so the
# model writes `x:w` and medfit builds the product. A separate entry point so tests/sim/run-gates.R can run it as the
# gates.csv row "product-null-colon" (it writes exo-product-null-colon-<date>.csv). MUTANT= passes through.
# Run from the package root:  Rscript tests/sim/exo-product-null-colon.R
Sys.setenv(PRODUCT_PATH = "colon")
source("tests/sim/exo-product-null.R")
