# Independent QA for IG2 (cluster-robust CR0 sandwich of the native two-level fit). The oracle here never calls
# `.sem_scores_ml2()`, `.sem_eval_ml2()` or the native information: each cluster's log-likelihood is the unreduced
# stacked multivariate normal of its rows, written from a hand map theta -> (Sigma_W, Sigma_B, mu) for the
# X -> M -> Y two-level model; scores and the Hessian come from numDeriv. Second oracle: lavaan's full robust
# covariance (se = "robust.huber.white", TL-3 convention), compared element by element, not only on the diagonal.

tlq_implied <- function(a, b, cp, vx, vm, vy) {
  bm <- matrix(0, 3, 3)
  bm[2, 1] <- a
  bm[3, 2] <- b
  bm[3, 1] <- cp
  ib <- solve(diag(3) - bm)
  ib %*% diag(c(vx, vm, vy)) %*% t(ib)
}
# native theta order: a_w b_w cp_w M~~M Y~~Y X~~X a_b b_b cp_b M~~M.l2 Y~~Y.l2 X~~X.l2 M~1.l2 X~1.l2 Y~1.l2
tlq_names <- c("a_w", "b_w", "cp_w", "M~~M", "Y~~Y", "X~~X", "a_b", "b_b", "cp_b",
               "M~~M.l2", "Y~~Y.l2", "X~~X.l2", "M~1.l2", "X~1.l2", "Y~1.l2")
tlq_ll_cluster <- function(th, y) {
  sw <- tlq_implied(th[1], th[2], th[3], th[6], th[4], th[5])
  sb <- tlq_implied(th[7], th[8], th[9], th[12], th[10], th[11])
  bm <- matrix(0, 3, 3)
  bm[2, 1] <- th[7]
  bm[3, 2] <- th[8]
  bm[3, 1] <- th[9]
  mu <- drop(solve(diag(3) - bm, c(th[14], th[13], th[15])))
  n <- nrow(y)
  r <- as.vector(t(y)) - rep(mu, n)
  ch <- chol(kronecker(diag(n), sw) + kronecker(matrix(1, n, n), sb))
  z <- backsolve(ch, r, transpose = TRUE)
  -0.5 * (length(r) * log(2 * pi) + 2 * sum(log(diag(ch))) + sum(z^2))
}
# Hand CR0 sandwich; `map` takes a reduced parameter vector to the 15 native ones (shared a across levels).
tlq_hand <- function(th, d, map = identity) {
  bl <- lapply(split(d[, c("X", "M", "Y")], factor(d$cluster)), as.matrix)
  s <- t(vapply(bl, function(y) numDeriv::grad(function(t) tlq_ll_cluster(map(t), y), th), numeric(length(th))))
  h <- numDeriv::hessian(function(t) sum(vapply(bl, function(y) tlq_ll_cluster(map(t), y), 0)), th)
  a_inv <- solve(-h)
  list(v = a_inv %*% crossprod(s) %*% a_inv, s = s)
}
tlq_rel_v <- function(v, ref) max(abs(v - ref) / sqrt(outer(diag(ref), diag(ref))))
tlq_key <- function(lhs, op, rhs, level) {
  paste(level, ifelse(op == "~~", pmin(lhs, rhs), lhs), op, ifelse(op == "~~", pmax(lhs, rhs), rhs))
}
tlq_lavaan <- function(model, d) {
  suppressWarnings(lavaan::sem(model, d, cluster = "cluster", fixed.x = FALSE, information = "observed",
                               h1.information = "structured", se = "robust.huber.white"))
}
# lavaan's robust vcov reordered to native theta order, with the row set and multiplicity asserted
tlq_lavaan_v <- function(fit, lav) {
  nt <- fit@table[fit@table$free, ]
  pt <- lavaan::parTable(lav)
  pt <- pt[pt$free > 0, ]
  m <- match(tlq_key(nt$lhs, nt$op, nt$rhs, nt$level), tlq_key(pt$lhs, pt$op, pt$rhs, pt$level))
  expect_false(anyNA(m))
  expect_identical(length(unique(pt$free[m])), length(fit@theta))
  o <- integer(length(fit@theta))
  o[fit@internals$par_map[fit@table$free]] <- pt$free[m]
  unname(lavaan::lavInspect(lav, "vcov")[o, o])
}
# Non-normal, unbalanced clusters (sizes 1 to 15, eight singletons): robust and model-based SEs differ by up to ~2x.
tlq_data <- function() {
  withr::local_seed(7)
  sizes <- c(rep(1, 8), rep(c(2, 4, 7, 15), 10))
  sw <- tl_sigma(0.5, 0.4, 0.2, 1.0, 0.8, 0.9)
  sb <- tl_sigma(0.3, 0.6, 0.1, 0.7, 0.5, 0.6)
  cl <- rep(seq_along(sizes), sizes)
  u <- matrix(stats::rt(length(sizes) * 3, 4) / sqrt(2), ncol = 3) %*% chol(sb)
  e <- matrix((stats::rchisq(length(cl) * 3, 2) - 2) / 2, ncol = 3) %*% chol(sw)
  out <- data.frame(cluster = cl, sweep(u[cl, , drop = FALSE] + e, 2, c(1.5, -0.8, 2.2), `+`))
  names(out)[2:4] <- c("X", "M", "Y")
  out
}

