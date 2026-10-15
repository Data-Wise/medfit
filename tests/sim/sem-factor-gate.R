# Factor-covariate gate for the native SEM engine (0.11.0 plan T4/T5): a factor covariate fits exactly as its
# hand-coded dummies do, under missing data and `fixed_x`, with a lavaan check and an MBCO refit, and planted
# defects that must turn the gate red.
#
# Cells: 2 sample sizes (100, 400) x SEEDS seeds (5 by default) x factor levels {2, 3, 5} x missingness {none, 10% of
# the factor, 10% of the outcome} x fixed_x {FALSE, "g", TRUE, c("x", "g")}.
# Per run the rule (a failing run fails the gate):
#   twin     estimates 1e-8, SEs 1e-6 (relative), logLik 1e-8 (relative) against the hand-coded twin fitted with the
#            same dummies (and the same dummies fixed); n_obs equals the complete cases
#   names    the dummies and the reference level follow the documented rule (reference = first level, `g_<level>`)
#   lavaan   regression estimates 1e-5 (scaled by max(1, |estimate|): lavaan stops near 1e-5 absolute; two of 180
#            runs sat at 1.08e-5 relative on a near-zero coefficient) and SEs 1e-3 (relative) against lavaan on the twin (fixed.x matched)
#   moments  with fixed_x, every fixed ~~ row equals the ML moment of the rows the fit used, computed in base R (1e-8)
#   refit    mbco_sem(paths = c("a", "b")) statistic equals the twin's (1e-6, relative): a refit works from the stored
#            data and factor map
# `MUTANT=<name>` plants a defect and the gate must then exit 1: wrongref (the reference is the last level), nofix
# (fixed_x names stay as the factor), halffix (a factor in fixed_x fixes only its first dummy), nomap (a refit loses
# the stored factor map), dropdummy (the last dummy is left out of the table). A dummy built from the kept rows only
# (a level present only in dropped rows) needs a purpose-built data set: it is a unit test, `test-sem-factor-missing.R`.
# lavaan's `fixed.x` is logical, so the lavaan rule runs for fixed_x = FALSE and TRUE only (other cells count as skipped).
# Run from the package root:  Rscript tests/sim/sem-factor-gate.R   (SEEDS=5 by default; SEEDS=1 is a smoke run)

suppressMessages(pkgload::load_all(quiet = TRUE))
seeds <- seq_len(as.integer(Sys.getenv("SEEDS", "5")))
mutant <- Sys.getenv("MUTANT", "")
ns <- asNamespace("medfit")
swap <- function(name, fn) {
  unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
if (mutant == "wrongref") {
  orig <- get(".sem_factor_levels", ns)
  swap(".sem_factor_levels", function(name, x) {
    r <- orig(name, x)
    if (!r$logical) {
      r$levels <- rev(r$levels)
      r$reference <- r$levels[1L]
    }
    r
  })
}
if (mutant == "nofix") swap(".sem_expand_fixed_x", function(fixed_x, map) fixed_x)
if (mutant == "halffix") {
  swap(".sem_expand_fixed_x", function(fixed_x, map) {
    if (!is.character(fixed_x)) {
      return(fixed_x)
    }
    unlist(lapply(fixed_x, function(v) if (v %in% names(map)) map[[v]]$dummies[1L] else v), use.names = FALSE)
  })
}
if (mutant == "nomap") swap(".sem_stored_factors", function(factors, data) list())
if (mutant == "dropdummy") {
  orig_t <- get(".sem_expand_table", ns)
  swap(".sem_expand_table", function(tab, map) {
    out <- orig_t(tab, map)
    last <- vapply(map, function(m) m$dummies[length(m$dummies)], "")
    out[!(out$op == "~" & out$rhs %in% last), , drop = FALSE]
  })
}

gen <- function(n, k, seed, miss) {
  set.seed(seed)
  lev <- letters[seq_len(k)]
  g <- factor(sample(lev, n, replace = TRUE), levels = lev)
  eff <- seq(0, 0.6, length.out = k)
  x <- rnorm(n)
  m <- 0.5 * x + eff[as.integer(g)] + rnorm(n)
  y <- 0.4 * m + 0.2 * x + 0.5 * eff[rev(seq_len(k))][as.integer(g)] + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, g = g)
  if (miss == "factor") d$g[sample(n, round(0.1 * n))] <- NA
  if (miss == "outcome") d$y[sample(n, round(0.1 * n))] <- NA
  tw <- d
  for (l in lev[-1L]) tw[[paste0("g_", l)]] <- as.numeric(d$g == l)
  list(factor = d, twin = tw, dummies = paste0("g_", lev[-1L]))
}

