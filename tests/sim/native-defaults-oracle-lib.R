# Cells and comparisons of the native-defaults oracle matrix (0.14.0 plan T8a, spec R-12, E-15), shared by the gate
# script tests/sim/native-defaults-oracle.R and the fast subset tests/testthat/test-native-defaults-oracle.R. Needs
# medfit loaded and lavaan installed; defines functions and data only (no side effects).
#
# A cell is a model, a data set and how it is fit; a combination is one setting of (fixed_x, meanstructure). Each core
# cell runs under the four combinations (fixed_x FALSE/TRUE x meanstructure NULL/TRUE: the old and the 0.15.0 default
# of each) with both arguments passed, and once with both unset under options(medfit.native_defaults = "0.15") (combo
# "optin"), which goes through fit_sem()'s resolver. No core model has a `~~` or `~1` statement on an exogenous
# variable, so the opt-in resolves to the full subset there, the same fit as (TRUE, TRUE).
# The `subset` cell passes a named fixed_x ("c") explicitly, under meanstructure NULL and TRUE; its oracle is lavaan
# with fixed.x = FALSE and the subset's moments written as fixed values (divisor N), built here from the data, not
# from medfit's own translation.
# T8b adds three cells (data from ndo_data_b(), which keeps the T8a columns): `product` (four-way x:m; lavaan gets the
# product as a data column xm, plus a named subset "x", "c" that leaves the product free), `factor` (g with three
# levels; lavaan gets hand dummies g_b, g_c; fixed_x = "g" as a named subset) and `lenient` (a `c ~~ c` statement, so
# the opt-in default leaves c free with a classed message and must equal fixed_x = "x"). Under the opt-in these models
# resolve to a named subset (T6); the opt-in rows also check that set (glance()$fixed_x) and the lenient message.
#
# One row per cell x combination x quantity. Status: pass or fail from the stated tolerance (fixed before the first
# run, never widened), or limit / block from the declared table `ndo_declared` with its reason (a declared row keeps
# both numbers). A disagreement found later is investigated and declared with a reason, never absorbed by a tolerance.

ndo_tol <- c(est = 1e-5, se = 1e-3, chisq = 1e-5, df = 0, npar = 0, logLik = 1e-6, AIC = 1e-6, BIC = 1e-6,
             same_as_explicit = 1e-10)

ndo_data <- function(n = 300L, seed = 20261024L) {
  set.seed(seed)
  x <- stats::rnorm(n)
  c <- 0.4 * x + stats::rnorm(n)
  m <- 0.3 + 0.5 * x + 0.3 * c + stats::rnorm(n, sd = 0.8)
  eta <- 0.5 * x + 0.3 * c + stats::rnorm(n, sd = 0.8)
  data.frame(
    x = x, c = c, m = m,
    y = 0.4 * m + 0.2 * x + 0.1 * c + stats::rnorm(n, sd = 0.7),
    m1 = 1 + eta + stats::rnorm(n, sd = 0.5), m2 = 0.5 + 0.8 * eta + stats::rnorm(n, sd = 0.5),
    m3 = -0.5 + 0.7 * eta + stats::rnorm(n, sd = 0.5),
    yl = 0.4 * eta + 0.2 * x + 0.1 * c + stats::rnorm(n, sd = 0.7),
    w = stats::runif(n, 0.5, 2)
  )
}

# T8b columns, drawn after the T8a columns so those keep their values: a three-level factor g with its outcome pair
# (mg, yg), the hand-built dummies g_b, g_c and the product column xm = x * m that only lavaan sees
ndo_data_b <- function(d = ndo_data(), seed = 20261025L) {
  set.seed(seed)
  n <- nrow(d)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  d$g <- g
  d$mg <- 0.3 + 0.5 * d$x + c(0, 0.4, -0.3)[g] + stats::rnorm(n, sd = 0.8)
  d$yg <- 0.4 * d$mg + 0.2 * d$x + c(0, 0.2, 0.5)[g] + stats::rnorm(n, sd = 0.7)
  d$g_b <- as.numeric(g == "b")
  d$g_c <- as.numeric(g == "c")
  d$xm <- d$x * d$m
  d
}
# columns the native fit never sees (oracle-only translations of what it builds itself)
ndo_oracle_only <- c("w", "g_b", "g_c", "xm")

