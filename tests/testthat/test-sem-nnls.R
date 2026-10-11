# Non-negative least squares for the multiplier-sign check (0.8.0 plan T7).
#
# The Lawson-Hanson loop with an absolute tolerance divides 0 by 0 on rank-deficient problems once the data
# scale makes roundoff exceed the tolerance (planning/specs/evidence/native-sem-2026-10-11/02-nnls-dependent-columns.R).
# These tests rebuild the seeded `dup` and `mult` families of that fixture, check .sem_nnls() against a bounded
# least squares reference on the column-normalized problem, plant the defect (no column scaling), and give
# .sem_sign_check() the dependent active sets it used to skip.

# The Lawson-Hanson loop of the evidence script, reformatted and otherwise unchanged: absolute tolerance, no step guard.
nnls_old <- function(A, b, tol = 1e-12, maxit = 500) {
  n <- ncol(A)
  x <- numeric(n)
  P <- rep(FALSE, n)
  w <- as.vector(crossprod(A, b - A %*% x))
  it <- 0
  ls_on <- function(P) {
    s <- numeric(n)
    if (any(P)) {
      cf <- lm.fit(A[, P, drop = FALSE], b)$coefficients
      cf[is.na(cf)] <- 0
      s[P] <- cf
    }
    s
  }
  while (any(!P) && max(w[!P]) > tol && it < maxit) {
    it <- it + 1
    j <- which(!P)[which.max(w[!P])]
    P[j] <- TRUE
    repeat {
      s <- ls_on(P)
      if (all(s[P] > 0)) {
        x <- s
        break
      }
      neg <- P & s <= 0
      alpha <- min(x[neg] / (x[neg] - s[neg]))
      x <- x + alpha * (s - x)
      P <- P & x > tol
      x[!P] <- 0
    }
    w <- as.vector(crossprod(A, b - A %*% x))
  }
  x
}

nnls_gen <- list(
  dup = function(sc) {
    A <- matrix(stats::rnorm(6 * 3), 6)
    list(A = cbind(A, A[, 1], A[, 2] + A[, 3]) * sc, b = stats::rnorm(6) * sc)
  },
  mult = function(sc) {
    q <- 4
    J <- matrix(stats::rnorm(2 * q), 2)
    Jc <- matrix(stats::rnorm(2 * q), 2)
    Je <- rbind(J, J[1, ] + J[2, ])
    list(A = t(rbind(Jc, Je, -Je)) * sc, b = stats::rnorm(q) * sc)
  }
)

# squared residual on the column-normalized problem, and the reference from bounded least squares
nnls_normalized <- function(A, b) {
  list(a = sweep(A, 2, sqrt(colSums(A^2)), "/"), b = b / sqrt(sum(b^2)))
}
nnls_residual <- function(x, A, b) {
  nb <- nnls_normalized(A, b)
  sum((nb$a %*% (x * sqrt(colSums(A^2)) / sqrt(sum(b^2))) - nb$b)^2)
}
nnls_reference <- function(A, b) {
  nb <- nnls_normalized(A, b)
  stats::optim(rep(0.1, ncol(A)), function(p) sum((nb$a %*% p - nb$b)^2),
               function(p) as.vector(2 * crossprod(nb$a, nb$a %*% p - nb$b)),
               method = "L-BFGS-B", lower = 0, control = list(factr = 10, pgtol = 0))$value
}

# Count the cases a solver gets wrong: an error, a non-finite or negative result, or a squared residual more than
# 1e-8 from the reference. `fn` is the solver under test.
nnls_failures <- function(fn, families = c("dup", "mult"), scales = c(1, 1e2, 1e4, 1e6), seeds = 1:60) {
  out <- list()
  for (fam in families) for (sc in scales) {
    bad <- 0L
    for (sd in seeds) {
      set.seed(sd)
      d <- nnls_gen[[fam]](sc)
      x <- tryCatch(fn(d$A, d$b), error = function(e) NULL)
      ok <- !is.null(x) && all(is.finite(x)) && all(x >= 0) && !isFALSE(attr(x, "converged")) &&
        abs(nnls_residual(x, d$A, d$b) - nnls_reference(d$A, d$b)) < 1e-8
      bad <- bad + !ok
    }
    out[[paste(fam, sc)]] <- bad
  }
  unlist(out)
}

