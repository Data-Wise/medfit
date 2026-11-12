# FI-G0c/G0d parity: the existing X -> M -> Y kernel must reproduce the golden snapshot captured before any
# generalization (helper-fiml-golden.R). Prepared quantities and kernel numerics are compared at 1e-12 (bit-for-bit on
# the capturing machine); fitted results at the frozen 1e-6 (SLSQP differs across platforms near 1e-9).
gold <- readRDS(gk_golden_path())

test_that("the golden snapshot covers every kind, both policies, and the expected failure cells", {
  expect_setequal(names(gold), c(paste(gk_kinds, "free"), paste(gk_kinds, "zero")))
  failed <- names(gold)[vapply(gold, function(g) g$fit$error, logical(1))]
  expect_setequal(failed, c("minimal free", "ytwo free", "ytwo zero"))
})

for (direct in c(TRUE, FALSE)) {
  for (kind in gk_kinds) {
    cell <- paste(kind, if (direct) "free" else "zero")
    test_that(paste("FIML kernel matches the pre-change golden snapshot:", cell), {
      old <- gold[[cell]]
      now <- gk_snapshot(kind, direct)
      expect_identical(now$prepare$par_names, old$prepare$par_names)
      expect_identical(now$prepare$q, old$prepare$q)
      expect_identical(now$prepare$rows, old$prepare$rows)
      expect_identical(now$prepare$direct, old$prepare$direct)
      expect_identical(now$prepare$n, old$prepare$n)
      expect_identical(names(now$prepare$groups), names(old$prepare$groups))
      for (field in c("standardized", "center", "scale", "units", "transport", "offset", "jacobian", "groups")) {
        expect_equal(now$prepare[[field]], old$prepare[[field]], tolerance = 1e-12, info = field)
      }
      expect_identical(dimnames(now$prepare$transport), dimnames(old$prepare$transport))
      expect_identical(names(now$prepare$units), names(old$prepare$units))
      expect_identical(names(now$prepare$offset), names(old$prepare$offset))
      # Kernel numerics (Hessian-type blocks, finite differences) agree to about 1e-9 across platforms and BLAS builds,
      # not bit for bit (CI macOS and Linux runners differ from the capturing machine). Scaled absolute 1e-7: entries
      # that are pure roundoff near zero cannot fail a relative test.
      for (field in names(old$numerics)) {
        x <- now$numerics[[field]]
        y <- old$numerics[[field]]
        expect_identical(dim(x), dim(y), info = field)
        expect_lt(max(abs(x - y), 0, na.rm = TRUE), 1e-7 * max(1, abs(y), na.rm = TRUE), label = field)
      }
      a <- now$fit
      b <- old$fit
      expect_identical(a$error, b$error)
      expect_identical(a$n_calls, b$n_calls)
      if (b$error) {
        expect_identical(a$class, b$class)
        expect_identical(a$message, b$message)
        expect_identical(a$stage, b$stage)
      } else {
        expect_identical(names(a$coef), names(b$coef))
        expect_identical(dimnames(a$vcov), dimnames(b$vcov))
        expect_equal(a$coef, b$coef, tolerance = 1e-6)
        expect_equal(a$vcov, b$vcov, tolerance = 1e-6)
        expect_equal(a$loglik, b$loglik, tolerance = 1e-7)
        expect_identical(a$nobs, b$nobs)
        expect_identical(a$n_dropped, b$n_dropped)
        expect_identical(a$ledger, b$ledger)
        key <- c("lhs", "op", "rhs", "label", "free")
        expect_identical(a$table[key], b$table[key])
        expect_equal(a$table$est, b$table$est, tolerance = 1e-6)
        expect_equal(a$table$se, b$table$se, tolerance = 1e-6)
        expect_identical(a$likelihood[c("method", "x_policy", "n_obs", "k", "rows", "selected", "variables")],
                         b$likelihood[c("method", "x_policy", "n_obs", "k", "rows", "selected", "variables")])
        expect_equal(a$likelihood$nll, b$likelihood$nll, tolerance = 1e-7)
        expect_equal(a$likelihood$jacobian, b$likelihood$jacobian, tolerance = 1e-12)
        expect_equal(a$effects[c("nie", "nde", "te")], b$effects[c("nie", "nde", "te")], tolerance = 1e-6)
        expect_equal(a$effects$paths, b$effects$paths, tolerance = 1e-6)
        expect_identical(names(a$effects$estimates), names(b$effects$estimates))
        expect_equal(a$effects$estimates, b$effects$estimates, tolerance = 1e-6)
        expect_equal(a$effects$vcov, b$effects$vcov, tolerance = 1e-6)
      }
      # Attempt ledgers: solver, start and acceptance are identical; statuses and likelihoods agree.
      ka <- c("solver", "start", "first_status", "status", "accepted", "reason")
      expect_identical(a$attempts[ka], b$attempts[ka])
      # A failed fit's ledger records where each start stalled, which differs across platforms; only successful fits
      # pin the attempt likelihoods and stationarity.
      if (!b$error) {
        expect_equal(a$attempts$nll, b$attempts$nll, tolerance = 1e-7)
        expect_lt(max(abs(a$attempts$stationarity - b$attempts$stationarity), 0, na.rm = TRUE), 1e-6)
      }
    })
  }
}
