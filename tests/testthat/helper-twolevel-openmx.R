# Third oracle for the two-level 1-1-1 observed model (task U3): OpenMx's relational
# (joined) two-level model, next to lavaan two-level and the hand-built O8 likelihood
# (helper-twolevel-likelihood.R). Used by test-twolevel-three-oracle.R.
#
# Parameterization (the same as lavaan's `level: 1` / `level: 2` model):
#   between model, one row per cluster: latent cluster components XB, MB, YB with
#     MB <- a_b XB, YB <- b_b MB + cp_b XB, free variances and free intercepts (means);
#   within model, one row per unit: latent within components XW, MW, YW with
#     MW <- a_w XW, YW <- b_w MW + cp_w XW, free variances, zero means;
#   each observed variable is its within plus its joined between component, loading 1, no
#   residual variance: X = XW + XB_j, M = MW + MB_j, Y = YW + YB_j.
# The within paths must run between the latent within components. Regressing the observed
# M on the observed X (the plain relational spec) gives the same likelihood but the
# contextual parameterization (between path = a_b - a_w); `defect = "contextual"` builds that
# model so the tests can show the path check catches it while the logLik check cannot.

tl_mx_between_vars <- c("XB", "MB", "YB")
tl_mx_within_vars <- c("XW", "MW", "YW")

# Free parameters, keyed by the lavaan parameter table row (lhs, op, level).
tl_mx_param_map <- data.frame(
  name = c(
    "a_w", "b_w", "cp_w", "vx_w", "vm_w", "vy_w",
    "a_b", "b_b", "cp_b", "vx_b", "vm_b", "vy_b", "mx_b", "im_b", "iy_b"
  ),
  lhs = c("M", "Y", "Y", "X", "M", "Y", "M", "Y", "Y", "X", "M", "Y", "X", "M", "Y"),
  op = c("~", "~", "~", "~~", "~~", "~~", "~", "~", "~", "~~", "~~", "~~", "~1", "~1", "~1"),
  rhs = c("X", "M", "X", "X", "M", "Y", "X", "M", "X", "X", "M", "Y", "", "", ""),
  level = rep(c(1L, 2L), c(6L, 9L)),
  stringsAsFactors = FALSE
)

# Balanced (n_j = 5) and unbalanced (n_j cycling 2..9) fixtures, J = 100, from the O8 generator.
tl_mx_data_balanced <- function() tl_simulate(rep(5, 100), seed = 21)
tl_mx_data_unbalanced <- function() tl_simulate(rep(2:9, length.out = 100), seed = 22)

# Build and run the OpenMx model. `defect`:
#   "none"        the lavaan parameterization above
#   "no_a_b"      the between a path fixed at 0
#   "contextual"  within paths on the observed variables (same likelihood, other between paths)
tl_mx_fit <- function(data, defect = c("none", "no_a_b", "contextual")) {
  defect <- match.arg(defect)
  clusters <- data.frame(cluster = sort(unique(data$cluster)))
  between <- OpenMx::mxModel(
    "between",
    type = "RAM", latentVars = tl_mx_between_vars,
    OpenMx::mxData(clusters, type = "raw", primaryKey = "cluster"),
    OpenMx::mxPath(tl_mx_between_vars, arrows = 2, values = c(0.7, 0.5, 0.5), labels = c("vx_b", "vm_b", "vy_b")),
    OpenMx::mxPath("XB", "MB", free = defect != "no_a_b", values = if (defect == "no_a_b") 0 else 0.1, labels = "a_b"),
    OpenMx::mxPath("MB", "YB", values = 0.1, labels = "b_b"),
    OpenMx::mxPath("XB", "YB", values = 0.1, labels = "cp_b"),
    OpenMx::mxPath("one", tl_mx_between_vars, values = 0, labels = c("mx_b", "im_b", "iy_b"))
  )
  # the within structure: on latent within components, or (defect) on the observed variables
  wv <- if (defect == "contextual") tl_vars else tl_mx_within_vars
  within_paths <- list(
    OpenMx::mxPath(wv, arrows = 2, values = 1, labels = c("vx_w", "vm_w", "vy_w")),
    OpenMx::mxPath(wv[1], wv[2], values = 0.1, labels = "a_w"),
    OpenMx::mxPath(wv[2], wv[3], values = 0.1, labels = "b_w"),
    OpenMx::mxPath(wv[1], wv[3], values = 0.1, labels = "cp_w")
  )
  if (defect != "contextual") {
    within_paths <- c(within_paths, list(
      OpenMx::mxPath(tl_mx_within_vars, tl_vars, free = FALSE, values = 1),
      OpenMx::mxPath(tl_vars, arrows = 2, free = FALSE, values = 0)
    ))
  }
  model <- do.call(OpenMx::mxModel, c(
    list(
      "within",
      type = "RAM", between, manifestVars = tl_vars,
      latentVars = if (defect == "contextual") character(0) else tl_mx_within_vars,
      OpenMx::mxData(data[, c("cluster", tl_vars)], type = "raw"),
      OpenMx::mxPath("one", tl_vars, free = FALSE, values = 0),
      OpenMx::mxPath(paste0("between.", tl_mx_between_vars), tl_vars, free = FALSE, values = 1, joinKey = "cluster")
    ),
    within_paths
  ))
  # SEs come from OpenMx's numerical Hessian (observed information); set them on the model so
  # a global option elsewhere in the suite cannot turn them off
  model <- OpenMx::mxOption(model, "Calculate Hessian", "Yes")
  model <- OpenMx::mxOption(model, "Standard Errors", "Yes")
  suppressMessages(OpenMx::mxRun(model, silent = TRUE))
}

