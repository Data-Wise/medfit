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
#            runs sat at 1.08e-5 relative on a near-zero coefficient) and SEs 1e-3 (relative) against lavaan on
#            the twin (fixed.x matched)
#   moments  with fixed_x, every fixed ~~ row equals the ML moment of the rows the fit used, computed in base R (1e-8)
#   fitstats npar, df and chi-square equal lavaan's (chi-square 1e-5 relative); the model has no x -> y path, so df = 1
#            and the chi-square is not trivially zero; lavaan runs without a mean structure (medfit's has none)
#   refit    mbco_sem(paths = c("a", "b")) statistic equals the twin's (1e-6, relative): a refit works from the stored
#            data and factor map
# `lost` cells (T5): per n in {100, 400} x K in {3, 5} x seed, a character column whose last level occurs only where the
# outcome is NA, a factor with a declared level no row has, and (branchprod) a zero-product constraint with a product
# input that is NA exactly where the last level lives. The rule: the fit errors, the message names the dummy
# (`g_<level>`) and its cause; a run that fits fails. Dummies come from the full column before listwise deletion.
# `prod` cells (T6): per n in {100, 400} x K in {2, 3} x seed x missingness {none, factor, outcome} x form {gx, gf,
# gm, go}:
# `g:x` (exogenous product), `g:f` with `f` sorting before the dummies (canonical name `f:g_b`), `g:m` (endogenous
# product factor, model test NA), `go` = `g:x` with no bare `g` (the dummies are not model variables). Rule: the fit
# equals the hand-coded product twin (estimates 1e-8, SEs 1e-6, logLik
# 1e-8, identical terms), the outcome equation equals equation-wise OLS on columns built from the EXPECTED terms (1e-6;
# an oracle that uses neither medfit nor its table), the model-test verdict equals the twin's and the documented
# policy (NA only for gm), and mbco_sem() gives the twin's message (a refit that lost the factor would differ).
# `MUTANT=<name>` plants a defect and the gate must then exit 1: wrongref (the reference is the last level), nofix
# (fixed_x names stay as the factor), noncanon (a factor product is named in the written order, not the canonical
# one), oneprod (a factor product expands to all but its last dummy), afterdelete (the pre-pass sees only the complete
# rows, so a level present only in
# dropped rows vanishes silently), nolevelcheck (the constant-dummy check returns nothing), halffix (a factor in
# fixed_x fixes only its first dummy), nomap (a refit loses
# the stored factor map), dropdummy (the last dummy is left out of the table).
# lavaan's `fixed.x` is logical, so the lavaan rule runs for fixed_x = FALSE and TRUE only (other cells count as
# skipped).
# Run from the package root:  Rscript tests/sim/sem-factor-gate.R   (SEEDS=5 by default; SEEDS=1 is a smoke run)

