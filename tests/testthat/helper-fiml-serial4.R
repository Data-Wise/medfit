# Shared fixtures of the FI-G3 slice S4 tests (serial FIML with TWO covariates Z1 and Z2, both variants). Prefix s4_.
# Everything here is an oracle or a data generator and never calls the serial extraction or effect code it is used to
# test. It builds on helper-fiml-serial.R (sb_*) and helper-fiml-serial3.R (s3_*): the lavaan wrapper, the key
# alignment, the forger and the hand gradients.

s4_zeros <- sb_zeros
s4_vars <- c("X", "Z1", "Z2", "M1", "M2", "Y")
# model text. `variant` is "saturated" or "chain"; `direct` is "free" or "zero" (Y ~ 0*<treatment>); `tr` is the
# treatment (the variable that carries the labels a, a2, cp) and `cvs` the two covariates (labels gm1_i, gm2_i, gy_i).
# `exo_cov` is "none" (auto), "all" (X~~Z1, X~~Z2, Z1~~Z2 written) or "partial" (only the first written). In the pure
# chain the treatment is the variable absent from M2's equation, so `tr` also decides the syntax there.
s4_model <- function(variant = "saturated", direct = "free", labels = FALSE, tr = "X", cvs = c("Z1", "Z2"),
                     zeros = s4_zeros, defined = labels, exo_cov = "none") {
  l <- function(lab, v) if (labels) paste0(lab, "*", v) else v
  sat <- variant == "saturated"
  ypath <- switch(direct, free = l("cp", tr), zero = paste0("0*", tr))
  lz <- function(prefix) vapply(seq_along(cvs), function(i) l(paste0(prefix, "_", i), cvs[i]), "")
  ex <- c(tr, cvs)
  pr <- utils::combn(ex, 2L)
  paste(c(
    paste("M1 ~", paste(c(l("a", tr), lz("gm1")), collapse = " + ")),
    paste("M2 ~", paste(c(l("d1", "M1"), if (sat) l("a2", tr), lz("gm2")), collapse = " + ")),
    paste("Y ~", paste(c(if (sat) l("b1", "M1"), l("b", "M2"), ypath, lz("gy")), collapse = " + ")),
    zeros,
    switch(exo_cov, none = NULL, all = paste(pr[1L, ], "~~", pr[2L, ]), partial = paste(pr[1L, 1L], "~~", pr[2L, 1L])),
    if (defined) c(
      "ind := a*d1*b", if (sat) "ind_tot := a*d1*b + a2*b + a*b1" else "ind_tot := a*d1*b",
      if (direct == "free") "te := ind_tot + cp" else "te := ind_tot"
    )
  ), collapse = "\n")
}
# the data-generating values: every path distinct, and the covariate effects LARGE and distinct from the path values
# and from each other, so a covariate coefficient mistaken for a path (or one covariate for the other) cannot hide
s4_truth <- c(a = .9, a2 = .4, d1 = .7, b1 = .35, b = .6, cp = .25, gm1_1 = 1.4, gm1_2 = -.8, gm2_1 = -.9, gm2_2 = 1.1,
              gy_1 = 1.7, gy_2 = -1.2)
