# Shared fixtures of the FI-G3 slice S2 tests (the PURE CHAIN, k = 0: X -> M1 -> M2 -> Y with the shortcuts X -> M2 and
# M1 -> Y absent). Prefix sc_. Everything here is an oracle or a data generator and never calls the serial extraction or
# effect code it is used to test. It builds on helper-fiml-serial.R (sb_*): the lavaan wrapper, the alignment helpers,
# the independent implied moments (a coefficient that is not in the fit is 0), the delta-SE helper and the forger.

sc_zeros <- sb_zeros
# model text; `direct` is "free", "zero" (Y ~ 0*X) or "omit"; `labels` writes lavaan labels and the defined effects
sc_model <- function(direct = "free", labels = FALSE, zeros = sc_zeros, defined = labels) {
  l <- function(lab, v) if (labels) paste0(lab, "*", v) else v
  ypath <- switch(direct, free = l("cp", "X"), zero = "0*X", omit = NULL)
  paste(c(
    paste("M1 ~", l("a", "X")),
    paste("M2 ~", l("d1", "M1")),
    paste("Y ~", paste(c(l("b", "M2"), ypath), collapse = " + ")),
    zeros,
    if (defined) c("ind := a*d1*b", if (direct == "free") "te := ind + cp" else "te := ind")
  ), collapse = "\n")
}
# every chain path distinct and large; `a2` and `b1` are the shortcut effects of the data-generating process (0: a
# true chain; nonzero: a graph the chain cannot represent, so its likelihood must fall below the saturated one)
sc_truth <- c(a = .9, d1 = .7, b = .6, cp = .25)
sc_data <- function(kind = "mar", n = 300L, seed = 9201L, cp = sc_truth[["cp"]], a2 = 0, b1 = 0) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  m1 <- .3 + sc_truth[["a"]] * x + stats::rnorm(n, sd = .7)
  m2 <- -.2 + sc_truth[["d1"]] * m1 + a2 * x + stats::rnorm(n, sd = .8)
  y <- .2 + sc_truth[["b"]] * m2 + b1 * m1 + cp * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "mcar30") {
    for (v in names(d)) d[stats::runif(n) < .3, v] <- NA_real_
  } else if (kind == "sparse") {
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
sc_fit <- function(d, direct = "free", model = sc_model(direct)) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
}
# the saturated model on the same data (for the restriction test): free shortcuts, free direct path
sc_sat_fit <- function(d, direct = "free") sb_fit(d, direct)
sc_roles <- c(a = "a", d1 = "d1", b = "b", c_prime = "cp")
# lavaan reference for an extracted chain object: the path estimates, their covariance block, the defined effects
sc_reference <- function(d, direct = "free") {
  l <- sb_lavaan(sc_model(direct, labels = TRUE), d)
  pe <- lavaan::parameterEstimates(l)
  roles <- if (direct == "free") sc_roles else sc_roles[names(sc_roles) != "c_prime"]
  est <- stats::setNames(vapply(roles, function(r) pe$est[pe$label == r][1L], numeric(1)), names(roles))
  idx <- match(roles, names(lavaan::coef(l)))
  W <- lavaan::vcov(l)[idx, idx, drop = FALSE]
  dimnames(W) <- list(names(roles), names(roles))
  eff <- pe[pe$label %in% c("ind", "te"), ]
  list(
    fit = l, est = est, vcov = W, ind = eff[eff$label == "ind", ], te = eff[eff$label == "te", ],
    logl = as.numeric(lavaan::logLik(l)), df = unname(lavaan::fitMeasures(l, "df")),
    chisq = unname(lavaan::fitMeasures(l, "chisq"))
  )
}
# the hand gradients of spec 3.2 for the chain, from the extracted estimates: the shortcut paths do not exist, so no
# a2 * b or a * b1 term can appear
sc_grad <- function(z) {
  e <- z@estimates
  a <- e[["a"]]
  d1 <- e[["d1"]]
  b <- e[["b"]]
  nie <- c(a = d1 * b, d1 = a * b, b = a * d1)
  list(nie = nie, nie_total = nie, nde = c(c_prime = 1), te = c(nie, c_prime = 1))
}
sc_obj <- local({
  cache <- list()
  function(direct = "free", kind = "mar") {
    key <- paste(direct, kind)
    if (is.null(cache[[key]])) {
      d <- sc_data(kind, cp = if (direct == "free") .25 else 0)
      cache[[key]] <<- sb_extract(sc_fit(d, direct))
    }
    cache[[key]]
  }
})