ndo_base <- "m ~ a*x + c\ny ~ b*m + cp*x + c"
ndo_cells <- list(
  simple = list(model = ndo_base, labels = c("a", "b", "cp")),
  weights = list(model = ndo_base, labels = c("a", "b", "cp"), weights = TRUE),
  fixed_intercept = list(model = paste0(ndo_base, "\ny ~ 0*1"), labels = c("a", "b", "cp")),
  constrained_intercepts = list(model = paste0(ndo_base, "\nm ~ i1*1\ny ~ i2*1\ni1 == i2"),
                                labels = c("a", "b", "cp", "i1")),
  latent = list(model = "M =~ m1 + m2 + m3\nM ~ a*x + c\nyl ~ b*M + cp*x + c", labels = c("a", "b", "cp")),
  subset = list(model = ndo_base, labels = c("a", "b", "cp"), subset = "c"),
  # T8b. Four-way product: lavaan gets the product as a data column xm (E-11), so its fixed.x treats it like any other
  # exogenous column; "fx=x,c" names a subset that leaves the product free.
  product = list(model = paste0(ndo_base, " + t3*x:m"), lavaan_model = paste0(ndo_base, " + t3*xm"),
                 labels = c("a", "b", "cp", "t3"), exo = c("x", "c", "xm"), lav_names = c("m:x" = "xm"),
                 extra = list("fx=x,c ms=TRUE" = list(fixed_x = c("x", "c"), meanstructure = TRUE)),
                 optin_set = c("x", "c", "m:x"), quiet = TRUE),
  # factor covariate g (dummies g_b, g_c in medfit; built by hand for lavaan)
  factor = list(model = "mg ~ a*x + g\nyg ~ b*mg + cp*x + g",
                lavaan_model = "mg ~ a*x + g_b + g_c\nyg ~ b*mg + cp*x + g_b + g_c",
                labels = c("a", "b", "cp"), exo = c("x", "g_b", "g_c"), lav_names = list(g = c("g_b", "g_c")),
                extra = list("fx=g ms=NULL" = list(fixed_x = "g", meanstructure = NULL),
                             "fx=g ms=TRUE" = list(fixed_x = "g", meanstructure = TRUE)),
                optin_set = c("x", "g_b", "g_c")),
  # lenient subset: a `~~` statement on c leaves it out of the opt-in default, which must equal fixed_x = "x" and say so
  lenient = list(model = paste0(ndo_base, "\nc ~~ c"), labels = c("a", "b", "cp"),
                 combos = list("fx=FALSE ms=TRUE" = list(fixed_x = FALSE, meanstructure = TRUE),
                               "fx=x ms=TRUE" = list(fixed_x = "x", meanstructure = TRUE)),
                 optin_equals = "fx=x ms=TRUE", optin_set = "x", lenient = TRUE,
                 # matching translation: lavaan's own fixed.x = TRUE, which keeps c free because of its statement. The
                 # `c ~~ c` statement also drops the x ~~ c covariance in both programs (already with fixed_x = FALSE),
                 # so the moment-writing translation (which fixes cov(x, c) at its sample value) is not the same model.
                 lavaan_fx = list("fx=x ms=TRUE" = TRUE))
)

# combinations: name -> (fixed_x, meanstructure); NULL meanstructure is lavaan's "default" (means only when written)
ndo_combos <- list(
  "fx=FALSE ms=NULL" = list(fixed_x = FALSE, meanstructure = NULL),
  "fx=FALSE ms=TRUE" = list(fixed_x = FALSE, meanstructure = TRUE),
  "fx=TRUE ms=NULL" = list(fixed_x = TRUE, meanstructure = NULL),
  "fx=TRUE ms=TRUE" = list(fixed_x = TRUE, meanstructure = TRUE)
)
ndo_subset_combos <- list(
  "fx=c ms=NULL" = list(fixed_x = "c", meanstructure = NULL),
  "fx=c ms=TRUE" = list(fixed_x = "c", meanstructure = TRUE)
)