# Estimates and SEs of a fitted OpenMx model, named as tl_mx_param_map$name. A labeled fixed
# parameter (a planted defect) keeps its fixed value and an NA SE.
tl_mx_estimates <- function(mx) {
  p <- summary(mx)$parameters
  all_par <- OpenMx::omxGetParameters(mx, free = NA)
  list(
    est = all_par[tl_mx_param_map$name],
    se = stats::setNames(p$Std.Error, p$name)[tl_mx_param_map$name],
    loglik = -mx$output$fit / 2
  )
}

# The same 15 parameters from lavaan's table, matched by lhs, op, rhs and level.
tl_mx_lavaan_estimates <- function(fit) {
  pt <- lavaan::parameterEstimates(fit)
  row <- vapply(seq_len(nrow(tl_mx_param_map)), function(i) {
    r <- tl_mx_param_map[i, ]
    hit <- which(pt$lhs == r$lhs & pt$op == r$op & pt$rhs == r$rhs & pt$level == r$level)
    stopifnot(length(hit) == 1L)
    hit
  }, integer(1))
  list(
    est = stats::setNames(pt$est[row], tl_mx_param_map$name),
    se = stats::setNames(pt$se[row], tl_mx_param_map$name)
  )
}

# OpenMx's estimates unpacked to the O8 within and between covariances and the mean vector.
tl_mx_to_hand <- function(mx) {
  e <- tl_mx_estimates(mx)$est
  b_mat <- matrix(0, 3, 3)
  b_mat[2, 1] <- e[["a_b"]]
  b_mat[3, 2] <- e[["b_b"]]
  b_mat[3, 1] <- e[["cp_b"]]
  list(
    sw = tl_sigma(e[["a_w"]], e[["b_w"]], e[["cp_w"]], e[["vx_w"]], e[["vm_w"]], e[["vy_w"]]),
    sb = tl_sigma(e[["a_b"]], e[["b_b"]], e[["cp_b"]], e[["vx_b"]], e[["vm_b"]], e[["vy_b"]]),
    mu = drop(solve(diag(3) - b_mat, e[c("mx_b", "im_b", "iy_b")]))
  )
}

# One expectation each, so a planted defect can be run through it with expect_failure().
# Estimates (ADR TL-1, TL-5): |diff| <= max(0.01 * SE, 1e-4), SE from lavaan.
tl_mx_check_est <- function(mx_est, lav) {
  excess <- abs(mx_est - lav$est) - pmax(0.01 * lav$se, 1e-4)
  testthat::expect_lte(max(excess), 0, label = paste("worst estimate:", names(excess)[which.max(excess)]))
}
# SEs (ADR TL-2, TL-5): 1e-3 relative (lavaan fixed.x = FALSE, observed information, against
# OpenMx's Hessian).
tl_mx_check_se <- function(mx_se, lav) {
  rel <- abs(mx_se - lav$se) / lav$se
  testthat::expect_lte(max(rel), 1e-3, label = paste("worst SE:", names(rel)[which.max(rel)]))
}

# SE of the cross-level contrast a_w - a_b from a covariance matrix whose rows and columns
# carry the labels a_w and a_b (OpenMx's output$vcov and lavaan's vcov() both do). Unlike the
# marginal SEs it reads Cov(a_w, a_b), so it is the check the zeroed cross-level block fails
# (ADR TL-7).
tl_mx_contrast_se <- function(v) {
  sqrt(v["a_w", "a_w"] + v["a_b", "a_b"] - 2 * v["a_w", "a_b"])
}
# Contrast SE (ADR TL-2, TL-5): 1e-3 relative against lavaan's.
tl_mx_check_contrast_se <- function(mx_se, lav_se) {
  testthat::expect_lte(abs(mx_se - lav_se) / lav_se, 1e-3, label = "SE(a_w - a_b) relative difference")
}
