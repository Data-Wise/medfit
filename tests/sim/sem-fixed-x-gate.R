# fixed_x gate for the native SEM engine (0.9.0, plan task V9): subset invariance, lavaan parity, location sweep
# and a timing table, with planted defects that must turn the gate red.
#
# Cells: 2 sample sizes (100, 400) x SEEDS seeds (5 by default) x every subset of {x, c1, c2} (7), model-based and
# sandwich standard errors (the sandwich also with weights). Per run the rule (a failing run fails the gate):
#   invariant   estimates of the parameters the fixed and free fits share agree to 1e-6, SEs to 1e-6 (relative; the
#               two fits stop at separate SLSQP solutions, so about 1e-8 to 1e-7 of disagreement is the optimizer's)
#   counts      df equals the free fit's; the parameter count falls by the number of exogenous moments fixed
#   lavaan      fixed_x = TRUE: npar, df and chi-square equal lavaan fixed.x = TRUE (1e-5), estimates 1e-4
#   scale       fixed_x = TRUE and one subset, location shifts 1e2, 1e3, 1e5: accepted, paths within 1e-5 of shift 0,
#               logLik within 1e-6 (relative) of shift 0 (it does not depend on the location)
#   likelihood  logLik of a fixed_x = TRUE fit equals lavaan's fixed.x = TRUE value (1e-6)
#   guards      a non-exogenous name is refused; AIC across different fixed sets is refused
# The timing table (30 covariates) is printed and written, never gated.
# `MUTANT=<name>` plants a defect and the gate must then exit 1: countrestrict (fixed moments counted as
# restrictions), noshift (the shifted fit keeps a fixed mean at its raw value), droppair (the free pairs among
# unselected variables dropped), jointlik (joint instead of conditional logLik), acceptbad (a non-exogenous name
# accepted), aicwarnonly (AIC across fixed sets returns a number).
# Run from the package root:  Rscript tests/sim/sem-fixed-x-gate.R   (SEEDS=5 by default)
# Results: tests/sim/results/sem-fixed-x-gate-<date>.csv, one row per check (tag, check, pass); a mutant run writes to
# the temporary directory

