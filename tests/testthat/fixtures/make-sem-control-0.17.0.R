# Writes `sem-control-0.17.0.rds`: the 0.17.0 meaning of `fit_sem(control = list(...))` and `mbco_sem()`, pinned
# before `sem_control()` existed (0.18.0 plan S2, requirement R-4). Run it against an install of `origin/dev` at
# 63e6a573 (0.17.0.9000, before S2) in a scratch library, never against the branch under test:
#
#   git archive origin/dev | tar -x -C <scratch>/src
#   R CMD INSTALL --no-docs --library=<scratch>/lib <scratch>/src
#   Rscript tests/testthat/fixtures/make-sem-control-0.17.0.R <scratch>/lib
#
# Plain components are saved, not the S7 objects, so the fixture does not carry the old class definitions.
args <- commandArgs(trailingOnly = TRUE)
lib <- args[1L]
stopifnot(!is.na(lib), dir.exists(lib))
library(medfit, lib.loc = lib)
stopifnot(dirname(find.package("medfit")) == normalizePath(lib))

d <- mediation_demo
model <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
parts <- function(fit) {
  list(theta = fit@theta, vcov = fit@vcov, table = fit@table, defined = fit@defined, f = fit@f, n_obs = fit@n_obs,
       df = fit@df, converged = fit@converged, control = fit@internals$control, n_starts = fit@internals$n_starts,
       ledger = fit@diagnostics$ledger)
}
legacy <- fit_sem(model, d, control = list(maxeval = 20000L))
plain <- fit_sem(model, d)
mbco <- mbco_sem(legacy, "a", "b")

set.seed(271L)
n <- 240L
x <- .8 + stats::rnorm(n, sd = 1.1)
m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
fd <- data.frame(X = x, M = m, Y = y)
fd[seq(1L, n, 5L), "X"] <- NA_real_
fd[seq(2L, n, 5L), "M"] <- NA_real_
fd[seq(3L, n, 5L), "Y"] <- NA_real_
fiml <- fit_sem("M ~ a*X\nY ~ b*M + cp*X", fd, missing = "fiml", fixed_x = FALSE)

out <- list(
  legacy = parts(legacy), plain = parts(plain),
  mbco = list(statistic = mbco$statistic, p.value = mbco$p.value, tests = mbco$tests),
  fiml = list(theta = fiml@theta, vcov = fiml@vcov, control = fiml@internals$control,
              n_starts = fiml@internals$n_starts),
  source = list(medfit = as.character(utils::packageVersion("medfit", lib.loc = lib)), commit = "63e6a573",
                r = R.version.string, platform = R.version$platform, blas = extSoftVersion()[["BLAS"]],
                lapack = La_library(), nloptr = as.character(utils::packageVersion("nloptr")))
)
saveRDS(out, file.path("tests", "testthat", "fixtures", "sem-control-0.17.0.rds"), version = 2L)