# Declared disagreements: cell, combo ("*" = every combination), quantity, status, reason. Found in the first run
# (2026-10-24) and investigated before declaring:
# - weights: glance() reports NA for chi-square, logLik, AIC and BIC of a weighted fit by design.
# - covariance-only fits (meanstructure NULL, no `~1` written): logLik and npar agree with lavaan, but medfit's
#   logLik() df (.sem_loglik_df) also counts the observed means that are not fixed as implicitly estimated at their
#   sample values, while lavaan's AIC/BIC count npar only. The gap is exactly 2k (AIC) and k log(n) (BIC), k = the
#   number of such means (simple: 4 with fx=FALSE, 2 with fx=TRUE). Under meanstructure = TRUE, the 0.15.0 default,
#   the two agree, so this does not block the flip; it is a documented difference of the covariance-only fit.
ndo_ms_null <- c("fx=FALSE ms=NULL", "fx=TRUE ms=NULL", "fx=c ms=NULL")
ndo_declared <- rbind(
  data.frame(
    cell = "weights", combo = "*", quantity = c("chisq", "logLik", "AIC", "BIC"), status = "limit",
    reason = paste("by design glance() reports NA for a weighted fit (the weighted discrepancy is not a likelihood);",
                   "lavaan reports its weighted-ML values"),
    stringsAsFactors = FALSE
  ),
  data.frame(
    cell = rep(c("simple", "latent", "subset"), each = 2L * length(ndo_ms_null)),
    combo = rep(rep(ndo_ms_null, each = 2L), 3L), quantity = c("AIC", "BIC"), status = "limit",
    reason = paste("covariance-only fit: medfit's logLik() df counts the non-fixed observed means as implicitly",
                   "estimated, lavaan's AIC/BIC count npar only (gap 2k and k log(n)); logLik and npar agree"),
    stringsAsFactors = FALSE
  )
)

# T8b declared rows (first run 2026-10-24, investigated before declaring):
# - product: the model test is invalid by design when a product factor is a regression target (m:x with m ~ x), so
#   glance() reports chi-square and df as NA; lavaan reports numbers for the same misspecified normal model.
# - product, meanstructure NULL: a product turns medfit's mean structure on, lavaan's "default" fits no means; logLik
#   agrees, npar differs by the free means (5 with fx=FALSE, 2 with fx=TRUE) and so do AIC and BIC.
# - factor, meanstructure NULL: the covariance-only AIC/BIC difference of the core cells (gap 2k and k log(n)).
ndo_declared <- rbind(
  ndo_declared,
  data.frame(
    cell = "product", combo = "*", quantity = c("chisq", "df"), status = "limit",
    reason = paste("product with an endogenous factor (m:x, m ~ x): the model test is invalid by design and glance()",
                   "reports chi-square and df as NA; lavaan reports them for the same model"),
    stringsAsFactors = FALSE
  ),
  data.frame(
    cell = "product", combo = rep(c("fx=FALSE ms=NULL", "fx=TRUE ms=NULL"), each = 3L),
    quantity = c("npar", "AIC", "BIC"), status = "limit",
    reason = paste("a product turns medfit's mean structure on, lavaan's meanstructure = \"default\" fits none:",
                   "npar differs by the free means and AIC/BIC with it; logLik, estimates and SEs agree"),
    stringsAsFactors = FALSE
  ),
  data.frame(
    cell = "factor", combo = rep(c("fx=FALSE ms=NULL", "fx=TRUE ms=NULL", "fx=g ms=NULL"), each = 2L),
    quantity = c("AIC", "BIC"), status = "limit",
    reason = ndo_declared$reason[ndo_declared$cell == "simple"][1L],
    stringsAsFactors = FALSE
  )
)

# combinations a cell runs under (the opt-in is run separately)
ndo_cell_combos <- function(cell) {
  spec <- ndo_cells[[cell]]
  if (!is.null(spec$subset)) {
    return(ndo_subset_combos)
  }
  c(if (is.null(spec$combos)) ndo_combos else spec$combos, spec$extra)
}
ndo_has_optin <- function(cell) is.null(ndo_cells[[cell]]$subset)
ndo_optin_equals <- function(cell) {
  e <- ndo_cells[[cell]]$optin_equals
  if (is.null(e)) "fx=TRUE ms=TRUE" else e
}
# medfit name -> lavaan column names (a factor maps to its dummies, the product to xm)
ndo_lav_names <- function(cell, v) {
  map <- as.list(ndo_cells[[cell]]$lav_names)
  unlist(lapply(v, function(u) if (u %in% names(map)) map[[u]] else u), use.names = FALSE)
}

