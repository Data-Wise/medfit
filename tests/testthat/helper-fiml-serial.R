# Shared fixtures of the FI-G3 slice S1b tests (saturated serial FIML, k = 0). Prefix sb_. Everything here is an
# oracle or a data generator and never calls the serial extraction or effect code it is used to test.

sb_zeros <- c("M1 ~~ 0*M2", "M1 ~~ 0*Y", "M2 ~~ 0*Y")
# model text; `direct` is "free", "zero" (Y ~ 0*X) or "omit"; `labels` writes the lavaan labels and the defined effects
sb_model <- function(direct = "free", labels = FALSE, zeros = sb_zeros, defined = labels) {
  l <- function(lab, v) if (labels) paste0(lab, "*", v) else v
  ypath <- switch(direct, free = l("cp", "X"), zero = "0*X", omit = NULL)
  paste(c(
    paste("M1 ~", l("a", "X")),
    paste("M2 ~", paste(c(l("d1", "M1"), l("a2", "X")), collapse = " + ")),
    paste("Y ~", paste(c(l("b1", "M1"), l("b", "M2"), ypath), collapse = " + ")),
    zeros,
    if (defined) c(
      "ind := a*d1*b", "ind_tot := a*d1*b + a2*b + a*b1",
      if (direct == "free") "te := ind_tot + cp" else "te := ind_tot"
    )
  ), collapse = "\n")
}
# the data-generating values: every path distinct and large, so a swapped or aliased path cannot hide
sb_truth <- c(a = .9, a2 = .4, d1 = .7, b1 = .35, b = .6, cp = .25)
sb_data <- function(kind = "mar", n = 300L, seed = 9101L, cp = sb_truth[["cp"]]) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  m1 <- .3 + sb_truth[["a"]] * x + stats::rnorm(n, sd = .7)
  m2 <- -.2 + sb_truth[["d1"]] * m1 + sb_truth[["a2"]] * x + stats::rnorm(n, sd = .8)
  y <- .2 + sb_truth[["b"]] * m2 + sb_truth[["b1"]] * m1 + cp * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    # every variable can be incomplete; the mediators and Y depend (ignorably) on the observed X
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "mcar30") {
    for (v in names(d)) d[stats::runif(n) < .3, v] <- NA_real_
  } else if (kind == "sparse") {
    # single-variable, pair and triple patterns in disjoint row blocks plus an all-empty row
    d[1:25, "X"] <- NA_real_
    d[26:50, "M1"] <- NA_real_
    d[51:75, "M2"] <- NA_real_
    d[76:100, "Y"] <- NA_real_
    d[101:120, c("M1", "M2")] <- NA_real_
    d[121:140, c("X", "Y")] <- NA_real_
    d[141:160, c("M2", "Y")] <- NA_real_
    d[161:175, c("X", "M1", "Y")] <- NA_real_
    d[176L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
sb_fit <- function(d, direct = "free", model = sb_model(direct)) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
}
sb_extract <- function(f, ...) extract_mediation(f, treatment = "X", mediator = c("M1", "M2"), ...)
sb_lavaan <- function(model, d) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}
# lavaan reference for an extracted object: the six path estimates, their 6 x 6 covariance, the defined effects
sb_reference <- function(d, direct = "free") {
  l <- sb_lavaan(sb_model(direct, labels = TRUE), d)
  pe <- lavaan::parameterEstimates(l)
  roles <- c(a = "a", a2 = "a2", d1 = "d1", b1 = "b1", b = "b", c_prime = "cp")
  if (direct != "free") roles <- roles[names(roles) != "c_prime"]
  est <- stats::setNames(vapply(roles, function(r) pe$est[pe$label == r][1L], numeric(1)), names(roles))
  V <- lavaan::vcov(l)
  tb <- lavaan::coef(l)
  # lavaan names a labeled free parameter by its label
  nm <- names(tb)
  idx <- match(roles, nm)
  W <- V[idx, idx, drop = FALSE]
  dimnames(W) <- list(names(roles), names(roles))
  eff <- pe[pe$label %in% c("ind", "ind_tot", "te"), ]
  list(
    fit = l, est = est, vcov = W, ind = eff[eff$label == "ind", ], ind_tot = eff[eff$label == "ind_tot", ],
    te = eff[eff$label == "te", ], logl = as.numeric(lavaan::logLik(l))
  )
}
# lavaan writes an exogenous covariance in its own order: match by the unordered pair
sb_key <- function(nm) {
  vapply(strsplit(nm, "~~", fixed = TRUE), function(p) {
    if (length(p) == 2L) paste(sort(p), collapse = "~~") else paste(p, collapse = "")
  }, character(1))
}
sb_align <- function(ref_coef, q) ref_coef[match(sb_key(names(q)), sb_key(names(ref_coef)))]
sb_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))

