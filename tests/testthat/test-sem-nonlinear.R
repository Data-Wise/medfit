# Native SEM engine: nonlinear equality constraints (T13, `cp == a*b`).
# Oracles: OpenMx with an mxConstraint (estimates to 1e-5), a reparameterized fit (cp replaced by a*b,
# solved with optim, standard errors by the delta method), and a fixed-seed nonparametric bootstrap. The
# covariance must be annihilated by the constraint Jacobian at the solution. Planted defects: the row
# classified as linear, the covariance projection frozen at a stale Jacobian, and the projection omitted.

nl_syntax <- "M ~ a*X\nY ~ b*M + cp*X\ncp == a*b"

# Mediation data whose direct effect equals the indirect effect (cp = a*b = 0.2), so the constraint is true.
nl_data <- function(n = 400, seed = 11) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7)
  data.frame(X = x, M = m, Y = y)
}

# Names without the spaces some default names carry, so a variance reads "X~~X" either way.
nl_norm <- function(x) gsub(" ", "", x, fixed = TRUE)

# Jacobian of `cp - a*b` over the fit's parameters, analytic, in the fit's parameter order.
nl_jacobian <- function(th) {
  nm <- nl_norm(names(th))
  j <- stats::setNames(numeric(length(th)), nm)
  j[["a"]] <- -th[["b"]]
  j[["b"]] <- -th[["a"]]
  j[["cp"]] <- 1
  j
}

# Relative size of J V: zero when the covariance lies in the constraint's tangent space.
nl_annihilation <- function(v, th) {
  sqrt(sum((nl_jacobian(th) %*% v)^2)) / sqrt(sum(v^2))
}

# The reparameterized oracle: cp is replaced by a*b, the remaining parameters are fitted by optim, and the
# covariance is G (G' I G)^-1 G' with G = d theta / d phi.
nl_reparam <- function(fit) {
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  nm <- nl_norm(names(coef(fit)))
  ia <- match("a", nm)
  ib <- match("b", nm)
  ic <- match("cp", nm)
  free <- setdiff(seq_along(nm), ic)
  pa <- match(ia, free)
  pb <- match(ib, free)
  to_theta <- function(phi) {
    th <- numeric(length(nm))
    th[free] <- phi
    th[ic] <- th[ia] * th[ib]
    th
  }
  jac <- function(phi) {
    th <- to_theta(phi)
    g <- matrix(0, length(nm), length(free))
    g[cbind(free, seq_along(free))] <- 1
    g[ic, pa] <- th[ib]
    g[ic, pb] <- th[ia]
    g
  }
  obj <- function(phi) .sem_eval(to_theta(phi), ram, smp, deriv = TRUE)
  start <- unname(coef(fit))[free] * 0.8
  opt <- stats::optim(
    start, function(p) obj(p)$f, function(p) as.vector(crossprod(jac(p), obj(p)$g)),
    method = "BFGS", control = list(reltol = 1e-15, maxit = 1000)
  )
  th <- to_theta(opt$par)
  g <- jac(opt$par)
  info <- .sem_info_observed(th, ram, smp)
  v <- g %*% solve(crossprod(g, info %*% g)) %*% t(g)
  list(theta = stats::setNames(th, nm), se = stats::setNames(sqrt(diag(v)), nm))
}

# Largest estimate gap and largest relative SE gap between a fit and the reparameterized oracle.
nl_gap <- function(fit) {
  ref <- nl_reparam(fit)
  th <- stats::setNames(coef(fit), nl_norm(names(coef(fit))))
  se <- stats::setNames(sqrt(diag(vcov(fit))), nl_norm(names(coef(fit))))
  list(est = max(abs(th - ref$theta[names(th)])), se = max(abs(se / ref$se[names(se)] - 1)))
}

test_that("cp == a*b fits, satisfies the constraint, and reports the equality as active", {
  fit <- fit_sem(nl_syntax, nl_data())
  th <- coef(fit)
  expect_lt(abs(th[["cp"]] - th[["a"]] * th[["b"]]), 1e-6)
  expect_identical(fit@diagnostics$active_constraints, "cp == a*b")
  # six free parameters, one removed by the equality, six moments
  expect_equal(fit@df, 1)
  expect_identical(length(th), 6L)
})

