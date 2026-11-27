# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(medfit)

# The macOS and Windows CI legs set MEDFIT_TEST_FILTER to a platform subset (R-CMD-check.yaml); the full CI-tier
# suite runs on ubuntu release. Unset or empty means every file.
filter <- Sys.getenv("MEDFIT_TEST_FILTER", "")
if (nzchar(filter)) {
  test_check("medfit", filter = filter)
} else {
  test_check("medfit")
}