test_that("the stored T1 fixture: finite, non-negative, and the reference residual", {
  path <- test_path("..", "..", "planning", "specs", "evidence", "native-sem-2026-10-11", "results",
                    "02-nnls-fixture.csv")
  skip_if_not(file.exists(path), "evidence fixture is not shipped with the installed package")
  fx <- utils::read.csv(path)
  A <- as.matrix(fx[, paste0("A", 1:5)])
  x <- .sem_nnls(A, fx$b)
  expect_true(all(is.finite(x)))
  expect_true(all(x >= 0))
  expect_true(attr(x, "converged"))
  expect_lt(abs(nnls_residual(x, A, fx$b) - fx$ref_residual_normalized[1L]), 1e-8)
  # the old loop gives a non-finite result on this very case
  expect_true(inherits(try(nnls_old(A, fx$b), silent = TRUE), "try-error") || any(!is.finite(nnls_old(A, fx$b))))
})

test_that("the dup and mult families at scales 1 to 1e6 never fail, where the old loop fails often", {
  old <- nnls_failures(function(A, b) nnls_old(A, b), seeds = 1:100)
  expect_equal(unname(old[grep(" 1$", names(old))]), c(0, 0))
  expect_true(all(old[!grepl(" 1$", names(old))] > 0))
  new <- nnls_failures(.sem_nnls)
  expect_equal(unname(new), rep(0, 8L), info = paste(names(new), new, collapse = "; "))
})

test_that("the full 500-seed families pass at every scale", {
  skip_on_cran()
  new <- nnls_failures(.sem_nnls, seeds = 1:500)
  expect_equal(unname(new), rep(0, 8L), info = paste(names(new), new, collapse = "; "))
})

test_that("planted defect: without column scaling the dependent-column problems fail", {
  src <- paste(deparse(.sem_nnls), collapse = "\n")
  # Each substitution must change the source: a pattern that silently stops matching would leave the
  # scaling in place and make the test vacuous. Patterns tolerate a line break after a comma: covr
  # instruments the function, which changes how deparse() wraps long lines.
  swap <- function(x, from, to) {
    y <- sub(from, to, x)
    expect_false(identical(x, y), info = from)
    y
  }
  sweep_pat <- "a_s <- sweep\\(A\\[, use, drop = FALSE\\], 2, cn\\[use\\],\\s*\"/\"\\)"
  mut <- swap(src, sweep_pat, "a_s <- A[, use, drop = FALSE]")
  mut <- swap(mut, "b_s <- b/bn", "b_s <- b")
  mut <- swap(mut, "out\\[use\\] <- x \\* bn/cn\\[use\\]", "out[use] <- x")
  unscaled <- eval(parse(text = mut), environment(.sem_nnls))
  bad <- nnls_failures(unscaled, scales = c(1e4, 1e6), seeds = 1:60)
  expect_gt(sum(bad), 0)
})

test_that(".sem_nnls solves ordinary problems and never errors", {
  A <- cbind(c(1, 0, 0), c(0, 1, 0), c(0, 0, 1))
  x <- .sem_nnls(A, c(2, -1, 3))
  expect_equal(as.vector(x), c(2, 0, 3))
  expect_true(attr(x, "converged"))
  # a known mixed answer: the unconstrained solution (1, -1) is cut to the boundary
  A2 <- cbind(c(1, 1), c(1, 0))
  expect_equal(as.vector(.sem_nnls(A2, c(0.5, 1))), c(0.75, 0))
  # zero right-hand side, zero columns, non-finite input
  expect_equal(as.vector(.sem_nnls(A, c(0, 0, 0))), c(0, 0, 0))
  expect_equal(as.vector(.sem_nnls(cbind(A, 0), c(1, 1, 1))), c(1, 1, 1, 0))
  bad <- .sem_nnls(A, c(1, NA, 1))
  expect_identical(as.vector(bad), c(0, 0, 0))
  expect_false(attr(bad, "converged"))
  expect_no_error(.sem_nnls(matrix(numeric(), 3, 0), c(1, 2, 3)))
})

# ---- the sign check on constructed active rows ----

sign_check_on <- function(rows, gx, eq = rep(FALSE, nrow(rows)), hx = diag(ncol(rows))) {
  nm <- paste0("c", seq_len(nrow(rows)))
  ram <- list(par_names = paste0("p", seq_len(ncol(rows))))
  out <- list(sign_check = "ok", sign_warnings = character(), multipliers = NULL)
  .sem_sign_check(out, rows, rep(TRUE, nrow(rows)), eq, nm, rep(FALSE, ncol(rows)), rep(FALSE, ncol(rows)), ram, hx, gx)
}

