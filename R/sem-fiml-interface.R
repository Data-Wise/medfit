# The bounded public adapter keeps complete-data outcomes and discrepancy fields unchanged.
.sem_fiml_is <- function(x) {
  if (S7::S7_inherits(x, SEMFit)) {
    identical(x@internals$likelihood$method, "fiml") || identical(x@diagnostics$ledger$schema, "fiml-1")
  } else {
    S7::S7_inherits(x, FIMLMediationData)
  }
}

.sem_fiml_refuse <- function(x, operation) {
  if (.sem_fiml_is(x)) {
    stop(operation, " is not supported for bounded FIML objects", call. = FALSE)
  }
  invisible(NULL)
}

.sem_fiml_model <- function(model) {
  parsed <- .sem_parse(model)
  p <- parsed$parameters
  if (nrow(parsed$constraints) || any(!p$op %in% c("~", "~~", "~1")) ||
        any(p$level != 1L) || any(!is.na(p$lower) | !is.na(p$upper) | !is.na(p$start))) {
    .sem_fiml_diagnostic("unsupported FIML topology, constraints or bounds")
  }
  tab <- .sem_complete(p, meanstructure = TRUE, fixed_x = FALSE)
  roles <- .sem_roles(tab)
  reg <- tab[tab$op == "~", , drop = FALSE]
  x <- roles$ov_x
  y <- setdiff(unique(reg$lhs), reg$rhs)
  m <- setdiff(unique(reg$lhs), y)
  if (length(roles$obs) != 3L || length(x) != 1L || length(y) != 1L || length(m) != 1L ||
        any(grepl(":", roles$obs, fixed = TRUE))) {
    .sem_fiml_diagnostic("FIML requires exactly three observed variables in X -> M -> Y")
  }
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  required <- c(paste(m, "~", x), paste(y, "~", m))
  cp <- paste(y, "~", x)
  allowed <- c(required, cp, paste(roles$obs, "~~", roles$obs), paste(roles$obs, "~1", ""))
  if (anyDuplicated(keys) || !all(required %in% keys) || any(!keys %in% allowed)) {
    .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  }
  is_cp <- keys == cp
  if (any(!is.na(tab$fixed) & !(is_cp & tab$fixed == 0))) {
    .sem_fiml_diagnostic("only the direct path may be fixed, exactly at zero, in FIML")
  }
  direct <- any(is_cp & is.na(tab$fixed))
  conv <- .sem_to_ram(tab)
  if (conv$ram$q != if (direct) 9L else 8L) {
    .sem_fiml_diagnostic("FIML does not support parameter ties")
  }
  canonical <- c(
    required, if (direct) cp, paste(c(x, m, y), "~~", c(x, m, y)),
    paste(c(x, m, y), "~1", "")
  )
  labels <- c("a", "b", if (direct) "cp", "vx", "vm", "vy", "ix", "im", "iy")
  map <- stats::setNames(conv$ram$par_names[conv$par_map[match(canonical, keys)]], labels)
  list(parsed = parsed, conv = conv, vars = c(X = x, M = m, Y = y), direct = direct, map = map)
}

.sem_fiml_binding <- function(object) {
  list(
    model = object@model, data = object@data, theta = object@theta, vcov = object@vcov,
    table = object@table, information = object@information, n_obs = object@n_obs,
    n_dropped = object@n_dropped, f = object@f, df = object@df, converged = object@converged,
    likelihood = object@internals$likelihood, ram = object@internals$ram,
    settings = object@internals[c("n_starts", "control", "fixed_x", "weights")],
    attempts = object@diagnostics$attempts, solver_calls = object@diagnostics$solver_calls,
    status = object@diagnostics$status, se_type = object@diagnostics$se_type
  )
}

.sem_fiml_require <- function(object) {
  ledger <- object@diagnostics$ledger
  l <- object@internals$likelihood
  a <- object@diagnostics$attempts
  valid <- identical(ledger$schema, "fiml-1") && identical(ledger$outcome, "resolved") &&
    identical(ledger$binding, rlang::hash(.sem_fiml_binding(object))) &&
    identical(l$method, "fiml") && identical(l$x_policy, "random") &&
    isTRUE(object@converged) && identical(object@f, NA_real_) && identical(object@df, NA_real_) &&
    length(l$nll) == 1L && is.finite(l$nll) && identical(l$n_obs, object@n_obs) &&
    identical(l$k, length(object@theta)) && is.data.frame(a) && nrow(a) == 6L &&
    all(c("slsqp", "nlminb") %in% a$solver[a$accepted]) &&
    all(is.finite(object@vcov)) && identical(l$selected, which.min(ifelse(a$accepted, a$nll, Inf)))
  if (!isTRUE(valid)) {
    stop(structure(list(message = "missing or mismatched FIML outcome ledger", call = NULL, ledger = ledger),
      class = c("medfit_error_ledger", "error", "condition")
    ))
  }
  invisible(ledger)
}