# the recursive regressions implied by a mean vector and a covariance matrix over (X, M1, M2, Y)
sb_recursive <- function(mu, S) {
  reg <- function(y, xs) {
    b <- solve(S[xs, xs, drop = FALSE], S[xs, y])
    int <- mu[[y]] - sum(b * mu[xs])
    list(b = b, int = int, v = S[y, y] - sum(b * S[xs, y]))
  }
  list(
    m1 = reg("M1", "X"), m2 = reg("M2", c("M1", "X")), y = reg("Y", c("M1", "M2", "X")),
    vx = S[["X", "X"]], mx = mu[["X"]]
  )
}
sb_recursive_vec <- function(r) {
  c(a = r$m1$b[["X"]], a2 = r$m2$b[["X"]], d1 = r$m2$b[["M1"]], b1 = r$y$b[["M1"]], b = r$y$b[["M2"]],
    c_prime = r$y$b[["X"]])
}

# independent implied moments of the saturated serial model from the named coefficient vector of a fit
sb_moments <- function(q) {
  vars <- c("X", "M1", "M2", "Y")
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  B <- matrix(0, 4, 4, dimnames = list(vars, vars))
  # a coefficient that is not in the fit (an omitted or reversed path) is 0
  for (r in c("M1", "M2", "Y")) for (p in setdiff(vars, r)) B[r, p] <- g(paste0(r, "~", p))
  psi <- diag(vapply(vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(vars, vars)
  A <- solve(diag(4) - B)
  list(mu = drop(A %*% vapply(vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
sb_nll <- function(d, q) gk_row_nll(as.matrix(d[, c("X", "M1", "M2", "Y")]), sb_moments(q))

# delta-method SE of a linear combination from an extracted object's covariance block
sb_se <- function(z, g) sqrt(drop(t(g) %*% z@vcov[names(g), names(g), drop = FALSE] %*% g))
# the hand gradients of spec 3.2 for the saturated variant, from the extracted estimates
sb_grad <- function(z) {
  e <- z@estimates
  a <- e[["a"]]
  a2 <- e[["a2"]]
  d1 <- e[["d1"]]
  b1 <- e[["b1"]]
  b <- e[["b"]]
  list(
    nie = c(a = d1 * b, d1 = a * b, b = a * d1),
    nie_total = c(a = d1 * b + b1, a2 = b, d1 = a * b, b1 = a, b = a * d1 + a2),
    nde = c(c_prime = 1),
    te = c(a = d1 * b + b1, a2 = b, d1 = a * b, b1 = a, b = a * d1 + a2, c_prime = 1)
  )
}
# a forged object: set named estimates and the path slots, rebinding the parameter hash as the validator reads it
sb_forge <- function(z, vals, vcov = NULL) {
  ctx <- z@fit_context
  est <- z@estimates
  est[names(vals)] <- unlist(vals)
  V <- if (is.null(vcov)) z@vcov else vcov
  a <- unname(est[["a"]])
  d <- unname(est[["d1"]])
  b <- unname(est[["b"]])
  cp <- unname(est[["c_prime"]])
  ctx$parameter_hash <- rlang::hash(list(est, V, a, d, b, cp, z@variant))
  S7::set_props(z, a_path = a, d_path = d, b_path = b, c_prime = cp, estimates = est, vcov = V, fit_context = ctx)
}
sb_note_nie <- "NIE inference unavailable: zero delta gradient"
