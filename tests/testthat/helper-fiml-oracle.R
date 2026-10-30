# Test-only structural Gaussian oracle: no production RAM or objective helpers.
fo_model <- function(direct) paste0("M ~ a*X\nY ~ b*M + ", if (direct) "cp" else "0", "*X")
fo_fixture <- function(kind, direct) {
  set.seed(if (kind == "patterns") 997L else 271L)
  n <- 300L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + (if (direct) .25 else 0) * x +
    stats::rnorm(n, sd = if (kind == "near") .03 else .9)
  d <- data.frame(X = x, M = m, Y = y)
  if (kind %in% c("mar", "affine")) {
    d[stats::runif(n) < stats::plogis(-1.3 + .7 * x), "M"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.1 - .6 * x), "Y"] <- NA_real_
  } else if (kind == "patterns") {
    patterns <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))[-1L, ]
    d[!patterns[rep(1:7, length.out = n), ]] <- NA_real_
    d <- rbind(d, c(NA_real_, NA_real_, NA_real_))
  } else if (kind == "near") {
    d[stats::runif(n) < .22, "M"] <- NA_real_
    d[stats::runif(n) < .28, "Y"] <- NA_real_
  } else if (kind == "unidentified") {
    d[1:150, "Y"] <- NA_real_
    d[151:300, c("X", "M")] <- NA_real_
  } else {
    stop("unknown fixture")
  }
  if (kind == "affine") d <- as.data.frame(sweep(sweep(as.matrix(d), 2, c(3, .5, 2), `*`),
                                                 2, c(2, -3, 4), `+`))
  d
}
fo_affine <- function(q, scale, shift) {
  out <- q
  out["a"] <- q["a"] * scale[2] / scale[1]
  out["b"] <- q["b"] * scale[3] / scale[2]
  cp <- if ("cp" %in% names(q)) q[["cp"]] * scale[3] / scale[1] else 0
  if ("cp" %in% names(q)) out["cp"] <- cp
  out[c("X~~X", "M~~M", "Y~~Y")] <- q[c("X~~X", "M~~M", "Y~~Y")] * scale^2
  out["X~1"] <- q["X~1"] * scale[1] + shift[1]
  out["M~1"] <- q["M~1"] * scale[2] + shift[2] - out["a"] * shift[1]
  out["Y~1"] <- q["Y~1"] * scale[3] + shift[3] - out["b"] * shift[2] - cp * shift[1]
  out
}
fo_moments <- function(q) {
  cp <- if ("cp" %in% names(q)) q[["cp"]] else 0
  L <- rbind(c(1, 0, 0), c(q[["a"]], 1, 0), c(cp + q[["a"]] * q[["b"]], q[["b"]], 1))
  list(mu = drop(L %*% q[c("X~1", "M~1", "Y~1")]),
       sigma = L %*% diag(q[c("X~~X", "M~~M", "Y~~Y")]) %*% t(L))
}
fo_nll <- function(d, q) {
  moments <- fo_moments(q)
  sum(vapply(seq_len(nrow(d)), function(i) {
    j <- which(!is.na(d[i, ]))
    if (!length(j)) return(0)
    U <- chol(moments$sigma[j, j, drop = FALSE])
    z <- forwardsolve(t(U), as.numeric(d[i, j]) - moments$mu[j])
    .5 * (length(j) * log(2 * pi) + 2 * sum(log(diag(U))) + sum(z^2))
  }, numeric(1)))
}
# Central differences with four Richardson levels; independent of production derivatives.
fo_richardson <- function(values) {
  for (order in seq_len(length(values) - 1L)) {
    values <- lapply(seq_len(length(values) - 1L), function(i) {
      (4^order * values[[i + 1L]] - values[[i]]) / (4^order - 1)
    })
  }
  values[[1L]]
}
fo_jacobian <- function(fun, q) {
  columns <- lapply(seq_along(q), function(j) {
    fo_richardson(lapply(.01 / 2^(0:3), function(h) {
      step <- q * 0
      step[j] <- h * max(1, abs(q[j]))
      (fun(q + step) - fun(q - step)) / (2 * step[j])
    }))
  })
  do.call(cbind, columns)
}
fo_hessian <- function(fun, q, h) {
  units <- pmax(abs(q), 1)
  variances <- intersect(c("X~~X", "M~~M", "Y~~Y"), names(q))
  units[variances] <- q[variances] / 10
  f0 <- fun(q)
  fo_richardson(lapply(h / 2^(0:3), function(delta) {
    H <- matrix(0, length(q), length(q))
    for (j in seq_along(q)) {
      ej <- q * 0
      ej[j] <- units[j] * delta
      H[j, j] <- (fun(q + ej) - 2 * f0 + fun(q - ej)) / ej[j]^2
      if (j > 1L) for (k in seq_len(j - 1L)) {
        ek <- q * 0
        ek[k] <- units[k] * delta
        H[j, k] <- H[k, j] <- (fun(q + ej + ek) - fun(q + ej - ek) -
                                 fun(q - ej + ek) + fun(q - ej - ek)) / (4 * ej[j] * ek[k])
      }
    }
    H
  }))
}
# Public parameter contract is independent of either fitted object or its order.
fo_parameter_names <- function(direct) {
  c("a", "b", if (direct) "cp", "X~~X", "M~~M", "Y~~Y", "X~1", "M~1", "Y~1")
}
fo_assert_parameters <- function(q, V, direct) {
  expected <- fo_parameter_names(direct)
  exact_names <- function(actual) {
    length(actual) == length(expected) && !anyDuplicated(actual) && setequal(actual, expected)
  }
  if (!is.numeric(q) || !is.null(dim(q)) || length(q) != length(expected) || !exact_names(names(q))) {
    stop("FIML oracle coefficient names/count/multiplicity differ from the declared parameter set")
  }
  if (!is.matrix(V) || !is.numeric(V) || !identical(dim(V), rep(length(expected), 2L)) ||
        !exact_names(rownames(V)) || !exact_names(colnames(V))) {
    stop("FIML oracle covariance dimensions/names/multiplicity differ from the declared parameter set")
  }
  invisible(TRUE)
}
fo_record_columns <- function() {
  c("cell", "outcome", "coefficient", "covariance", "nll", "fixed_nll", "geometry_min", "geometry_max",
    "information_min", "information_max", "modelcov_min", "modelcov_max", "modelcov_at")
}
fo_write_records <- function(records, path) {
  if (!grepl("^/", path)) stop("FIML_ORACLE_RESULTS must be an absolute path")
  if (!is.data.frame(records) || ncol(records) != length(fo_record_columns()) ||
        anyDuplicated(names(records)) || !setequal(names(records), fo_record_columns())) {
    stop("FIML oracle evidence schema must contain every declared field exactly once")
  }
  utils::write.csv(records, path, row.names = FALSE)
}
fo_geometry <- function(d, q) {
  moments <- fo_moments(q)
  dm <- fo_jacobian(function(x) fo_moments(x)$mu, q)
  ds <- fo_jacobian(function(x) as.vector(fo_moments(x)$sigma), q)
  G <- matrix(0, length(q), length(q))
  masks <- split(seq_len(nrow(d)), apply(!is.na(d), 1, paste0, collapse = ""))
  for (ids in masks) {
    j <- which(!is.na(d[ids[1L], ]))
    if (!length(j)) next
    W <- solve(moments$sigma[j, j, drop = FALSE])
    D <- ds[as.vector(outer(j, (j - 1L) * 3L, `+`)), , drop = FALSE]
    G <- G + length(ids) * (crossprod(dm[j, , drop = FALSE], W %*% dm[j, , drop = FALSE]) +
                              crossprod(D, kronecker(W, W) %*% D) / 2)
  }
  G
}
fo_spectrum <- function(H) eigen(H / sqrt(outer(diag(H), diag(H))), symmetric = TRUE)$values
fo_truth <- function(kind, direct) {
  q <- c(a = .5, b = .6, cp = .25, `X~~X` = 1.21, `M~~M` = .64,
         `Y~~Y` = if (kind == "near") .0009 else .81, `X~1` = .8, `M~1` = -.4, `Y~1` = .7)
  if (!direct) q <- q[names(q) != "cp"]
  if (kind == "affine") q <- fo_affine(q, c(3, .5, 2), c(2, -3, 4))
  q
}
fo_internal <- function(q, p) {
  standardized <- fo_affine(q, 1 / p$scale, -p$center / p$scale)
  mapping <- c(a = "a", b = "b", cp = "cp", vx = "X~~X", vm = "M~~M", vy = "Y~~Y",
               ix = "X~1", im = "M~1", iy = "Y~1")
  stats::setNames(standardized[mapping[p$ram$par_names]], p$ram$par_names)
}
