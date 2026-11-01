# Independent QA: consumes the single bounded matrix; no optimizer calls.
devtools::load_all(quiet = TRUE)
source("tests/testthat/helper-fiml-oracle.R")
workspace <- "_agents_workspace/fiml-bounded-inference"
mat <- readRDS(file.path(workspace, "qa-matrix.rds"))
checks <- list()
check <- function(name, expression) {
  outcome <- tryCatch(
    {
      force(expression)
      "PASS"
    },
    error = function(e) conditionMessage(e),
    interrupt = function(e) "INTERRUPT ESCAPED"
  )
  checks[[name]] <<- outcome # nolint: assignment_linter. Intentional closure-local test instrumentation.
  cat(name, ":", outcome, "\n")
  saveRDS(checks, file.path(workspace, "qa-contracts.rds"))
}
assert <- function(x) if (!isTRUE(x)) stop("independent assertion failed")
q7 <- function(x, p) {
  y <- sort(x)
  h <- 1 + (length(y) - 1) * p
  j <- floor(h)
  y[j] + (h - j) * (y[pmin(j + 1, length(y))] - y[j])
}
fit <- mat$artifacts[["mar-free"]]$fit
zero <- mat$artifacts[["mcar-zero"]]$fit
for (cell in names(mat$artifacts)) {
  f <- mat$artifacts[[cell]]$fit
  check(paste(cell, "independent score Hessian covariance"), {
    d <- f@data
    q <- coef(f)
    center <- colMeans(d, na.rm = TRUE)
    scales <- apply(d, 2, stats::sd, na.rm = TRUE)
    z <- as.data.frame(sweep(sweep(as.matrix(d), 2, center), 2, scales, `/`))
    qs <- fo_affine(q, 1 / scales, -center / scales)
    H <- fo_hessian(function(x) fo_nll(z, x), qs, .01)
    gradient <- drop(fo_jacobian(function(x) fo_nll(z, x), qs))
    J <- fo_jacobian(function(x) fo_affine(x, 1 / scales, -center / scales), q)
    W <- J %*% vcov(f) %*% t(J)
    reference <- solve(H)
    assert(max(abs(W - reference) / sqrt(outer(diag(reference), diag(reference)))) < 1e-3)
    assert(sqrt(drop(crossprod(gradient, solve(H, gradient)))) < 1e-5)
    # Defects: diagonal information and omission of observed affine Jacobian.
    # Complete zero-direct model has diagonal information in centered coordinates.
    if (cell != "complete-zero") {
      assert(max(abs(W - diag(diag(reference))) / sqrt(outer(diag(reference), diag(reference)))) > 1e-3)
    }
    jacobian <- sum(colSums(!is.na(d)) * log(scales))
    assert(abs(fo_nll(d, q) - fo_nll(z, qs) - jacobian) < 1e-7)
    assert(abs(jacobian) > 1e-7)
    # Row and column permutation with matched structural order preserves density.
    assert(abs(fo_nll(d[rev(seq_len(nrow(d))), ], q) - fo_nll(d, q)) < 1e-7)
    assert(abs(fo_nll(d[, c("Y", "X", "M")][, c("X", "M", "Y")], q) - fo_nll(d, q)) < 1e-7)
  })
}
check("supplied normals independent root all effects aliases no optimizer", {
  calls <- 0L
  f <- function(...) {
    calls <<- calls + 1L # nolint: assignment_linter. Intentional closure-local test instrumentation.
    stop("unexpected optimizer")
  }
  for (s in list(fit, zero)) {
    for (effect in c("nie", "nde", "te")) {
      q <- coef(s)
      V <- vcov(s)
      sdv <- sqrt(diag(V))
      corr <- V / (sdv %o% sdv)
      eig <- eigen(corr, symmetric = TRUE)
      oracle_factor <- diag(sdv) %*% eig$vectors %*% diag(sqrt(pmax(0, eig$values))) %*% t(eig$vectors)
      set.seed(123L)
      Z <- matrix(stats::rnorm(8L * length(q)), 8L, byrow = TRUE)
      draw <- sweep(Z %*% t(oracle_factor), 2, q, `+`)
      colnames(draw) <- names(q)
      cp <- if ("cp" %in% names(q)) draw[, "cp"] else rep(0, 8L)
      expected <- switch(effect,
        nie = draw[, "a"] * draw[, "b"],
        nde = cp,
        te = cp + draw[, "a"] * draw[, "b"]
      )
      out <- testthat::with_mocked_bindings(
        bootstrap_mediation(source_fit = s, effect = effect, method = "parametric", n_boot = 8L, seed = 123L),
        .bootstrap_fiml_refit = f, .sem_fiml_prepare = f, .package = "medfit"
      )
      assert(max(abs(expected - out@boot_estimates)) < 1e-13)
      assert(max(abs(confint(out, level = .8)[1, ] - q7(expected, c(.1, .9)))) < 1e-13)
      assert(length(out@inference$parameters) == if ("cp" %in% names(q)) 9L else 8L)
      if (!"cp" %in% names(q) && effect == "nde") assert(identical(out@boot_estimates, rep(0, 8L)))
      # Defect: drop cross covariance, or draw another alias for a.
      if (effect == "nie") {
        diagonal <- sweep(sweep(Z, 2, sdv, `*`), 2, q, `+`)
        colnames(diagonal) <- names(q)
        assert(max(abs(expected - diagonal[, "a"] * diagonal[, "b"])) > 1e-6)
        assert(max(abs(expected - (draw[, "a"] + .1) * draw[, "b"])) > 1e-6)
      }
      perm <- rev(names(q))
      factor <- medfit:::.bootstrap_fiml_factor(V[perm, perm], names(q))$factor
      assert(max(abs(factor - oracle_factor)) < 1e-13)
      assert(max(abs(tcrossprod(oracle_factor) - V) / (sdv %o% sdv)) <=
               10 * max(out@inference$covariance_factor$tau_sym, out@inference$covariance_factor$tau_eig))
    }
  }
  assert(calls == 0L)
})
check("source masks duplicate multiplicity and resample scaling mutants", {
  a <- mat$artifacts[["mcar-free"]]
  rows <- a$indices[[1]]
  d <- a$fit@data[rows, , drop = FALSE]
  q <- coef(a$native[[1]])
  target <- fo_nll(d, q)
  assert(abs(target - fo_nll(stats::na.omit(d), q)) > 1e-5)
  assert(abs(target - fo_nll(unique(d), q)) > 1e-5)
  assert(abs(target - fo_nll(a$fit@data, q)) > 1e-5)
  assert(max(abs(colMeans(d, na.rm = TRUE) - colMeans(a$fit@data, na.rm = TRUE))) > 1e-5)
  assert(!identical(
    table(apply(is.na(d), 1, paste0, collapse = "")),
    table(apply(is.na(a$fit@data), 1, paste0, collapse = ""))
  ))
})
check("source mutation missing and NA ledger reject before RNG", {
  for (type in c("data", "covariance", "model", "missing", "NA")) {
    damaged <- fit
    if (type == "data") damaged@data[1, 1] <- damaged@data[1, 1] + 1
    if (type == "covariance") damaged@vcov[1, 1] <- damaged@vcov[1, 1] * 2
    if (type == "model") damaged@model <- "M ~ X\nY ~ M + X"
    if (type %in% c("missing", "NA")) {
      dg <- damaged@diagnostics
      dg$ledger <- if (type == "missing") NULL else list(schema = "fiml-1", outcome = NA)
      damaged@diagnostics <- dg
    }
    set.seed(199L)
    rng <- .Random.seed
    e <- tryCatch(bootstrap_mediation(source_fit = damaged, effect = "nie", method = "parametric"), error = identity)
    assert(inherits(e, "medfit_error_ledger"))
    assert(identical(rng, .Random.seed))
  }
})
check("full failure ledger all levels and stale accessor bounds", {
  i <- 0L
  out <- testthat::with_mocked_bindings(
    bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L),
    .bootstrap_fiml_refit = function(...) {
      i <<- i + 1L # nolint: assignment_linter. Intentional closure-local test instrumentation.
      if (i == 2L) stop("rank/information unresolved")
      fit
    },
    .package = "medfit"
  )
  assert(identical(is.na(out@boot_estimates), c(FALSE, TRUE, FALSE)))
  assert(identical(vapply(out@inference$replicates, `[[`, integer(1), "id"), 1:3))
  out@ci_lower <- -9
  out@ci_upper <- 9
  for (level in c(.01, .5, .8, .95, .99)) assert(all(is.na(confint(out, level = level))))
  assert(all(is.na(tidy(out)[c("std_error", "conf_low", "conf_high")])))
  assert(all(is.na(summary(out)$ci)))
  assert(any(grepl("withheld", capture.output(print(out)))))
  assert(any(grepl("withheld", capture.output(show(out)))))
  assert(any(is.finite(q7(out@boot_estimates[is.finite(out@boot_estimates)], c(.025, .975)))))
})
check("interrupt returns full incomplete ledger and unattempted IDs", {
  i <- 0L
  out <- testthat::with_mocked_bindings(
    bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L),
    .bootstrap_fiml_refit = function(...) {
      i <<- i + 1L # nolint: assignment_linter. Intentional closure-local test instrumentation.
      if (i == 2L) {
        stop(structure(list(message = "synthetic interrupt", call = NULL),
          class = c("interrupt", "condition")
        ))
      }
      fit
    }, .package = "medfit"
  )
  assert(S7::S7_inherits(out, BootstrapResult))
  assert(length(out@boot_estimates) == 3L)
  assert(identical(out@inference$replicates[[3]]$status, "unattempted"))
  assert(all(is.na(confint(out))))
})
check("manual type7 catches alternate interpolation", {
  x <- mat$artifacts[["mar-free"]]$out@boot_estimates
  assert(max(abs(q7(x, c(.025, .975)) - unname(stats::quantile(x, c(.025, .975), type = 7)))) < 1e-14)
  assert(max(abs(q7(x, c(.025, .975)) - unname(stats::quantile(x, c(.025, .975), type = 6)))) > 1e-6)
})
if (!all(vapply(checks, identical, logical(1), "PASS"))) stop("QA contract failures; inspect qa-contracts.rds")
