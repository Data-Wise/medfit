# Numerical limits and fixtures were committed before candidate fits; see planning/fixtures.
fo_records <- new.env(parent = emptyenv())
fo_records$rows <- list()
for (fo_direct in c(TRUE, FALSE)) {
  for (fo_kind in c("mar", "patterns", "affine", "near", "unidentified")) {
    test_that(paste("FIML independent regression", fo_kind, if (fo_direct) "free" else "zero"), {
      skip_if_not_installed("lavaan")
      d <- fo_fixture(fo_kind, fo_direct)
      q0 <- fo_truth(fo_kind, fo_direct)
      p <- .sem_fiml_prepare(as.matrix(d), direct = fo_direct)
      actual_fixed <- .sem_fiml_eval(fo_internal(q0, p), p)$value + p$jacobian
      expect_lt(abs(actual_fixed - fo_nll(d, q0)), 1e-7)
      center <- colMeans(d, na.rm = TRUE)
      scale <- apply(d, 2, stats::sd, na.rm = TRUE)
      z <- as.data.frame(sweep(sweep(as.matrix(d), 2, center), 2, scale, `/`))
      q0s <- fo_affine(q0, 1 / scale, -center / scale)
      g0 <- fo_spectrum(fo_geometry(z, q0s))
      modelcov0 <- fo_spectrum(fo_moments(q0)$sigma)
      fit <- tryCatch(fit_sem(fo_model(fo_direct), d, missing = "fiml", fixed_x = FALSE), error = identity)
      cell <- paste(fo_kind, if (fo_direct) "free" else "zero", sep = "-")
      if (fo_kind == "unidentified") {
        expect_equal(sum(g0 > 1e-7), 7L)
        expect_s3_class(fit, "medfit_sem_fiml_error")
        expect_identical(fit$stage, "numerical")
        expect_identical(fit$reason, "observed-pattern moment Jacobian is rank deficient")
        expect_equal(nrow(fit$attempts), 6L)
        expect_true(all(is.finite(fit$attempts$status)))
        expect_length(fit$solver_calls, 9L)
        fo_records$rows[[cell]] <- data.frame(
          cell, outcome = fit$reason, coefficient = NA_real_, covariance = NA_real_, nll = NA_real_,
          fixed_nll = abs(actual_fixed - fo_nll(d, q0)),
          geometry_min = min(g0), geometry_max = max(g0), information_min = NA_real_, information_max = NA_real_,
          modelcov_min = min(modelcov0), modelcov_max = max(modelcov0), modelcov_at = "generating parameters"
        )
      } else {
        expect_false(inherits(fit, "error"), info = if (inherits(fit, "error")) conditionMessage(fit) else cell)
        if (inherits(fit, "error")) {
          fo_records$rows[[cell]] <- data.frame(
            cell, outcome = conditionMessage(fit), coefficient = NA_real_, covariance = NA_real_, nll = NA_real_,
            fixed_nll = abs(actual_fixed - fo_nll(d, q0)),
            geometry_min = min(g0), geometry_max = max(g0), information_min = NA_real_, information_max = NA_real_,
            modelcov_min = min(modelcov0), modelcov_max = max(modelcov0), modelcov_at = "generating parameters"
          )
        } else {
          ref_data <- if (fo_kind == "affine") fo_fixture("mar", fo_direct) else d
          ref <- lavaan::sem(fo_model(fo_direct), ref_data, missing = "ml", fixed.x = FALSE,
                             meanstructure = TRUE, information = "observed", control = list(rel.tol = 1e-10))
          q <- coef(fit)
          V <- vcov(fit)
          ref_q <- lavaan::coef(ref)
          ref_v <- lavaan::vcov(ref)
          expect_no_error(fo_assert_parameters(q, V, fo_direct))
          expect_no_error(fo_assert_parameters(ref_q, ref_v, fo_direct))
          # Stop before subsetting or transforming a malformed object.
          fo_assert_parameters(q, V, fo_direct)
          fo_assert_parameters(ref_q, ref_v, fo_direct)
          offset <- 0
          if (fo_kind == "affine") {
            transform <- function(x) fo_affine(x, 1 / c(3, .5, 2), -c(2, -3, 4) / c(3, .5, 2))
            J <- fo_jacobian(transform, q)
            V <- J %*% V %*% t(J)
            q <- transform(q)
            offset <- sum(colSums(!is.na(d)) * log(c(3, .5, 2)))
          }
          ref_q <- ref_q[names(q)]
          ref_v <- ref_v[names(q), names(q)]
          coefficient <- max(abs(q - ref_q))
          covariance <- max(abs(V - ref_v) / sqrt(outer(diag(ref_v), diag(ref_v))))
          nll <- abs(fo_nll(d, coef(fit)) + as.numeric(logLik(fit)))
          expect_lt(coefficient, 1e-5)
          expect_lt(covariance, 1e-3)
          expect_lt(nll, 1e-7)
          expect_lt(abs(-as.numeric(logLik(fit)) - offset - fo_nll(ref_data, q)), 1e-7)
          expect_equal(nobs(fit), 300L)
          expect_equal(fit@n_dropped, as.integer(fo_kind == "patterns"))
          counts <- table(apply(!is.na(d), 1, paste0, collapse = ""))
          if (fo_kind == "patterns") {
            expect_length(counts, 8L)
            expect_equal(sort(as.integer(counts)), c(1L, 42L, rep(43L, 6)))
            expect_identical(fit@internals$likelihood$rows$empty, 301L)
          }
          if (fo_kind %in% c("mar", "affine")) expect_false(anyNA(d$X))
          ref_center <- colMeans(ref_data, na.rm = TRUE)
          ref_scale <- apply(ref_data, 2, stats::sd, na.rm = TRUE)
          rz <- as.data.frame(sweep(sweep(as.matrix(ref_data), 2, ref_center), 2, ref_scale, `/`))
          rqs <- fo_affine(ref_q, 1 / ref_scale, -ref_center / ref_scale)
          G <- fo_spectrum(fo_geometry(rz, rqs))
          H <- fo_hessian(function(q) fo_nll(rz, q), rqs, .01)
          H2 <- fo_hessian(function(q) fo_nll(rz, q), rqs, .005)
          expect_lt(max(abs(H - H2) / sqrt(outer(diag(H), diag(H)))), 1e-3)
          information <- fo_spectrum(H)
          expect_gt(min(G), 1e-4)
          expect_gt(min(information), 1e-4)
          modelcov <- fo_spectrum(fo_moments(ref_q)$sigma)
          if (fo_kind == "near") expect_lt(min(modelcov), .01)
          fo_records$rows[[cell]] <- data.frame(
            cell, outcome = "fit", coefficient, covariance, nll,
            fixed_nll = abs(actual_fixed - fo_nll(d, q0)), geometry_min = min(G), geometry_max = max(G),
            information_min = min(information), information_max = max(information),
            modelcov_min = min(modelcov), modelcov_max = max(modelcov), modelcov_at = "reference optimum"
          )
        }
      }
    })
  }
}
if (nzchar(Sys.getenv("FIML_ORACLE_RESULTS"))) {
  fo_write_records(do.call(rbind, fo_records$rows), Sys.getenv("FIML_ORACLE_RESULTS"))
}