suppressMessages(pkgload::load_all(quiet = TRUE))
if (!requireNamespace("lavaan", quietly = TRUE)) {
  stop("this gate needs lavaan (Suggests): without it the parity checks would be skipped, not failed",
       call. = FALSE)
}
source("tests/testthat/helper-fixed-x.R")
source("tests/testthat/helper-sem.R") # provides sem_mutate
seeds <- seq_len(as.integer(Sys.getenv("SEEDS", "5")))
mutant <- Sys.getenv("MUTANT", "")
ns <- asNamespace("medfit")
swap <- function(name, fn) {
  unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
if (mutant == "countrestrict") {
  orig <- get(".sem_moments", ns)
  swap(".sem_moments", function(ram) {
    ram$n_fixed_x <- 0L
    orig(ram)
  })
} else if (mutant == "noshift") {
  # the shifted fit keeps a fixed exogenous mean at its raw value although the data is centered
  swap(".sem_fit_pipeline", sem_mutate(get(".sem_fit_pipeline", ns), "ram_opt$m0[ram$fixed_x_mean] <- 0",
                                       "ram_opt$m0[ram$fixed_x_mean] <- ram$m0[ram$fixed_x_mean]"))
} else if (mutant == "droppair") {
  swap(".sem_complete", sem_mutate(get(".sem_complete", ns), "if (r$ov_x[i] %in% paired && r$ov_x[j] %in% paired)",
                                   "if (FALSE)"))
} else if (mutant == "jointlik") {
  registerS3method("logLik", "medfit::SEMFit",
                   sem_mutate(utils::getS3method("logLik", "medfit::SEMFit"), "if (length(fx)) {", "if (FALSE) {"))
} else if (mutant == "acceptbad") {
  swap(".sem_resolve_fixed_x", sem_mutate(get(".sem_resolve_fixed_x", ns), "if (length(bad)) {", "if (FALSE) {"))
} else if (mutant == "aicwarnonly") {
  swap(".sem_check_comparable", sem_mutate(get(".sem_check_comparable", ns),
                                           "!all(vapply(sets[-1L], identical, logical(1), sets[[1L]]))", "FALSE"))
} else if (nzchar(mutant)) {
  stop("unknown mutant '", mutant, "'", call. = FALSE)
}

sim <- function(n, seed) {
  set.seed(1000L * seed + n)
  x <- stats::rnorm(n)
  c1 <- 0.4 * x + stats::rnorm(n)
  c2 <- stats::rnorm(n)
  m <- 0.5 * x + 0.3 * c1 - 0.2 * c2 + stats::rnorm(n, sd = 0.8)
  data.frame(treatment = x, covariate1 = c1, covariate2 = c2, mediator1 = m,
             outcome = 0.4 * m + 0.2 * x + 0.1 * c1 + 0.1 * c2 + stats::rnorm(n, sd = 0.7))
}
subsets <- unlist(lapply(1:3, function(k) utils::combn(fx_exo, k, simplify = FALSE)), recursive = FALSE)

bad <- character()
worst <- 0
ck <- list() # one row per check made, pass or fail, for the driver (tests/sim/run-gates.R)
check <- function(tag, what, ok) {
  ok <- isTRUE(ok)
  ck[[length(ck) + 1L]] <<- data.frame(tag = tag, check = what, pass = ok) # nolint: assignment_linter.
  if (!ok) bad <<- c(bad, paste(tag, what)) # nolint: assignment_linter.
  invisible(ok)
}
for (n in c(100L, 400L)) {
  for (seed in seeds) {
    d <- sim(n, seed)
    w <- stats::runif(n, 0.5, 2)
    for (se in c("model", "sandwich")) {
      for (weighted in if (se == "sandwich") c(FALSE, TRUE) else FALSE) {
        args <- list(model = fx_syntax, data = d, se_type = se)
        if (weighted) args$weights <- w
        free <- suppressWarnings(do.call(fit_sem, c(args, list(fixed_x = FALSE, meanstructure = NULL)))) # unrestricted baseline, pinned since 0.15.0 fixes x by default
        for (sel in subsets) {
          tag <- sprintf("n=%d seed=%d %s%s {%s}", n, seed, se, if (weighted) " w" else "", paste(sel, collapse = ","))
          fixed <- tryCatch(suppressWarnings(do.call(fit_sem, c(args, list(fixed_x = sel, meanstructure = NULL)))), error = function(e) NULL)
          check(tag, "fit", !is.null(fixed))
          if (is.null(fixed)) next
          sh <- fx_shared(free, fixed)
          est_dev <- max(abs(sh$est[[2L]] - sh$est[[1L]])) / max(1, max(abs(sh$est[[1L]])))
          worst <- max(worst, est_dev)
          check(tag, "estimates", est_dev <= 1e-6)
          check(tag, "SEs", max(abs(sh$se[[2L]] / sh$se[[1L]] - 1)) <= 1e-6)
          check(tag, "df", fixed@df == free@df)
          check(tag, "npar", length(fixed@theta) == length(free@theta) - fx_n_removed(sel))
        }
      }
    }
    if (n == 400L) {
      fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE, information = "expected", meanstructure = NULL)
      ref <- lavaan::sem(fx_syntax, d, fixed.x = TRUE)
      tag <- sprintf("lavaan n=%d seed=%d", n, seed)
      check(tag, "npar", length(fixed@theta) == lavaan::fitMeasures(ref, "npar"))
      check(tag, "df", fixed@df == lavaan::fitMeasures(ref, "df"))
      check(tag, "chisq", abs(fixed@f * fixed@n_obs - lavaan::fitMeasures(ref, "chisq")) <= 1e-5)
    }
  }
}

