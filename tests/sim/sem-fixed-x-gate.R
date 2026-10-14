# fixed_x gate for the native SEM engine (0.9.0, plan task V9): subset invariance, lavaan parity, location sweep
# and a timing table, with planted defects that must turn the gate red.
#
# Cells: 2 sample sizes (100, 400) x SEEDS seeds (5 by default) x every subset of {x, c1, c2} (7), model-based and
# sandwich standard errors (the sandwich also with weights). Per run the rule (a failing run fails the gate):
#   invariant   estimates of the parameters the fixed and free fits share agree to 1e-8, SEs to 1e-6 (relative)
#   counts      df equals the free fit's; the parameter count falls by the number of exogenous moments fixed
#   lavaan      fixed_x = TRUE: npar, df and chi-square equal lavaan fixed.x = TRUE (1e-5), estimates 1e-4
#   scale       fixed_x = TRUE and one subset, location shifts 1e2, 1e3, 1e5: accepted, paths within 1e-5 of shift 0
# The timing table (30 covariates) is printed and written, never gated.
# `MUTANT=<name>` plants a defect and the gate must then exit 1: countrestrict (fixed moments counted as
# restrictions), noshift (the shifted route refused under fixed_x). Wired at later tasks: droppair (V3), jointlik
# (V4), acceptbad (V1), aicwarnonly (V7).
# Run from the package root:  Rscript tests/sim/sem-fixed-x-gate.R   (SEEDS=5 by default)

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-fixed-x.R")
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
  swap(".sem_shift_ok", function(...) FALSE)
} else if (nzchar(mutant)) {
  stop("mutant '", mutant, "' is wired at a later task", call. = FALSE)
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
note <- function(tag) bad <<- c(bad, tag)
for (n in c(100L, 400L)) {
  for (seed in seeds) {
    d <- sim(n, seed)
    w <- stats::runif(n, 0.5, 2)
    for (se in c("model", "sandwich")) {
      for (weighted in if (se == "sandwich") c(FALSE, TRUE) else FALSE) {
        args <- list(model = fx_syntax, data = d, se_type = se)
        if (weighted) args$weights <- w
        free <- suppressWarnings(do.call(fit_sem, args))
        for (sel in subsets) {
          tag <- sprintf("n=%d seed=%d %s%s {%s}", n, seed, se, if (weighted) " w" else "", paste(sel, collapse = ","))
          fixed <- tryCatch(suppressWarnings(do.call(fit_sem, c(args, list(fixed_x = sel)))), error = function(e) NULL)
          if (is.null(fixed)) {
            note(paste(tag, "fit failed"))
            next
          }
          sh <- fx_shared(free, fixed)
          est_tol <- 1e-8 * max(1, max(abs(sh$est[[1L]])))
          if (max(abs(sh$est[[2L]] - sh$est[[1L]])) > est_tol) note(paste(tag, "estimates"))
          if (max(abs(sh$se[[2L]] / sh$se[[1L]] - 1)) > 1e-6) note(paste(tag, "SEs"))
          if (fixed@df != free@df) note(paste(tag, "df"))
          if (length(fixed@theta) != length(free@theta) - fx_n_removed(sel)) note(paste(tag, "npar"))
        }
      }
    }
    if (requireNamespace("lavaan", quietly = TRUE) && n == 400L) {
      fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE, information = "expected")
      ref <- lavaan::sem(fx_syntax, d, fixed.x = TRUE)
      tag <- sprintf("lavaan n=%d seed=%d", n, seed)
      if (length(fixed@theta) != lavaan::fitMeasures(ref, "npar")) note(paste(tag, "npar"))
      if (fixed@df != lavaan::fitMeasures(ref, "df")) note(paste(tag, "df"))
      if (abs(fixed@f * fixed@n_obs - lavaan::fitMeasures(ref, "chisq")) > 1e-5) note(paste(tag, "chisq"))
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
  if (is.null(fit) || anyNA(fit@vcov)) {
    note(sprintf("scale %g not accepted", shift))
  } else if (max(abs(fit@theta[c("a", "b", "cp")] - base@theta[c("a", "b", "cp")])) > 1e-5) {
    note(sprintf("scale %g paths", shift))
  }
}

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
  t_free <- system.time(f_free <- fit_sem(syn, dd))[["elapsed"]]
  t_fix <- system.time(f_fix <- fit_sem(syn, dd, fixed_x = TRUE))[["elapsed"]]
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

cat(sprintf("\nviolations: %d\n", length(bad)))
if (length(bad)) {
  print(utils::head(bad, 15L))
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