ndo_fit_native <- function(cell, combo, d = ndo_data_b()) {
  spec <- ndo_cells[[cell]]
  args <- list(model = spec$model, data = d[setdiff(names(d), ndo_oracle_only)])
  if (isTRUE(spec$weights)) {
    args$weights <- d$w
    args$se_type <- "sandwich"
  }
  if (identical(combo, "optin")) {
    old <- options(medfit.native_defaults = "0.15")
    on.exit(options(old), add = TRUE)
    return(if (isTRUE(spec$quiet)) suppressWarnings(do.call(fit_sem, args)) else do.call(fit_sem, args))
  }
  s <- ndo_cell_combos(cell)[[combo]]
  args <- c(args, list(fixed_x = s$fixed_x, meanstructure = s$meanstructure))
  # the product cell's two expected warnings (invalid model test, model-based SEs with a product) are by design
  if (isTRUE(spec$quiet)) suppressWarnings(do.call(fit_sem, args)) else do.call(fit_sem, args)
}

# lavaan oracle; a subset is written as fixed values (divisor N) with fixed.x = FALSE
ndo_fit_lavaan <- function(cell, combo, d = ndo_data_b()) {
  spec <- ndo_cells[[cell]]
  if (identical(combo, "optin")) combo <- ndo_optin_equals(cell)
  s <- ndo_cell_combos(cell)[[combo]]
  model <- if (is.null(spec$lavaan_model)) spec$model else spec$lavaan_model
  fixed_x <- if (is.character(s$fixed_x)) ndo_lav_names(cell, s$fixed_x) else s$fixed_x
  if (!is.null(spec$lavaan_fx[[combo]])) fixed_x <- spec$lavaan_fx[[combo]]
  ms <- if (is.null(s$meanstructure)) "default" else s$meanstructure
  if (is.character(fixed_x)) {
    exo <- if (is.null(spec$exo)) c("x", "c") else spec$exo
    n <- nrow(d)
    mu <- colMeans(d[exo])
    sc <- crossprod(sweep(as.matrix(d[exo]), 2L, mu)) / n
    rows <- character()
    sub <- fixed_x
    for (v in sub) {
      for (u in exo) {
        if (u == v || !(u %in% sub) || match(u, exo) > match(v, exo)) {
          rows <- c(rows, sprintf("%s ~~ %.17g*%s", v, sc[v, u], u))
        }
      }
      if (isTRUE(s$meanstructure)) rows <- c(rows, sprintf("%s ~ %.17g*1", v, mu[[v]]))
    }
    rows <- unique(rows)
    model <- paste(c(model, rows), collapse = "\n")
    fixed_x <- FALSE
    # medfit's subset fit is conditional on the fixed block and does not count its moments: the oracle subtracts
    # the block's marginal normal log-likelihood at its sample moments and the written fixed rows from df
    k <- length(sub)
    sx <- sc[sub, sub, drop = FALSE]
    adjust <- list(ll = -0.5 * n * (as.numeric(determinant(sx, logarithm = TRUE)$modulus) + k + k * log(2 * pi)),
                   df = length(rows), n = n)
  } else {
    adjust <- NULL
  }
  args <- list(model = model, data = d[setdiff(names(d), "g")], fixed.x = fixed_x, meanstructure = ms,
               information = "observed")
  if (isTRUE(spec$weights)) {
    args$sampling.weights <- "w"
    args$se <- "robust.huber.white"
  }
  ref <- suppressWarnings(do.call(lavaan::sem, args))
  attr(ref, "ndo_adjust") <- adjust
  ref
}

ndo_native_values <- function(fit, labels) {
  g <- glance(fit)
  se <- sqrt(diag(fit@vcov))
  c(stats::setNames(fit@theta[labels], paste0("est:", labels)), stats::setNames(se[labels], paste0("se:", labels)),
    chisq = g$chisq, df = g$df, npar = g$npar, logLik = g$logLik, AIC = g$AIC, BIC = g$BIC)
}

ndo_lavaan_values <- function(ref, labels) {
  pe <- lavaan::parameterEstimates(ref)
  pe <- pe[pe$label %in% labels & !duplicated(pe$label), , drop = FALSE]
  est <- stats::setNames(pe$est, pe$label)[labels]
  se <- stats::setNames(pe$se, pe$label)[labels]
  fm <- lavaan::fitMeasures(ref, c("chisq", "df", "npar", "logl", "aic", "bic", "ntotal"))
  adj <- attr(ref, "ndo_adjust")
  if (!is.null(adj)) {
    fm[["logl"]] <- fm[["logl"]] - adj$ll
    fm[["df"]] <- fm[["df"]] - adj$df
    fm[["aic"]] <- -2 * fm[["logl"]] + 2 * fm[["npar"]]
    fm[["bic"]] <- -2 * fm[["logl"]] + log(fm[["ntotal"]]) * fm[["npar"]]
  }
  c(stats::setNames(est, paste0("est:", labels)), stats::setNames(se, paste0("se:", labels)),
    chisq = fm[["chisq"]], df = fm[["df"]], npar = fm[["npar"]], logLik = fm[["logl"]], AIC = fm[["aic"]],
    BIC = fm[["bic"]])
}

