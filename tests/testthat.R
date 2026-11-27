# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(medfit)

# Hosted runs (CRAN, GitHub Actions) run a smoke subset: classes, extraction, fitting, the optimizer core, bootstrap,
# effect SEs, and the structural guards. The rest of the suite runs on the maintainer's machine (scripts/check-local-full.sh,
# whose receipt gates a release). MEDFIT_TEST_FILTER overrides the choice: a regex selects files, "all" runs everything.
smoke <- paste0(
  "^(classes|validators|extract-(lm|glm|lavaan|serial|parallel|interaction)|fit-(glm|sem)|",
  "sem-(parse|model|ml|optim|constraints|se|fit|methods|anova)|bootstrap|effect-se|methods-|native-identities|",
  "mediation-demo|gate-coverage|local-only|ci-workflows|adr-front-matter|api-freeze|dependents-contract|",
  "docs-release|refcard-coverage)"
)
filter <- Sys.getenv("MEDFIT_TEST_FILTER", "")
hosted <- !identical(Sys.getenv("NOT_CRAN"), "true") || nzchar(Sys.getenv("CI"))
if (identical(filter, "all") || (!nzchar(filter) && !hosted)) {
  test_check("medfit")
} else {
  test_check("medfit", filter = if (nzchar(filter)) filter else smoke)
}
