# Opt-in bounded numerical oracle; run once through the verification budget runner.
devtools::load_all(quiet = TRUE)
source("tests/testthat/helper-fiml-bootstrap.R")
source("tests/testthat/helper-fiml-oracle.R")
fo_helpers <- mget(c("fo_assert_parameters", "fo_affine", "fo_nll"), inherits = FALSE)
stopifnot(requireNamespace("lavaan", quietly = TRUE))
workspace <- "_agents_workspace/fiml-bounded-inference"
records <- list()
artifacts <- list()
invocations <- c(native = 0L, lavaan = 0L)
quantile7 <- function(x, p) {
  y <- sort(x)
  h <- 1 + (length(y) - 1) * p
  j <- floor(h)
  y[j] + (h - j) * (y[pmin(j + 1L, length(y))] - y[j])
}
compare <- function(fit, ref, d, direct, cell, replicate) {
  row <- list(
    cell = cell, replicate = replicate, native = !inherits(fit, "error"),
    lavaan = !inherits(ref, "error")
  )
  if (!row$native || !row$lavaan) {
    row$pass <- FALSE
    return(row)
  }
  q <- coef(fit)
  V <- vcov(fit)
  r <- lavaan::coef(ref)
  W <- lavaan::vcov(ref)
  fo_helpers$fo_assert_parameters(q, V, direct)
  fo_helpers$fo_assert_parameters(r, W, direct)
  r <- r[names(q)]
  W <- W[names(q), names(q)]
  scales <- apply(d, 2, stats::sd, na.rm = TRUE)
  center <- colMeans(d, na.rm = TRUE)
  row$coefficient <- max(abs(fo_helpers$fo_affine(q, 1 / scales, -center / scales) -
                               fo_helpers$fo_affine(r, 1 / scales, -center / scales)))
  row$covariance <- max(abs(V - W) / sqrt(outer(diag(W), diag(W))))
  row$identity_nll <- abs(fo_helpers$fo_nll(d, q) + as.numeric(logLik(fit)))
  row$optimum_nll <- abs(as.numeric(logLik(fit)) - as.numeric(lavaan::logLik(ref)))
  row$reference_identity <- abs(fo_helpers$fo_nll(d, r) + as.numeric(lavaan::logLik(ref)))
  row$pass <- row$coefficient < 1e-5 && row$covariance < 1e-3 &&
    row$identity_nll < 1e-7 && row$optimum_nll <= 1e-5 && row$reference_identity < 1e-7
  row
}
for (direct in c(TRUE, FALSE)) {
  for (kind in c("complete", "mcar", "mar")) {
    cell <- paste(kind, if (direct) "free" else "zero", sep = "-")
    collected <- fb_fixture(kind, direct)
    d <- collected[rowSums(!is.na(collected)) > 0, , drop = FALSE]
    stopifnot(nrow(d) == 300L, nrow(collected) == if (kind == "mcar") 303L else 300L)
    model <- fb_model(direct)
    invocations["native"] <- invocations["native"] + 1L
    fit <- tryCatch(fit_sem(model, collected, missing = "fiml", fixed_x = FALSE), error = identity)
    invocations["lavaan"] <- invocations["lavaan"] + 1L
    ref <- tryCatch(suppressWarnings(lavaan::sem(model, d,
                      missing = "ml", fixed.x = FALSE,
                      meanstructure = TRUE, information = "observed", control = list(rel.tol = 1e-10)
                    )), error = identity)
    records[[paste(cell, 0)]] <- compare(fit, ref, d, direct, cell, 0L)
    set.seed(911L)
    indices <- lapply(seq_len(12L), function(i) sample.int(300L, 300L, replace = TRUE))
    captured <- list()
    refit_original <- medfit:::.bootstrap_fiml_refit
    out <- testthat::with_mocked_bindings(
      bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 12L, seed = 911L),
      .bootstrap_fiml_refit = function(source, rows) {
        invocations["native"] <<- invocations["native"] + 1L
        candidate <- tryCatch(refit_original(source, rows), error = identity)
        captured[[length(captured) + 1L]] <<- candidate
        if (inherits(candidate, "error")) stop(candidate)
        candidate
      }, .package = "medfit"
    )
    stopifnot(
      identical(lapply(out@inference$replicates, `[[`, "rows"), indices),
      identical(fit@data, d), length(captured) == 12L
    )
    references <- vector("list", 12L)
    for (i in seq_len(12L)) {
      resample <- d[indices[[i]], , drop = FALSE]
      stopifnot(
        anyDuplicated(indices[[i]]) > 0L,
        identical(is.na(resample), is.na(fit@data[indices[[i]], , drop = FALSE]))
      )
      invocations["lavaan"] <- invocations["lavaan"] + 1L
      references[[i]] <- tryCatch(suppressWarnings(lavaan::sem(model, resample,
                                    missing = "ml", fixed.x = FALSE,
                                    meanstructure = TRUE, information = "observed", control = list(rel.tol = 1e-10)
                                  )), error = identity)
      records[[paste(cell, i)]] <- compare(captured[[i]], references[[i]], resample, direct, cell, i)
      if (!inherits(captured[[i]], "error")) {
        stopifnot(identical(captured[[i]]@data, resample))
        hand <- unname(coef(captured[[i]])["a"] * coef(captured[[i]])["b"])
        stopifnot(abs(out@boot_estimates[i] - hand) < 1e-14)
      }
    }
    if (all(is.finite(out@boot_estimates))) {
      stopifnot(max(abs(confint(out)[1, ] - quantile7(out@boot_estimates, c(.025, .975)))) < 1e-14)
    }
    artifacts[[cell]] <- list(
      fit = fit, ref = ref, out = out, indices = indices,
      native = captured, reference = references, direct = direct, kind = kind
    )
    saveRDS(
      list(records = records, artifacts = artifacts, invocations = invocations),
      file.path(workspace, "qa-matrix.rds")
    )
    cat(
      cell, "completed; passing comparisons:", sum(vapply(records, `[[`, logical(1), "pass")),
      "/", length(records), "invocations", invocations, "\n"
    )
    flush.console()
  }
}
stopifnot(identical(unname(invocations), c(78L, 78L)))
if (!all(vapply(records, `[[`, logical(1), "pass"))) {
  stop("Bounded paired matrix has numerical failures; inspect saved evidence")
}
