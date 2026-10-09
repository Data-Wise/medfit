# Native SEM fit driver: nloptr SLSQP, acceptance gate, retries, bounds (plan S5).
#
# Oracles: lavaan estimates to 1e-6; exact parameter transport across data
# scales (the gate decision and the Newton decrement must not change); planted
# defects rebuild one internal function and must turn a check red.

test_that("estimates equal lavaan to 1e-6 on all four structures", {
  skip_if_not_installed("lavaan")
  for (nm in names(sem_models())) {
    ref <- sem_lavaan_ref(nm, "expected", n = 200, seed = 7)
    fit <- .sem_optimize(ref$mod$ram, ref$smp, sem_start(ref$mod$ram))
    expect_true(fit$converged)
    expect_equal(fit$retries, 0L)
    expect_lt(max(abs(unname(fit$theta) - ref$theta)), 1e-6, label = nm)
  }
})

test_that("a Heywood case matches lavaan, warns, and names the negative variance", {
  skip_if_not_installed("lavaan")
  mod <- sem_model_heywood()
  d <- sem_sim(mod, 50, 10)
  smp <- .sem_sample(d, mod$ram)
  lav <- suppressWarnings(lavaan::sem(sem_lavaan_text("latent"), d, fixed.x = FALSE))
  pe <- lavaan::parameterEstimates(lav)
  neg <- pe[pe$op == "~~" & pe$lhs == pe$rhs & pe$est < 0, ]
  expect_gt(nrow(neg), 0)
  expect_warning(fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram)),
                 paste0("negative variance: .*", neg$lhs[1], " ~~ ", neg$lhs[1]))
  expect_lt(min(fit$theta[paste(neg$lhs[1], "~~", neg$lhs[1])]), 0)
  est <- stats::setNames(pe$est, ifelse(pe$op == "=~", paste(pe$rhs, "~", pe$lhs), paste(pe$lhs, pe$op, pe$rhs)))
  est <- est[names(est) %in% names(fit$theta)]
  expect_lt(max(abs(fit$theta[names(est)] - est)), 1e-6)
})

test_that("an active lower bound is accepted and reported", {
  mod <- sem_model_heywood()
  smp <- .sem_sample(sem_sim(mod, 50, 10), mod$ram)
  is_var <- vapply(strsplit(mod$ram$par_names, " ~~ ", fixed = TRUE),
                   function(p) length(p) == 2 && p[1] == p[2], logical(1))
  lb <- ifelse(is_var, 0, -Inf)
  expect_no_warning(fit <- .sem_optimize(mod$ram, smp, pmax(sem_start(mod$ram), lb), lb = lb))
  expect_gt(length(fit$active_bounds), 0)
  expect_true(all(fit$active_bounds %in% mod$ram$par_names[is_var]))
  expect_true(all(fit$theta[is_var] >= 0))
  expect_length(fit$improper, 0)
})

test_that("a start with an invalid covariance is retried, and a single start errors by name", {
  mod <- sem_model_latent()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  good <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  bad <- sem_start(mod$ram)
  bad["X ~~ X"] <- -0.5
  expect_error(.sem_optimize(mod$ram, smp, bad, n_starts = 1),
               "no start converged \\(1 tried\\).*not positive definite")
  expect_warning(fit <- .sem_optimize(mod$ram, smp, bad, n_starts = 5), "perturbed start")
  expect_gt(fit$retries, 0)
  expect_lt(max(abs(fit$theta - good$theta)), 1e-6)
})

test_that("non-convergence at a tiny evaluation budget errors with the status", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  expect_error(.sem_optimize(mod$ram, smp, sem_start(mod$ram), n_starts = 1, control = list(maxeval = 5L)),
               "no start converged.*status 5")
})

test_that("reruns are identical and the caller's random-number stream is untouched", {
  mod <- sem_model_latent()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  bad <- sem_start(mod$ram)
  bad["X ~~ X"] <- -0.5
  set.seed(99)
  ref_draw <- stats::runif(1)
  set.seed(99)
  f1 <- suppressWarnings(.sem_optimize(mod$ram, smp, bad))
  after <- stats::runif(1)
  f2 <- suppressWarnings(.sem_optimize(mod$ram, smp, bad))
  expect_identical(f1$theta, f2$theta)
  expect_identical(after, ref_draw)
})

