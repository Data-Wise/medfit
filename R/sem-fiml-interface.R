# The bounded public adapter keeps complete-data outcomes and discrepancy fields unchanged.
.sem_fiml_is <- function(x) {
  if (S7::S7_inherits(x, SEMFit)) {
    identical(x@internals$likelihood$method, "fiml") || identical(x@diagnostics$ledger$schema, "fiml-1")
  } else {
    S7::S7_inherits(x, FIMLMediationData) || S7::S7_inherits(x, FIMLParallelMediationData)
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
  if (length(x) %in% 2:3 && length(roles$obs) == length(x) + 2L && !any(grepl(":", roles$obs, fixed = TRUE))) {
    return(.sem_fiml_model_cov(parsed, tab, roles, reg))
  }
  if (length(x) == 1L && length(roles$obs) == 4L && !any(grepl(":", roles$obs, fixed = TRUE))) {
    return(.sem_fiml_model_par(parsed, tab, roles, reg))
  }
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

# One or two covariates (FI-G1): M ~ X + Z... and Y ~ M + X + Z... with free covariances among all exogenous variables
# and independent disturbances. The covariate paths are complete (free); the only fixed value is one exact zero on an
# exogenous variable's Y path, and that variable is then the treatment (`X`), the others the covariates (`Z`, or `Z1`,
# `Z2` in order of appearance). With every Y path free the first exogenous variable is `X`; extraction may name any of
# them as the treatment. Everything else (three or more covariates, an omitted Y path, covariates on M only, fixed
# covariate paths, covariate residual covariances) is refused.
.sem_fiml_model_cov <- function(parsed, tab, roles, reg) {
  e <- roles$ov_x
  k <- length(e) - 1L
  y <- setdiff(unique(reg$lhs), reg$rhs)
  m <- setdiff(unique(reg$lhs), y)
  if (length(y) != 1L || length(m) != 1L || !setequal(roles$obs, c(e, m, y))) {
    .sem_fiml_diagnostic("unsupported FIML topology: covariates need M ~ X + Z and Y ~ M + X + Z")
  }
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  y_keys <- paste(y, "~", e)
  fixed <- which(!is.na(tab$fixed))
  if (length(fixed) > 1L || (length(fixed) == 1L && !(keys[fixed] %in% y_keys && tab$fixed[fixed] == 0))) {
    .sem_fiml_diagnostic("only one direct path may be fixed, exactly at zero, in FIML")
  }
  # Every Y path must be written: an omitted path is ambiguous with a covariate that acts on M only, so it is refused.
  # The treatment `x` is the variable whose Y path is fixed at zero; with all paths free it is the first.
  if (any(!y_keys %in% keys)) {
    .sem_fiml_diagnostic("FIML with a covariate needs a Y path from each exogenous variable (free, or one fixed at 0)")
  }
  direct <- !length(fixed)
  x <- if (direct) e[1L] else e[match(keys[fixed], y_keys)]
  z <- setdiff(e, x)
  nm <- .sem_fiml_cov_names(k)
  ex <- c(x, z)
  # exogenous covariances in either written order are the one canonical pair
  pair <- tab$op == "~~" & tab$lhs %in% ex & tab$rhs %in% ex & tab$lhs != tab$rhs
  lo <- pmin(match(tab$lhs, ex), match(tab$rhs, ex))
  hi <- pmax(match(tab$lhs, ex), match(tab$rhs, ex))
  keys[pair] <- paste(ex[lo[pair]], "~~", ex[hi[pair]])
  covariance <- paste(ex[utils::combn(k + 1L, 2L)[1L, ]], "~~", ex[utils::combn(k + 1L, 2L)[2L, ]])
  required <- c(paste(m, "~", x), paste(m, "~", z), paste(y, "~", m), paste(y, "~", z), covariance)
  cp <- paste(y, "~", x)
  obs <- c(x, z, m, y)
  allowed <- c(required, cp, paste(obs, "~~", obs), paste(obs, "~1", ""))
  if (anyDuplicated(keys) || !all(required %in% keys) || any(!keys %in% allowed)) {
    .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  }
  conv <- .sem_to_ram(tab)
  q_expected <- (k + 1L) + (k + 2L) + (k + 3L) + choose(k + 1L, 2L) + (k + 3L) - !direct
  if (conv$ram$q != q_expected) .sem_fiml_diagnostic("FIML does not support parameter ties")
  canonical <- c(
    paste(m, "~", x), paste(m, "~", z), paste(y, "~", m), if (direct) cp, paste(y, "~", z),
    paste(obs, "~~", obs), covariance, paste(obs, "~1", "")
  )
  tables <- .sem_fiml_tables_cov(k, direct)
  labels <- c(
    "a", paste0("gm", nm$sfx), "b", if (direct) "cp", paste0("gy", nm$sfx), tables$s$label, tables$m$label
  )
  stopifnot(length(labels) == length(canonical))
  map <- stats::setNames(conv$ram$par_names[conv$par_map[match(canonical, keys)]], labels)
  list(
    parsed = parsed, conv = conv, vars = c(X = x, M = m, Y = y), direct = direct, map = map,
    covariate = stats::setNames(z, nm$z)
  )
}

# Two parallel mediators (FI-G2): M1 ~ X, M2 ~ X and Y ~ M1 + M2 [+ X], independent disturbances. The independence of
# the two mediator disturbances must be WRITTEN as `M1 ~~ 0*M2` (either order): an omitted statement is ambiguous with
# lavaan's default of a free residual covariance among such variables, so it is refused. Slice 2 also admits the free,
# label-less statement `M1 ~~ M2` (either order); a labeled, bounded, tied or fixed nonzero one is refused.
# The direct path may be free, fixed at exactly zero, or omitted. Mediators are `M1`, `M2` in order of appearance.
.sem_fiml_model_par <- function(parsed, tab, roles, reg) {
  x <- roles$ov_x
  y <- setdiff(unique(reg$lhs), reg$rhs)
  m <- setdiff(unique(reg$lhs), y)
  if (length(y) != 1L || length(m) != 2L || !setequal(roles$obs, c(x, m, y))) {
    .sem_fiml_diagnostic("unsupported FIML topology: parallel mediation needs M1 ~ X, M2 ~ X and Y ~ M1 + M2")
  }
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  is_cov <- tab$op == "~~" & tab$lhs %in% m & tab$rhs %in% m & tab$lhs != tab$rhs
  covariance <- paste(m[1L], "~~", m[2L])
  keys[is_cov] <- covariance
  required <- c(paste(m, "~", x), paste(y, "~", m), covariance)
  cp <- paste(y, "~", x)
  obs <- c(x, m, y)
  allowed <- c(required, cp, paste(obs, "~~", obs), paste(obs, "~1", ""))
  if (anyDuplicated(keys) || any(!keys %in% allowed)) {
    .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  }
  if (!covariance %in% keys) {
    .sem_fiml_diagnostic("FIML parallel mediation needs the independent mediator disturbances written as M1 ~~ 0*M2")
  }
  if (!all(setdiff(required, covariance) %in% keys)) {
    .sem_fiml_diagnostic("unsupported FIML topology: parallel mediation needs M1 ~ X, M2 ~ X and Y ~ M1 + M2")
  }
  is_cp <- keys == cp
  # The residual covariance is admitted either fixed at exactly zero (independent disturbances) or free and label-less
  # (FI-G2 slice 2); a labeled, bounded, nonzero or tied one is refused.
  free_cov <- any(is_cov & is.na(tab$fixed))
  if (free_cov && any(is_cov & nzchar(tab$label))) {
    .sem_fiml_diagnostic("a labeled mediator residual covariance is not supported in FIML")
  }
  if (any(!is.na(tab$fixed) & !((is_cp | is_cov) & tab$fixed == 0 & !is.na(tab$fixed)))) {
    .sem_fiml_diagnostic("only the direct path and the mediator residual covariance may be fixed, exactly at zero")
  }
  direct <- any(is_cp & is.na(tab$fixed))
  conv <- .sem_to_ram(tab)
  if (conv$ram$q != (if (direct) 13L else 12L) + free_cov) {
    .sem_fiml_diagnostic("FIML does not support parameter ties")
  }
  canonical <- c(
    paste(m, "~", x), paste(y, "~", m), if (direct) cp, paste(obs, "~~", obs), if (free_cov) covariance,
    paste(obs, "~1", "")
  )
  tables <- .sem_fiml_tables_med(2L, direct, free_cov)
  labels <- c(tables$a$label[is.na(tables$a$value)], tables$s$label, tables$m$label)
  stopifnot(length(labels) == length(canonical))
  map <- stats::setNames(conv$ram$par_names[conv$par_map[match(canonical, keys)]], labels)
  list(
    parsed = parsed, conv = conv, vars = stats::setNames(c(x, m, y), tables$vars), direct = direct, map = map,
    mediators = stats::setNames(m, c("M1", "M2")), residual_covariance = free_cov
  )
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
      # data columns in kernel order: X, [Z], M, Y
      model_vars <- if (is.null(spec$covariate)) {
        spec$vars
      } else {
        c(spec$vars["X"], spec$covariate, spec$vars[c("M", "Y")])
      }
      if (!all(model_vars %in% names(data))) .sem_fiml_diagnostic("FIML model variables are absent from data")
      d <- data[, model_vars, drop = FALSE]
      if (!all(vapply(d, function(x) is.numeric(x) && !is.object(x), logical(1)))) {
        .sem_fiml_diagnostic("FIML model variables must be numeric continuous columns")
      }
      z <- as.matrix(d)
      colnames(z) <- names(model_vars)
      if (!is.null(spec$mediators)) {
        tables <- .sem_fiml_tables_med(length(spec$mediators), spec$direct, isTRUE(spec$residual_covariance))
        prepared <- .sem_fiml_prepare_core(z, tables, direct = spec$direct)
        stage <- "numerical"
        candidate <- .sem_fiml_solve(prepared)
      } else if (is.null(spec$covariate)) {
        .sem_fiml_prepare(z, direct = spec$direct)
        stage <- "numerical"
        candidate <- .sem_fiml_fit(z, direct = spec$direct)
      } else {
        tables <- .sem_fiml_tables_cov(length(spec$covariate), spec$direct)
        prepared <- .sem_fiml_prepare_core(z, tables, direct = spec$direct)
        stage <- "numerical"
        candidate <- .sem_fiml_solve(prepared)
      }
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
        list(rows = p$rows$original[g$ids], variables = unname(model_vars[g$cols]), n = g$n)
      }), complete = sum(stats::complete.cases(z))))
      likelihood <- list(
        method = "fiml", x_policy = "random", nll = candidate$nll,
        n_obs = as.integer(p$n), k = length(theta), rows = row_context, selected = selected,
        jacobian = p$jacobian, variables = spec$vars
      )
      if (!is.null(spec$covariate)) likelihood$covariate <- unname(spec$covariate)
      if (!is.null(spec$mediators)) likelihood$mediators <- unname(spec$mediators)
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
  if (!is.null(object@internals$likelihood$mediators)) {
    return(.sem_fiml_extract_parallel(object, treatment, mediator, args))
  }
  v <- object@internals$likelihood$variables
  covariate <- object@internals$likelihood$covariate
  spec <- .sem_fiml_model(object@model)
  allowed <- c("outcome", "a_label", "b_label", "cp_label", "standardized", "structure", "decomposition")
  # With covariates any exogenous variable may be the treatment, except that a fixed-zero direct path belongs to the
  # treatment `X` (a covariate's outcome path must be complete).
  treatment_ok <- identical(treatment, unname(v["X"])) ||
    (!is.null(covariate) && spec$direct && is.character(treatment) && length(treatment) == 1L &&
       treatment %in% covariate)
  if (length(setdiff(names(args), allowed)) || !treatment_ok ||
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
  map <- spec$map
  as_covariate <- !is.null(covariate) && !identical(treatment, unname(v["X"]))
  sfx <- if (!is.null(covariate)) .sem_fiml_cov_names(length(covariate))$sfx
  i <- match(treatment, covariate)
  roles <- if (as_covariate) {
    c(a = unname(map[paste0("gm", sfx[i])]), b = unname(map["b"]), c_prime = unname(map[paste0("gy", sfx[i])]))
  } else {
    c(a = unname(map["a"]), b = unname(map["b"]), c_prime = unname(map["cp"]))
  }
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
  if (as_covariate) {
    ctx$variables["X"] <- treatment
    ctx$covariate <- replace(covariate, i, unname(v["X"]))
  }
  ctx$source_theta <- object@theta
  ctx$source_vcov <- object@vcov
  ctx$source_roles <- roles
  ctx$source_hash <- rlang::hash(list(ctx$source_theta, ctx$source_vcov, ctx$source_roles))
  ctx$data_hash <- rlang::hash(out@data)
  ctx$parameter_hash <- rlang::hash(list(estimates, V, out@a_path, out@b_path, out@c_prime))
  do.call(FIMLMediationData, c(props, list(fit_context = ctx)))
}