suppressMessages(pkgload::load_all(quiet = TRUE))
if (!requireNamespace("lavaan", quietly = TRUE)) {
  stop("this gate needs lavaan (Suggests): without it the parity checks would be skipped, not failed",
       call. = FALSE)
}
seeds <- seq_len(as.integer(Sys.getenv("SEEDS", "5")))
mutant <- Sys.getenv("MUTANT", "")
ns <- asNamespace("medfit")
# A mutant replaces an internal function: it must keep the original's argument list, otherwise the gate turns red
# from an "unused argument" error (the wrong reason) and the mutant proves nothing (Codex review of T5).
swap <- function(name, fn) {
  if (!identical(formals(get(name, ns)), formals(fn))) {
    stop("MUTANT ", mutant, ": the replacement of ", name, " changes the argument list or its defaults (",
         paste(names(formals(get(name, ns))), collapse = ", "), "), so it would fail for the wrong reason")
  }
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
if (mutant == "noncanon") {
  orig_n <- get(".sem_row_expansion", ns)
  swap(".sem_row_expansion", function(rhs, map) {
    sides <- strsplit(rhs, ":", fixed = TRUE)[[1L]]
    hit <- sides %in% names(map)
    if (length(sides) == 2L && any(hit)) {
      return(paste0(map[[sides[hit]]]$dummies, ":", sides[!hit]))
    }
    orig_n(rhs, map)
  })
}
if (mutant == "oneprod") {
  orig_r <- get(".sem_row_expansion", ns)
  swap(".sem_row_expansion", function(rhs, map) {
    out <- orig_r(rhs, map)
    if (grepl(":", rhs, fixed = TRUE) && length(out) > 1L) out[-length(out)] else out
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
if (mutant == "afterdelete") {
  orig_e <- get(".sem_expand_factors", ns)
  swap(".sem_expand_factors", function(tab, data, fixed_x, factors = NULL) {
    vars <- intersect(c(tab$lhs, tab$rhs), names(data))
    orig_e(tab, data[stats::complete.cases(data[, vars, drop = FALSE]), , drop = FALSE], fixed_x, factors)
  })
}
if (mutant == "nolevelcheck") {
  swap(".sem_check_dummy_support", function(map, data, keep, weights = NULL) invisible(NULL))
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
  mod_f <- "m ~ a*x + g\ny ~ b*m + g"
  mod_t <- paste0("m ~ a*x + ", paste(dum, collapse = " + "), "\ny ~ b*m + ", paste(dum, collapse = " + "))
  fx_f <- switch(fxmode, free = FALSE, g = "g", all = TRUE, xg = c("x", "g"))
  fx_t <- switch(fxmode, free = FALSE, g = dum, all = TRUE, xg = c("x", dum))
  row <- data.frame(n = n, k = k, seed = seed, miss = miss, fxmode = fxmode, twin = NA, names = NA, lavaan = NA,
                    fitstats = NA, moments = NA, refit = NA, err = "", stringsAsFactors = FALSE)
  res <- tryCatch({
    f <- suppressMessages(fit_sem(mod_f, d$factor, fixed_x = fx_f, meanstructure = NULL))
    ft <- suppressMessages(fit_sem(mod_t, d$twin, fixed_x = fx_t, meanstructure = NULL))
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
      nrow(fixed) > 0L && all(c(fixed$lhs, fixed$rhs) %in% colnames(sm)) &&
        max(abs(fixed$est - mapply(function(a, b) sm[a, b], fixed$lhs, fixed$rhs))) <= 1e-8
    }
    if (fxmode %in% c("free", "all")) {
      l <- lavaan::sem(mod_t, d$twin, meanstructure = TRUE, fixed.x = fxmode == "all", information = "observed")
      l0 <- lavaan::sem(mod_t, d$twin, meanstructure = FALSE, fixed.x = fxmode == "all", information = "observed")
      ref <- lavaan::fitMeasures(l0, c("npar", "df", "chisq"))
      gl <- generics::glance(f)
      row$fitstats <- gl$df > 0 && is.finite(gl$chisq) && gl$chisq > 0 && gl$npar == ref[["npar"]] &&
        gl$df == ref[["df"]] && abs(gl$chisq - ref[["chisq"]]) <= 1e-5 * max(1, ref[["chisq"]])
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
# lost-level cells: the fit must error naming the dummy and the cause
lost_run <- function(n, k, seed, kind) {
  mod <- "m ~ x + g\ny ~ m + g"
  set.seed(seed)
  lev <- letters[seq_len(k)]
  g <- sample(lev, n, replace = TRUE)
  x <- rnorm(n)
  m <- 0.5 * x + rnorm(n)
  y <- 0.4 * m + rnorm(n)
  last <- lev[k]
  if (kind == "dropped") {
    y[g == last] <- NA
    g[which(g == last)[1L]] <- NA_character_ # the level also has an NA row: still only in dropped rows
    d <- data.frame(y = y, m = m, x = x, g = g, stringsAsFactors = FALSE)
    want <- paste0("`g_", last, "`.*only in rows dropped for missing values")
  } else if (kind == "productonly") {
    # the factor appears only inside g:z, and z is NA exactly where the last level lives (no bare g in the model)
    z <- rnorm(n)
    z[g == last] <- NA
    d <- data.frame(y = y, m = m, x = x, z = z, g = g, stringsAsFactors = FALSE)
    mod <- "m ~ x\ny ~ m + g:z"
    want <- paste0("^dummy `g_", last, "`.*only in rows dropped for missing values")
  } else if (kind == "branchprod") {
    # a zero-product constraint (branch fits) and a product whose input is NA exactly where the last level lives
    z <- rnorm(n)
    z[g == last] <- NA
    d <- data.frame(y = y, m = m, x = x, w = rnorm(n), z = z, g = g, stringsAsFactors = FALSE)
    mod <- "m ~ a*x + g + z:w\ny ~ b*m + g\na*b == 0"
    want <- paste0("^dummy `g_", last, "`.*only in rows dropped for missing values") # not the branch wrapper
  } else {
    d <- data.frame(y = y, m = m, x = x, g = factor(g, levels = c(lev, "zz")))
    want <- "`g_zz`.*no row has this level"
  }
  msg <- tryCatch({
    suppressMessages(fit_sem(mod, d, fixed_x = FALSE, meanstructure = NULL))
    NA_character_
  }, error = function(e) conditionMessage(e))
  data.frame(n = n, k = k, seed = seed, miss = kind, fxmode = "lost", twin = NA, names = NA, lavaan = NA,
             fitstats = NA, moments = NA, refit = NA, lost = !is.na(msg) && grepl(want, msg),
             err = "", stringsAsFactors = FALSE, msg = msg)
}
lost_cells <- expand.grid(n = c(100L, 400L), k = c(3L, 5L), seed = seeds,
                          kind = c("dropped", "unused", "branchprod", "productonly"),
                          stringsAsFactors = FALSE)
lost <- do.call(rbind, lapply(seq_len(nrow(lost_cells)), function(i) do.call(lost_run, as.list(lost_cells[i, ]))))
# product cells
prod_run <- function(n, k, seed, miss, form) {
  set.seed(seed)
  lev <- letters[seq_len(k)]
  g <- factor(sample(lev, n, replace = TRUE), levels = lev)
  x <- rnorm(n)
  f <- 0.3 * x + rnorm(n)
  m <- 0.5 * x + 0.4 * f + 0.4 * (g == lev[2L]) + rnorm(n)
  inter <- switch(form, gx = x, go = x, gf = f, gm = m)
  y <- 0.4 * m + 0.2 * x + 0.1 * f + 0.3 * (g == lev[k]) + 0.3 * inter * (g == lev[2L]) + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, f = f, g = g)
  if (miss == "factor") d$g[sample(n, round(0.1 * n))] <- NA
  if (miss == "outcome") d$y[sample(n, round(0.1 * n))] <- NA
  dum <- paste0("g_", lev[-1L])
  tw <- d
  for (l in lev[-1L]) tw[[paste0("g_", l)]] <- as.numeric(d$g == l)
  other <- switch(form, gx = "x", go = "x", gf = "f", gm = "m")
  pf <- paste0("g:", other)
  pt <- paste(paste0(dum, ":", other), collapse = " + ")
  dp <- paste(dum, collapse = " + ")
  bare <- form != "go"
  mod_f <- paste0("m ~ x + f\ny ~ m + x + f + ", if (bare) "g + " else "", pf)
  mod_t <- paste0("m ~ x + f\ny ~ m + x + f + ", if (bare) paste0(dp, " + ") else "", pt)
  expected <- c("m", "x", "f", if (bare) dum, paste0(dum, ":", other))
  row <- data.frame(n = n, k = k, seed = seed, miss = miss, fxmode = form, twin = NA, names = NA, lavaan = NA,
                    fitstats = NA, moments = NA, refit = NA, lost = NA, ols = NA, verdict = NA, err = "",
                    stringsAsFactors = FALSE)
  tryCatch({
    fa <- suppressWarnings(suppressMessages(fit_sem(mod_f, d, fixed_x = FALSE, meanstructure = NULL)))
    ft <- suppressWarnings(suppressMessages(fit_sem(mod_t, tw, fixed_x = FALSE, meanstructure = NULL)))
    se_ok <- identical(is.na(fa@table$se), is.na(ft@table$se)) && any(!is.na(ft@table$se)) &&
      rel(fa@table$se[!is.na(ft@table$se)], ft@table$se[!is.na(ft@table$se)]) <= 1e-6
    ll <- abs(as.numeric(logLik(fa)) - as.numeric(logLik(ft))) / max(1, abs(as.numeric(logLik(ft))))
    row$twin <- identical(fa@table$rhs, ft@table$rhs) && rel(fa@table$est, ft@table$est) <= 1e-8 && se_ok && ll <= 1e-8
    keep <- stats::complete.cases(tw[, c("y", "m", "x", "f", "g")])
    yrows <- fa@table[fa@table$lhs == "y" & fa@table$op == "~", ]
    # OLS columns from the expected terms, not from the fit's table; the terms must be the fit's, as a set
    X <- vapply(expected, function(r) {
      sides <- strsplit(r, ":", fixed = TRUE)[[1L]]
      Reduce(`*`, lapply(sides, function(z) tw[[z]][keep]))
    }, numeric(sum(keep)))
    ols <- stats::coef(stats::lm.fit(cbind(1, X), tw$y[keep]))[-1L]
    key <- function(r) vapply(strsplit(r, ":", fixed = TRUE), function(z) paste(sort(z), collapse = ":"), "")
    got <- stats::setNames(yrows$est, key(yrows$rhs)) # sides sorted, so the spelling of a product cannot matter here
    want <- stats::setNames(unname(ols), key(expected))
    row$ols <- setequal(names(got), names(want)) && all(is.finite(ols)) &&
      max(abs(want[names(got)] - got)) <= 1e-6
    chisq <- c(generics::glance(fa)$chisq, generics::glance(ft)$chisq)
    row$verdict <- identical(is.na(chisq[1L]), is.na(chisq[2L])) &&
      (anyNA(chisq) || abs(chisq[1L] - chisq[2L]) <= 1e-8 * max(1, chisq[2L])) &&
      identical(is.na(chisq[1L]), c(gx = FALSE, gf = FALSE, go = FALSE, gm = TRUE)[[form]])
    msg <- function(fit) tryCatch(mbco_sem(fit, paths = c("a", "b")), error = function(e) conditionMessage(e))
    row$refit <- is.character(msg(fa)) && identical(msg(fa), msg(ft))
    row$names <- identical(fa@internals$factors$g$dummies, dum)
    row
  }, error = function(e) {
    row$err <- substr(conditionMessage(e), 1L, 120L)
    row
  })
}
prod_cells <- expand.grid(n = c(100L, 400L), k = c(2L, 3L), seed = seeds, miss = c("none", "factor", "outcome"),
                          form = c("gx", "gf", "gm", "go"), stringsAsFactors = FALSE)
prod <- do.call(rbind, lapply(seq_len(nrow(prod_cells)), function(i) do.call(prod_run, as.list(prod_cells[i, ]))))
ok <- function(x) x %in% TRUE
prod$pass <- ok(prod$twin) & ok(prod$ols) & ok(prod$verdict) & ok(prod$refit) & ok(prod$names) & !nzchar(prod$err)
lav_ran <- out$fxmode %in% c("free", "all") # the lavaan and fit-statistic rules apply to these cells, always
out$pass <- ok(out$twin) & ok(out$names) & (ok(out$lavaan) | !lav_ran) & (ok(out$fitstats) | !lav_ran) &
  ok(out$moments) & ok(out$refit) & !nzchar(out$err)
lost$pass <- ok(lost$lost)
# a failing cell keeps what went wrong: the wrong message, or that the fit succeeded
lost$err <- ifelse(lost$pass, "", ifelse(is.na(lost$msg), "fitted without an error", substr(lost$msg, 1L, 120L)))
lost$msg <- NULL
out$lost <- NA
out$ols <- NA
out$verdict <- NA
lost$ols <- NA
lost$verdict <- NA
dir.create("tests/sim/results", showWarnings = FALSE)
tag <- if (nzchar(mutant)) paste0("-", mutant) else ""
f_out <- file.path("tests/sim/results", paste0("sem-factor-gate-", Sys.Date(), tag, ".csv"))
bind_fill <- function(...) {
  dfs <- list(...)
  cols <- unique(unlist(lapply(dfs, names)))
  do.call(rbind, lapply(dfs, function(d) {
    for (cn in setdiff(cols, names(d))) d[[cn]] <- NA
    d[, cols, drop = FALSE]
  }))
}
all_rows <- bind_fill(out, lost, prod)
utils::write.csv(all_rows, f_out, row.names = FALSE)
n_pass <- sum(out$pass) + sum(lost$pass) + sum(prod$pass)
n_run <- nrow(out) + nrow(lost) + nrow(prod)
cat(sprintf("factor gate%s: %d runs, %d pass, %d fail\n", if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else "",
            n_run, n_pass, n_run - n_pass))
for (col in c("twin", "names", "moments", "refit")) {
  cat(sprintf("  %-7s fail %d\n", col, sum(!ok(out[[col]]))))
}
cat(sprintf("  lavaan  fail %d, fitstats fail %d, of %d run (%d skipped)\n", sum(lav_ran & !ok(out$lavaan)),
            sum(lav_ran & !ok(out$fitstats)), sum(lav_ran), sum(!lav_ran)))
cat(sprintf("  lost    fail %d of %d cells\n", sum(!lost$pass), nrow(lost)))
cat(sprintf("  prod    fail %d of %d cells (twin %d, ols %d, verdict %d, refit %d)\n", sum(!prod$pass),
            nrow(prod), sum(!ok(prod$twin)), sum(!ok(prod$ols)), sum(!ok(prod$verdict)), sum(!ok(prod$refit))))
errs <- c(out$err[nzchar(out$err)], lost$err[nzchar(lost$err)], prod$err[nzchar(prod$err)])
if (length(errs)) cat("  errors, first:", errs[1L], "\n")
quit(status = if (n_pass == n_run) 0L else 1L)