d0 <- fx_data()
base <- fit_sem(fx_syntax, d0, meanstructure = TRUE, fixed_x = TRUE)
for (shift in c(1e2, 1e3, 1e5)) {
  far <- fx_data()
  for (v in c("mediator1", "outcome", "covariate1", "covariate2")) far[[v]] <- far[[v]] + shift
  fit <- tryCatch(suppressWarnings(fit_sem(fx_syntax, far, meanstructure = TRUE, fixed_x = TRUE)),
                  error = function(e) NULL)
  tag <- sprintf("scale %g", shift)
  accepted <- !is.null(fit) && !anyNA(fit@vcov)
  check(tag, "accepted", accepted)
  if (accepted) {
    check(tag, "paths", max(abs(fit@theta[c("a", "b", "cp")] - base@theta[c("a", "b", "cp")])) <= 1e-5)
    check(tag, "logLik", abs(as.numeric(logLik(fit)) / as.numeric(logLik(base)) - 1) <= 1e-6)
  }
}

# likelihood parity and guards
ref <- as.numeric(lavaan::logLik(lavaan::sem(fx_syntax, d0, meanstructure = TRUE, fixed.x = TRUE)))
check("lavaan", "logLik", abs(as.numeric(logLik(base)) - ref) <= 1e-6)
check("guard", "non-exogenous fixed_x name refused",
      inherits(try(fit_sem(fx_syntax, d0, fixed_x = "outcome", meanstructure = NULL), silent = TRUE), "try-error"))
check("guard", "AIC across different fixed sets refused",
      inherits(try(AIC(fit_sem(fx_syntax, d0,
                               fixed_x = FALSE, meanstructure = NULL), base), silent = TRUE), "try-error"))

# timing table (reported, not gated): p covariates, free parameters and wall time, fixed vs free
timing <- NULL
for (p in c(5L, 15L, 30L)) {
  set.seed(p)
  n <- 400L
  cv <- matrix(stats::rnorm(n * p), n, p, dimnames = list(NULL, sprintf("c%02d", seq_len(p))))
  x <- stats::rnorm(n)
  m <- 0.5 * x + cv[, 1] * 0.2 + stats::rnorm(n)
  dd <- data.frame(x = x, m = m, y = 0.4 * m + 0.2 * x + cv[, 2] * 0.2 + stats::rnorm(n), cv)
  syn <- paste0("m ~ a*x + ", paste(colnames(cv), collapse = " + "), "\ny ~ b*m + cp*x + ",
                paste(colnames(cv), collapse = " + "))
  t_free <- system.time(f_free <- fit_sem(syn, dd, fixed_x = FALSE, meanstructure = NULL))[["elapsed"]]
  t_fix <- system.time(f_fix <- fit_sem(syn, dd, fixed_x = TRUE, meanstructure = NULL))[["elapsed"]]
  timing <- rbind(timing, data.frame(p = p, free_params = length(f_free@theta), fixed_params = length(f_fix@theta),
                                     secs_free = round(t_free, 2), secs_fixed = round(t_fix, 2),
                                     ratio = round(t_free / t_fix, 1)))
}
cat("\ntiming (reported, not gated):\n")
print(timing, row.names = FALSE)
dir.create("planning/specs/evidence/native-fixed-x-2026-10-13", showWarnings = FALSE, recursive = TRUE)
if (!nzchar(mutant)) {
  utils::write.csv(timing, "planning/specs/evidence/native-fixed-x-2026-10-13/timing.csv", row.names = FALSE)
}

ck <- do.call(rbind, ck)
out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
utils::write.csv(ck, file.path(out_dir, sprintf("sem-fixed-x-gate-%s.csv", Sys.Date())), row.names = FALSE)
cat(sprintf("\nworst relative estimate deviation (fixed vs free): %.2e\n", worst))
cat(sprintf("\nviolations: %d\n", length(bad)))
if (length(bad)) {
  print(utils::head(bad, 15L))
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
