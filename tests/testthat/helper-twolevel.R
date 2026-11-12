# Fixtures and oracles for the two-level (1-1-1) lavaan adapter, TwoLevelMediationData (#394, slice S2)
#
# Every oracle here is independent of the adapter:
# - tl_closed_form():  O1, the balanced saturated closed form, hand code, no lavaan
# - tl_lm_within():    O2, lm on cluster-centered data
# - tl_lm_between():   O2, lm on cluster means (approximate: manifest, not latent, means)
# The fits are lavaan two-level ML fits (about 1-3 s each), cached once per test process.

.tl_cache <- new.env(parent = emptyenv())

# Cached value: computed on first use, then reused by every test file in this process.
tl_cached <- function(key, expr) {
  if (!exists(key, envir = .tl_cache, inherits = FALSE)) {
    assign(key, expr, envir = .tl_cache)
  }
  get(key, envir = .tl_cache, inherits = FALSE)
}

# Data from a known two-level DGP: X, M, Y with a within part and a cluster part. `x_mode` builds the
# degenerate-X fixtures of S1-Q1: "centered" (cluster-mean centered X), "small_between" (a between SD of
# `sd_xb`), "randomized" (X permuted within each cluster with a fixed total, so no between variance).
# `m_mode = "centered"` removes the between part of the mediator.
tl_sim <- function(J = 100L, n = 5L, seed = 20261110L, sd_xb = 1,
                   x_mode = c("normal", "centered", "small_between", "randomized"),
                   m_mode = c("normal", "centered")) {
  x_mode <- match.arg(x_mode)
  m_mode <- match.arg(m_mode)
  set.seed(seed)
  id <- rep(seq_len(J), each = n)
  xb <- stats::rnorm(J, sd = sd_xb)[id]
  xw <- stats::rnorm(J * n)
  x <- switch(x_mode,
    normal = xb + xw,
    centered = xw - stats::ave(xw, id),
    small_between = stats::rnorm(J, sd = 0.05)[id] + xw,
    randomized = as.vector(replicate(J, sample(seq(-2, 2, length.out = n))))
  )
  xw_eff <- if (x_mode %in% c("centered", "randomized")) x else xw
  xb_eff <- if (x_mode == "normal") xb else 0
  mb <- 0.5 * stats::rnorm(J)[id]
  m <- 0.4 * xw_eff + 0.7 * xb_eff + mb + stats::rnorm(J * n)
  if (m_mode == "centered") m <- m - stats::ave(m, id)
  yb <- 0.5 * stats::rnorm(J)[id]
  y <- 0.3 * xw_eff + 0.2 * xb_eff + 0.5 * (m - stats::ave(m, id)) + 0.9 * stats::ave(m, id) +
    yb + stats::rnorm(J * n)
  data.frame(id = id, X = x, M = m, Y = y)
}

# The two-level model: the same three regressions at each level, free labels at the between level.
tl_model <- function(within = "a*X", between = "a2*X") {
  paste0(
    "level: 1\n  M ~ ", within, "\n  Y ~ b*M + cp*X\n",
    "level: 2\n  M ~ ", between, "\n  Y ~ b2*M + cp2*X\n"
  )
}

# The same model with the between-level mediator-to-outcome slope shared with the within level (label `b`).
tl_model_b_shared <- function(within = "a*X", between = "a2*X") {
  paste0(
    "level: 1\n  M ~ ", within, "\n  Y ~ b*M + cp*X\n",
    "level: 2\n  M ~ ", between, "\n  Y ~ b*M + cp2*X\n"
  )
}

# A model without any labels: the first block must not be read for both levels.
tl_model_unlabeled <- function() {
  "level: 1\n  M ~ X\n  Y ~ M + X\nlevel: 2\n  M ~ X\n  Y ~ M + X\n"
}

# Quiet two-level fit: lavaan's warnings on degenerate fixtures are part of the scenario, not a failure.
tl_fit <- function(d, model = tl_model(), ...) {
  suppressWarnings(lavaan::sem(model, data = d, cluster = "id", ...))
}

tl_extract <- function(fit, ...) {
  suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y", ...))
}

