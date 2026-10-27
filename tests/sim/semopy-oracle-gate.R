# The semopy oracle gate (ADR D-13; planning/specs/BRAINSTORM-semopy-oracle-2026-10-24.md, Shape B): a third, Python
# implementation of normal-theory ML checks the native engine's estimates and standard errors on the four sem_models()
# structures (observed, latent, parallel, serial), n in {200, 500}, seeds 1:5. Scope: estimates and SEs only (no
# logLik, no fit indices). Monthly only: tests/sim/gates-monthly.txt keeps it out of the PR gates shards; the
# qc-monthly workflow runs it with --monthly and MEDFIT_SEMOPY_REQUIRED=true.
#
# Conventions, aligned on all three sides and measured before the tolerances were set:
#   medfit  fit_sem(..., fixed_x = TRUE, meanstructure = FALSE, information = "observed")
#   lavaan  sem(..., fixed.x = TRUE, meanstructure = FALSE, information = "observed", rel.tol 1e-10); at 1e-12
#           nlminb reports false convergence on 7 of the 10 latent fits (estimates within 1e-7 either way), so
#           1e-10 is the tightest setting lavaan calls converged, and a non-converged lavaan fit is an error row
#   semopy  Model.fit(obj = "MLW", options = {"ftol": 1e-12}); inspect(information = "observed")
# All three use the ML covariance (denominator N) and observed-information SEs; semopy's default expected-information
# SE is about 3e-3 relative off on the latent model. Exogenous moments are fixed at their sample values on all sides,
# so no side reports them. Names: semopy's inspect() table goes through so_map_names() (a loading `m2 ~ eta` becomes
# `eta=~m2`, the fixed marker is dropped, `~~` sides are sorted); a parameter missing on any side is "unmatched".
# Counting rule (tests/sim/semopy-oracle-lib.R): a row passes when medfit is within tol_est/tol_se of semopy AND semopy
# is within the same tolerances of lavaan; where semopy is off lavaan the row is "disputed" (neither pass nor fail),
# and gates.csv min_pass is the floor on pass rows. Without uv every row is n/a and the gate skips (a fail when
# MEDFIT_SEMOPY_REQUIRED=true).
#
# Planted defects (each must exit 1):
#   MUTANT=medfit_shift  medfit's first estimate in every fit moved by 1e-4: those rows fail
#   MUTANT=perturb       every semopy estimate moved by 1e-3: every row disputed, the pass floor fails
#   MUTANT=swapname      two semopy parameter names swapped in every fit: 80 rows disputed, the pass floor fails
#   MUTANT=medfit_se     medfit's first SE in every fit scaled by 1.01 (relative gap 1e-2 > 1e-3): those rows fail
# Run from the package root:  Rscript tests/sim/semopy-oracle-gate.R   (uv on PATH, or MEDFIT_UV=/path/to/uv)
# Results: tests/sim/results/semopy-oracle-gate-<date>.csv, one row per structure x n x seed x parameter; a mutant run
# writes to the temporary directory.

suppressMessages(pkgload::load_all(quiet = TRUE))
if (!requireNamespace("lavaan", quietly = TRUE)) {
  stop("this gate needs lavaan (Suggests): semopy counts only where it agrees with lavaan", call. = FALSE)
}
source("tests/testthat/helper-sem.R") # sem_models(), sem_sim(), sem_lavaan_text()
source("tests/sim/semopy-oracle-lib.R")
mutant <- Sys.getenv("MUTANT", "")
if (nzchar(mutant) && !mutant %in% c("medfit_shift", "medfit_se", "perturb", "swapname")) {
  stop("unknown mutant '", mutant, "'", call. = FALSE)
}
spec <- utils::read.csv("tests/sim/gates.csv", stringsAsFactors = FALSE)
spec <- spec[spec$gate == "semopy", , drop = FALSE]
tol_est <- spec$tol_est
tol_se <- spec$tol_se

grid <- expand.grid(seed = 1:5, n = c(200L, 500L), structure = names(sem_models()), stringsAsFactors = FALSE)
grid$id <- sprintf("%s-n%d-s%d", grid$structure, grid$n, grid$seed)
data_dir <- tempfile("semopy-data-")
dir.create(data_dir)
grid$data <- file.path(data_dir, paste0(grid$id, ".csv"))
grid$model <- vapply(grid$structure, sem_lavaan_text, "")

