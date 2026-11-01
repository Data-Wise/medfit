# Explicit, provenance-checked existing-model FIML intervals. Legacy callbacks stay in bootstrap.R.
.bootstrap_fiml_withheld <- function(x) {
  identical(x@inference$schema, "fiml-bootstrap-1") &&
    (!identical(x@inference$status, "complete") || any(!is.finite(x@boot_estimates)))
}

.bootstrap_fiml_interval <- function(x) {
  if (.bootstrap_fiml_withheld(x)) c(NA_real_, NA_real_) else c(x@ci_lower, x@ci_upper)
}

.bootstrap_fiml_factor <- function(V, parameters) {
  q <- length(parameters)
  if (!is.matrix(V) || !is.numeric(V) || !identical(dim(V), c(q, q)) ||
        anyDuplicated(parameters) || anyDuplicated(rownames(V)) || anyDuplicated(colnames(V)) ||
        !setequal(rownames(V), parameters) || !setequal(colnames(V), parameters)) {
    stop("FIML covariance names must match the canonical free parameters exactly", call. = FALSE)
  }
  V <- V[parameters, parameters, drop = FALSE]
  if (any(!is.finite(V)) || any(diag(V) <= 0)) {
    stop("FIML covariance must be finite with positive marginal variances", call. = FALSE)
  }
  scales <- sqrt(diag(V))
  C <- V / outer(scales, scales)
  tau_sym <- 100 * .Machine$double.eps * q * max(1, max(abs(C)))
  adjustment <- max(abs(C - t(C)))
  if (adjustment > tau_sym) stop("FIML covariance is not symmetric within tolerance", call. = FALSE)
  C <- (C + t(C)) / 2
  eig <- eigen(C, symmetric = TRUE)
  tau_eig <- 100 * .Machine$double.eps * q * max(1, max(abs(eig$values)))
  if (any(eig$values < -tau_eig)) {
    stop("FIML covariance is not positive semidefinite within tolerance", call. = FALSE)
  }
  root <- sweep(eig$vectors, 2, sqrt(pmax(eig$values, 0)), `*`) %*% t(eig$vectors)
  factor <- sweep(root, 1, scales, `*`)
  dimnames(factor) <- list(parameters, parameters)
  list(factor = factor, scales = scales, eigenvalues = eig$values, tau_sym = tau_sym,
       tau_eig = tau_eig, symmetry_adjustment = adjustment, clipped = which(eig$values < 0))
}

.bootstrap_fiml_effect <- function(theta, spec, template, effect) {
  # The ordinary effect methods own the functional; no formula is duplicated here.
  template@a_path <- unname(theta[[spec$map[["a"]]]])
  template@b_path <- unname(theta[[spec$map[["b"]]]])
  template@c_prime <- if (spec$direct) unname(theta[[spec$map[["cp"]]]]) else 0
  value <- switch(effect, nie = nie(template), nde = nde(template), te = te(template))
  value <- as.numeric(value)
  if (length(value) != 1L || !is.finite(value)) stop("nonfinite FIML effect", call. = FALSE)
  value
}

.bootstrap_fiml_refit <- function(source, rows) {
  fit_sem(source@model, source@data[rows, , drop = FALSE], missing = "fiml", fixed_x = FALSE,
          meanstructure = TRUE, information = source@information, n_starts = source@internals$n_starts,
          control = source@internals$control, se_type = "model")
}