test_that("the gate decision and the Newton decrement are invariant to the data scale", {
  mod <- sem_model_latent()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  n <- mod$ram$q
  # Converged, mildly off, and clearly stalled points; status 3 so only the stationarity rule decides.
  is_s <- grepl(" ~~ ", names(fit$theta), fixed = TRUE)
  off <- fit$theta
  off[is_s] <- off[is_s] * 1.001
  pts <- list(fit$theta, fit$theta + 0.0005 * seq_len(n), fit$theta * 1.02, off)
  old_gate <- function(theta, smp_s) {
    g <- .sem_grad(theta, mod$ram, smp_s)
    max(abs(g)) / max(1, max(abs(g))) <= 1e-3
  }
  for (th in pts) {
    base <- .sem_gate(th, 3L, mod$ram, smp, rep(-Inf, n), rep(Inf, n))
    for (s in c(0.01, 100, 1000)) {
      th_s <- sem_transport(th, s)
      smp_s <- sem_scale_sample(smp, s)
      expect_equal(.sem_fml(th_s, mod$ram, smp_s), .sem_fml(th, mod$ram, smp), tolerance = 1e-9)
      gt <- .sem_gate(th_s, 3L, mod$ram, smp_s, rep(-Inf, n), rep(Inf, n))
      expect_identical(gt$accepted, base$accepted, label = paste("decision at scale", s))
      expect_equal(gt$decrement, base$decrement, tolerance = 1e-6, label = paste("decrement at scale", s))
    }
  }
  # The spec's absolute scaling max(1, max|grad F|) depends on the units (the planted defect):
  # the 0.1% variance offset is rejected at scales 0.01 and 1 but accepted at 100 and 1000, while
  # the Newton decrement rejects it everywhere (the loop above asserts the decision is identical).
  stalled <- pts[[4]]
  old <- vapply(c(0.01, 1, 100, 1000), function(s) {
    old_gate(sem_transport(stalled, s), sem_scale_sample(smp, s))
  }, logical(1))
  expect_identical(old, c(FALSE, FALSE, TRUE, TRUE))
  expect_false(.sem_gate(stalled, 3L, mod$ram, smp, rep(-Inf, n), rep(Inf, n))$accepted)
})