test_that("QA: the native CR0 sandwich equals a hand stacked-density sandwich and lavaan's full robust vcov", {
  skip_if_not_installed("lavaan")
  skip_if_not_installed("numDeriv")
  d <- tlq_data()
  fit <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
  expect_identical(names(fit@theta), tlq_names)
  v <- unname(stats::vcov(fit))
  hand <- tlq_hand(unname(fit@theta), d)
  expect_lt(tlq_rel_v(v, hand$v), 1e-6)
  # per-cluster score rows, cluster by cluster (same factor order)
  s <- .sem_scores_ml2(fit@theta, fit@internals$ram, d[, c("X", "M", "Y", "cluster")], "cluster")
  expect_lt(max(abs(unname(s) - hand$s)) / max(abs(hand$s)), 1e-6)
  # the hand scores sum to about zero at the optimum
  expect_lt(max(abs(colSums(hand$s))) / max(abs(hand$s)), 1e-5)
  lv <- tlq_lavaan_v(fit, tlq_lavaan(tl_lavaan_model, d))
  expect_lt(tlq_rel_v(v, lv), 1e-3)
  # the sandwich is not the model-based covariance on these data (the check would be vacuous otherwise)
  vm <- unname(stats::vcov(fit_sem(tl_lavaan_model, d, cluster = "cluster")))
  expect_gt(max(abs(sqrt(diag(v) / diag(vm)) - 1)), 0.5)
})

test_that("QA: under a_w == a_b the projected sandwich equals the hand sandwich of the reduced parameterization", {
  skip_if_not_installed("lavaan")
  skip_if_not_installed("numDeriv")
  d <- tl_simulate(rep(2:9, length.out = 40), seed = 42)
  model <- paste0(tl_lavaan_model, "\na_w == a_b\n")
  fit <- fit_sem(model, d, cluster = "cluster", se_type = "sandwich")
  v <- unname(stats::vcov(fit))
  lmap <- diag(15)[, -7]
  lmap[7, 1] <- 1
  hand <- tlq_hand(unname(fit@theta)[-7], d, map = function(t) drop(lmap %*% t))
  expect_lt(tlq_rel_v(v, lmap %*% hand$v %*% t(lmap)), 1e-6)
  expect_lt(tlq_rel_v(v, tlq_lavaan_v(fit, tlq_lavaan(model, d))), 1e-3)
})