tl_fixture <- function(name = "base") {
  tl_cached(paste0("fit_", name), {
    switch(name,
      base = tl_fit(tl_sim()),
      unlabeled = tl_fit(tl_sim(), tl_model_unlabeled()),
      fixed_x_false = tl_fit(tl_sim(), fixed.x = FALSE),
      robust = tl_fit(tl_sim(), se = "robust.huber.white"),
      bootstrap = suppressMessages(tl_fit(tl_sim(), se = "bootstrap", bootstrap = 60L)),
      fiml = {
        d <- tl_sim()
        set.seed(7)
        d$M[sample(nrow(d), 60)] <- NA
        d$Y[sample(nrow(d), 40)] <- NA
        tl_fit(d, missing = "fiml")
      },
      shared_label = tl_fit(tl_sim(), tl_model(within = "a*X", between = "a*X")),
      equal_rows = tl_fit(tl_sim(), paste0(tl_model(), "  a == a2\n")),
      shared_b = tl_fit(tl_sim(), tl_model_b_shared()),
      shared_ab = tl_fit(tl_sim(), tl_model_b_shared(within = "a*X", between = "a*X")),
      # equalities lavaan does not fold into one free parameter: the numeric detector is the only route
      nl_a = tl_fit(tl_sim(), paste0(tl_model(), "  a^2 - a2^2 == 0\n")),
      nl_b = tl_fit(tl_sim(), paste0(tl_model(), "  b^2 - b2^2 == 0\n")),
      nl_ab = tl_fit(tl_sim(), paste0(tl_model(), "  a^2 - a2^2 == 0\n  b^2 - b2^2 == 0\n")),
      x_centered = tl_fit(tl_sim(x_mode = "centered")),
      x_small_between = tl_fit(tl_sim(x_mode = "small_between")),
      x_randomized = tl_fit(tl_sim(x_mode = "randomized")),
      m_centered = tl_fit(tl_sim(m_mode = "centered")),
      j20 = tl_fit(tl_sim(J = 20L)),
      stop("unknown fixture: ", name)
    )
  })
}

# O1: balanced saturated closed form (Muthen 1990). Sigma_W = S_PW with N - J divisor, Sigma_B =
# (S_B - S_PW) / n with S_B = n * sum_j (ybar_j - ybar)(ybar_j - ybar)' / J. No lavaan.
tl_closed_form <- function(d, vars = c("X", "M", "Y")) {
  J <- length(unique(d$id))
  n <- nrow(d) / J
  ybar <- as.matrix(stats::aggregate(d[vars], list(id = d$id), mean)[vars])
  dc <- as.matrix(d[vars]) - ybar[match(d$id, unique(d$id)), ]
  s_pw <- crossprod(dc) / (nrow(d) - J)
  s_b <- n * crossprod(scale(ybar, scale = FALSE)) / J
  slopes <- function(S) {
    a <- S["M", "X"] / S["X", "X"]
    bc <- solve(S[c("M", "X"), c("M", "X")], S[c("M", "X"), "Y"])
    c(a = a, b = unname(bc["M"]), c_prime = unname(bc["X"]))
  }
  list(within = slopes(s_pw), between = slopes((s_b - s_pw) / n))
}

# O2: lm on cluster-centered data (within) and on cluster means (between, approximate).
tl_lm_within <- function(d) {
  ybar <- stats::ave(d$M, d$id)
  dc <- data.frame(
    X = d$X - stats::ave(d$X, d$id), M = d$M - ybar, Y = d$Y - stats::ave(d$Y, d$id)
  )
  cm <- stats::coef(stats::lm(M ~ X - 1, dc))
  cy <- stats::coef(stats::lm(Y ~ M + X - 1, dc))
  c(a = unname(cm["X"]), b = unname(cy["M"]), c_prime = unname(cy["X"]))
}

tl_lm_between <- function(d) {
  bm <- stats::aggregate(d[c("X", "M", "Y")], list(id = d$id), mean)
  cm <- stats::coef(stats::lm(M ~ X, bm))
  cy <- stats::coef(stats::lm(Y ~ M + X, bm))
  c(a = unname(cm["X"]), b = unname(cy["M"]), c_prime = unname(cy["X"]))
}

# lavaan's own parameter estimates for the six path rows, read by label (the base fixture's labels).
tl_lavaan_paths <- function(fit) {
  pe <- lavaan::parameterEstimates(fit)
  get <- function(lbl) pe$est[match(lbl, pe$label)]
  c(a_within = get("a"), b_within = get("b"), c_prime_within = get("cp"),
    a_between = get("a2"), b_between = get("b2"), c_prime_between = get("cp2"))
}

