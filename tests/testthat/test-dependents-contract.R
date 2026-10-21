# Contract observed in sibling R/ sources and tests/ on 2026-10-20.
# Keep the evidence beside each group so additions can be audited.
.dependent_classes <- list(
  MediationData = c(
    # probmed R/compute-core.R:42-62, R/compute-bootstrap.R:15-37,
    # R/compute-mbco.R:215-240; RMediation R/ci_medfit.R:20-21,153.
    "a_path", "b_path", "c_prime", "estimates", "vcov", "sigma_m",
    "sigma_y", "family_m", "family_y", "treatment", "mediator",
    "outcome", "mediator_predictors", "outcome_predictors", "data",
    # missingmed R/pool.R:112-138,177-192; R/run.R:236; R/infer.R:247-279.
    "n_obs", "converged", "source_package"
  ),
  SerialMediationData = c(
    # RMediation R/ci_medfit.R:20-21,168-170,220.
    "a_path", "d_path", "b_path", "estimates", "vcov"
  ),
  ParallelMediationData = c(
    # probmed R/compute-parallel.R:32-33,74-78,109,136-153,182-197.
    # probmed R/compute-parallel-mbco.R:18-33.
    "a_paths", "b_paths", "sigma_mediators", "sigma_y", "mediators",
    "estimates", "vcov", "data", "treatment", "outcome",
    "mediator_predictors", "outcome_predictors"
  ),
  InteractionMediationData = c(
    # missingmed R/pool.R:112-119,221-243,253-259,297,309;
    # missingmed R/methods-output.R:45-56, R/infer.R:247-279.
    "a_path", "b_path", "c_prime", "estimates", "vcov", "data",
    "sigma_m", "sigma_y", "converged", "interaction", "cde",
    "int_ref", "int_med", "pie", "nde", "nie", "total_effect",
    "m_star", "treatment", "n_obs", "source_package"
  ),
  SEMFit = c(
    # RMediation R/mbco_semfit.R:4-8,36.
    "df"
  )
)

.dependent_exports <- c(
  # probmed R/methods-pmed.R:149; tests/testthat/helper-parallel.R:61,83;
  # RMediation tests/testthat/test-serial-medfit-integration.R:32,77;
  # missingmed R/run.R:205; mediationverse R/mediationverse-package.R:65.
  "extract_mediation",
  # missingmed R/run.R:36,281; RMediation tests/testthat/test-mbco-semfit.R:154.
  "fit_mediation",
  # missingmed R/methods-output.R:43-56.
  "nie",
  # RMediation tests/testthat/test-mbco-semfit.R:77-102,151-152.
  "fit_sem"
)

# Version guards: RMediation R/mbco_semfit.R:22 (>= 0.8.0),
# tests/testthat/test-serial-medfit-integration.R:14 (>= 0.2.0);
# missingmed tests/testthat/test-edge-pipeline.R:165 (>= 0.4.0),
# tests/testthat/test-refcard-matrix.R:80 (>= 0.4.0);
# mediationverse R/zzz.R:22 reports the installed medfit version.

.expect_dependent_properties <- function(class, required) {
  missing <- setdiff(required, names(class@properties))
  testthat::expect_true(length(missing) == 0L,
                        info = paste(missing, collapse = ", "))
}

testthat::test_that("dependent S7 class properties remain available", {
  exports <- getNamespaceExports("medfit")
  for (name in names(.dependent_classes)) {
    testthat::expect_true(name %in% exports, info = name)
    if (name %in% exports) {
      class <- getExportedValue("medfit", name)
      .expect_dependent_properties(class, .dependent_classes[[name]])
    }
  }
})

testthat::test_that("dependent function imports remain exported", {
  testthat::expect_true(
    all(.dependent_exports %in% getNamespaceExports("medfit")),
    info = paste(setdiff(.dependent_exports, getNamespaceExports("medfit")),
                 collapse = ", ")
  )
})

testthat::test_that("missingmed copy-modify preserves S7 validation", {
  fit <- create_test_mediation_data(generate_mediation_data(n = 40L))
  pooled <- fit
  estimates <- fit@estimates
  estimates[[1L]] <- estimates[[1L]] + 0.01
  covariance <- fit@vcov * 1.1
  S7::props(pooled) <- list(estimates = estimates, vcov = covariance)
  testthat::expect_equal(pooled@estimates, estimates)
  testthat::expect_equal(pooled@vcov, covariance)
  testthat::expect_no_error(S7::validate(pooled))
})

testthat::test_that("property rename planted defect fails the contract", {
  renamed <- S7::new_class(
    "ContractRenamedMediationData",
    properties = list(a_renamed = S7::class_numeric)
  )
  testthat::expect_failure(
    .expect_dependent_properties(renamed, "a_path")
  )
})