rel <- function(a, b) max(abs(a - b) / pmax(abs(b), 1e-8))
# estimates near zero make a purely relative gap meaningless (lavaan stops at about 1e-5 absolute): scale by max(1, |b|)
scaled <- function(a, b) max(abs(a - b) / pmax(abs(b), 1))
one_run <- function(n, k, seed, miss, fxmode) {
  d <- gen(n, k, seed, miss)
  dum <- d$dummies
  mod_f <- "m ~ a*x + g\ny ~ b*m + cp*x + g"
  mod_t <- paste0("m ~ a*x + ", paste(dum, collapse = " + "), "\ny ~ b*m + cp*x + ", paste(dum, collapse = " + "))
  fx_f <- switch(fxmode, free = FALSE, g = "g", all = TRUE, xg = c("x", "g"))
  fx_t <- switch(fxmode, free = FALSE, g = dum, all = TRUE, xg = c("x", dum))
  row <- data.frame(n = n, k = k, seed = seed, miss = miss, fxmode = fxmode, twin = NA, names = NA, lavaan = NA,
                    moments = NA, refit = NA, err = "", stringsAsFactors = FALSE)
  res <- tryCatch({
    f <- suppressMessages(fit_sem(mod_f, d$factor, fixed_x = fx_f))
    ft <- suppressMessages(fit_sem(mod_t, d$twin, fixed_x = fx_t))
    keep <- stats::complete.cases(d$twin[, c("y", "m", "x", "g")])
    se_ok <- identical(is.na(f@table$se), is.na(ft@table$se)) && any(!is.na(ft@table$se)) &&
      rel(f@table$se[!is.na(ft@table$se)], ft@table$se[!is.na(ft@table$se)]) <= 1e-6
    ll_gap <- abs(as.numeric(logLik(f)) - as.numeric(logLik(ft))) / max(1, abs(as.numeric(logLik(ft))))
    row$twin <- f@n_obs == sum(keep) && identical(f@table$rhs, ft@table$rhs) &&
      rel(f@table$est, ft@table$est) <= 1e-8 && se_ok && ll_gap <= 1e-8
    row$names <- identical(f@internals$factors$g$dummies, dum) && f@internals$factors$g$reference == "a"
    fixed <- f@table[f@table$fixed_x %in% TRUE & f@table$op == "~~", ]
    used <- d$twin[keep, c("x", dum)]
    sm <- stats::cov(used) * (nrow(used) - 1) / nrow(used)
    row$moments <- if (fxmode == "free") {
      nrow(fixed) == 0L
    } else {
      nrow(fixed) > 0L && max(abs(fixed$est - mapply(function(a, b) sm[a, b], fixed$lhs, fixed$rhs))) <= 1e-8
    }
    if (fxmode %in% c("free", "all") && requireNamespace("lavaan", quietly = TRUE)) {
      l <- lavaan::sem(mod_t, d$twin, meanstructure = TRUE, fixed.x = fxmode == "all", information = "observed")
      pe <- lavaan::parameterEstimates(l)
      pe <- pe[pe$op == "~", ]
      est <- f@table[f@table$op == "~", ]
      row$lavaan <- scaled(est$est, pe$est) <= 1e-5 && rel(est$se[!is.na(est$se)], pe$se[!is.na(est$se)]) <= 1e-3
    }
    r <- mbco_sem(f, paths = c("a", "b"))
    rt <- mbco_sem(ft, paths = c("a", "b"))
    row$refit <- is.finite(r$statistic) && rel(r$statistic, rt$statistic) <= 1e-6
    row
  }, error = function(e) {
    row$err <- substr(conditionMessage(e), 1L, 120L)
    row
  })
  res
}

cells <- expand.grid(n = c(100L, 400L), k = c(2L, 3L, 5L), seed = seeds, miss = c("none", "factor", "outcome"),
                     fxmode = c("free", "g", "all", "xg"), stringsAsFactors = FALSE)
out <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  do.call(one_run, as.list(cells[i, c("n", "k", "seed", "miss", "fxmode")]))
}))
ok <- function(x) x %in% TRUE
lav_ran <- out$fxmode %in% c("free", "all") & requireNamespace("lavaan", quietly = TRUE)
pass <- ok(out$twin) & ok(out$names) & (ok(out$lavaan) | !lav_ran) & ok(out$moments) & ok(out$refit) & !nzchar(out$err)
out$pass <- pass
dir.create("tests/sim/results", showWarnings = FALSE)
tag <- if (nzchar(mutant)) paste0("-", mutant) else ""
f_out <- file.path("tests/sim/results", paste0("sem-factor-gate-", Sys.Date(), tag, ".csv"))
utils::write.csv(out, f_out, row.names = FALSE)
cat(sprintf("factor gate%s: %d runs, %d pass, %d fail\n", if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else "",
            nrow(out), sum(pass), sum(!pass)))
for (col in c("twin", "names", "moments", "refit")) {
  cat(sprintf("  %-7s fail %d\n", col, sum(!ok(out[[col]]))))
}
cat(sprintf("  lavaan  fail %d of %d run (%d skipped)\n", sum(lav_ran & !ok(out$lavaan)), sum(lav_ran), sum(!lav_ran)))
if (any(nzchar(out$err))) cat("  errors, first:", out$err[nzchar(out$err)][1L], "\n")
quit(status = if (all(pass)) 0L else 1L)
