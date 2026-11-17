# Few-clusters design study (planning/PLAN-few-clusters-design-study-2026-11-16.md, tasks T1 to T3): the data
# generator, the cell grid, the seeds, the two lavaan arms (P0 default, P1 syntax floor), the row builder used by
# tests/sim/twolevel-few-clusters.R and the three-effect cluster-bootstrap closure (T3). Checked by the harness
# tests in tests/testthat/test-twolevel-few-clusters-harness.R.
#
# Population (P2X section 4.1, the O8 oracle population): z_ij = u_j + e_ij, z = (X, M, Y), mean 0,
#   within  M = .5 X, Y = .4 M + .2 X, residual variances 1, .8, .9;
#   between M = .3 X, Y = .6 M + .1 X (b = 0 in the null cells), residual variances .7, .5, .6, each times s,
# with s = ICC_X / (.7 (1 - ICC_X)), so that ICC_X = .7 s / (.7 s + 1). Truths: NIE_W = .20, NIE_B = .18 or 0;
# the adapter's `nie_contrast` row is within minus between, so its truth is NIE_W - NIE_B (.02 or .20).
#
# Every function is prefixed `fc_` so that it does not mask the `tl_*` helpers of the two-level tests.

fc_population <- function() {
  list(
    within = list(a = .5, b = .4, cp = .2, vx = 1, vm = .8, vy = .9),
    between = list(a = .3, b = .6, cp = .1, vx = .7, vm = .5, vy = .6)
  )
}

# Covariance implied by one level's paths, (I - B)^-1 Psi (I - B)^-T, order X, M, Y.
fc_sigma <- function(a, b, cp, vx, vm, vy) {
  beta <- matrix(0, 3, 3, dimnames = list(c("X", "M", "Y"), c("X", "M", "Y")))
  beta["M", "X"] <- a
  beta["Y", "M"] <- b
  beta["Y", "X"] <- cp
  inv <- solve(diag(3) - beta)
  out <- inv %*% diag(c(vx, vm, vy)) %*% t(inv)
  dimnames(out) <- dimnames(beta)
  out
}

# Between-level scale s for a target ICC_X (section 4).
fc_scale <- function(icc_x) {
  checkmate::assert_number(icc_x, lower = 0, upper = 1, .var.name = "icc_x")
  icc_x / (fc_population()$between$vx * (1 - icc_x))
}

# Implied within and between covariance matrices for scale s and NIE_B .18 (b_b = .6) or 0 (b_b = 0).
fc_implied <- function(s, nie_b = .18) {
  checkmate::assert_number(s, lower = 0, .var.name = "s")
  checkmate::assert_choice(nie_b, c(.18, 0), .var.name = "nie_b")
  pop <- fc_population()
  w <- pop$within
  b <- pop$between
  b_b <- if (nie_b == 0) 0 else b$b
  list(
    s = s,
    sw = fc_sigma(w$a, w$b, w$cp, w$vx, w$vm, w$vy),
    sb = s * fc_sigma(b$a, b_b, b$cp, b$vx, b$vm, b$vy)
  )
}

# Intraclass correlations from the implied covariance diagonals.
fc_icc <- function(implied) {
  vb <- diag(implied$sb)
  vb / (vb + diag(implied$sw))
}

# Population values of the reported estimands.
fc_truth <- function(nie_b) {
  checkmate::assert_choice(nie_b, c(.18, 0), .var.name = "nie_b")
  pop <- fc_population()
  nie_w <- pop$within$a * pop$within$b
  nie_bt <- if (nie_b == 0) 0 else pop$between$a * pop$between$b
  c(
    nie_within = nie_w, nie_between = nie_bt, nie_contrast = nie_w - nie_bt,
    c_prime_within = pop$within$cp, c_prime_between = pop$between$cp
  )
}