test_that("QA: the meat is invariant to row order and cluster labels; listwise deletion keeps lavaan parity", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  fit <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
  withr::local_seed(99)
  d2 <- d[sample(nrow(d)), ]
  d2$cluster <- paste0("c", sample(1e4, 40)[match(d2$cluster, unique(d$cluster))])
  vars <- c("X", "M", "Y", "cluster")
  b1 <- .sem_meat_ml2(fit@theta, fit@internals$ram, d[, vars], "cluster")
  b2 <- .sem_meat_ml2(fit@theta, fit@internals$ram, d2[, vars], "cluster")
  expect_lt(max(abs(b1 - b2)) / max(abs(b1)), 1e-12)
  # NA rows, a cluster with every row incomplete, a factor cluster with an unused level
  d3 <- d
  d3$M[c(2, 50, 51)] <- NA
  d3$Y[d3$cluster == 7] <- NA
  d3$cluster <- factor(d3$cluster, levels = c(1:40, 99))
  f3 <- suppressMessages(fit_sem(tl_lavaan_model, d3, cluster = "cluster", se_type = "sandwich"))
  dc <- d3[stats::complete.cases(d3[, c("X", "M", "Y")]), ]
  dc$cluster <- as.integer(droplevels(dc$cluster))
  expect_lt(tlq_rel_v(unname(stats::vcov(f3)), tlq_lavaan_v(f3, tlq_lavaan(tl_lavaan_model, dc))), 1e-3)
})

test_that("QA: extraction carries the sandwich block unchanged; effect SEs match the delta method on lavaan's V", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  fit <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
  em <- suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"))
  map <- c(a_within = "a_w", b_within = "b_w", c_prime_within = "cp_w",
           a_between = "a_b", b_between = "b_b", c_prime_between = "cp_b")
  expect_identical(unname(em@vcov[names(map), names(map)]), unname(stats::vcov(fit)[map, map]))
  lv <- lavaan::lavInspect(tlq_lavaan(tl_lavaan_model, d), "vcov")
  td <- suppressWarnings(generics::tidy(em))
  for (lvl in c("within", "between")) {
    a <- map[[paste0("a_", lvl)]]
    b <- map[[paste0("b_", lvl)]]
    g <- unname(c(fit@theta[b], fit@theta[a]))
    se_hand <- sqrt(drop(t(g) %*% lv[c(a, b), c(a, b)] %*% g))
    expect_lt(abs(td$std_error[td$term == paste0("nie_", lvl)] / se_hand - 1), 1e-3)
  }
})

test_that("QA: planted meat defects (CR1 factor, zeroed cross-level block) fail the hand oracle", {
  skip_if_not_installed("numDeriv")
  d <- tl_simulate(rep(2:9, length.out = 40), seed = 42)
  ref <- tlq_hand(unname(fit_sem(tl_lavaan_model, d, cluster = "cluster")@theta), d)$v
  good <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
  expect_lt(tlq_rel_v(unname(stats::vcov(good)), ref), 1e-6)
  real_meat <- .sem_meat_ml2
  local({
    local_mocked_bindings(.sem_meat_ml2 = function(theta, ram, data, cluster) {
      nrow(unique(data[cluster])) / (nrow(unique(data[cluster])) - 1) * real_meat(theta, ram, data, cluster)
    })
    bad <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
    expect_failure(expect_lt(tlq_rel_v(unname(stats::vcov(bad)), ref), 1e-6))
  })
  local({
    local_mocked_bindings(.sem_meat_ml2 = function(theta, ram, data, cluster) {
      b <- real_meat(theta, ram, data, cluster)
      b[1:6, 7:15] <- 0
      b[7:15, 1:6] <- 0
      b
    })
    bad <- fit_sem(tl_lavaan_model, d, cluster = "cluster", se_type = "sandwich")
    expect_failure(expect_lt(tlq_rel_v(unname(stats::vcov(bad)), ref), 1e-6))
  })
})