s4_data <- function(kind = "mar", n = 420L, seed = 9401L, cp = s4_truth[["cp"]], a2 = s4_truth[["a2"]],
                    b1 = s4_truth[["b1"]]) {
  set.seed(seed)
  tr <- s4_truth
  x <- .5 + stats::rnorm(n)
  z1 <- 1 + .5 * x + stats::rnorm(n, sd = 1.1)
  z2 <- -.5 + .3 * x - .4 * z1 + stats::rnorm(n, sd = .9)
  m1 <- .3 + tr[["a"]] * x + tr[["gm1_1"]] * z1 + tr[["gm1_2"]] * z2 + stats::rnorm(n, sd = .7)
  m2 <- -.2 + tr[["d1"]] * m1 + a2 * x + tr[["gm2_1"]] * z1 + tr[["gm2_2"]] * z2 + stats::rnorm(n, sd = .8)
  y <- .2 + tr[["b"]] * m2 + b1 * m1 + cp * x + tr[["gy_1"]] * z1 + tr[["gy_2"]] * z2 + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, Z1 = z1, Z2 = z2, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    # every variable, the covariates included, can be incomplete; the others depend (ignorably) on the observed X
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.5 + .5 * x), "Z1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.6 + .4 * x), "Z2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "mcar30") {
    for (v in names(d)) d[stats::runif(n) < .3, v] <- NA_real_
  } else if (kind == "zmiss") {
    # only the covariates have missing values
    d[stats::runif(n) < .3, "Z1"] <- NA_real_
    d[stats::runif(n) < .3, "Z2"] <- NA_real_
  } else if (kind == "sparse") {
    # single-variable, pair and triple patterns in disjoint row blocks plus an all-empty row
    d[1:25, "X"] <- NA_real_
    d[26:50, "Z1"] <- NA_real_
    d[51:75, "Z2"] <- NA_real_
    d[76:100, "M1"] <- NA_real_
    d[101:125, "M2"] <- NA_real_
    d[126:150, "Y"] <- NA_real_
    d[151:165, c("M1", "M2")] <- NA_real_
    d[166:180, c("X", "Y")] <- NA_real_
    d[181:195, c("Z1", "M2")] <- NA_real_
    d[196:210, c("Z2", "Y")] <- NA_real_
    d[211:225, c("M2", "Y")] <- NA_real_
    d[226:240, c("X", "Z1", "Z2")] <- NA_real_
    d[241:250, c("X", "M1", "Y")] <- NA_real_
    d[251L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
s4_fit <- function(d, variant = "saturated", direct = "free", model = s4_model(variant, direct)) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
}
s4_extract <- function(f, treatment = "X", ...) {
  extract_mediation(f, treatment = treatment, mediator = c("M1", "M2"), ...)
}
# the `:=` and label roles of a lavaan reference (the treatment's coefficients)
s4_roles <- s3_roles
# lavaan reference: path estimates, their covariance block, the defined effects, the logLik and the model test
s4_reference <- function(d, variant, direct, tr = "X", cvs = c("Z1", "Z2")) {
  l <- sb_lavaan(s4_model(variant, direct, labels = TRUE, tr = tr, cvs = cvs), d)
  pe <- lavaan::parameterEstimates(l)
  roles <- s4_roles(variant, direct)
  est <- stats::setNames(vapply(roles, function(r) pe$est[pe$label == r][1L], numeric(1)), names(roles))
  idx <- match(roles, names(lavaan::coef(l)))
  W <- lavaan::vcov(l)[idx, idx, drop = FALSE]
  dimnames(W) <- list(names(roles), names(roles))
  eff <- pe[pe$label %in% c("ind", "ind_tot", "te"), ]
  list(
    fit = l, est = est, vcov = W, ind = eff[eff$label == "ind", ], ind_tot = eff[eff$label == "ind_tot", ],
    te = eff[eff$label == "te", ], logl = as.numeric(lavaan::logLik(l)),
    df = unname(lavaan::fitMeasures(l, "df")), chisq = unname(lavaan::fitMeasures(l, "chisq"))
  )
}
# complete-data oracle: equation-wise OLS with the ML residual variance and the ML exogenous moments. The covariance
# is exactly block diagonal over the three equations and the exogenous block. A named coefficient vector and its
# covariance, in medfit's parameter names (aligned by unordered pair with sb_key()).
s4_ols <- function(d, variant, direct) {
  sat <- variant == "saturated"
  n <- nrow(d)
  eq <- list(
    M1 = c("X", "Z1", "Z2"), M2 = c("M1", if (sat) "X", "Z1", "Z2"),
    Y = c(if (sat) "M1", "M2", if (direct == "free") "X", "Z1", "Z2")
  )
  est <- numeric()
  blocks <- list()
  for (r in names(eq)) {
    Z <- cbind(1, as.matrix(d[, eq[[r]], drop = FALSE]))
    b <- drop(solve(crossprod(Z), crossprod(Z, d[[r]])))
    s2 <- mean((d[[r]] - drop(Z %*% b))^2)
    nm <- c(paste0(r, "~", eq[[r]]), paste0(r, "~1"))
    cf <- stats::setNames(c(b[-1L], b[1L]), nm)
    V <- s2 * solve(crossprod(Z))
    V <- V[c(seq_along(eq[[r]]) + 1L, 1L), c(seq_along(eq[[r]]) + 1L, 1L)]
    dimnames(V) <- list(nm, nm)
    vn <- paste0(r, "~~", r)
    blocks[[r]] <- list(est = c(cf, stats::setNames(s2, vn)), V = V, vn = vn, s2 = s2)
    est <- c(est, blocks[[r]]$est)
  }
  ex <- c("X", "Z1", "Z2")
  E <- as.matrix(d[, ex])
  S <- stats::cov(E) * (n - 1) / n
  mu <- colMeans(E)
  ij <- which(upper.tri(S, diag = TRUE), arr.ind = TRUE)
  prm <- paste0(ex[ij[, 1L]], "~~", ex[ij[, 2L]])
  sv <- S[ij]
  VS <- outer(seq_len(nrow(ij)), seq_len(nrow(ij)), Vectorize(function(u, v) {
    i <- ij[u, 1L]
    j <- ij[u, 2L]
    k <- ij[v, 1L]
    l <- ij[v, 2L]
    (S[i, k] * S[j, l] + S[i, l] * S[j, k]) / n
  }))
  dimnames(VS) <- list(prm, prm)
  mn <- paste0(ex, "~1")
  VM <- S / n
  dimnames(VM) <- list(mn, mn)
  est <- c(est, stats::setNames(sv, prm), stats::setNames(mu, mn))
  nms <- names(est)
  V <- matrix(0, length(est), length(est), dimnames = list(nms, nms))
  for (b in blocks) {
    V[rownames(b$V), rownames(b$V)] <- b$V
    V[b$vn, b$vn] <- 2 * b$s2^2 / n
  }
  V[prm, prm] <- VS
  V[mn, mn] <- VM
  list(est = est, vcov = V, logl = -sum(vapply(seq_len(3), function(i) {
    n / 2 * (log(2 * pi) + log(blocks[[i]]$s2) + 1)
  }, numeric(1))) - n / 2 * (3 * log(2 * pi) + log(det(S)) + 3))
}
# independent implied moments of the serial model (6 variables) from a named coefficient vector; a coefficient that is
# not in the fit is 0. Exogenous covariances may be named in either order.
s4_moments <- function(q, vars = s4_vars) {
  p <- length(vars)
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  B <- matrix(0, p, p, dimnames = list(vars, vars))
  for (r in c("M1", "M2", "Y")) for (v in setdiff(vars, r)) B[r, v] <- g(paste0(r, "~", v))
  psi <- diag(vapply(vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(vars, vars)
  ex <- c("X", "Z1", "Z2")
  for (i in 1:2) for (j in (i + 1):3) {
    v <- g(paste0(ex[i], "~~", ex[j])) + g(paste0(ex[j], "~~", ex[i]))
    psi[ex[i], ex[j]] <- psi[ex[j], ex[i]] <- v
  }
  A <- solve(diag(p) - B)
  list(mu = drop(A %*% vapply(vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
s4_nll <- function(d, q) gk_row_nll(as.matrix(d[, s4_vars]), s4_moments(q))
s4_align_v <- s3_align_v
s4_align_m <- s3_align_m
s4_grad <- s3_grad
# fit and extraction cache
s4_obj <- local({
  cache <- list()
  function(variant = "saturated", direct = "free", kind = "mar") {
    key <- paste(variant, direct, kind)
    if (is.null(cache[[key]])) {
      d <- s4_data(kind, cp = if (direct == "free") s4_truth[["cp"]] else 0)
      f <- s4_fit(d, variant, direct)
      cache[[key]] <<- list(d = d, f = f, z = s4_extract(f))
    }
    cache[[key]]
  }
})