.sem_fiml_syntax <- function(model, data, information, n_starts, control, weights, se_type,
                             meanstructure, fixed_x, fx_unset, call) {
  stage <- "input"
  candidate <- NULL
  tryCatch(
    {
      if (fx_unset || !identical(fixed_x, FALSE)) {
        .sem_fiml_diagnostic("FIML requires explicit fixed_x = FALSE")
      }
      if (!isTRUE(meanstructure) || information != "observed" || se_type != "model" ||
            !is.null(weights) || length(control) || (!is.null(n_starts) && n_starts != 3L)) {
        .sem_fiml_diagnostic(paste0(
          "FIML requires meanstructure = TRUE, observed/model SEs, no weights, ",
          "empty control and n_starts = 3 or NULL"
        ))
      }
      spec <- .sem_fiml_model(model)
      if (!all(spec$vars %in% names(data))) .sem_fiml_diagnostic("FIML model variables are absent from data")
      d <- data[, spec$vars, drop = FALSE]
      if (!all(vapply(d, function(x) is.numeric(x) && !is.object(x), logical(1)))) {
        .sem_fiml_diagnostic("FIML model variables must be numeric continuous columns")
      }
      z <- as.matrix(d)
      colnames(z) <- c("X", "M", "Y")
      .sem_fiml_prepare(z, direct = spec$direct)
      stage <- "numerical"
      candidate <- .sem_fiml_fit(z, direct = spec$direct)
      conv <- spec$conv
      theta <- stats::setNames(candidate$estimate[names(spec$map)], unname(spec$map))[conv$ram$par_names]
      V <- candidate$covariance[names(spec$map), names(spec$map), drop = FALSE]
      dimnames(V) <- list(unname(spec$map), unname(spec$map))
      V <- V[names(theta), names(theta), drop = FALSE]
      tab <- conv$table
      free <- !is.na(conv$par_map)
      tab$free <- free
      tab$est <- ifelse(free, theta[pmax(conv$par_map, 1L)], tab$fixed)
      tab$se <- ifelse(free, sqrt(diag(V))[pmax(conv$par_map, 1L)], NA_real_)
      p <- candidate$prepared
      selected <- which.min(ifelse(candidate$attempts$accepted, candidate$attempts$nll, Inf))
      row_context <- c(p$rows, list(patterns = lapply(p$groups, function(g) {
        list(rows = p$rows$original[g$ids], variables = unname(spec$vars[g$cols]), n = g$n)
      }), complete = sum(stats::complete.cases(z))))
      likelihood <- list(
        method = "fiml", x_policy = "random", nll = candidate$nll,
        n_obs = as.integer(p$n), k = length(theta), rows = row_context, selected = selected,
        jacobian = p$jacobian, variables = spec$vars
      )
      out <- SEMFit(
        theta = theta, vcov = V,
        table = tab[, c("lhs", "op", "rhs", "label", "free", "est", "se", "fixed_x")],
        defined = data.frame(name = character(), expr = character(), est = numeric(), se = numeric()),
        f = NA_real_, df = NA_real_, n_obs = as.integer(p$n), n_dropped = as.integer(length(p$rows$empty)),
        information = "observed", converged = TRUE, data = d[p$rows$retained, , drop = FALSE], model = model,
        diagnostics = list(
          status = candidate$attempts$status[selected],
          decrement = candidate$attempts$stationarity[selected], retries = 5L,
          active_bounds = character(), active_constraints = character(), improper = character(),
          sign_check = "not_applicable", se_type = "model", attempts = candidate$attempts,
          solver_calls = candidate$calls, spread = candidate$spread
        ),
        internals = list(
          ram = conv$ram, par_map = conv$par_map, constraints = spec$parsed$constraints,
          partable = tab, weights = NULL, eq_rank = 0L, n_starts = 3L, control = list(),
          fixed_x = character(), factors = list(), likelihood = likelihood
        ), call = call
      )
      dg <- out@diagnostics
      dg$ledger <- list(
        schema = "fiml-1", outcome = "resolved", binding = rlang::hash(.sem_fiml_binding(out)),
        stationarity = "local", solver_groups = 6L, solver_calls = length(candidate$calls),
        accepted = sum(candidate$attempts$accepted)
      )
      out@diagnostics <- dg
      .sem_fiml_require(out)
      out
    },
    error = function(parent) {
      stop(structure(list(
        message = conditionMessage(parent), call = NULL, stage = stage,
        reason = conditionMessage(parent), parent = parent,
        attempts = if (!is.null(candidate)) candidate$attempts else parent$attempts,
        solver_calls = if (!is.null(candidate)) candidate$calls else parent$solver_calls
      ), class = c("medfit_sem_fiml_error", "error", "condition")))
    }
  )
}

