# Native two-level (1-1-1, observed) parity gate, S4a.4 of planning/PLAN-S4a-native-twolevel-core-2026-11-18.md.
# Oracle: lavaan two-level with the TL-3 convention (fixed.x = FALSE, observed information, structured h1
# information). Cells: balanced and unbalanced data at J = 40 and J = 100, each with and without a cluster-only Z.
# Checks per cell (limits from planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md):
#   estimates  max over free rows of |est - lavaan| / max(0.01 SE, 1e-4) (TL-1), limit 1
#   se         max relative SE gap (TL-2), limit 1e-3
#   loglik     relative logLik gap (TL-4), limit 1e-6
#   df         absolute df gap, limit 0
#   contrast   relative gap of the SE of a_w - a_b, which needs the cross-level vcov block (labeled cells), limit 1e-3
# MUTANT=zero_cross (cross-level vcov block zeroed), se_scale (every SE times 1.01), perturb_theta (an estimate
# moved 1e-3 off the optimum) alter production functions in memory only and must fail.
suppressMessages(pkgload::load_all(quiet = TRUE))
for (h in c("helper-sem.R", "helper-twolevel-likelihood.R", "helper-twolevel-native.R", "helper-twolevel-openmx.R")) {
  source(file.path("tests/testthat", h))
}
ns <- asNamespace("medfit")
mutant <- Sys.getenv("MUTANT", "")
swap <- function(name, pattern, replacement) {
  fn <- sem_mutate(get(name, ns), pattern, replacement)
  if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
vcov_call <- ".sem_vcov(fit$theta, tl, smp, information, cons, lb, ub, se_type, meat)"
if (mutant == "zero_cross") {
  swap(".sem_fit_twolevel", vcov_call, paste0(
    "(function(v) { i1 <- setdiff(tl$k1, tl$k2); i2 <- setdiff(tl$k2, tl$k1); v[i1, i2] <- 0; v[i2, i1] <- 0; v })(",
    vcov_call, ")"
  ))
} else if (mutant == "se_scale") {
  swap(".sem_fit_twolevel", vcov_call, paste0("1.0201 * ", vcov_call))
} else if (mutant == "perturb_theta") {
  swap(".sem_fit_twolevel", "lb <- fit$effective_lower",
       "fit$theta[1L] <- fit$theta[1L] + 0.001; lb <- fit$effective_lower")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

limits <- c(estimates = 1, se = 1e-3, loglik = 1e-6, df = 0, contrast = 1e-3)
records <- new.env(parent = emptyenv())
records$rows <- list()
add <- function(cell, check, value) {
  records$rows[[length(records$rows) + 1L]] <- data.frame(
    cell = cell, check = check, value = value, limit = limits[[check]],
    pass = is.finite(value) && value >= 0 && value <= limits[[check]], stringsAsFactors = FALSE
  )
}
key <- function(lhs, op, rhs, level) {
  paste(level, ifelse(op == "~~", pmin(lhs, rhs), lhs), op, ifelse(op == "~~", pmax(lhs, rhs), rhs))
}
contrast_se <- function(v) sqrt(v["a_w", "a_w"] + v["a_b", "a_b"] - 2 * v["a_w", "a_b"])
fixtures <- list(
  bal40 = tl_simulate(rep(5, 40), seed = 41),
  unb40 = tl_simulate(rep(2:9, length.out = 40), seed = 42),
  bal100 = tl_mx_data_balanced(),
  unb100 = tl_mx_data_unbalanced()
)
for (nm in names(fixtures)) {
  for (with_z in c(FALSE, TRUE)) {
    cell <- paste0(nm, if (with_z) "-z" else "")
    model <- if (with_z) tln_model_z() else tl_lavaan_model
    d <- if (with_z) tln_add_z(fixtures[[nm]]) else fixtures[[nm]]
    fit <- tryCatch(
      suppressWarnings(fit_sem(model, d, cluster = "cluster", fixed_x = FALSE, meanstructure = TRUE)),
      error = function(e) NULL
    )
    checks <- if (with_z) setdiff(names(limits), "contrast") else names(limits)
    if (is.null(fit)) {
      for (ch in checks) add(cell, ch, NA_real_)
      next
    }
    lav <- tln_fit_lavaan(model, d)
    nt <- fit@table[fit@table$free, ]
    pt <- lavaan::parameterEstimates(lav)
    pt <- pt[pt$op %in% c("~", "~~", "~1"), ]
    m <- match(key(nt$lhs, nt$op, nt$rhs, nt$level), key(pt$lhs, pt$op, pt$rhs, pt$level))
    complete <- !anyNA(m) && length(m) == as.integer(lavaan::fitMeasures(lav, "npar"))
    add(cell, "estimates", if (complete) max(abs(nt$est - pt$est[m]) / pmax(0.01 * pt$se[m], 1e-4)) else NA_real_)
    add(cell, "se", if (complete) max(abs(nt$se - pt$se[m]) / pt$se[m]) else NA_real_)
    ll <- as.numeric(lavaan::logLik(lav))
    add(cell, "loglik", abs(as.numeric(stats::logLik(fit)) - ll) / abs(ll))
    add(cell, "df", abs(as.numeric(fit@df) - as.numeric(lavaan::fitMeasures(lav, "df"))))
    if (!with_z) {
      ref <- contrast_se(lavaan::lavInspect(lav, "vcov"))
      add(cell, "contrast", abs(contrast_se(fit@vcov) - ref) / ref)
    }
  }
}
results <- do.call(rbind, records$rows)
rownames(results) <- NULL
dir.create("tests/sim/results", recursive = TRUE, showWarnings = FALSE)
out <- if (nzchar(mutant)) {
  tempfile("twolevel-parity-mutant-", fileext = ".csv")
} else {
  file.path("tests/sim/results", paste0("sem-twolevel-parity-gate-", Sys.Date(), ".csv"))
}
utils::write.csv(results, out, row.names = FALSE)
print(results)
if (!all(results$pass %in% TRUE)) stop("native two-level parity gate failed")