test_that("a dependent active set gets a computed verdict, not a skip", {
  # a == b entered as an equality plus the active a - b < 0: the equality's free multiplier absorbs any gradient
  r <- rbind(c(1, -1), c(1, -1)) / sqrt(2)
  for (g in list(c(-1, 1), c(1, -1))) {
    res <- sign_check_on(r, g * 0.4, eq = c(TRUE, FALSE))
    expect_identical(res$sign_check, "ok")
    expect_length(res$sign_warnings, 0L)
    expect_false(is.null(res$multipliers))
  }
  # parallel inequalities a + b < 0.2 and 2a + 2b < 0.4: gradient pushing toward infeasibility is fine,
  # away from the boundary is the wrong sign
  p <- rbind(c(1, 1), c(2, 2))
  good <- sign_check_on(p, c(-1, -1) * 0.5)
  expect_identical(good$sign_check, "ok")
  expect_length(good$sign_warnings, 0L)
  wrong <- sign_check_on(p, c(1, 1) * 0.5)
  expect_identical(wrong$sign_check, "ok")
  expect_length(wrong$sign_warnings, 2L)
  expect_match(wrong$sign_warnings[1L], "constraint c1 is active, but moving into the feasible region would lower")
  # a + b == 0.2 with an active a + b > 0.2 (row -1, -1): the equality can carry either sign
  e <- rbind(c(1, 1), c(-1, -1))
  expect_length(sign_check_on(e, c(1, 1), eq = c(TRUE, FALSE))$sign_warnings, 0L)
  expect_length(sign_check_on(e, c(-1, -1), eq = c(TRUE, FALSE))$sign_warnings, 0L)
  # three dependent inequalities that cannot reproduce the gradient: a wrong-sign verdict, never a skip
  t3 <- rbind(c(1, 0), c(0, 1), c(1, 1))
  bad <- sign_check_on(t3, c(1, -1))
  expect_identical(bad$sign_check, "ok")
  expect_gt(length(bad$sign_warnings), 0L)
  expect_length(sign_check_on(t3, c(-1, -2))$sign_warnings, 0L)
})

test_that("independent rows keep the least-squares verdict and the wrong-sign multiplier in the table", {
  res <- sign_check_on(rbind(c(1, 1)), c(0.5, 0.5))
  expect_length(res$sign_warnings, 1L)
  expect_lt(res$multipliers$scaled, .sem_sign_tol)
  ok <- sign_check_on(rbind(c(1, 1)), c(-0.5, -0.5))
  expect_length(ok$sign_warnings, 0L)
  expect_gt(ok$multipliers$lambda, 0)
  # a correct row with a tiny wrong-sign multiplier stays below the tolerance
  expect_length(sign_check_on(rbind(c(1, 0)), c(1e-5, 0))$sign_warnings, 0L)
})

test_that("scaling the gradient and rows by data units does not change the dependent verdict", {
  for (sc in c(1e-3, 1, 1e4)) {
    p <- rbind(c(1, 1), c(2, 2))
    expect_length(sign_check_on(p, c(-1, -1) * 0.5 * sc, hx = diag(2) * sc)$sign_warnings, 0L)
    expect_length(sign_check_on(p, c(1, 1) * 0.5 * sc, hx = diag(2) * sc)$sign_warnings, 2L)
  }
})

test_that("a short row beside a long one is still judged, and a zero row is ignored", {
  # one row of length 1e9 and a lower-bound row e_2 with a wrong-sign multiplier
  rows <- rbind(c(1e9, 0), c(0, -1))
  res <- sign_check_on(rows, c(-1e-3, -0.5))
  expect_length(res$sign_warnings, 1L)
  expect_match(res$sign_warnings, "constraint c2 is active")
  # a zero-norm active row neither warns nor names itself
  z <- sign_check_on(rbind(c(1, 1), c(0, 0)), c(1, 1))
  expect_length(z$sign_warnings, 1L)
  expect_match(z$sign_warnings, "constraint c1 is active")
  expect_false(anyNA(z$multipliers$lambda))
})

test_that("a solver that does not converge skips the check and says so", {
  testthat::local_mocked_bindings(.sem_nnls = function(A, b, ...) structure(numeric(ncol(A)), converged = FALSE))
  res <- sign_check_on(rbind(c(1, 1)), c(0.5, 0.5))
  expect_identical(res$sign_check, "skipped: the multipliers could not be computed")
  expect_length(res$sign_warnings, 0L)
  expect_null(res$multipliers)
})

test_that("near-dependent columns converge: the pivot tolerance matches the weight threshold", {
  set.seed(11)
  for (eps in c(1e-6, 1e-8, 1e-9, 1e-12)) {
    base <- matrix(stats::rnorm(18), 6)
    A <- cbind(base, base[, 1] + eps * stats::rnorm(6))
    b <- stats::rnorm(6)
    x <- .sem_nnls(A, b)
    expect_true(attr(x, "converged"), info = eps)
    expect_true(all(is.finite(x) & x >= 0), info = eps)
    expect_lt(nnls_residual(x, A, b) - nnls_reference(A, b), 1e-8)
  }
})