test_that("the estimates and standard errors equal the reparameterized oracle", {
  fit <- fit_sem(nl_syntax, nl_data())
  gap <- nl_gap(fit)
  expect_lt(gap$est, 1e-5)
  expect_lt(gap$se, 1e-3)
})

test_that("the covariance is annihilated by the Jacobian at the solution", {
  fit <- fit_sem(nl_syntax, nl_data())
  expect_lt(nl_annihilation(vcov(fit), coef(fit)), 1e-8)
  # a second dataset moves the solution; the Jacobian moves with it
  fit2 <- fit_sem(nl_syntax, nl_data(n = 300, seed = 4))
  expect_lt(nl_annihilation(vcov(fit2), coef(fit2)), 1e-8)
  expect_gt(abs(coef(fit)[["a"]] - coef(fit2)[["a"]]), 1e-3)
})

test_that("the estimates equal OpenMx's constrained optimum to 1e-5", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- nl_data()
  fit <- fit_sem(nl_syntax, d)
  cv <- stats::cov(d)
  dimnames(cv) <- list(c("X", "M", "Y"), c("X", "M", "Y"))
  old <- vapply(c("Optimality tolerance", "Feasibility tolerance", "Function precision"),
                function(o) as.character(OpenMx::mxOption(NULL, o)), "")
  OpenMx::mxOption(NULL, "Optimality tolerance", 1e-12)
  OpenMx::mxOption(NULL, "Feasibility tolerance", 1e-12)
  OpenMx::mxOption(NULL, "Function precision", 1e-15)
  on.exit(for (o in names(old)) OpenMx::mxOption(NULL, o, if (old[[o]] == "Auto") "Auto" else as.numeric(old[[o]])))
  m <- OpenMx::mxModel(
    "nl", type = "RAM", manifestVars = c("X", "M", "Y"),
    OpenMx::mxPath("X", "M", labels = "a", values = 0.3),
    OpenMx::mxPath("M", "Y", labels = "b", values = 0.3),
    OpenMx::mxPath("X", "Y", labels = "cp", values = 0.1),
    OpenMx::mxPath(c("X", "M", "Y"), arrows = 2, labels = c("vx", "vm", "vy"), values = 0.8),
    OpenMx::mxData(observed = cv, type = "cov", numObs = nrow(d)),
    OpenMx::mxAlgebra(cp - a * b, name = "con"),
    OpenMx::mxConstraint(con == 0, name = "k")
  )
  om <- suppressMessages(OpenMx::mxRun(m, silent = TRUE))
  est <- summary(om)$parameters
  ref <- stats::setNames(est$Estimate, est$name)
  th <- stats::setNames(coef(fit), nl_norm(names(coef(fit))))
  expect_lt(max(abs(th[c("a", "b", "cp")] - ref[c("a", "b", "cp")])), 1e-5)
  expect_lt(max(abs(th[c("X~~X", "M~~M", "Y~~Y")] - ref[c("vx", "vm", "vy")])), 1e-5)
})

test_that("the standard errors agree with a fixed-seed nonparametric bootstrap", {
  skip_on_cran()
  d <- nl_data(n = 300, seed = 21)
  fit <- fit_sem(nl_syntax, d)
  set.seed(2026)
  boot <- t(vapply(seq_len(150), function(i) {
    r <- tryCatch(suppressWarnings(fit_sem(nl_syntax, d[sample(nrow(d), replace = TRUE), ], n_starts = 3)),
                  error = function(e) NULL)
    if (is.null(r)) rep(NA_real_, 3) else unname(coef(r)[c("a", "b", "cp")])
  }, numeric(3)))
  expect_lt(mean(is.na(boot[, 1])), 0.05)
  se_boot <- apply(boot, 2, stats::sd, na.rm = TRUE)
  se_fit <- sqrt(diag(vcov(fit)))[c("a", "b", "cp")]
  expect_lt(max(abs(unname(se_boot) / unname(se_fit) - 1)), 0.25)
})