fit_side <- function(f) tryCatch(f(), error = function(e) conditionMessage(e))
med <- lav <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  d <- sem_sim(sem_models()[[grid$structure[i]]], grid$n[i], grid$seed[i])
  utils::write.csv(d, grid$data[i], row.names = FALSE)
  med[[i]] <- fit_side(function() {
    f <- fit_sem(grid$model[i], d, fixed_x = TRUE, meanstructure = FALSE, information = "observed")
    so_named(stats::coef(f), sqrt(diag(stats::vcov(f))))
  })
  lav[[i]] <- fit_side(function() {
    f <- lavaan::sem(grid$model[i], d, fixed.x = TRUE, meanstructure = FALSE, information = "observed",
                     control = list(rel.tol = 1e-10))
    if (!lavaan::lavInspect(f, "converged")) stop("lavaan did not converge", call. = FALSE)
    so_named(lavaan::coef(f), sqrt(diag(lavaan::vcov(f))))
  })
  if (mutant == "medfit_shift" && is.data.frame(med[[i]])) med[[i]]$estimate[1] <- med[[i]]$estimate[1] + 1e-4
  if (mutant == "medfit_se" && is.data.frame(med[[i]])) med[[i]]$se[1] <- med[[i]]$se[1] * 1.01
}

sp <- so_run_semopy(grid[, c("id", "model", "data")])
empty <- data.frame(name = character(), estimate = numeric(), se = numeric())
rows <- lapply(seq_len(nrow(grid)), function(i) {
  ok_side <- vapply(list(med[[i]], lav[[i]]), is.data.frame, TRUE)
  m <- if (ok_side[1]) med[[i]] else empty
  l <- if (ok_side[2]) lav[[i]] else empty
  if (!sp$ok) {
    r <- so_compare(m, l, l, tol_est, tol_se)
    r$status <- "n/a"
    r$reason <- sp$why
  } else {
    sr <- sp$rows[sp$rows$id == grid$id[i], , drop = FALSE]
    fit_ok <- nrow(sr) > 0L && all(sr$fit_ok %in% TRUE)
    s <- if (fit_ok) so_map_names(sr, grid$model[i]) else empty
    if (fit_ok && mutant == "perturb") s$estimate <- s$estimate + 1e-3
    if (fit_ok && mutant == "swapname") s$name[1:2] <- s$name[2:1]
    r <- so_compare(m, s, l, tol_est, tol_se)
    errs <- c(medfit = if (!ok_side[1]) med[[i]], lavaan = if (!ok_side[2]) lav[[i]],
              semopy = if (!fit_ok) paste(c(sr$error, "no rows")[1L]))
    if (length(errs)) {
      r$status <- "error"
      r$reason <- paste(names(errs), errs, sep = ": ", collapse = "; ")
    }
  }
  cbind(grid[i, c("structure", "n", "seed")], r, row.names = NULL)
})
res <- do.call(rbind, rows)
ver <- if (sp$ok) sp$versions else c(semopy = NA, python = NA, numpy = NA, scipy = NA, pandas = NA)
for (v in names(ver)) res[[v]] <- unname(ver[[v]])
res$lavaan <- as.character(utils::packageVersion("lavaan"))
res$medfit <- as.character(utils::packageVersion("medfit"))

out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
f <- file.path(out_dir, sprintf("semopy-oracle-gate-%s.csv", Sys.Date()))
utils::write.csv(res, f, row.names = FALSE)

cat(sprintf("rows %d: %s\n", nrow(res), paste(names(table(res$status)), table(res$status), collapse = ", ")))
if (sp$ok) cat("versions:", paste(names(ver), ver, sep = " ", collapse = ", "), "\n")
by_struct <- lapply(split(res, res$structure), function(x) {
  data.frame(structure = x$structure[1], pass = sum(x$status == "pass"), disputed = sum(x$status == "disputed"),
             max_est_gap = max(c(0, x$est_gap), na.rm = TRUE), max_se_rel = max(c(0, x$se_rel), na.rm = TRUE),
             max_sl_est_gap = max(c(0, x$sl_est_gap), na.rm = TRUE),
             max_sl_se_rel = max(c(0, x$sl_se_rel), na.rm = TRUE))
})
print(do.call(rbind, by_struct), row.names = FALSE, digits = 3)
show <- c("structure", "n", "seed", "param", "status", "est_gap", "se_rel", "sl_est_gap", "sl_se_rel", "reason")
bad <- res[!res$status %in% c("pass", "n/a"), show]
if (nrow(bad)) print(utils::head(bad, 20L), row.names = FALSE, digits = 3)
v <- so_gate_checks(res, spec)
for (j in seq_len(nrow(v))) cat(sprintf("  %-4s %-24s %s\n", if (v$pass[j]) "ok" else "FAIL", v$check[j], v$detail[j]))
cat(sprintf("\nresults: %s\n", f))
if (!all(v$pass)) {
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
