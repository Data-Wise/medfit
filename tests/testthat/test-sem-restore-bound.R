# Native SEM engine: the cap on a status -4 restoration (`.sem_restore_allowance()`, `.sem_restore_k`).
# A restoration used to be accepted whenever the gate accepted the restored point, whatever the rise of the
# discrepancy (slack Inf). The cap is k times |g' delta| + 0.5 |delta' H_L delta|, delta = -M^+ c, the first-order
# cost of restoring feasibility. Oracle: the same quantity from the normal equations (delta = -M'(MM')^-1 c), a second
# route to the step that does not use the SVD. Planted defects: a restoration into a worse point (rise far above the
# cap) with the gate accepting it, a rescaled row, a duplicated row, rows of rank zero, and the boundary on either side.

rb_data <- function(n = 100, seed = 17) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
  data.frame(X = x, M = m, Y = 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7))
}
rb_base <- "M ~ a*X\nY ~ b*M + cp*X\n"

rb_setup <- function(constraint) {
  fit <- fit_sem(paste0(rb_base, constraint), rb_data())
  ram <- fit@internals$ram
  list(
    fit = fit, ram = ram, smp = .sem_sample(fit@data, ram),
    cons = .sem_constraint_rows(fit@internals$constraints, ram),
    lb = rep(-Inf, ram$q), ub = rep(Inf, ram$q), star = unname(fit@theta),
    ic = match("cp", gsub(" ", "", ram$par_names, fixed = TRUE))
  )
}
# the optimum with cp moved `d` natural units off the row
rb_stall <- function(s, d) {
  u <- .sem_active_set(s$star, s$ram, s$smp, s$lb, s$ub, s$cons)$u
  st <- s$star
  st[s$ic] <- st[s$ic] + d * u[s$ic]
  st
}
rb_allow <- function(s, theta) .sem_restore_allowance(theta, s$ram, s$smp, s$lb, s$ub, s$cons)
# the allowance through the normal equations, for rows of full rank
rb_hand <- function(s, theta) {
  act <- .sem_active_set(theta, s$ram, s$smp, s$lb, s$ub, s$cons)
  r <- .sem_eval(theta, s$ram, s$smp, deriv = TRUE)
  free <- act$free
  m <- act$ax[act$active_row, free, drop = FALSE]
  cval <- act$cval[act$active_row]
  gx <- r$g * act$u
  hx <- .sem_hess_f(theta, s$ram, s$smp) * outer(act$u, act$u)
  delta <- -drop(crossprod(m, solve(tcrossprod(m), cval)))
  hl <- .sem_lagrangian_hessian(hx, gx, act, s$cons, theta)[free, free, drop = FALSE]
  abs(sum(gx[free] * delta)) + 0.5 * abs(drop(crossprod(delta, hl %*% delta)))
}
rb_restore <- function(s, stall, restore = TRUE) {
  res <- list(solution = stall, status = -4L, objective = .sem_eval(stall, s$ram, s$smp, deriv = FALSE)$f)
  gate <- .sem_gate(stall, -4L, s$ram, s$smp, s$lb, s$ub, s$cons)
  list(res = res, gate = gate,
       out = .sem_polish_accept(res, gate, s$ram, s$smp, s$lb, s$ub, s$cons, restore = restore))
}

test_that("the allowance equals the normal-equations value, on one row and on two independent rows", {
  for (con in c("cp == a*b", "cp == a*b\na == 0.5")) {
    s <- rb_setup(con)
    for (d in c(0.01, 0.05, 0.3)) {
      st <- rb_stall(s, d)
      expect_equal(rb_allow(s, st), rb_hand(s, st), tolerance = 1e-8)
    }
  }
})

test_that("the allowance does not depend on the scale of a row or on a duplicated row", {
  one <- rb_setup("cp == a*b")
  scaled <- rb_setup("1000*cp == 1000*a*b")
  two <- rb_setup("cp == a*b\na == 0.5")
  dup <- rb_setup("cp == a*b\na == 0.5\na == 0.5")
  # the fits differ by the optimizer's tolerance, so the stalls are the same offsets from each optimum
  expect_equal(rb_allow(scaled, rb_stall(scaled, 0.05)), rb_allow(one, rb_stall(one, 0.05)), tolerance = 1e-6)
  expect_equal(rb_allow(dup, rb_stall(dup, 0.05)), rb_allow(two, rb_stall(two, 0.05)), tolerance = 1e-6)
  # a plain inverse of the Gram matrix breaks on the duplicate; the pseudo-inverse does not
  act <- .sem_active_set(rb_stall(dup, 0.05), dup$ram, dup$smp, dup$lb, dup$ub, dup$cons)
  expect_gt(sum(act$active_row), nrow(act$ax[act$active_row, act$free, drop = FALSE]) - 1L)
})