test_that("planted defects are caught", {
  mod <- sem_model_latent()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  start <- sem_start(mod$ram)

  # (1) Remove the status test: a stubbed status-5 result is admitted.
  stub5 <- function(...) {
    r <- nloptr::nloptr(...)
    r$status <- 5L
    r
  }
  local({
    local_mocked_bindings(.sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts) {
      stub5(x0 = x0, eval_f = eval_f, eval_grad_f = eval_grad_f, lb = lb, ub = ub, opts = opts)
    })
    expect_error(.sem_optimize(mod$ram, smp, start, n_starts = 1), "status 5")
    no_status <- sem_mutate(.sem_gate, "!isTRUE(status %in% .sem_ok_status)", "FALSE")
    local_mocked_bindings(.sem_gate = no_status)
    expect_true(.sem_optimize(mod$ram, smp, start, n_starts = 1)$converged)
  })

  # (2) Remove the positive-definite start test: an invalid perturbed start reaches nloptr.
  bad <- start
  bad["X ~~ X"] <- -0.5
  seen <- function() {
    xs <- list()
    list(record = function(x0) xs[[length(xs) + 1L]] <<- x0, get = function() xs)
  }
  valid_ref <- .sem_start_valid
  run_recording <- function() {
    rec <- seen()
    local_mocked_bindings(.sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts) {
      rec$record(x0 * .sem_step_floor(mod$ram, smp))
      nloptr::nloptr(x0 = x0, eval_f = eval_f, eval_grad_f = eval_grad_f, lb = lb, ub = ub, opts = opts)
    }, .env = parent.frame())
    suppressWarnings(try(.sem_optimize(mod$ram, smp, bad, n_starts = 6), silent = TRUE))
    vapply(rec$get()[-1], function(x) valid_ref(x, mod$ram), logical(1))
  }
  expect_true(all(run_recording()))
  local({
    local_mocked_bindings(.sem_start_valid = sem_mutate(.sem_start_valid, "> .sem_pd_floor", "> -Inf"))
    expect_false(all(run_recording()))
  })

  # (3) Remove the clamp: a perturbed start below the lower bound reaches nloptr, which errors.
  # The bound sits on a path (not a variance), so such a start is still positive definite and
  # only the clamp keeps it inside the box.
  lb <- rep(-Inf, mod$ram$q)
  lb[mod$ram$par_names == "Y ~ eta"] <- 0
  in_box <- function() {
    rec <- seen()
    local_mocked_bindings(.sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts) {
      rec$record(x0 * .sem_step_floor(mod$ram, smp))
      nloptr::nloptr(x0 = x0, eval_f = eval_f, eval_grad_f = eval_grad_f, lb = lb, ub = ub, opts = opts)
    }, .env = parent.frame())
    # An invalid first start forces the retries whose perturbed starts the clamp must keep in the box.
    s0 <- bad
    s0["Y ~ eta"] <- 0.01
    suppressWarnings(try(.sem_optimize(mod$ram, smp, s0, lb = lb, n_starts = 6), silent = TRUE))
    vapply(rec$get(), function(x) all(x >= lb), logical(1))
  }
  expect_true(all(in_box()))
  local({
    local_mocked_bindings(.sem_clamp = sem_mutate(.sem_clamp, "pmin(pmax(x, lb), ub)", "x"))
    expect_false(all(in_box()))
  })
})

test_that("a Hessian with a negative diagonal beside huge entries is rejected, not an error", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 100, 2), mod$ram)
  q <- mod$ram$q
  h <- diag(c(1e12, rep(1, q - 2), -1e-6))
  local_mocked_bindings(.sem_hess_f = function(theta, ram, smp) h)
  gate <- expect_no_error(.sem_gate(mod$theta, 3L, mod$ram, smp, rep(-Inf, q), rep(Inf, q)))
  expect_false(gate$accepted)
  expect_match(gate$reason, "not positive definite")
})

test_that("standard errors match OpenMx within the frozen tolerance at n = 200", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  for (nm in names(sem_models())) {
    mod <- sem_models()[[nm]]
    for (seed in 1:3) {
      smp <- .sem_sample(sem_sim(mod, 200, 10 * seed), mod$ram)
      fit <- .sem_optimize(mod$ram, smp, .sem_default_start(mod$ram, smp))
      om <- sem_openmx(mod, smp)
      sm <- summary(om)$parameters
      lbl <- as.integer(sub("^p", "", sm$name))
      est_o <- stats::setNames(sm$Estimate, mod$ram$par_names[lbl])[names(fit$theta)]
      se_o <- stats::setNames(sm[["Std.Error"]], mod$ram$par_names[lbl])[names(fit$theta)]
      expect_lt(max(abs(est_o - fit$theta)), 1e-4, label = paste("estimates", nm, seed))
      se_n <- sqrt(diag(.sem_vcov(fit$theta, mod$ram, smp, "observed")))
      expect_lt(max(abs(se_n / se_o - 1)), 1e-3, label = paste("observed SEs", nm, seed))
    }
  }
})

test_that("the default start is a valid point and rescales with the data", {
  for (nm in names(sem_models())) {
    mod <- sem_models()[[nm]]
    smp <- .sem_sample(sem_sim(mod, 200, 3), mod$ram)
    st <- .sem_default_start(mod$ram, smp)
    expect_true(.sem_start_valid(st, mod$ram), label = paste("valid start", nm))
    for (s in c(0.01, 100, 1000)) {
      st_s <- .sem_default_start(mod$ram, sem_scale_sample(smp, s))
      expect_equal(st_s, sem_transport(st, s), tolerance = 1e-10, label = paste(nm, "at scale", s))
    }
  }
})
