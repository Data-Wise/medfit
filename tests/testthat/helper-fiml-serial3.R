# Shared fixtures of the FI-G3 slice S3 tests (serial FIML with ONE covariate Z, both variants). Prefix s3_. Everything
# here is an oracle or a data generator and never calls the serial extraction or effect code it is used to test. It
# builds on helper-fiml-serial.R (sb_*): the lavaan wrapper, the key alignment and the forger.

s3_zeros <- sb_zeros
# model text. `variant` is "saturated" or "chain"; `direct` is "free" or "zero" (Y ~ 0*<treatment>); `tr` is the
# treatment (the variable that carries the labels a, a2, cp) and `cv` the covariate (labels gm1, gm2, gy). In the pure
# chain the treatment is the variable absent from M2's equation, so `tr` also decides the syntax there.
s3_model <- function(variant = "saturated", direct = "free", labels = FALSE, tr = "X", cv = "Z", zeros = s3_zeros,
                     defined = labels, exo_cov = FALSE) {
  l <- function(lab, v) if (labels) paste0(lab, "*", v) else v
  sat <- variant == "saturated"
  ypath <- switch(direct, free = l("cp", tr), zero = paste0("0*", tr))
  paste(c(
    paste("M1 ~", paste(c(l("a", tr), l("gm1", cv)), collapse = " + ")),
    paste("M2 ~", paste(c(l("d1", "M1"), if (sat) l("a2", tr), l("gm2", cv)), collapse = " + ")),
    paste("Y ~", paste(c(if (sat) l("b1", "M1"), l("b", "M2"), ypath, l("gy", cv)), collapse = " + ")),
    zeros,
    if (exo_cov) paste(tr, "~~", cv),
    if (defined) c(
      "ind := a*d1*b", if (sat) "ind_tot := a*d1*b + a2*b + a*b1" else "ind_tot := a*d1*b",
      if (direct == "free") "te := ind_tot + cp" else "te := ind_tot"
    )
  ), collapse = "\n")
}
# the data-generating values: every path distinct, and the covariate effects LARGE and distinct from the path values,
# so a covariate coefficient mistaken for a path (or the reverse) cannot hide
s3_truth <- c(a = .9, a2 = .4, d1 = .7, b1 = .35, b = .6, cp = .25, gm1 = 1.4, gm2 = -.9, gy = 1.7)
s3_data <- function(kind = "mar", n = 360L, seed = 9301L, cp = s3_truth[["cp"]], a2 = s3_truth[["a2"]],
                    b1 = s3_truth[["b1"]]) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  z <- 1 + .5 * x + stats::rnorm(n, sd = 1.1)
  m1 <- .3 + s3_truth[["a"]] * x + s3_truth[["gm1"]] * z + stats::rnorm(n, sd = .7)
  m2 <- -.2 + s3_truth[["d1"]] * m1 + a2 * x + s3_truth[["gm2"]] * z + stats::rnorm(n, sd = .8)
  y <- .2 + s3_truth[["b"]] * m2 + b1 * m1 + cp * x + s3_truth[["gy"]] * z + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, Z = z, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    # every variable, the covariate included, can be incomplete; the others depend (ignorably) on the observed X
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.5 + .5 * x), "Z"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "mcar30") {
    for (v in names(d)) d[stats::runif(n) < .3, v] <- NA_real_
  } else if (kind == "zmiss") {
    # only the covariate has missing values
    d[stats::runif(n) < .35, "Z"] <- NA_real_
  } else if (kind == "sparse") {
    # single-variable, pair and triple patterns in disjoint row blocks plus an all-empty row
    d[1:25, "X"] <- NA_real_
    d[26:50, "Z"] <- NA_real_
    d[51:75, "M1"] <- NA_real_
    d[76:100, "M2"] <- NA_real_
    d[101:125, "Y"] <- NA_real_
    d[126:140, c("M1", "M2")] <- NA_real_
    d[141:155, c("X", "Y")] <- NA_real_
    d[156:170, c("Z", "M2")] <- NA_real_
    d[171:185, c("M2", "Y")] <- NA_real_
    d[186:195, c("X", "M1", "Y")] <- NA_real_
    d[196L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
s3_fit <- function(d, variant = "saturated", direct = "free", model = s3_model(variant, direct)) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
}
s3_extract <- function(f, treatment = "X", ...) {
  extract_mediation(f, treatment = treatment, mediator = c("M1", "M2"), ...)
}
# the `:=` and label roles of a lavaan reference
s3_roles <- function(variant, direct) {
  r <- if (variant == "saturated") {
    c(a = "a", a2 = "a2", d1 = "d1", b1 = "b1", b = "b", c_prime = "cp")
  } else {
    c(a = "a", d1 = "d1", b = "b", c_prime = "cp")
  }
  if (direct != "free") r[names(r) != "c_prime"] else r
}
# lavaan reference: path estimates, their covariance block, the defined effects, the logLik and the model test
s3_reference <- function(d, variant, direct, tr = "X", cv = "Z") {
  l <- sb_lavaan(s3_model(variant, direct, labels = TRUE, tr = tr, cv = cv), d)
  pe <- lavaan::parameterEstimates(l)
  roles <- s3_roles(variant, direct)
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
# is exactly block diagonal over the three equations and the exogenous block (observed = expected information at the
# MLE for a Gaussian model). A named coefficient vector and its covariance, in medfit's parameter names.
s3_ols <- function(d, variant, direct) {
  sat <- variant == "saturated"
  n <- nrow(d)
  eq <- list(
    M1 = c("X", "Z"), M2 = c("M1", if (sat) "X", "Z"),
    Y = c(if (sat) "M1", "M2", if (direct == "free") "X", "Z")
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
  E <- as.matrix(d[, c("X", "Z")])
  S <- stats::cov(E) * (n - 1) / n
  mu <- colMeans(E)
  prm <- c("X~~X", "X~~Z", "Z~~Z")
  sv <- c(S[1, 1], S[1, 2], S[2, 2])
  ij <- list(c(1, 1), c(1, 2), c(2, 2))
  VS <- outer(seq_along(ij), seq_along(ij), Vectorize(function(u, v) {
    i <- ij[[u]][1]
    j <- ij[[u]][2]
    k <- ij[[v]][1]
    l <- ij[[v]][2]
    (S[i, k] * S[j, l] + S[i, l] * S[j, k]) / n
  }))
  dimnames(VS) <- list(prm, prm)
  VM <- S / n
  dimnames(VM) <- list(c("X~1", "Z~1"), c("X~1", "Z~1"))
  est <- c(est, stats::setNames(sv, prm), stats::setNames(mu, c("X~1", "Z~1")))
  nms <- names(est)
  V <- matrix(0, length(est), length(est), dimnames = list(nms, nms))
  for (b in blocks) {
    nm <- c(rownames(b$V), b$vn)
    V[rownames(b$V), rownames(b$V)] <- b$V
    V[b$vn, b$vn] <- 2 * b$s2^2 / n
  }
  V[prm, prm] <- VS
  V[rownames(VM), colnames(VM)] <- VM
  list(est = est, vcov = V, logl = -sum(vapply(seq_len(3), function(i) {
    n / 2 * (log(2 * pi) + log(blocks[[i]]$s2) + 1)
  }, numeric(1))) - n / 2 * (2 * log(2 * pi) + log(det(S)) + 2))
}
# independent implied moments of the serial model (5 variables) from a named coefficient vector; a coefficient that is
# not in the fit is 0
s3_moments <- function(q, vars = c("X", "Z", "M1", "M2", "Y")) {
  p <- length(vars)
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  B <- matrix(0, p, p, dimnames = list(vars, vars))
  for (r in c("M1", "M2", "Y")) for (v in setdiff(vars, r)) B[r, v] <- g(paste0(r, "~", v))
  psi <- diag(vapply(vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(vars, vars)
  psi["X", "Z"] <- psi["Z", "X"] <- g("X~~Z")
  A <- solve(diag(p) - B)
  list(mu = drop(A %*% vapply(vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
s3_nll <- function(d, q) gk_row_nll(as.matrix(d[, c("X", "Z", "M1", "M2", "Y")]), s3_moments(q))
# the hand gradients of spec 3.2, from an extracted object's estimates (the covariate never enters an effect)
s3_grad <- function(z) {
  e <- z@estimates
  if (z@variant == "chain") {
    nie <- c(a = e[["d1"]] * e[["b"]], d1 = e[["a"]] * e[["b"]], b = e[["a"]] * e[["d1"]])
    return(list(nie = nie, nie_total = nie, nde = c(c_prime = 1), te = c(nie, c_prime = 1)))
  }
  sb_grad(z)
}
# alignment of a vector / matrix named in lavaan's or medfit's style
s3_align_v <- function(ref, nm) ref[match(sb_key(nm), sb_key(names(ref)))]
s3_align_m <- function(V, nm) {
  i <- match(sb_key(nm), sb_key(rownames(V)))
  V[i, i, drop = FALSE]
}
# kernel and fit helpers
s3_obj <- local({
  cache <- list()
  function(variant = "saturated", direct = "free", kind = "mar") {
    key <- paste(variant, direct, kind)
    if (is.null(cache[[key]])) {
      d <- s3_data(kind, cp = if (direct == "free") s3_truth[["cp"]] else 0)
      f <- s3_fit(d, variant, direct)
      cache[[key]] <<- list(d = d, f = f, z = s3_extract(f))
    }
    cache[[key]]
  }
})