test_that("rows of rank zero, or no active row, give NA and the restoration is refused", {
  # a*b == 0 at a = b = 0: the row's gradient vanishes
  zero <- rb_setup("a*b == 0")
  th <- zero$star
  nm <- gsub(" ", "", zero$ram$par_names, fixed = TRUE)
  th[match(c("a", "b"), nm)] <- 0
  expect_true(is.na(rb_allow(zero, th)))
  # an inactive inequality: nothing to restore onto
  inactive <- rb_setup("a*b < 100")
  expect_true(is.na(rb_allow(inactive, inactive$star)))
  # through the acceptance step: a polished point that the gate accepts is still refused when the allowance is NA
  s <- rb_setup("cp == a*b")
  stall <- rb_stall(s, 0.05)
  r <- rb_restore(s, stall)
  testthat::local_mocked_bindings(.sem_restore_allowance = function(...) NA_real_)
  refused <- .sem_polish_accept(r$res, r$gate, s$ram, s$smp, s$lb, s$ub, s$cons, restore = TRUE)
  expect_identical(refused$res$solution, stall)
  expect_identical(refused$gate, r$gate)
})

test_that("a restoration is accepted at its cost times k and refused when k is smaller than its ratio", {
  s <- rb_setup("cp == a*b")
  stall <- rb_stall(s, 0.05)
  base <- rb_restore(s, stall)
  allow <- rb_allow(s, stall)
  restored <- .sem_polish(stall, s$ram, s$smp, s$lb, s$ub, s$cons, reach = .sem_restore_reach)
  rise <- .sem_eval(restored, s$ram, s$smp, deriv = FALSE)$f - base$res$objective
  rho <- rise / allow
  expect_gt(rho, 0.5)
  expect_lt(rho, 1.01) # the structural ratio: the rise is the model value, up to cubic terms
  expect_true(base$out$gate$accepted)
  # the boundary on either side: k = rho / 0.9 keeps it, k = rho / 1.1 refuses it
  testthat::local_mocked_bindings(.sem_restore_k = rho / 0.9)
  expect_true(rb_restore(s, stall)$out$gate$accepted)
  testthat::local_mocked_bindings(.sem_restore_k = rho / 1.1)
  tight <- rb_restore(s, stall)
  expect_false(tight$out$gate$accepted)
  expect_identical(tight$out$res$solution, stall)
})

test_that("the curvature term decides a case: the allowance exceeds |g' delta| alone", {
  s <- rb_setup("cp == a*b")
  stall <- rb_stall(s, 0.3)
  act <- .sem_active_set(stall, s$ram, s$smp, s$lb, s$ub, s$cons)
  m <- act$ax[act$active_row, act$free, drop = FALSE]
  delta <- -drop(crossprod(m, solve(tcrossprod(m), act$cval[act$active_row])))
  g1 <- abs(sum((.sem_eval(stall, s$ram, s$smp, deriv = TRUE)$g * act$u)[act$free] * delta))
  expect_gt(rb_allow(s, stall), 1.1 * g1)
})

test_that("a restoration into a worse point is refused although the gate accepts it (planted defect)", {
  s <- rb_setup("cp == a*b")
  stall <- rb_stall(s, 0.05)
  base <- rb_restore(s, stall)
  allow <- rb_allow(s, stall)
  # a replacement far worse than the cap allows: the path b moved until the rise is 100 times the cap
  u <- .sem_active_set(stall, s$ram, s$smp, s$lb, s$ub, s$cons)$u
  ib <- match("b", gsub(" ", "", s$ram$par_names, fixed = TRUE))
  bad <- stall
  rise <- 0
  step <- 0.5
  while (rise <= 100 * .sem_restore_k * allow && step < 1e3) {
    bad[ib] <- stall[ib] + step * u[ib]
    rise <- .sem_eval(bad, s$ram, s$smp, deriv = FALSE)$f - base$res$objective
    step <- step * 2
  }
  expect_gt(rise, 100 * .sem_restore_k * allow) # far above the cap, so only the cap can refuse it
  testthat::local_mocked_bindings(
    .sem_polish = function(...) bad,
    .sem_gate = function(...) list(accepted = TRUE)
  )
  refused <- .sem_polish_accept(base$res, base$gate, s$ram, s$smp, s$lb, s$ub, s$cons, restore = TRUE)
  expect_identical(refused$res$solution, stall)
  # the ordinary polish path keeps its own slack: the same replacement is refused there too, by the 1e-8 rule
  ordinary <- .sem_polish_accept(base$res, base$gate, s$ram, s$smp, s$lb, s$ub, s$cons, restore = FALSE)
  expect_identical(ordinary$res$solution, stall)
})
