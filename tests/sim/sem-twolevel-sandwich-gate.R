# Native two-level cluster-robust (CR0) sandwich gate, IG2 (planning/specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md).
# Oracle: lavaan two-level with se = "robust.huber.white" and the TL-3 convention (fixed.x = FALSE, observed
# information, structured h1 information). Cells: the unbalanced fixtures (n in 2..9) at J = 40 and J = 100, each with
# and without a cluster-only Z, and J = 40 with the cross-level equality a_w == a_b (the projected sandwich).
# Checks per cell:
#   se         max relative SE gap over the free rows (TL-2), limit 1e-3
#   contrast   relative gap of the SE of a_w - a_b, which needs the cross-level meat block (labeled cells), limit 1e-3
#   sum        the per-cluster scores sum to the total score, -N / 2 times the `.sem_eval_ml2()` gradient, at a point
#              off the optimum (max gap over max(1, max |score|)), limit 1e-8
# MUTANT=casewise (scores scaled by sqrt(n_j) instead of n_j), zero_cross_meat (the within-between block of the meat
# zeroed), drop_cluster (the first cluster left out of the scores), cr1 (the J / (J - 1) factor, decision D3 says CR0),
# no_projection (the constrained sandwich not projected) alter production functions in memory only and must fail.
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
meat_call <- "crossprod(.sem_scores_ml2(theta, ram, data, cluster))"
if (mutant == "casewise") {
  swap(".sem_scores_ml2", "-s$n/2 *", "-sqrt(s$n)/2 *")
} else if (mutant == "zero_cross_meat") {
  swap(".sem_meat_ml2", meat_call, paste0(
    "(function(b) { i1 <- setdiff(ram$k1, ram$k2); i2 <- setdiff(ram$k2, ram$k1); ",
    "b[i1, i2] <- 0; b[i2, i1] <- 0; b })(",
    meat_call, ")"
  ))
} else if (mutant == "drop_cluster") {
  swap(".sem_ml2_cluster_samples", "lapply(idx,", "lapply(idx[-1L],")
} else if (mutant == "cr1") {
  swap(".sem_meat_ml2", meat_call, paste0("(function(s) nrow(s) / (nrow(s) - 1) * crossprod(s))(",
                                          ".sem_scores_ml2(theta, ram, data, cluster))"))
} else if (mutant == "no_projection") {
  swap(".sem_vcov", "pinned <- !all(act$free) || any(act$active_row)", "pinned <- FALSE")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

limits <- c(se = 1e-3, contrast = 1e-3, sum = 1e-8)
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
fixtures <- list(unb40 = tl_simulate(rep(2:9, length.out = 40), seed = 42), unb100 = tl_mx_data_unbalanced())
cells <- list(
  list(cell = "unb40", fx = "unb40", z = FALSE, eq = FALSE),
  list(cell = "unb40-z", fx = "unb40", z = TRUE, eq = FALSE),
  list(cell = "unb100", fx = "unb100", z = FALSE, eq = FALSE),
  list(cell = "unb100-z", fx = "unb100", z = TRUE, eq = FALSE),
  list(cell = "unb40-eq", fx = "unb40", z = FALSE, eq = TRUE)
)
for (cl in cells) {
  model <- if (cl$z) tln_model_z() else tl_lavaan_model
  if (cl$eq) model <- paste(model, "a_w == a_b", sep = "\n")
  d <- if (cl$z) tln_add_z(fixtures[[cl$fx]]) else fixtures[[cl$fx]]
  checks <- c("se", if (!cl$z && !cl$eq) "contrast", "sum")
  fit <- tryCatch(
    suppressWarnings(fit_sem(model, d, cluster = "cluster", fixed_x = FALSE, meanstructure = TRUE,
                             se_type = "sandwich")),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    for (ch in checks) add(cl$cell, ch, NA_real_)
    next
  }
  lav <- suppressWarnings(lavaan::sem(model, d, cluster = "cluster", fixed.x = FALSE, information = "observed",
                                      h1.information = "structured", se = "robust.huber.white"))
  nt <- fit@table[fit@table$free, ]
  pt <- lavaan::parameterEstimates(lav)
  pt <- pt[pt$op %in% c("~", "~~", "~1"), ]
  m <- match(key(nt$lhs, nt$op, nt$rhs, nt$level), key(pt$lhs, pt$op, pt$rhs, pt$level))
  add(cl$cell, "se", if (anyNA(m)) NA_real_ else max(abs(nt$se - pt$se[m]) / pt$se[m]))
  if ("contrast" %in% checks) {
    ref <- contrast_se(lavaan::lavInspect(lav, "vcov"))
    add(cl$cell, "contrast", abs(contrast_se(fit@vcov) - ref) / ref)
  }
  tl <- fit@internals$ram
  x <- d[, c(tl$within, tl$between, "cluster")]
  smp <- .sem_sample_ml2(x, list(within = tl$within, between = tl$between), "cluster")
  th <- fit@theta + 0.05 * seq_len(tl$q) / tl$q
  target <- -smp$n / 2 * .sem_eval_ml2(th, tl, smp, TRUE)$g
  s <- .sem_scores_ml2(th, tl, x, "cluster")
  add(cl$cell, "sum", max(abs(colSums(s) - target)) / max(1, max(abs(target))))
}
results <- do.call(rbind, records$rows)
rownames(results) <- NULL
dir.create("tests/sim/results", recursive = TRUE, showWarnings = FALSE)
out <- if (nzchar(mutant)) {
  tempfile("twolevel-sandwich-mutant-", fileext = ".csv")
} else {
  file.path("tests/sim/results", paste0("sem-twolevel-sandwich-gate-", Sys.Date(), ".csv"))
}
utils::write.csv(results, out, row.names = FALSE)
print(results)
if (!all(results$pass %in% TRUE)) stop("native two-level sandwich gate failed")