# Cluster sizes. Equal: n per cluster. Unequal (same mean, CV about .5, at least 2 per cluster): a deterministic
# right-skewed design, 2 + (n - 2) w_j with w_j standardized exponential quantiles scaled so that the CV of the sizes
# is .5 before rounding; the rounding residue is moved to the largest clusters so the total stays J n.
fc_sizes <- function(n_clusters, n, balance, cv = .5) {
  checkmate::assert_count(n_clusters, positive = TRUE, .var.name = "n_clusters")
  checkmate::assert_number(n, lower = 3, .var.name = "n")
  checkmate::assert_choice(balance, c("equal", "unequal"), .var.name = "balance")
  if (balance == "equal") return(rep(as.integer(n), n_clusters))
  e <- stats::qexp(stats::ppoints(n_clusters))
  z <- (e - mean(e)) / stats::sd(e)
  w <- 1 + cv * n / (n - 2) * z
  sizes <- pmax(2L, as.integer(round(2 + (n - 2) * w)))
  total <- as.integer(n_clusters * n)
  gap <- total - sum(sizes)
  ord <- order(sizes, decreasing = TRUE)
  while (gap != 0L) {
    k <- ord[seq_len(min(abs(gap), n_clusters))]
    sizes[k] <- sizes[k] + as.integer(sign(gap))
    gap <- total - sum(sizes)
  }
  sizes
}

# Main grid (section 4): 5 x 2 x 3 x 2 x 2 = 120 cells, ids from 1001 (disjoint from the P2X section 4.6
# mini-pilot, which used s in {1, .1}).
fc_grid <- function() {
  g <- expand.grid(
    J = c(10, 20, 30, 50, 100), n = c(5, 20), icc_x = c(.05, .20, .40), balance = c("equal", "unequal"),
    nie_b = c(.18, 0), stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
  )
  cbind(cell_id = 1000L + seq_len(nrow(g)), g)
}

# Seed per dataset (section 9).
fc_seed <- function(cell_id, rep) {
  as.integer(cell_id * 1e5 + rep)
}

# One dataset for a grid row; L'Ecuyer-CMRG streams, the session's RNG state left untouched.
fc_simulate <- function(cell, rep) {
  sizes <- fc_sizes(cell$J, cell$n, cell$balance)
  imp <- fc_implied(fc_scale(cell$icc_x), cell$nie_b)
  draws <- withr::with_seed(fc_seed(cell$cell_id, rep), .rng_kind = "L'Ecuyer-CMRG", {
    list(
      u = matrix(stats::rnorm(cell$J * 3), cell$J, 3) %*% chol(imp$sb),
      e = matrix(stats::rnorm(sum(sizes) * 3), sum(sizes), 3) %*% chol(imp$sw)
    )
  })
  id <- rep(seq_len(cell$J), sizes)
  z <- draws$u[id, , drop = FALSE] + draws$e
  data.frame(id = id, X = z[, 1], M = z[, 2], Y = z[, 3])
}

# A planted dataset whose level-2 variance of Y has a negative ML estimate (T2): Y's cluster means are replaced by
# near-constant values, so the between variance of Y is pushed below zero.
fc_planted_negative <- function() {
  withr::with_seed(1, .rng_kind = "Mersenne-Twister", {
    n_clusters <- 30
    id <- rep(seq_len(n_clusters), each = 5)
    xb <- stats::rnorm(n_clusters)[id]
    mb <- stats::rnorm(n_clusters, sd = .7)[id]
    x <- xb + stats::rnorm(length(id))
    m <- .5 * x + mb + stats::rnorm(length(id))
    y <- .4 * m + .2 * x + stats::rnorm(length(id))
    y <- y - stats::ave(y, id) + stats::rnorm(n_clusters, sd = .05)[id]
    data.frame(id = id, X = x, M = m, Y = y)
  })
}

