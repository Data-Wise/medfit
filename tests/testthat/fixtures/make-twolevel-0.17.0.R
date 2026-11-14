# Writes tests/testthat/fixtures/twolevel-0.17.0.rds: a TwoLevelMediationData object saved by medfit 0.17.0,
# which has no `source_version` property (0.18.0 plan S4, spec R-14). test-twolevel-provenance.R reads it.
#
# The v0.17.0 tag is installed into a scratch library (never the user library) and loaded from there.
# Run from the repository root with plain Rscript (not inside a session that already loaded medfit):
#
#   Rscript tests/testthat/fixtures/make-twolevel-0.17.0.R [scratch_dir]
#
# Written 2026-11-14 with R 4.6.2, S7 0.2.2 and lavaan 0.7.3 (the versions this script prints).

args <- commandArgs(trailingOnly = TRUE)
scratch <- if (length(args) >= 1L) args[[1L]] else tempfile("medfit-0.17.0-")
src <- file.path(scratch, "src")
lib <- file.path(scratch, "lib")
dir.create(src, recursive = TRUE, showWarnings = FALSE)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)

# The tag's tree, without a worktree or a checkout
tarball <- file.path(scratch, "medfit-0.17.0.tar")
status <- system2("git", c("archive", "--format=tar", "-o", tarball, "v0.17.0"))
stopifnot(status == 0L)
utils::untar(tarball, exdir = src)
status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-test-load", "-l", lib, src))
stopifnot(status == 0L)

.libPaths(c(lib, .libPaths()))
stopifnot(utils::packageVersion("medfit", lib.loc = lib) == "0.17.0")
suppressPackageStartupMessages(library(medfit, lib.loc = lib))
stopifnot(utils::packageVersion("medfit") == "0.17.0")
stopifnot(normalizePath(find.package("medfit")) == normalizePath(file.path(lib, "medfit")))

set.seed(1)
id <- rep(1:60, each = 5)
x <- stats::rnorm(60)[id] + stats::rnorm(300)
m <- 0.5 * x + stats::rnorm(60)[id] + stats::rnorm(300)
y <- 0.4 * m + 0.2 * x + stats::rnorm(60)[id] + stats::rnorm(300)
d <- data.frame(id = id, X = x, M = m, Y = y)
model <- "
  level: 1
    M ~ X
    Y ~ M + X
  level: 2
    M ~ X
    Y ~ M + X
"
fit <- lavaan::sem(model, data = d, cluster = "id")
td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
stopifnot(!S7::prop_exists(td, "source_version"))

saveRDS(td, file.path("tests", "testthat", "fixtures", "twolevel-0.17.0.rds"), version = 3)
cat(sprintf("medfit %s from %s; R %s; S7 %s; lavaan %s; lavaan_version %s\n",
            utils::packageVersion("medfit"), find.package("medfit"), getRversion(),
            utils::packageVersion("S7"), utils::packageVersion("lavaan"), td@lavaan_version))