.bootstrap_fiml <- function(source, effect, method, method_missing, mediation_data, data,
                            n_boot, ci_level, parallel, ncores, seed, cluster, dots_n, call) {
  if (!S7::S7_inherits(source, SEMFit) || !.sem_fiml_is(source)) {
    stop("source_fit must be an accepted bounded FIML SEMFit", call. = FALSE)
  }
  .sem_fiml_require(source)
  if (method_missing) stop("method must be explicitly supplied with source_fit", call. = FALSE)
  checkmate::assert_choice(method, c("nonparametric", "parametric"), .var.name = "method")
  checkmate::assert_choice(effect, c("nie", "nde", "te"), .var.name = "effect")
  if (!is.null(mediation_data) || !is.null(data) || !is.null(cluster) || dots_n) {
    stop("source_fit cannot be combined with mediation_data, data, cluster, or ...", call. = FALSE)
  }
  checkmate::assert_count(n_boot, positive = TRUE, .var.name = "n_boot")
  checkmate::assert_number(ci_level, lower = 0, upper = 1, .var.name = "ci_level")
  if (ci_level <= 0 || ci_level >= 1) stop("ci_level must be strictly between 0 and 1", call. = FALSE)
  checkmate::assert_flag(parallel, .var.name = "parallel")
  checkmate::assert_count(ncores, positive = TRUE, null.ok = TRUE, .var.name = "ncores")
  checkmate::assert_int(seed, null.ok = TRUE, .var.name = "seed")
  spec <- .sem_fiml_model(source@model)
  theta <- source@theta
  if (!setequal(names(theta), unname(spec$map)) || anyDuplicated(names(theta)) || any(!is.finite(theta))) {
    stop("source_fit must contain finite canonical free parameters", call. = FALSE)
  }
  # A plain MediationData supplies only the existing functional evaluator, not a new likelihood fit.
  template <- MediationData(a_path = 0, b_path = 0, c_prime = 0, n_obs = source@n_obs,
                            estimates = numeric(), vcov = matrix(numeric(), 0L, 0L),
                            sigma_m = NULL, sigma_y = NULL, data = NULL,
                            treatment = spec$vars[["X"]], mediator = spec$vars[["M"]],
                            outcome = spec$vars[["Y"]], converged = TRUE, source_package = "medfit")
  estimate <- .bootstrap_fiml_effect(theta, spec, template, effect)
  factor <- if (method == "parametric") .bootstrap_fiml_factor(source@vcov, names(theta)) else NULL
  B <- as.integer(n_boot)
  protocol <- list(model = source@model, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE,
                   information = source@information, se_type = "model", n_starts = source@internals$n_starts,
                   control = source@internals$control, acceptance = "fiml-1")
  rng_kind <- RNGkind()
  if (!is.null(seed)) set.seed(seed)
  rng_start <- if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) get(".Random.seed", .GlobalEnv) else NULL
  indices <- if (method == "nonparametric") {
    lapply(seq_len(B), function(i) sample.int(source@n_obs, source@n_obs, replace = TRUE))
  } else {
    NULL
  }
  draws <- if (method == "parametric") {
    Z <- matrix(stats::rnorm(B * length(theta)), nrow = B, byrow = TRUE)
    sweep(Z %*% t(factor$factor), 2, theta, `+`)
  } else {
    NULL
  }
  run <- function(i) {
    notices <- character()
    record <- list(id = i, status = "unattempted", reason = NULL,
                   rows = if (is.null(indices)) NULL else indices[[i]],
                   normal_draw_id = if (is.null(draws)) NULL else i)
    value <- tryCatch(withCallingHandlers({
      if (method == "nonparametric") {
        refit <- .bootstrap_fiml_refit(source, indices[[i]])
        .sem_fiml_require(refit)
        record$acceptance <- refit@diagnostics$ledger
        record$attempts <- refit@diagnostics$attempts
        record$frame <- refit@internals$likelihood$rows
        .bootstrap_fiml_effect(refit@theta, spec, template, effect)
      } else {
        .bootstrap_fiml_effect(stats::setNames(draws[i, ], names(theta)), spec, template, effect)
      }
    }, warning = function(w) {
      notices <<- c(notices, conditionMessage(w))
      invokeRestart("muffleWarning")
    }), error = function(e) {
      record$status <<- "failed"
      record$reason <<- conditionMessage(e)
      record$condition_class <<- class(e)
      record$attempts <<- e$attempts
      NA_real_
    })
    if (is.finite(value)) record$status <- "accepted"
    record$warnings <- notices
    list(value = value, record = record)
  }
  results <- if (parallel && .Platform$OS.type == "unix") {
    cores <- if (is.null(ncores)) max(1L, parallel::detectCores() - 1L) else ncores
    parallel::mclapply(seq_len(B), run, mc.cores = cores, mc.set.seed = FALSE)
  } else {
    lapply(seq_len(B), run)
  }
  # Keep every requested ID. A failed worker is an unresolved replicate, never a survivor replacement.
  for (i in seq_len(B)) {
    if (!is.list(results[[i]]) || is.null(results[[i]]$value)) {
      record <- list(
        id = i, status = "failed",
        reason = "worker failed", rows = if (is.null(indices)) NULL else indices[[i]],
        normal_draw_id = if (is.null(draws)) NULL else i
      )
      results[[i]] <- list(value = NA_real_, record = record)
    }
  }
  values <- vapply(results, `[[`, numeric(1), "value")
  success <- sum(is.finite(values))
  complete <- success == B
  ci <- if (complete) stats::quantile(values, c((1 - ci_level) / 2, (1 + ci_level) / 2),
                                      names = FALSE, type = 7) else c(NA_real_, NA_real_)
  inference <- list(
    schema = "fiml-bootstrap-1", status = if (complete) "complete" else "withheld",
    method_label = if (method == "parametric") "Gaussian parameter-draw percentile interval" else
      "Retained-row FIML percentile interval", effect = effect,
    target = "conditional on retained nonempty records", source_binding = source@diagnostics$ledger$binding,
    source_data_hash = rlang::hash(source@data), source_likelihood = source@internals$likelihood,
    parameters = names(theta), frame = list(
      collected_n = source@n_obs + source@n_dropped, retained_n = source@n_obs,
      dropped_n = source@n_dropped, rows = source@internals$likelihood$rows
    ),
    refit_protocol = protocol, covariance_factor = factor, quantile_type = 7L,
    seed = seed, rng_kind = rng_kind, rng_start = rng_start, requested = B, successful = success,
    failed = B - success, replicates = lapply(results, `[[`, "record")
  )
  BootstrapResult(estimate = estimate, ci_lower = ci[1], ci_upper = ci[2], ci_level = ci_level,
                  boot_estimates = values, n_boot = B, method = method, call = call, inference = inference)
}
