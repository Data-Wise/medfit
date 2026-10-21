# The OpenMx adapter of compare_lr() (#249 T3). Observed-variable covariance models only (see `.lr_unsupported()`): the
# RAM model is built straight from the fit's table and fitted on the sample covariance matrix with numObs = n, which is
# the ML likelihood medfit uses.

# OpenMx accepts tight convergence settings; its defaults stop up to 5.5e-6 from the optimum, which would make a correct
# fit look like a disagreement. Returns the function that restores the previous options (call it from `on.exit()`).
.lr_openmx_tight <- function() {
  opts <- c("Optimality tolerance", "Feasibility tolerance", "Function precision")
  old <- vapply(opts, function(o) as.character(OpenMx::mxOption(NULL, o)), "")
  OpenMx::mxOption(NULL, "Optimality tolerance", 1e-12)
  OpenMx::mxOption(NULL, "Feasibility tolerance", 1e-12)
  OpenMx::mxOption(NULL, "Function precision", 1e-15)
  function() {
    for (o in opts) {
      OpenMx::mxOption(NULL, o, if (old[[o]] == "Auto") "Auto" else as.numeric(old[[o]]))
    }
  }
}

# RAM model from the free parameters of a fit table. `labels` are p1..pq in table order (OpenMx labels cannot hold `~`);
# `start` is the start vector in that order; `constrain` the labels whose product is constrained to 0 (or NULL).
.lr_openmx_model <- function(object, labels, start, constrain = NULL) {
  tab <- object@table
  obs <- object@internals$ram$obs
  paths <- lapply(seq_len(nrow(tab)), function(i) {
    row <- tab[i, ]
    if (row$op == "~") {
      OpenMx::mxPath(from = row$rhs, to = row$lhs, arrows = 1, free = TRUE, values = start[[i]], labels = labels[[i]])
    } else {
      OpenMx::mxPath(from = row$lhs, to = if (row$lhs == row$rhs) NA else row$rhs, arrows = 2, free = TRUE,
                     values = start[[i]], labels = labels[[i]])
    }
  })
  cv <- stats::cov(object@data[, obs, drop = FALSE])
  parts <- c(list("compare_lr", type = "RAM", manifestVars = obs), paths,
             list(OpenMx::mxData(observed = cv, type = "cov", numObs = object@n_obs)))
  if (length(constrain)) {
    prod_expr <- parse(text = paste(constrain, collapse = " * "))[[1L]]
    parts <- c(parts, list(do.call(OpenMx::mxAlgebra, list(prod_expr, name = "g")),
                           do.call(OpenMx::mxConstraint, list(quote(g == 0), name = "k"))))
  }
  do.call(OpenMx::mxModel, parts)
}

.lr_openmx_run <- function(model) {
  tryCatch(suppressMessages(suppressWarnings(OpenMx::mxRun(model, silent = TRUE))), error = function(e) NULL)
}

# TRUE when the fit converged: OpenMx status code 0 or 1 (1 is a satisfied optimum with a warning).
.lr_openmx_ok <- function(fit) !is.null(fit) && fit$output$status$code <= 1

.lr_engine_openmx <- function(object, paths) {
  if (!requireNamespace("OpenMx", quietly = TRUE)) {
    stop("the OpenMx package is needed for engine = \"openmx\"; install it first.", call. = FALSE)
  }
  why <- .lr_unsupported(object)
  if (!is.null(why)) {
    stop(sprintf("compare_lr() does not support %s; it compares observed-variable covariance models only.", why),
         call. = FALSE)
  }
  restore <- .lr_openmx_tight()
  on.exit(restore(), add = TRUE)
  tab <- object@table
  ram <- object@internals$ram
  smp <- .sem_sample(object@data[, ram$obs, drop = FALSE], ram)
  labels <- paste0("p", seq_len(nrow(tab)))
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  # medfit's own default start, by the name medfit gives each parameter (the label, else `lhs~rhs` / `lhs~~rhs`)
  start_all <- .sem_default_start(ram, smp)
  start_name <- ifelse(nzchar(tab$label), tab$label, paste0(tab$lhs, tab$op, tab$rhs))
  start_default <- unname(start_all[start_name])
  path_idx <- match(paths, tab$label)
  zero_start <- start_default
  zero_start[path_idx] <- 0
  scale <- .lr_residual_scale(object, paths)

  full <- .lr_openmx_run(.lr_openmx_model(object, labels, start_default))
  sat_chisq <- function(fit) {
    if (!.lr_openmx_ok(fit)) {
      return(NA_real_)
    }
    refs <- NULL
    utils::capture.output(refs <- suppressMessages(OpenMx::mxRefModels(fit, run = TRUE))) # runs quietly
    unname(summary(fit, refModels = refs)$Chi)
  }
  run <- function(start, name) {
    fit <- .lr_openmx_run(.lr_openmx_model(object, labels, start, constrain = labels[path_idx]))
    ok <- .lr_openmx_ok(fit) && .lr_openmx_ok(full)
    resid <- NA_real_
    if (ok) {
      est <- OpenMx::omxGetParameters(fit)
      resid <- abs(prod(est[labels[path_idx]]))
    }
    list(start = name, lr = if (ok) fit$output$fit - full$output$fit else NA_real_, converged = ok,
         residual = resid, residual_scale = scale, jac_zero_at_start = sum(start[path_idx] == 0) >= 2L)
  }
  est <- NULL
  if (.lr_openmx_ok(full)) {
    est <- stats::setNames(unname(OpenMx::omxGetParameters(full)[labels]), keys)
  }
  list(engine = "openmx", version = as.character(utils::packageVersion("OpenMx")), est = est, fit = sat_chisq(full),
       runs = list(run(start_default, "default"), run(zero_start, "zero")))
}