test_that("planted defect: classifying the row as linear fails the oracle checks", {
  testthat::local_mocked_bindings(.sem_tree_linear = function(e) TRUE)
  res <- tryCatch(
    {
      fit <- fit_sem(nl_syntax, nl_data())
      nl_gap(fit)$est < 1e-5
    },
    error = function(e) FALSE
  )
  expect_false(res)
})

test_that("planted defects: a stale Jacobian or no projection leaves the covariance off the tangent space", {
  d <- nl_data()
  fit <- fit_sem(nl_syntax, d)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  cons <- .sem_constraint_rows(fit@internals$constraints, ram)
  lb <- rep(-Inf, ram$q)
  ub <- rep(Inf, ram$q)
  th <- unname(coef(fit))
  good <- .sem_vcov(th, ram, smp, "observed", cons, lb, ub)
  expect_lt(nl_annihilation(good, coef(fit)), 1e-8)
  # the projection omitted: the plain inverse information
  expect_gt(nl_annihilation(.sem_vcov(th, ram, smp, "observed", NULL, lb, ub), coef(fit)), 1e-3)
  # the projection frozen at the starting Jacobian instead of the solution's
  stale <- sem_mutate(.sem_active_set, "nl$jac(theta, u)", "nl$jac(rep(0.1, length(theta)), u)")
  testthat::local_mocked_bindings(.sem_active_set = stale)
  expect_gt(nl_annihilation(.sem_vcov(th, ram, smp, "observed", cons, lb, ub), coef(fit)), 1e-3)
})

test_that("the Jacobian is a central difference of the guarded value and equals the analytic one", {
  ram <- list(q = 3L, par_names = c("a", "b", "c"))
  cons <- .sem_constraint_rows(
    data.frame(lhs = c("c", "a * exp(b)"), op = c("==", "=="), rhs = c("a * b", "c"), stringsAsFactors = FALSE),
    ram
  )
  theta <- c(0.3, -0.7, 1.9)
  expect_equal(cons$nl$value(theta), c(1.9 - 0.3 * -0.7, 0.3 * exp(-0.7) - 1.9))
  j <- cons$nl$jac(theta, c(1, 1, 1))
  expect_equal(j[1, ], c(0.7, -0.3, 1), tolerance = 1e-8)
  expect_equal(j[2, ], c(exp(-0.7), 0.3 * exp(-0.7), -1), tolerance = 1e-8)
  # a point where the expression is not a finite real number is an error naming it
  bad <- .sem_constraint_rows(data.frame(lhs = "log(a)", op = "==", rhs = "b", stringsAsFactors = FALSE), ram)
  expect_error(bad$nl$value(c(-1, 0, 0)), "did not evaluate to one finite real number")
})

test_that("nonlinear inequalities and unknown labels still error by name", {
  ram <- list(q = 3L, par_names = c("a", "b", "c"))
  row <- function(lhs, op, rhs) {
    .sem_constraint_rows(data.frame(lhs = lhs, op = op, rhs = rhs, stringsAsFactors = FALSE), ram)
  }
  expect_error(row("a*b", ">", "0.1"), "nonlinear inequality constraints are not supported in this version")
  expect_error(row("a", "<", "b^2"), "nonlinear inequality constraints are not supported")
  expect_error(row("a*z", "==", "b"), "'z', which is not a free parameter")
  expect_error(row("2*3", "==", "6"), "constraint contains no parameters")
})

test_that("a nonlinear equality beside a linear one gives a consistent fit", {
  d <- nl_data()
  fit <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\ncp == a*b\nb == 2*a", d)
  th <- coef(fit)
  expect_lt(abs(th[["cp"]] - th[["a"]] * th[["b"]]), 1e-6)
  expect_lt(abs(th[["b"]] - 2 * th[["a"]]), 1e-6)
  expect_equal(fit@df, 2)
  expect_lt(nl_annihilation(vcov(fit), th), 1e-8)
})