# Parallel mediation: both mediators are named; a_j and b_j follow the requested order. The extracted covariance is the
# fitted observed-information covariance, so the sum of the two products keeps every cross-path term (Cov(a1, a2),
# Cov(b1, b2), Cov(a_i, b_j)), unlike the separate-regression lm/glm route.
.sem_fiml_extract_parallel <- function(object, treatment, mediator, args) {
  ctx0 <- object@internals$likelihood
  v <- ctx0$variables
  spec <- .sem_fiml_model(object@model)
  meds <- spec$mediators
  allowed <- c("outcome", "standardized", "structure", "decomposition")
  if (length(setdiff(names(args), allowed)) || !identical(treatment, unname(v["X"])) ||
        !is.character(mediator) || length(mediator) != length(meds) || !setequal(mediator, meds) ||
        (!is.null(args$outcome) && !identical(args$outcome, unname(v["Y"]))) ||
        (!is.null(args$standardized) && !identical(args$standardized, FALSE)) ||
        (!is.null(args$structure) && !args$structure %in% c("auto", "parallel")) ||
        (!is.null(args$decomposition) && !args$decomposition %in% c("auto", "two_way"))) {
    stop("FIML extraction supports only the fitted unstandardized two-way parallel mediation naming both mediators",
         call. = FALSE)
  }
  map <- spec$map
  i <- match(mediator, meds)
  k <- length(i)
  a_aliases <- map[paste0("a", i)]
  b_aliases <- map[paste0("b", i)]
  roles <- c(
    stats::setNames(unname(a_aliases), paste0("a", seq_len(k))),
    stats::setNames(unname(b_aliases), paste0("b", seq_len(k))),
    c_prime = if (spec$direct) unname(map["cp"]) else NA_character_
  )
  idx <- stats::setNames(seq_along(object@theta), names(object@theta))
  idx[names(roles)] <- match(roles, names(object@theta))
  estimates <- object@theta[idx]
  estimates[is.na(idx)] <- 0
  names(estimates) <- names(idx)
  V <- matrix(0, length(idx), length(idx), dimnames = list(names(idx), names(idx)))
  present <- !is.na(idx)
  V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]
  tb <- object@table
  sigma <- function(label) sqrt(unname(object@theta[map[[label]]]))
  ctx <- ctx0
  ctx$mediators <- mediator
  ctx$source_theta <- object@theta
  ctx$source_vcov <- object@vcov
  ctx$source_roles <- roles
  ctx$source_hash <- rlang::hash(list(ctx$source_theta, ctx$source_vcov, ctx$source_roles))
  out <- list(
    a_paths = unname(estimates[paste0("a", seq_len(k))]), b_paths = unname(estimates[paste0("b", seq_len(k))]),
    c_prime = unname(estimates[["c_prime"]])
  )
  ctx$data_hash <- rlang::hash(object@data)
  ctx$parameter_hash <- rlang::hash(list(estimates, V, out$a_paths, out$b_paths, out$c_prime))
  FIMLParallelMediationData(
    a_paths = out$a_paths, b_paths = out$b_paths, c_prime = out$c_prime, estimates = estimates, vcov = V,
    sigma_mediators = unname(vapply(paste0("vm", i), sigma, numeric(1))), sigma_y = sigma("vy"),
    treatment = treatment, mediators = mediator, outcome = unname(v["Y"]),
    mediator_predictors = lapply(mediator, function(m) tb$rhs[tb$lhs == m & tb$op == "~"]),
    outcome_predictors = tb$rhs[tb$lhs == v[["Y"]] & tb$op == "~"], data = object@data,
    n_obs = object@n_obs, converged = TRUE, source_package = "medfit", fit_context = ctx
  )
}

.sem_fiml_origin <- function(x) {
  .sem_fiml_is(x) && S7::S7_inherits(x, MediationData) && x@a_path == 0 && x@b_path == 0
}