# lavaan syntax. P0: lavaan defaults. P1: each level-2 residual variance labeled and bounded below by eps in syntax
# (`bounds = "pos.var"` adds no bound to a two-level fit; planning/studies/few-clusters/T2-floor-mechanics.md).
fc_model <- function(floor = FALSE, eps = 1e-3) {
  checkmate::assert_flag(floor, .var.name = "floor")
  checkmate::assert_number(eps, lower = 0, .var.name = "eps")
  l2_var <- if (floor) "  X ~~ vx_b*X\n  M ~~ vm_b*M\n  Y ~~ vy_b*Y\n" else ""
  ineq <- if (floor) sprintf("vx_b > %1$.10g\nvm_b > %1$.10g\nvy_b > %1$.10g\n", eps) else ""
  paste0(
    "level: 1\n  M ~ a_w*X\n  Y ~ b_w*M + cp_w*X\n",
    "level: 2\n", l2_var, "  M ~ a_b*X\n  Y ~ b_b*M + cp_b*X\n",
    ineq
  )
}

# Fit one arm; lavaan warnings are collected and an error is returned, not thrown.
fc_fit <- function(data, arm = c("p0", "p1"), eps = 1e-3) {
  arm <- match.arg(arm)
  msgs <- character(0)
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    withCallingHandlers(
      lavaan::sem(fc_model(floor = arm == "p1", eps = eps), data = data, cluster = "id", fixed.x = FALSE),
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  list(
    fit = fit, lavaan_warnings = msgs,
    error = if (inherits(fit, "error")) conditionMessage(fit) else NA_character_,
    time = proc.time()[["elapsed"]] - t0
  )
}

# Level-2 residual variances read from the lavaan parameter table (separately from post.check).
fc_l2_var <- function(fit) {
  pt <- lavaan::parTable(fit)
  rows <- pt$level == 2L & pt$op == "~~" & pt$lhs == pt$rhs & pt$lhs %in% c("X", "M", "Y")
  stats::setNames(pt$est[rows], pt$lhs[rows])[c("X", "M", "Y")]
}

fc_estimands <- c("nie_within", "nie_between", "nie_contrast", "c_prime_within", "c_prime_between")

fc_adapter_classes <- c(
  few_clusters = "medfit_warning_twolevel_few_clusters",
  inadmissible = "medfit_warning_twolevel_inadmissible",
  between_unidentified = "medfit_between_unidentified",
  between_weak = "medfit_warning_between_weak"
)

# One row for a dataset and arm: fit status, level-2 variances, adapter warning flags, and per estimand the delta
# estimate, SE, interval and truth (NA when the adapter returns a within-only object or the fit fails).
fc_analyze <- function(data, arm, eps = 1e-3, truth, ci_level = .95) {
  f <- fc_fit(data, arm, eps)
  row <- data.frame(
    arm = arm, eps = if (arm == "p1") eps else NA_real_, lavaan_error = f$error,
    n_lavaan_warn = length(f$lavaan_warnings), lavaan_warn = paste(unique(f$lavaan_warnings), collapse = " | "),
    fit_time = f$time, converged = NA, between_identified = NA, admissible = NA,
    l2_var_x = NA_real_, l2_var_m = NA_real_, l2_var_y = NA_real_, neg_l2_var = NA, at_bound = NA,
    adapter_error = NA_character_, other_warn = "", tidy_warn = "", stringsAsFactors = FALSE
  )
  for (k in names(fc_adapter_classes)) row[[paste0("warn_", k)]] <- FALSE
  for (e in fc_estimands) {
    row[[paste0("est_", e)]] <- NA_real_
    row[[paste0("se_", e)]] <- NA_real_
    row[[paste0("lo_", e)]] <- NA_real_
    row[[paste0("hi_", e)]] <- NA_real_
    row[[paste0("truth_", e)]] <- truth[[e]]
  }
  if (!is.na(f$error)) return(row)
  row$converged <- isTRUE(lavaan::lavInspect(f$fit, "converged"))
  v <- fc_l2_var(f$fit)
  row$l2_var_x <- v[["X"]]
  row$l2_var_m <- v[["M"]]
  row$l2_var_y <- v[["Y"]]
  row$neg_l2_var <- any(v < 0)
  row$at_bound <- if (arm == "p1") any(v - eps <= 10 * eps) else NA

  adapter_warn <- character(0)
  other <- character(0)
  obj <- tryCatch(
    withCallingHandlers(
      medfit::extract_mediation(f$fit, treatment = "X", mediator = "M", outcome = "Y"),
      warning = function(w) {
        hit <- names(fc_adapter_classes)[vapply(fc_adapter_classes, function(k) inherits(w, k), logical(1))]
        if (length(hit)) adapter_warn <<- c(adapter_warn, hit) else other <<- c(other, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  for (k in unique(adapter_warn)) row[[paste0("warn_", k)]] <- TRUE
  row$other_warn <- paste(unique(other), collapse = " | ")
  if (inherits(obj, "error")) {
    row$adapter_error <- conditionMessage(obj)
    return(row)
  }
  row$between_identified <- obj@between_identified
  row$admissible <- obj@admissible
  # tidy() warns that the between rows are NA on a within-only object; record it, do not let it escape
  tidy_warn <- character(0)
  td <- withCallingHandlers(
    generics::tidy(obj, conf_int = TRUE, conf_level = ci_level),
    warning = function(w) {
      tidy_warn <<- c(tidy_warn, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  row$tidy_warn <- paste(unique(tidy_warn), collapse = " | ")
  for (e in intersect(fc_estimands, td$term)) {
    i <- match(e, td$term)
    row[[paste0("est_", e)]] <- td$estimate[i]
    row[[paste0("se_", e)]] <- td$std_error[i]
    row[[paste0("lo_", e)]] <- td$conf_low[i]
    row[[paste0("hi_", e)]] <- td$conf_high[i]
  }
  row
}

# Planted mutants (T4 uses them; the scaffold is here): "truth" adds .05 to every truth, "narrow" shrinks every
# delta interval by 20% about its estimate. An empty name leaves the row alone; any other name is an error.
fc_apply_mutant <- function(row, mutant) {
  checkmate::assert_string(mutant, .var.name = "mutant")
  if (!nzchar(mutant)) return(row)
  if (!mutant %in% c("truth", "narrow")) stop("unknown mutant '", mutant, "'", call. = FALSE)
  for (col in grep("^truth_", names(row), value = TRUE)) {
    e <- sub("^truth_", "", col)
    if (mutant == "truth") {
      row[[col]] <- row[[col]] + .05
    } else {
      est <- row[[paste0("est_", e)]]
      row[[paste0("lo_", e)]] <- est - .8 * (est - row[[paste0("lo_", e)]])
      row[[paste0("hi_", e)]] <- est + .8 * (row[[paste0("hi_", e)]] - est)
    }
  }
  row
}

# Three-effect cluster-bootstrap closure (task T3): one refit per resample, the three statistics of
# fc_boot_effects. It reproduces three runs of the shipped `twolevel_statistic(fit, effect)` refit callback
# (R/twolevel-statistic.R): the same refit call (the stored lavaan call with `data`, `se`, `test` and `check.post`
# replaced, and a non-literal `model` replaced by the fit's parameter table without estimates and starts), the same
# key rows, effect arithmetic and ICC gate, which applies to the between effect and the contrast only. A refit that
# errors or warns is left to the caller, as bootstrap_mediation()'s cluster loop does. `defect` plants the T3
# mutants: "swap" (NIE_B returned as NIE_W), "sign" (contrast between minus within), "original" (refit on `data`, the
# original sample, whatever the resample) and "gate_all" (the ICC gate also blanks NIE_W).
# The shipped constructor's refusals are carried over at build time, per effect: the same extraction of the original
# fit and the same `.twolevel_stat_check()`. When every effect is refused the builder signals that condition (same
# class); otherwise the refused effects are listed in the `refused` attribute (effect = condition) and returned as NA.
# A fifth mutant, "nobuild", skips these build-time checks.
fc_boot_effects <- c("nie_within", "nie_between", "nie_contrast")

fc_boot_closure <- function(fit, treatment = "X", mediator = "M", outcome = "Y", data = NULL, defect = "",
                            env = parent.frame()) {
  # forced here, as the shipped refit does: the frame that called the closure builder resolves the stored call's names
  force(env)
  checkmate::assert_choice(defect, c("", "swap", "sign", "original", "gate_all", "nobuild"), .var.name = "defect")
  if (defect == "original") checkmate::assert_data_frame(data, .var.name = "data")
  med <- asNamespace("medfit")
  refused <- list()
  if (defect != "nobuild") {
    # as twolevel_statistic() does for a lavaan fit: read the fit once, then check each effect
    td <- tryCatch(
      suppressWarnings(medfit::extract_mediation(fit, treatment = treatment, mediator = mediator, outcome = outcome)),
      error = function(e) e
    )
    if (inherits(td, "error")) stop(td)
    for (e in fc_boot_effects) {
      cnd <- tryCatch(med$.twolevel_stat_check(td, e), error = function(err) err)
      if (inherits(cnd, "error")) refused[[e]] <- cnd
    }
    if (length(refused) == length(fc_boot_effects)) stop(refused[[1L]])
  }
  call <- fit@call
  if (is.null(call)) stop("the lavaan fit has no stored call to refit", call. = FALSE)
  if (!is.character(call$model)) {
    model <- lavaan::parTable(fit)
    model$est <- NULL
    model$se <- NULL
    model$start <- NULL
    call$model <- model
  }
  call$se <- "none"
  call$test <- "none"
  call$check.post <- FALSE
  rm(fit)
  # the shipped callback's own internals, so the key rows, ICC and effect arithmetic cannot drift from it
  value <- med$.twolevel_stat_value
  na3 <- stats::setNames(rep(NA_real_, 3L), fc_boot_effects)

  fn <- function(d) {
    refit_call <- call
    refit_call$data <- if (defect == "original") data else d
    # re-evaluates the fit's own lavaan call (the harness model and options), not arbitrary input
    refit <- eval(refit_call, env)
    if (!med$.twolevel_converged(refit)) return(na3)
    key <- med$.twolevel_key_rows(lavaan::parTable(refit), treatment, mediator, outcome)
    p <- stats::setNames(key$est, key$path)
    out <- vapply(fc_boot_effects, function(e) value(e, p), numeric(1))
    if (defect == "swap") out[["nie_within"]] <- out[["nie_between"]]
    if (defect == "sign") out[["nie_contrast"]] <- -out[["nie_contrast"]]
    icc <- med$.twolevel_icc(refit)
    icc_floor <- med$.twolevel_option("icc_error")
    if (!all(c(treatment, mediator) %in% names(icc)) || any(icc[c(treatment, mediator)] < icc_floor)) {
      gated <- if (defect == "gate_all") fc_boot_effects else c("nie_between", "nie_contrast")
      out[gated] <- NA_real_
    }
    out[!is.finite(out)] <- NA_real_
    out[names(refused)] <- NA_real_
    out
  }
  attr(fn, "refused") <- refused
  fn
}

# One row per dataset and arm for a grid row and replicate.
fc_row <- function(cell, rep, arm, eps = 1e-3, mutant = "") {
  d <- fc_simulate(cell, rep)
  out <- fc_analyze(d, arm, eps = eps, truth = fc_truth(cell$nie_b))
  out <- fc_apply_mutant(out, mutant)
  cbind(cell, rep = as.integer(rep), seed = fc_seed(cell$cell_id, rep), n_obs = nrow(d), out, mutant = mutant,
        stringsAsFactors = FALSE)
}