ndo_declared_row <- function(cell, combo, quantity) {
  q <- sub(":.*$", "", quantity)
  i <- which(ndo_declared$cell == cell & ndo_declared$combo %in% c("*", combo) &
               ndo_declared$quantity %in% c("*", quantity, q))
  if (length(i)) ndo_declared[i[1L], ] else NULL
}

# rows for one value pair; `kind` picks the tolerance (est/se for the parameter rows)
ndo_rows <- function(cell, combo, quantity, native, oracle) {
  kind <- sub(":.*$", "", quantity)
  tol <- ndo_tol[[kind]]
  diff <- if (kind == "se") abs(native / oracle - 1) else abs(native - oracle) / max(1, abs(oracle))
  if (kind %in% c("df", "npar", "same_as_explicit")) diff <- abs(native - oracle)
  dec <- ndo_declared_row(cell, combo, quantity)
  status <- if (!is.null(dec)) dec$status else if (isTRUE(diff <= tol)) "pass" else "fail"
  data.frame(cell = cell, combo = combo, quantity = quantity, native = unname(native), oracle = unname(oracle),
             diff = unname(diff), tol = tol, status = status, reason = if (is.null(dec)) "" else dec$reason,
             stringsAsFactors = FALSE)
}

# every row of one cell x combination; a native fit that errors is one `fail` row (quantity "fit"), never a skip
ndo_cell_rows <- function(cell, combo, d = ndo_data_b()) {
  spec <- ndo_cells[[cell]]
  labels <- spec$labels
  lenient <- 0
  fit <- tryCatch(withCallingHandlers(ndo_fit_native(cell, combo, d), medfit_message_fixed_x_lenient = function(m) {
    lenient <<- 1
    invokeRestart("muffleMessage")
  }), error = function(e) e)
  if (inherits(fit, "error")) {
    return(data.frame(cell = cell, combo = combo, quantity = "fit", native = NA_real_, oracle = NA_real_,
                      diff = NA_real_, tol = NA_real_, status = "fail", reason = conditionMessage(fit),
                      stringsAsFactors = FALSE))
  }
  nv <- ndo_native_values(fit, labels)
  ov <- ndo_lavaan_values(ndo_fit_lavaan(cell, combo, d), labels)
  out <- do.call(rbind, lapply(names(nv), function(q) ndo_rows(cell, combo, q, nv[[q]], ov[[q]])))
  if (identical(combo, "optin")) {
    # the resolver must give exactly the explicit fit it stands for ((TRUE, TRUE), or the named subset it resolves to)
    ex <- ndo_fit_native(cell, ndo_optin_equals(cell), d)
    same <- length(fit@theta) == length(ex@theta) && setequal(names(fit@theta), names(ex@theta))
    gap <- if (same) max(abs(fit@theta - ex@theta[names(fit@theta)])) else Inf
    out <- rbind(out, ndo_rows(cell, combo, "same_as_explicit", gap, 0))
    # T6: the opt-in resolves to a named subset (glance()$fixed_x), which must be the expected set, and the lenient
    # message is emitted exactly when a statement leaves a variable out
    if (!is.null(spec$optin_set)) {
      got <- strsplit(glance(fit)$fixed_x, ", ", fixed = TRUE)[[1L]]
      miss <- as.numeric(!setequal(got, spec$optin_set))
      out <- rbind(out, ndo_rows(cell, combo, "same_as_explicit:fixed_x", miss, 0))
    }
    out <- rbind(out, ndo_rows(cell, combo, "same_as_explicit:lenient_message", lenient,
                               as.numeric(isTRUE(spec$lenient))))
  }
  out
}

ndo_run <- function(cells = names(ndo_cells), d = ndo_data_b()) {
  rows <- list()
  for (cell in cells) {
    combos <- names(ndo_cell_combos(cell))
    if (ndo_has_optin(cell)) combos <- c(combos, "optin")
    for (combo in combos) rows[[length(rows) + 1L]] <- ndo_cell_rows(cell, combo, d)
  }
  do.call(rbind, rows)
}