.sem_fiml_modeltest_note <- function() {
  "FIML model test unavailable: no saturated missing-data reference is fitted"
}

.sem_fiml_extract <- function(object, treatment, mediator, args) {
  .sem_fiml_require(object)
  v <- object@internals$likelihood$variables
  allowed <- c("outcome", "a_label", "b_label", "cp_label", "standardized", "structure", "decomposition")
  if (length(setdiff(names(args), allowed)) || !identical(treatment, unname(v["X"])) ||
        !identical(mediator, unname(v["M"])) ||
        (!is.null(args$outcome) && !identical(args$outcome, unname(v["Y"]))) ||
        (!is.null(args$standardized) && !identical(args$standardized, FALSE)) ||
        (!is.null(args$structure) && !identical(args$structure, "auto")) ||
        (!is.null(args$decomposition) && !args$decomposition %in% c("auto", "two_way"))) {
    stop("FIML extraction supports only the fitted simple unstandardized two-way mediation", call. = FALSE)
  }
  acc <- .sem_accessors_native(object)
  original_table <- acc$param_table()
  # Topology is authoritative. Labels may validly name another role, including a reserved alias.
  acc$param_table <- function(standardized = FALSE) {
    tab <- original_table
    tab$label <- ""
    tab
  }
  acc$partable <- function() acc$param_table()
  canonical <- gsub(" ", "", paste(original_table$lhs, original_table$op, original_table$rhs), fixed = TRUE)
  canonical <- canonical[match(seq_along(object@theta), object@internals$par_map)]
  acc$coef <- function() stats::setNames(object@theta, canonical)
  acc$vcov <- function() {
    V <- object@vcov
    dimnames(V) <- list(canonical, canonical)
    V
  }
  out <- do.call(
    extract_mediation_lavaan,
    c(list(acc, treatment = treatment, mediator = mediator), args)
  )
  map <- .sem_fiml_model(object@model)$map
  roles <- c(a = unname(map["a"]), b = unname(map["b"]), c_prime = unname(map["cp"]))
  idx <- stats::setNames(seq_along(object@theta), names(object@theta))
  aliases <- c(roles, stats::setNames(unname(roles), c(
    paste0("m_", treatment),
    paste0("y_", mediator), paste0("y_", treatment)
  )))
  idx[names(aliases)] <- match(aliases, names(object@theta))
  estimates <- object@theta[idx]
  estimates[is.na(idx)] <- 0
  names(estimates) <- names(idx)
  V <- matrix(0, length(idx), length(idx), dimnames = list(names(idx), names(idx)))
  present <- !is.na(idx)
  V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]
  out@source_package <- "medfit"
  props <- S7::props(out)
  props$estimates <- estimates
  props$vcov <- V
  ctx <- object@internals$likelihood
  ctx$source_theta <- object@theta
  ctx$source_vcov <- object@vcov
  ctx$source_roles <- roles
  ctx$source_hash <- rlang::hash(list(ctx$source_theta, ctx$source_vcov, ctx$source_roles))
  ctx$data_hash <- rlang::hash(out@data)
  ctx$parameter_hash <- rlang::hash(list(estimates, V, out@a_path, out@b_path, out@c_prime))
  do.call(FIMLMediationData, c(props, list(fit_context = ctx)))
}

.sem_fiml_origin <- function(x) {
  .sem_fiml_is(x) && S7::S7_inherits(x, MediationData) && x@a_path == 0 && x@b_path == 0
}