# A hand-built, valid TwoLevelMediationData: no lavaan needed. `...` overrides any constructor argument.
tl_td <- function(within_only = FALSE, ...) {
  nm_w <- c("a_within", "b_within", "c_prime_within")
  nm_b <- c("a_between", "b_between", "c_prime_between")
  est_w <- c(0.4, 0.5, 0.3)
  est_b <- c(0.7, 1.5, -0.1)
  nms <- if (within_only) nm_w else c(nm_w, nm_b)
  est <- stats::setNames(if (within_only) est_w else c(est_w, est_b), nms)
  vc <- diag(0.01 * seq_along(est), length(est))
  dimnames(vc) <- list(nms, nms)
  pt <- data.frame(
    path = c(nm_w, nm_b), level = rep(c("within", "between"), each = 3),
    lhs = c("M", "Y", "Y", "M", "Y", "Y"), op = "~", rhs = c("X", "M", "X", "X", "M", "X"),
    label = c("a", "b", "cp", "a2", "b2", "cp2"), free = c(1L, 2L, 3L, 6L, 7L, 8L),
    est = c(est_w, est_b), se = c(0.1, 0.1, 0.1, 0.2, 0.2, 0.2), stringsAsFactors = FALSE
  )
  args <- list(
    a_within = 0.4, b_within = 0.5, c_prime_within = 0.3,
    a_between = if (within_only) NA_real_ else 0.7,
    b_between = if (within_only) NA_real_ else 1.5,
    c_prime_between = if (within_only) NA_real_ else -0.1,
    estimates = est, vcov = vc, parameter_table = pt,
    treatment = "X", mediator = "M", outcome = "Y", cluster = "id",
    n_obs = 500L, n_clusters = 100L, cluster_sizes = rep(5L, 100L),
    icc = c(X = 0.4, M = 0.3, Y = 0.4), between_identified = !within_only,
    admissible = TRUE, converged = TRUE, cross_level_equal = character(0),
    fixed_paths = character(0), source = "lavaan", fixed_x = TRUE, information = "observed",
    h1_information = "structured", se_type = "standard", estimator = "ML", missing = "listwise",
    lavaan_version = "0.7.3", call = "lavaan::sem()", between_parameterization = "latent",
    data = NULL, source_package = "lavaan"
  )
  overrides <- list(...)
  args[names(overrides)] <- overrides
  do.call(TwoLevelMediationData, args)
}

# A classed condition caught from `expr`: the first condition whose class includes `class`.
tl_catch <- function(expr, class) {
  caught <- NULL
  withCallingHandlers(
    tryCatch(expr, error = function(e) {
      if (inherits(e, class)) caught <<- e
      NULL
    }),
    warning = function(w) {
      if (inherits(w, class) && is.null(caught)) caught <<- w
      invokeRestart("muffleWarning")
    }
  )
  caught
}

# --- Checks shared by the extraction and degenerate test files ---

# O1 as a reusable check: the six paths against the closed form, tolerance max(0.01 * SE, 1e-4).
# Booleans, so a planted defect is asserted with expect_false() (an expectation helper would report one
# failure per path under the defect).
tl_o1_ok <- function(td, d) {
  cf <- tl_closed_form(d)
  est <- c(td@a_within, td@b_within, td@c_prime_within, td@a_between, td@b_between, td@c_prime_between)
  ref <- c(cf$within, cf$between)
  se <- td@parameter_table$se
  all(abs(est - ref) <= pmax(0.01 * se, 1e-4))
}

# The keyed free-parameter indices must be exactly the table's path rows.
tl_index_set_ok <- function(td, fit) {
  pt <- lavaan::parTable(fit)
  rows <- pt[pt$op == "~", ]
  pick <- function(level, lhs, rhs) rows$free[rows$level == level & rows$lhs == lhs & rows$rhs == rhs]
  want <- c(pick(1, "M", "X"), pick(1, "Y", "M"), pick(1, "Y", "X"),
            pick(2, "M", "X"), pick(2, "Y", "M"), pick(2, "Y", "X"))
  identical(as.integer(td@parameter_table$free), as.integer(want))
}

# A within-only object: three finite within rows, NA between paths, no equated paths. Boolean, so a planted
# defect is asserted with expect_false().
tl_within_only_ok <- function(td) {
  !td@between_identified &&
    is.na(td@a_between) && is.na(td@b_between) && is.na(td@c_prime_between) &&
    identical(names(td@estimates), c("a_within", "b_within", "c_prime_within")) &&
    identical(dim(td@vcov), c(3L, 3L)) &&
    identical(td@cross_level_equal, character(0)) &&
    all(is.finite(c(td@a_within, td@b_within, td@c_prime_within)))
}

tl_unidentified <- function(name) {
  fit <- tl_fixture(name)
  w <- tl_catch(
    extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
    "medfit_between_unidentified"
  )
  list(warning = w, td = tl_extract(fit), fit = fit)
}

# The base fit with the mediator's ICC replaced: lavaan does not converge when the mediator has no between
# variance at all, so the mediator branch of the rule is exercised on an otherwise healthy fit.
tl_mock_tiny_mediator_icc <- function(wrap = identity) {
  real <- medfit:::.twolevel_icc
  testthat::local_mocked_bindings(
    .twolevel_icc = function(fit) {
      icc <- real(fit)
      icc[["M"]] <- 0.001
      wrap(icc)
    },
    .package = "medfit",
    .env = parent.frame()
  )
}
