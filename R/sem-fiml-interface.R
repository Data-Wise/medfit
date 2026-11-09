# The bounded public adapter keeps complete-data outcomes and discrepancy fields unchanged.
.sem_fiml_is <- function(x) {
  if (S7::S7_inherits(x, SEMFit)) {
    identical(x@internals$likelihood$method, "fiml") || identical(x@diagnostics$ledger$schema, "fiml-1")
  } else {
    S7::S7_inherits(x, FIMLMediationData) || S7::S7_inherits(x, FIMLParallelMediationData) ||
      S7::S7_inherits(x, FIMLSerialMediationData)
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
  # Two mediators in sequence (FI-G3): a regression between the two non-outcome endogenous variables. This runs before
  # the covariate and parallel routing, which would answer a serial syntax with a parallel-flavored refusal.
  if (.sem_fiml_ser_detect(reg)) return(.sem_fiml_model_ser(parsed, tab, roles, reg))
  if (length(x) %in% 2:3 && length(roles$obs) == length(x) + 2L && !any(grepl(":", roles$obs, fixed = TRUE))) {
    return(.sem_fiml_model_cov(parsed, tab, roles, reg))
  }
  # two mediators: one exogenous variable (X) and no covariate, or X and one or two covariates (FI-G2)
  if (length(x) %in% 1:3 && length(roles$obs) == length(x) + 3L && !any(grepl(":", roles$obs, fixed = TRUE))) {
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

# Largest number of covariates the parallel form admits.
.sem_fiml_par_cov_max <- function() 2L

# Two parallel mediators (FI-G2): M1 ~ X, M2 ~ X and Y ~ M1 + M2 [+ X], independent disturbances. The independence of
# the two mediator disturbances must be WRITTEN as `M1 ~~ 0*M2` (either order): an omitted statement is ambiguous with
# lavaan's default of a free residual covariance among such variables, so it is refused. Slice 2 also admits the free,
# label-less statement `M1 ~~ M2` (either order); a labeled, bounded, tied or fixed nonzero one is refused.
# The direct path may be free, fixed at exactly zero, or omitted. Mediators are `M1`, `M2` in order of appearance.
# Slices 3 and 4 add one or two observed covariates with the FI-G1 rules: every exogenous variable has a free path to
# both mediators and a written path to Y (free, or one fixed at exactly zero, which makes that variable the treatment
# `X`; otherwise the first by appearance is `X`), the exogenous covariances are all written or none, and an omitted Y
# path (ambiguous with a covariate acting on the mediators only) is refused. Every equation carries every covariate.
.sem_fiml_model_par <- function(parsed, tab, roles, reg) {
  e <- roles$ov_x
  k <- length(e) - 1L
  y <- setdiff(unique(reg$lhs), reg$rhs)
  m <- setdiff(unique(reg$lhs), y)
  if (k > .sem_fiml_par_cov_max()) .sem_fiml_diagnostic("unsupported number of FIML covariates")
  if (length(y) != 1L || length(m) != 2L || !setequal(roles$obs, c(e, m, y))) {
    .sem_fiml_diagnostic("unsupported FIML topology: parallel mediation needs M1 ~ X, M2 ~ X and Y ~ M1 + M2")
  }
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  # The treatment: with covariates the exogenous variable whose Y path is fixed at zero, else the first one.
  x <- e
  if (k > 0L) {
    y_keys <- paste(y, "~", e)
    fixed_y <- which(!is.na(tab$fixed) & keys %in% y_keys)
    if (any(!y_keys %in% keys)) {
      .sem_fiml_diagnostic(paste0(
        "FIML with a covariate needs a Y path from each exogenous variable ",
        "(free, or one fixed at 0)"
      ))
    }
    if (length(fixed_y) > 1L) .sem_fiml_diagnostic("only one direct path may be fixed, exactly at zero, in FIML")
    x <- if (length(fixed_y)) e[match(keys[fixed_y], y_keys)] else e[1L]
  }
  z <- setdiff(e, x)
  ex <- c(x, z)
  # exogenous covariances in either written order are the one canonical pair
  pair <- tab$op == "~~" & tab$lhs %in% ex & tab$rhs %in% ex & tab$lhs != tab$rhs
  lo <- pmin(match(tab$lhs, ex), match(tab$rhs, ex))
  hi <- pmax(match(tab$lhs, ex), match(tab$rhs, ex))
  keys[pair] <- paste(ex[lo[pair]], "~~", ex[hi[pair]])
  exo_cov <- if (k > 0L) {
    paste(ex[utils::combn(k + 1L, 2L)[1L, ]], "~~", ex[utils::combn(k + 1L, 2L)[2L, ]])
  } else {
    character()
  }
  is_cov <- tab$op == "~~" & tab$lhs %in% m & tab$rhs %in% m & tab$lhs != tab$rhs
  covariance <- paste(m[1L], "~~", m[2L])
  keys[is_cov] <- covariance
  required <- c(
    paste(m, "~", x), if (k > 0L) paste(m, "~", rep(z, each = 2L)), paste(y, "~", m), if (k > 0L) paste(y, "~", z),
    exo_cov, covariance
  )
  cp <- paste(y, "~", x)
  obs <- c(x, z, m, y)
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
  if (conv$ram$q != 12L + 5L * k + choose(k + 1L, 2L) + direct + free_cov) {
    .sem_fiml_diagnostic("FIML does not support parameter ties")
  }
  tables <- .sem_fiml_tables_med(2L, direct, free_cov, k)
  # The canonical key of every free table entry, read off the kernel tables through the data names of the variables.
  kernel <- stats::setNames(c(x, z, m, y), tables$vars)
  free <- function(tb) is.na(tb$value)
  canonical <- c(
    paste(kernel[tables$a$row[free(tables$a)]], "~", kernel[tables$a$col[free(tables$a)]]),
    paste(kernel[tables$s$row], "~~", kernel[tables$s$col]),
    paste(kernel[tables$m$row], "~1", "")
  )
  labels <- c(tables$a$label[free(tables$a)], tables$s$label, tables$m$label)
  stopifnot(length(labels) == length(canonical), all(canonical %in% keys))
  map <- stats::setNames(conv$ram$par_names[conv$par_map[match(canonical, keys)]], labels)
  out <- list(
    parsed = parsed, conv = conv, vars = stats::setNames(c(x, m, y), c("X", "M1", "M2", "Y")), direct = direct,
    map = map, mediators = stats::setNames(m, c("M1", "M2")), residual_covariance = free_cov
  )
  if (k > 0L) out$covariate <- stats::setNames(z, .sem_fiml_cov_names(k)$z)
  out
}

# Fail-closed admission of serial FIML fits (FI-G3). `.fiml_serial_admitted()` is the master switch that opens every
# serial shape (always FALSE; tests mock it to exercise the downstream serial plumbing: tables, ledger, source-fit and
# extract refusals). Each slice admits its own shapes through `.fiml_serial_shape_admitted()`: slices S1b and S2 admit
# the saturated variant and the pure chain with no covariates and nothing else (covariates are S3 and S4), so the
# predicate tests the variant AND the covariate count. Every other serial syntax is refused at fit with its classed
# reason.
.fiml_serial_admitted <- function() FALSE
.fiml_serial_shape_admitted <- function(variant, k) {
  isTRUE(.fiml_serial_admitted()) || (variant %in% c("saturated", "chain") && identical(as.integer(k), 0L))
}
# The shapes `.sem_fiml_extract_serial()` implements (a mocked-open fit of any other shape is refused at extract).
.fiml_serial_extract_supported <- function(variant, k) {
  variant %in% c("saturated", "chain") && identical(as.integer(k), 0L)
}

# Serial syntax: exactly one outcome, exactly two other endogenous variables, and a regression of one of them on the
# other. Anything else keeps the existing routing (and its refusal messages) unchanged.
.sem_fiml_ser_detect <- function(reg) {
  endo <- unique(reg$lhs)
  outcome <- setdiff(endo, reg$rhs)
  mediators <- setdiff(endo, outcome)
  length(outcome) == 1L && length(mediators) == 2L && any(reg$lhs %in% mediators & reg$rhs %in% mediators)
}

# TRUE where a regression `lhs ~ rhs` is WRITTEN, a fixed term (`0*X`) included: variant detection counts every written
# term before it decides the variant.
.sem_fiml_ser_written <- function(tab, keys, lhs, rhs) paste(lhs, "~", rhs) %in% keys

# The residual-zero statements (all three pairs of M1, M2, Y must be written; Q2) that no row of the table supplies.
.sem_fiml_ser_missing_zeros <- function(counts, labels) labels[counts == 0L]

# Two serial mediators (FI-G3): X -> M1 -> M2 -> Y with zero, one or two covariates, in two shortcut states. Saturated:
# X -> M2 and M1 -> Y both written and free. Pure chain: both absent (a structural zero, not a fixed one). Everything
# else (one shortcut only, a fixed, labeled or tied shortcut) is refused. The independence of ALL THREE disturbance
# pairs among M1, M2 and Y must be written as `M1 ~~ 0*M2`, `M1 ~~ 0*Y` and `M2 ~~ 0*Y` (either order within a pair);
# an omitted, free, labeled, nonzero or duplicated statement is refused. In lavaan 0.7-3 `sem()` frees none of these
# covariances, so the written statement mirrors the parallel contract; no claim about other lavaan versions is made.
# Mediators are structural: M1 has no mediator among its predictors, M2 regresses on M1. The treatment `X` is the one
# exogenous variable with no path to M2 in the chain; in the saturated graph it is the variable whose Y path is fixed
# at exactly zero, else the first by appearance. The direct path may be free, fixed at zero, or (k = 0 only) omitted.
.sem_fiml_model_ser <- function(parsed, tab, roles, reg) {
  e <- roles$ov_x
  k <- length(e) - 1L
  y <- setdiff(unique(reg$lhs), reg$rhs)
  m <- setdiff(unique(reg$lhs), y)
  if (any(grepl(":", roles$obs, fixed = TRUE))) .sem_fiml_diagnostic("unsupported FIML topology: interactions")
  if (k > .sem_fiml_par_cov_max()) .sem_fiml_diagnostic("unsupported number of FIML covariates")
  if (k < 0L || !setequal(roles$obs, c(e, m, y))) {
    .sem_fiml_diagnostic("unsupported FIML topology: serial mediation needs M1 ~ X, M2 ~ M1 and Y ~ M2")
  }
  mm <- reg[reg$lhs %in% m & reg$rhs %in% m, , drop = FALSE]
  if (nrow(mm) != 1L || mm$lhs == mm$rhs) {
    .sem_fiml_diagnostic("unsupported FIML topology: the two mediators must be in sequence, without a cycle")
  }
  m1 <- mm$rhs
  m2 <- mm$lhs
  keys <- paste(tab$lhs, tab$op, tab$rhs)
  reg_keys <- keys[tab$op == "~"]
  if (anyDuplicated(reg_keys)) .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  written <- function(lhs, rhs) .sem_fiml_ser_written(tab, keys, lhs, rhs)
  fixed_of <- function(lhs, rhs) tab$fixed[match(paste(lhs, "~", rhs), keys)]
  label_of <- function(lhs, rhs) tab$label[match(paste(lhs, "~", rhs), keys)]
  # the shortcut rows: any exogenous variable on M2, and M1 on Y; a fixed or labeled one is refused before the variant
  # is decided (`M2 ~ M1 + 0*X` is a fixed shortcut, not a chain)
  sc_lhs <- c(rep(m2, length(e)), y)
  sc_rhs <- c(e, m1)
  sc_here <- written(sc_lhs, sc_rhs)
  if (any(sc_here & (!is.na(fixed_of(sc_lhs, sc_rhs)) | nzchar(label_of(sc_lhs, sc_rhs))), na.rm = TRUE)) {
    .sem_fiml_diagnostic("FIML serial shortcut paths are free or absent, never fixed or labeled")
  }
  absent <- e[!written(m2, e)]
  b1 <- written(y, m1)
  if (length(absent) == 0L && b1) {
    variant <- "saturated"
  } else if (length(absent) == 1L && !b1) {
    variant <- "chain"
  } else {
    .sem_fiml_diagnostic(paste0(
      "unsupported FIML topology: serial mediation needs both shortcut paths (X to M2 and M1 to Y) or neither, ",
      "and in the pure chain exactly one exogenous variable (the treatment) without a path to M2"
    ))
  }
  y_keys <- paste(y, "~", e)
  fixed_y <- which(y_keys %in% keys & !is.na(tab$fixed[match(y_keys, keys)]))
  if (k > 0L && any(!y_keys %in% keys)) {
    .sem_fiml_diagnostic("FIML with a covariate needs a Y path from each exogenous variable (free, or one fixed at 0)")
  }
  if (length(fixed_y) > 1L) .sem_fiml_diagnostic("only one direct path may be fixed, exactly at zero, in FIML")
  x <- if (variant == "chain") {
    absent
  } else if (length(fixed_y)) {
    e[fixed_y]
  } else {
    e[1L]
  }
  if (variant == "chain" && length(fixed_y) && e[fixed_y] != x) {
    .sem_fiml_diagnostic("in the pure chain only the direct path of the treatment may be fixed, exactly at zero")
  }
  z <- setdiff(e, x)
  if (any(!written(m1, e))) {
    .sem_fiml_diagnostic("unsupported FIML topology: every exogenous variable needs a path to M1")
  }
  ex <- c(x, z)
  # exogenous covariances in either written order are the one canonical pair
  pair <- tab$op == "~~" & tab$lhs %in% ex & tab$rhs %in% ex & tab$lhs != tab$rhs
  lo <- pmin(match(tab$lhs, ex), match(tab$rhs, ex))
  hi <- pmax(match(tab$lhs, ex), match(tab$rhs, ex))
  keys[pair] <- paste(ex[lo[pair]], "~~", ex[hi[pair]])
  exo_cov <- character()
  if (k > 0L) {
    cb <- utils::combn(k + 1L, 2L)
    exo_cov <- paste(ex[cb[1L, ]], "~~", ex[cb[2L, ]])
  }
  # the three disturbance pairs, in structural order
  pairs <- list(c(m1, m2), c(m1, y), c(m2, y))
  is_pair <- lapply(pairs, function(p) {
    tab$op == "~~" & ((tab$lhs == p[1L] & tab$rhs == p[2L]) | (tab$lhs == p[2L] & tab$rhs == p[1L]))
  })
  stray <- tab$op == "~~" & tab$lhs != tab$rhs & !pair & !Reduce(`|`, is_pair)
  if (any(stray) || any(vapply(is_pair, sum, 0L) > 1L)) {
    .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  }
  free_pair <- vapply(is_pair, function(i) {
    any(i & (is.na(tab$fixed) | (!is.na(tab$fixed) & tab$fixed != 0) | nzchar(tab$label)))
  }, logical(1))
  if (any(free_pair)) .sem_fiml_diagnostic("correlated serial disturbances are not supported in FIML")
  labels <- vapply(pairs, function(p) paste0(p[1L], " ~~ 0*", p[2L]), character(1))
  missing_zeros <- .sem_fiml_ser_missing_zeros(vapply(is_pair, sum, 0L), labels)
  if (length(missing_zeros)) {
    .sem_fiml_diagnostic(paste0(
      "FIML serial mediation needs the independent disturbances written as ", paste(missing_zeros, collapse = ", ")
    ))
  }
  keys[Reduce(`|`, is_pair)] <- "disturbance"
  required <- c(
    paste(m1, "~", e), paste(m2, "~", m1), if (variant == "saturated") paste(m2, "~", x),
    if (k > 0L) paste(m2, "~", z),
    if (variant == "saturated") paste(y, "~", m1), paste(y, "~", m2), if (k > 0L) paste(y, "~", z), exo_cov
  )
  cp <- paste(y, "~", x)
  obs <- c(x, z, m1, m2, y)
  allowed <- c(required, cp, "disturbance", paste(obs, "~~", obs), paste(obs, "~1", ""))
  if (anyDuplicated(keys[keys != "disturbance"]) || any(!keys %in% allowed)) {
    .sem_fiml_diagnostic("unsupported FIML topology or correlated disturbances")
  }
  if (!all(required %in% keys)) {
    .sem_fiml_diagnostic("unsupported FIML topology: serial mediation needs M1 ~ X, M2 ~ M1 and Y ~ M2")
  }
  is_cp <- keys == cp
  is_dist <- keys == "disturbance"
  if (any(!is.na(tab$fixed) & !((is_cp | is_dist) & tab$fixed == 0 & !is.na(tab$fixed)))) {
    .sem_fiml_diagnostic("only the direct path and the disturbance covariances may be fixed, exactly at zero, in FIML")
  }
  direct <- any(is_cp & is.na(tab$fixed))
  conv <- .sem_to_ram(tab)
  q_expected <- (if (variant == "saturated") 13L else 11L) + 5L * k + choose(k + 1L, 2L) + direct
  if (conv$ram$q != q_expected) .sem_fiml_diagnostic("FIML does not support parameter ties")
  tables <- .sem_fiml_tables_ser(direct, k, variant == "saturated")
  # The data name of every kernel variable; the canonical key of every free table entry follows from it.
  kernel <- stats::setNames(c(x, z, m1, m2, y), tables$vars)
  free <- function(tb) is.na(tb$value)
  canonical <- c(
    paste(kernel[tables$a$row[free(tables$a)]], "~", kernel[tables$a$col[free(tables$a)]]),
    paste(kernel[tables$s$row], "~~", kernel[tables$s$col]),
    paste(kernel[tables$m$row], "~1", "")
  )
  labels <- c(tables$a$label[free(tables$a)], tables$s$label, tables$m$label)
  stopifnot(length(labels) == length(canonical), length(labels) == conv$ram$q, all(canonical %in% keys))
  map <- stats::setNames(conv$ram$par_names[conv$par_map[match(canonical, keys)]], labels)
  out <- list(
    parsed = parsed, conv = conv, vars = stats::setNames(c(x, m1, m2, y), c("X", "M1", "M2", "Y")), direct = direct,
    map = map, mediators = stats::setNames(c(m1, m2), c("M1", "M2")), structure = "serial", variant = variant
  )
  if (k > 0L) out$covariate <- stats::setNames(z, .sem_fiml_cov_names(k)$z)
  out
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
      serial <- identical(spec$structure, "serial")
      if (serial && !isTRUE(.fiml_serial_shape_admitted(spec$variant, length(spec$covariate)))) {
        .sem_fiml_diagnostic(paste0(
          "serial FIML is not yet available: the ", spec$variant, " serial syntax is valid but bounded FIML serial ",
          "fits are withheld until their own admission"
        ))
      }
      # data columns in kernel order: X, [Z], M, Y (M1, M2 for the parallel form)
      model_vars <- if (is.null(spec$covariate)) {
        spec$vars
      } else {
        c(spec$vars["X"], spec$covariate, spec$vars[names(spec$vars) != "X"])
      }
      if (!all(model_vars %in% names(data))) .sem_fiml_diagnostic("FIML model variables are absent from data")
      d <- data[, model_vars, drop = FALSE]
      if (!all(vapply(d, function(x) is.numeric(x) && !is.object(x), logical(1)))) {
        .sem_fiml_diagnostic("FIML model variables must be numeric continuous columns")
      }
      z <- as.matrix(d)
      colnames(z) <- names(model_vars)
      if (serial) {
        tables <- .sem_fiml_tables_ser(spec$direct, length(spec$covariate), identical(spec$variant, "saturated"))
        prepared <- .sem_fiml_prepare_core(z, tables, direct = spec$direct)
        stage <- "numerical"
        candidate <- .sem_fiml_solve(prepared)
      } else if (!is.null(spec$mediators)) {
        tables <- .sem_fiml_tables_med(
          length(spec$mediators), spec$direct, isTRUE(spec$residual_covariance), length(spec$covariate)
        )
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
      if (serial) {
        likelihood$structure <- "serial"
        likelihood$variant <- spec$variant
      }
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
  # serial before parallel: both have two mediators, and share the strings `a2` and `b1` with different roles
  if (identical(object@internals$likelihood$structure, "serial")) {
    return(.sem_fiml_extract_serial(object, treatment, mediator, args))
  }
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
  covariate <- ctx0$covariate
  # As in the one-mediator covariate form, any exogenous variable may be the treatment unless a Y path is fixed at zero
  # (that variable is the fit's treatment `X`; a covariate's outcome path must be complete).
  treatment_ok <- identical(treatment, unname(v["X"])) ||
    (!is.null(covariate) && spec$direct && is.character(treatment) && length(treatment) == 1L &&
       treatment %in% covariate)
  if (length(setdiff(names(args), allowed)) || !treatment_ok ||
        !is.character(mediator) || length(mediator) != length(meds) || !setequal(mediator, meds) ||
        (!is.null(args$outcome) && !identical(args$outcome, unname(v["Y"]))) ||
        (!is.null(args$standardized) && !identical(args$standardized, FALSE)) ||
        (!is.null(args$structure) && !args$structure %in% c("auto", "parallel")) ||
        (!is.null(args$decomposition) && !args$decomposition %in% c("auto", "two_way"))) {
    stop(structure(
      class = c("medfit_error_fiml_extract_unsupported", "error", "condition"),
      list(message = paste0(
        "FIML extraction supports only the fitted unstandardized two-way parallel mediation naming both mediators"
      ), call = NULL)
    ))
  }
  map <- spec$map
  i <- match(mediator, meds)
  k <- length(i)
  a_aliases <- map[paste0("a", i)]
  b_aliases <- map[paste0("b", i)]
  # A covariate named the treatment: its paths to the mediators and to Y take the roles of a_j and c_prime.
  as_covariate <- !is.null(covariate) && !identical(treatment, unname(v["X"]))
  iz <- match(treatment, covariate)
  if (as_covariate) {
    sfx <- .sem_fiml_cov_names(length(covariate))$sfx
    a_aliases <- map[paste0("gm", i, "z", iz)]
  }
  roles <- c(
    stats::setNames(unname(a_aliases), paste0("a", seq_len(k))),
    stats::setNames(unname(b_aliases), paste0("b", seq_len(k))),
    c_prime = if (as_covariate) {
      unname(map[paste0("gy", sfx[iz])])
    } else if (spec$direct) {
      unname(map["cp"])
    } else {
      NA_character_
    }
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
  if (as_covariate) {
    ctx$variables["X"] <- treatment
    ctx$covariate <- replace(covariate, iz, unname(v["X"]))
  }
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

# Two serial mediators, both variants, no covariates (FI-G3 slices S1b and S2). Both mediators are named in the fitted
# (structural) order; the reversed order asks for a different model (M2 -> M1) and is refused with the fitted order
# named. The six (saturated) or four (pure chain) path estimates and their covariance are the fitted
# observed-information block, so every cross-path term (Cov(a, d1), Cov(d1, b), Cov(a2, d1), Cov(b1, b), ...) is kept,
# unlike the separate-regression lm/glm route; a fixed-zero or omitted direct path is a zero row and column.
.sem_fiml_extract_serial <- function(object, treatment, mediator, args) {
  ctx0 <- object@internals$likelihood
  v <- ctx0$variables
  meds <- unname(ctx0$mediators)
  refuse <- function(message) {
    stop(structure(
      class = c("medfit_error_fiml_extract_unsupported", "error", "condition"),
      list(message = message, call = NULL)
    ))
  }
  if (!.fiml_serial_extract_supported(ctx0$variant, length(ctx0$covariate))) {
    refuse("FIML extraction of serial mediation fits is not yet available")
  }
  ok_mediators <- is.character(mediator) && length(mediator) == 2L && setequal(mediator, meds)
  if (ok_mediators && !identical(mediator, meds)) {
    refuse(paste0(
      "FIML extraction of serial mediation needs the mediators in the fitted order (", paste(meds, collapse = ", "),
      "); the reversed order is a different model"
    ))
  }
  allowed <- c("outcome", "standardized", "structure", "decomposition")
  if (length(setdiff(names(args), allowed)) || !identical(treatment, unname(v["X"])) || !ok_mediators ||
        (!is.null(args$outcome) && !identical(args$outcome, unname(v["Y"]))) ||
        (!is.null(args$standardized) && !identical(args$standardized, FALSE)) ||
        (!is.null(args$structure) && !args$structure %in% c("auto", "serial")) ||
        (!is.null(args$decomposition) && !args$decomposition %in% c("auto", "two_way"))) {
    refuse(paste0(
      "FIML extraction supports only the fitted unstandardized two-way serial mediation naming both mediators in order"
    ))
  }
  spec <- .sem_fiml_model(object@model)
  map <- spec$map
  par <- function(label) unname(map[[label]])
  # The kernel label of each role; the fitted parameter names may be user labels, so roles are read by topology.
  # The pure chain has no a2 and b1 rows at all (structural zeros): its aliases are the four paths a, d1, b, c_prime.
  chain <- identical(ctx0$variant, "chain")
  roles <- c(
    a = par("a"), if (!chain) c(a2 = par("a2")), d1 = par("d1"), if (!chain) c(b1 = par("b1")), b = par("b"),
    c_prime = if (spec$direct) par("cp") else NA_character_
  )
  present <- !is.na(roles)
  estimates <- stats::setNames(numeric(length(roles)), names(roles))
  estimates[present] <- object@theta[roles[present]]
  V <- matrix(0, length(roles), length(roles), dimnames = list(names(roles), names(roles)))
  V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]
  sigma <- function(label) sqrt(unname(object@theta[par(label)]))
  x <- unname(v["X"])
  y <- unname(v["Y"])
  ctx <- ctx0
  ctx$source_theta <- object@theta
  ctx$source_vcov <- object@vcov
  ctx$source_roles <- roles
  ctx$source_hash <- rlang::hash(list(ctx$source_theta, ctx$source_vcov, ctx$source_roles))
  ctx$data_hash <- rlang::hash(object@data)
  a_path <- unname(estimates[["a"]])
  d_path <- unname(estimates[["d1"]])
  b_path <- unname(estimates[["b"]])
  c_prime <- unname(estimates[["c_prime"]])
  ctx$parameter_hash <- rlang::hash(list(estimates, V, a_path, d_path, b_path, c_prime, ctx0$variant))
  FIMLSerialMediationData(
    a_path = a_path, d_path = d_path, b_path = b_path, c_prime = c_prime, estimates = estimates, vcov = V,
    sigma_mediators = c(sigma("vm1"), sigma("vm2")), sigma_y = sigma("vy"),
    treatment = x, mediators = meds, outcome = y,
    mediator_predictors = list(x, if (chain) meds[1L] else c(meds[1L], x)),
    outcome_predictors = if (chain) c(meds[2L], x) else c(meds, x),
    data = object@data, n_obs = object@n_obs, converged = TRUE, source_package = "medfit", fit_context = ctx,
    variant = ctx0$variant
  )
}

# Exact origin: the NIE delta gradient (b, a for one mediator; b_j, a_j for the sum over parallel mediators) is zero.
# Scalar by contract: it is read inside scalar `if (... && ...)` by the simple and parallel callers. A serial FIML
# object has two effects with their own rules and uses `.sem_fiml_origin_effects()`; it is FALSE here.
.sem_fiml_origin <- function(x) {
  if (!.sem_fiml_is(x)) return(FALSE)
  if (S7::S7_inherits(x, FIMLSerialMediationData)) return(FALSE)
  if (S7::S7_inherits(x, FIMLParallelMediationData)) return(all(x@a_paths == 0) && all(x@b_paths == 0))
  S7::S7_inherits(x, MediationData) && x@a_path == 0 && x@b_path == 0
}

# Per-effect exact origin (FI-G3, decision Q8): a named logical over the effects whose delta gradient can vanish.
# Chain `nie` = a d1 b has gradient (d1 b, a b, a d1), zero exactly when AT LEAST TWO of a, d1, b are 0 (one zero factor
# leaves a nonzero gradient). Saturated `nie_total` = a d1 b + a2 b + a b1 has gradient
# (d1 b + b1, b, a b, a, a d1 + a2), zero exactly when a = a2 = b = b1 = 0 (d1 free). In the pure chain `nie_total` is
# the chain effect, so both follow the one chain rule. `te` and `nde` (gradient 1 on c_prime) are never withheld.
# Every other class has the scalar rule for `nie` only.
.sem_fiml_origin_effects <- function(x) {
  if (!S7::S7_inherits(x, FIMLSerialMediationData)) return(c(nie = .sem_fiml_origin(x)))
  e <- x@estimates
  chain_zero <- sum(c(e[["a"]], e[["d1"]], e[["b"]]) == 0) >= 2L
  if (identical(x@variant, "chain")) return(c(nie = chain_zero, nie_total = chain_zero))
  c(nie = chain_zero, nie_total = all(c(e[["a"]], e[["a2"]], e[["b"]], e[["b1"]]) == 0))
}

# The note of each withheld effect, named by effect.
.sem_fiml_origin_notes <- function(withheld) {
  notes <- c(
    nie = "NIE inference unavailable: zero delta gradient",
    nie_total = "NIE total inference unavailable: zero delta gradient"
  )
  notes[names(withheld)[withheld]]
}

# The path rows an extracted serial FIML object reports (Q4: every estimated path; Q12: `c_prime` always listed, value 0
# and SE 0 when it is fixed), and the `@vcov` alias of each row.
.sem_fiml_ser_paths <- function(x) {
  e <- x@estimates
  if (identical(x@variant, "chain")) {
    return(c(a = e[["a"]], d = e[["d1"]], b = e[["b"]], c_prime = e[["c_prime"]]))
  }
  c(a = e[["a"]], a2 = e[["a2"]], d = e[["d1"]], b1 = e[["b1"]], b = e[["b"]], c_prime = e[["c_prime"]])
}
.sem_fiml_ser_alias <- function(x) {
  if (identical(x@variant, "chain")) c("a", "d1", "b", "c_prime") else c("a", "a2", "d1", "b1", "b", "c_prime")
}

# `coef(type = "paths")` and `summary()` of a serial FIML object list every estimated path (Q4), not the base four.
.sem_fiml_ser_coef_paths <- function(x) .sem_fiml_ser_paths(x)
.sem_fiml_ser_summary_paths <- function(x) {
  c(
    .sem_fiml_ser_paths(x), indirect = x@a_path * prod(x@d_path) * x@b_path,
    indirect_total = as.numeric(nie(x, type = "total"))
  )
}
.sem_fiml_ser_summary <- function(object) {
  structure(
    list(
      paths = .sem_fiml_ser_summary_paths(object), mediators = object@mediators,
      variables = c(treatment = object@treatment, outcome = object@outcome),
      n_mediators = length(object@mediators), n_obs = object@n_obs, converged = object@converged,
      source_package = object@source_package, estimates = object@estimates, vcov = object@vcov,
      sigma_mediators = object@sigma_mediators, sigma_y = object@sigma_y, fit_context = object@fit_context
    ),
    class = "summary_SerialMediationData"
  )
}

# The four effects `confint(parm = "effects")` reports for a serial FIML object (`nie_total` has its own row).
.sem_fiml_ser_effect_estimates <- function(object) {
  c(
    nie = unname(nie(object)), nie_total = unname(nie(object, type = "total")),
    nde = unname(nde(object)), te = unname(te(object))
  )
}
