# Frozen copy of R/extract-lavaan.R as it stood before the accessor-seam refactor
# (S10, PR 3). Every function carries a `.frozen_` prefix. test-extract-seam.R
# extracts the same lavaan fits through this copy and through the seam and
# requires identical results, so this file must not be edited to follow later
# changes to the extractor; it is deleted when the seam is retired.

# S7 Method for Extracting Mediation Structure from lavaan Models
#
# This file implements extract_mediation() method for lavaan SEM models.
#
# The extraction supports simple mediation patterns:
#   X -> M -> Y  # nolint: commented_code_linter.
# where the lavaan model typically specifies:
#   M ~ a*X      # nolint: commented_code_linter.
#   Y ~ b*M + cp*X  # nolint: commented_code_linter.
#
# Note: This method is registered dynamically in zzz.R when lavaan is available

.frozen_extract_mediation_lavaan <- function(object,
                                     treatment,
                                     mediator,
                                     outcome = NULL,
                                     a_label = "a",
                                     b_label = "b",
                                     cp_label = "cp",
                                     standardized = FALSE,
                                     structure = c("auto", "serial", "parallel"),
                                     decomposition = c("auto", "four_way", "two_way"),
                                     interaction = NULL,
                                     m_star = 0,
                                     ...) {

  # --- Check lavaan is available ---
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for this method but is not installed.",
         call. = FALSE)
  }

  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  checkmate::assert_string(treatment, .var.name = "treatment")
  # `mediator` may be a scalar (simple X -> M -> Y) or an ordered character
  # vector of length >= 2 (serial X -> M1 -> M2 -> ... -> Y). The arity selects
  # both the extraction path and the return type (MediationData for a scalar,
  # SerialMediationData for a vector).
  checkmate::assert_character(mediator, min.len = 1, any.missing = FALSE,
                              .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  checkmate::assert_flag(standardized, .var.name = "standardized")
  structure <- match.arg(structure)
  decomposition <- match.arg(decomposition)

  # --- Multi-mediator: dispatch on mediator arity AND structure -------------
  # The lavaan S7 method dispatches on object class only, so the simple-vs-
  # serial-vs-parallel decision is made here. With >= 2 mediators and
  # structure = "auto" (default), infer serial vs parallel from the single SEM's
  # regression rows (mirrors the lm/glm engine's `.classify_multimediator_*`).
  if (length(mediator) > 1L) {
    if (!missing(m_star)) .stop_on_unused_m_star(treatment, mediator[1L])
    .stop_on_multimediator_products(
      .frozen_find_product_terms_lavaan(object, c(treatment, mediator), interaction)
    )
    if (structure == "auto") {
      structure <- .frozen_classify_multimediator_structure_lavaan(object, mediator,
                                                            standardized)
    }
    if (structure == "serial") {
      return(.frozen_extract_serial_mediation_lavaan(
        object,
        treatment    = treatment,
        mediators    = mediator,
        outcome      = outcome,
        standardized = standardized,
        ...
      ))
    }
    return(.frozen_extract_parallel_mediation_lavaan(
      object,
      treatment    = treatment,
      mediators    = mediator,
      outcome      = outcome,
      standardized = standardized,
      ...
    ))
  }

  # --- Single mediator with treatment x mediator interaction (Extension B) ---
  # In lavaan the interaction enters as a product predictor of the outcome
  # (a data column the user multiplies, e.g. Y ~ b*M + cp*X + t3*XM). Detect it
  # by the explicit `interaction` name or an X:M / M:X term, then route to the
  # four-way worker. Falls through to the standard simple path when absent.
  int_term <- .frozen_find_interaction_term_lavaan(object, treatment, mediator,
                                            interaction, standardized)
  if (decomposition == "four_way" && is.na(int_term)) {
    stop(
      paste0("decomposition = 'four_way' requires an interaction term in the ",
             "outcome model. Pass its name via `interaction = ` (the product ",
             "variable, e.g. 'XM') or include an '", treatment, ":", mediator,
             "' term."),
      call. = FALSE
    )
  }
  if (decomposition != "two_way" && !is.na(int_term)) {
    return(.frozen_extract_interaction_mediation_lavaan(
      object,
      treatment    = treatment,
      mediator     = mediator,
      int_term     = int_term,
      outcome      = outcome,
      m_star       = m_star,
      standardized = standardized
    ))
  }
  if (!missing(m_star)) .stop_on_unused_m_star(treatment, mediator)

  # --- Simple mediation (scalar mediator): path-label args apply ------------
  checkmate::assert_string(a_label, .var.name = "a_label")
  checkmate::assert_string(b_label, .var.name = "b_label")
  checkmate::assert_string(cp_label, .var.name = "cp_label")

  # --- Extract Parameter Estimates ---

  # Get parameter estimates table
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }

  # --- Try to Extract Paths by Label First ---

  # Look for labeled paths
  a_row <- param_table[param_table$label == a_label, ]
  b_row <- param_table[param_table$label == b_label, ]
  cp_row <- param_table[param_table$label == cp_label, ]

  paths_found_by_label <- nrow(a_row) == 1 && nrow(b_row) == 1 && nrow(cp_row) == 1

  if (paths_found_by_label) {
    # Extract from labeled paths
    a_path <- a_row[[est_col]]
    b_path <- b_row[[est_col]]
    c_prime <- cp_row[[est_col]]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      outcome <- b_row$lhs[1]
    }
  } else {
    # Fall back to extracting by variable names
    # Find a path: mediator ~ treatment
    a_row <- param_table[param_table$lhs == mediator &
                           param_table$op == "~" &
                           param_table$rhs == treatment, ]

    if (nrow(a_row) == 0) {
      stop(sprintf(
        "Could not find a path (treatment -> mediator). Expected '%s ~ %s'",
        mediator, treatment
      ), call. = FALSE)
    }

    a_path <- a_row[[est_col]][1]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      # Find equations where mediator is a predictor
      mediator_effects <- param_table[param_table$op == "~" &
                                        param_table$rhs == mediator, ]
      if (nrow(mediator_effects) > 0) {
        outcome <- mediator_effects$lhs[1]
      } else {
        stop("Could not auto-detect outcome variable. Please specify 'outcome' argument.",
             call. = FALSE)
      }
    }

    # Find b path: outcome ~ mediator
    b_row <- param_table[param_table$lhs == outcome &
                           param_table$op == "~" &
                           param_table$rhs == mediator, ]

    if (nrow(b_row) == 0) {
      stop(sprintf(
        "Could not find b path (mediator -> outcome). Expected '%s ~ %s'",
        outcome, mediator
      ), call. = FALSE)
    }

    b_path <- b_row[[est_col]][1]

    # Find c' path: outcome ~ treatment
    cp_row <- param_table[param_table$lhs == outcome &
                            param_table$op == "~" &
                            param_table$rhs == treatment, ]

    if (nrow(cp_row) == 0) {
      # c' might be zero (full mediation) or not in model
      # Set to 0 if not found
      c_prime <- 0
      warning("Direct effect (c' path) not found in model. Setting to 0.",
              call. = FALSE)
    } else {
      c_prime <- cp_row[[est_col]][1]
    }
  }

  # --- Extract All Parameters and Variance-Covariance Matrix ---

  # Get all free parameter estimates
  all_coef <- lavaan::coef(object)

  # Get variance-covariance matrix
  vcov_mat <- lavaan::vcov(object)

  # Create estimates vector with named elements
  estimates <- all_coef

  # Add convenient aliases for key paths (only if not already present)
  # Track which aliases we're adding (not overwriting)
  aliases_to_add <- character(0)
  if (!("a" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "a")
  }
  if (!("b" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "b")
  }
  if (!("c_prime" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "c_prime")
  }

  # Add aliases
  estimates["a"] <- a_path
  estimates["b"] <- b_path
  estimates["c_prime"] <- c_prime

  # Name-based consumers (probmed's parametric bootstrap) look the three paths
  # up as m_<treatment>, y_<mediator> and y_<treatment>, the names the glm
  # route gives its coefficients. Each is a second name for a path already
  # aliased above; they are appended after it, so no existing row moves.
  probmed_names <- .frozen_lavaan_probmed_alias_names(
    object, treatment, mediator, outcome, standardized
  )
  aliases_to_add <- c(
    aliases_to_add,
    setdiff(unname(probmed_names), c(names(all_coef), aliases_to_add))
  )
  estimates[unname(probmed_names)] <- c(a = a_path, b = b_path, c_prime = c_prime)[names(probmed_names)]

  # --- Resolve each alias to its source parameter in the original vcov ---
  #
  # Mapping the alias to a source *index* lets us copy the FULL covariance
  # structure (variances AND off-diagonal covariances), not just the diagonal
  # variance. This is essential: in single-equation SEM the a/b/c' paths are
  # estimated jointly and their pairwise covariances are non-zero.
  #
  # The source is the same parameter-table row each estimate was read from
  # (a_row / b_row / cp_row), not a path rebuilt from the variable-name
  # arguments: when the paths were found by label, those arguments need not
  # name the labeled paths. An absent c' row (zero rows) gives NA.
  source_idx <- .frozen_lavaan_alias_source_idx(
    object,
    lhs = c(a = a_row$lhs[1], b = b_row$lhs[1], c_prime = cp_row$lhs[1]),
    rhs = c(a = a_row$rhs[1], b = b_row$rhs[1], c_prime = cp_row$rhs[1]),
    op = c(a_row$op[1], b_row$op[1], cp_row$op[1]),
    orig_names = names(all_coef)
  )
  source_idx <- c(
    source_idx,
    stats::setNames(source_idx[names(probmed_names)], unname(probmed_names))
  )

  # Expand vcov so each NEW alias carries the FULL covariance row/column of its
  # source parameter (preserving off-diagonals such as cov(a, b), which are
  # non-zero in single-equation SEM). Shared with the lm/glm extractor so the
  # two engines cannot drift in how they assemble the alias block.
  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat,
    source_idx = source_idx,
    aliases_to_add = aliases_to_add
  )

  # --- Extract Residual Variances ---

  # In lavaan, error variances are estimated parameters
  # Look for variance of mediator and outcome residuals

  sigma_m <- NULL
  sigma_y <- NULL

  # Mediator residual variance
  m_var_row <- param_table[param_table$lhs == mediator &
                             param_table$op == "~~" &
                             param_table$rhs == mediator, ]
  if (nrow(m_var_row) > 0) {
    m_var <- m_var_row[[est_col]][1]
    if (m_var > 0) {
      sigma_m <- sqrt(m_var)
    }
  }

  # Outcome residual variance
  y_var_row <- param_table[param_table$lhs == outcome &
                             param_table$op == "~~" &
                             param_table$rhs == outcome, ]
  if (nrow(y_var_row) > 0) {
    y_var <- y_var_row[[est_col]][1]
    if (y_var > 0) {
      sigma_y <- sqrt(y_var)
    }
  }

  # --- Get Data ---

  # Try to get data from lavaan object
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    # lavaan may return a matrix; convert to data.frame if possible
    if (is.matrix(d)) {
      as.data.frame(d)
    } else if (is.data.frame(d)) {
      d
    } else {
      # If it's something else (like numeric), return NULL
      NULL
    }
  }, error = function(e) {
    NULL
  })

  # Get sample size
  # Multiple groups: the total
  n_obs <- .frozen_lavaan_n_obs(object)

  # --- Get Predictor Names ---

  # Mediator predictors: variables that predict the mediator
  m_predictors <- param_table[param_table$lhs == mediator &
                                param_table$op == "~", "rhs"]

  # Outcome predictors: variables that predict the outcome
  y_predictors <- param_table[param_table$lhs == outcome &
                                param_table$op == "~", "rhs"]

  # --- Check Convergence ---

  converged <- lavaan::lavInspect(object, "converged")

  # --- Create MediationData Object ---

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
    sigma_m = sigma_m,
    sigma_y = sigma_y,
    # SEM here estimates continuous (Gaussian) responses on the identity scale.
    family_m = stats::gaussian(),
    family_y = stats::gaussian(),
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = m_predictors,
    outcome_predictors = y_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}


.frozen_extract_serial_mediation_lavaan <- function( # nolint: object_length_linter.
  object,
  treatment,
  mediators,
  outcome = NULL,
  standardized = FALSE,
  ...) {

  # --- Input validation ---
  checkmate::assert_character(mediators, min.len = 2, unique = TRUE,
                              any.missing = FALSE, .var.name = "mediators")

  k <- length(mediators)

  # --- Parameter table & raw coefficient vector ---
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }
  all_coef <- lavaan::coef(object)
  vcov_mat <- lavaan::vcov(object)

  # Pull a single regression coefficient (`lhs ~ rhs`) from the parameter
  # table; return NA so callers decide whether the path is required.
  get_path <- function(lhs, rhs) {
    row <- param_table[param_table$lhs == lhs &
                         param_table$op == "~" &
                         param_table$rhs == rhs, ]
    if (nrow(row) == 0) return(NA_real_)
    row[[est_col]][1]
  }

  # --- Structural paths ---
  # Validate the chain links BEFORE outcome auto-detection so a missing link
  # reports the specific path (e.g. the a path), not a vague outcome error.

  # a path: treatment predicts the first mediator.
  a_path <- get_path(mediators[1], treatment)
  if (is.na(a_path)) {
    stop(sprintf("Could not find a path (%s ~ %s).", mediators[1], treatment),
         call. = FALSE)
  }

  # d paths: each mediator predicts the next; k - 1 links in chain order.
  d_path <- vapply(seq_len(k - 1L), function(i) {
    val <- get_path(mediators[i + 1L], mediators[i])
    if (is.na(val)) {
      stop(sprintf("Could not find d path (%s ~ %s).",
                   mediators[i + 1L], mediators[i]), call. = FALSE)
    }
    val
  }, numeric(1))

  # --- Auto-detect the outcome (variable predicted by the last mediator) ---
  if (is.null(outcome)) {
    is_pred <- param_table$op == "~" & param_table$rhs == mediators[k]
    # A well-formed serial chain has the last mediator point only at the
    # outcome; exclude any mediator-valued lhs defensively.
    last_med_effects <- param_table[is_pred & !param_table$lhs %in% mediators, ]
    if (nrow(last_med_effects) == 0) {
      stop(sprintf(
        paste0("Could not auto-detect outcome: no regression has '%s' as a ",
               "predictor. Please specify the 'outcome' argument."),
        mediators[k]
      ), call. = FALSE)
    }
    outcome <- last_med_effects$lhs[1]
  }
  checkmate::assert_string(outcome, .var.name = "outcome")

  # b path: last mediator predicts the outcome.
  b_path <- get_path(outcome, mediators[k])
  if (is.na(b_path)) {
    stop(sprintf("Could not find b path (%s ~ %s).", outcome, mediators[k]),
         call. = FALSE)
  }

  # c-prime path: direct treatment-to-outcome effect (may be absent).
  c_prime <- get_path(outcome, treatment)
  if (is.na(c_prime)) {
    c_prime <- 0
    warning("Direct effect (c-prime path) not found in model. Setting to 0.",
            call. = FALSE)
  }

  # --- Estimates + vcov with stable structural aliases ---
  # Mirror the simple-mediation extractor: expose named aliases
  # (a, d1..d{k-1}, b, c_prime) alongside lavaan's raw parameter vector, and
  # copy the FULL covariance row/column of each source parameter so the
  # off-diagonal covariances between chain paths are preserved.
  d_names <- paste0("d", seq_len(k - 1L))
  alias_var <- c(
    a = paste0(mediators[1], "~", treatment),
    stats::setNames(paste0(mediators[-1L], "~", mediators[-k]), d_names),
    b = paste0(outcome, "~", mediators[k]),
    c_prime = paste0(outcome, "~", treatment)
  )
  alias_val <- c(
    a = a_path,
    stats::setNames(d_path, d_names),
    b = b_path,
    c_prime = c_prime
  )

  # Paths that skip a chain link (X -> Mj, Mi -> Mj for j > i + 1, Mi -> Y for
  # i < k) are aliased too, so te() can sum every X -> Y path. Resolved here
  # from the parameter table, since user labels rename them in coef().
  skip <- .serial_edges(k)
  skip <- skip[!skip$chain & skip$alias != "c_prime", , drop = FALSE]
  node_names <- c(treatment, mediators, outcome)
  for (r in seq_len(nrow(skip))) {
    lhs <- node_names[skip$to[r] + 1L]
    rhs <- node_names[skip$from[r] + 1L]
    val <- get_path(lhs, rhs)
    if (is.na(val)) next
    alias_var[skip$alias[r]] <- paste0(lhs, "~", rhs)
    alias_val[skip$alias[r]] <- val
  }

  estimates <- all_coef
  aliases_to_add <- names(alias_var)[!names(alias_var) %in% names(estimates)]
  for (al in names(alias_var)) estimates[al] <- alias_val[[al]]

  source_idx <- .frozen_lavaan_alias_source_idx_from_names(object, alias_var, names(all_coef))

  # Same full-row/column alias expansion as the simple path and the lm/glm
  # extractor (shared helper), so the serial chain's off-diagonal covariances
  # -- needed for serial indirect-effect SEs -- are preserved.
  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat,
    source_idx = source_idx,
    aliases_to_add = aliases_to_add
  )

  # --- Residual standard deviations (sqrt of estimated error variances) ---
  get_resid_sd <- function(v) {
    row <- param_table[param_table$lhs == v &
                         param_table$op == "~~" &
                         param_table$rhs == v, ]
    if (nrow(row) == 0) return(NA_real_)
    val <- row[[est_col]][1]
    if (is.na(val) || val < 0) return(NA_real_)
    sqrt(val)
  }
  sigma_mediators <- unname(vapply(mediators, get_resid_sd, numeric(1)))
  if (all(is.na(sigma_mediators))) sigma_mediators <- NULL
  sigma_y <- get_resid_sd(outcome)
  if (is.na(sigma_y)) sigma_y <- NULL

  # --- Predictor bookkeeping ---
  mediator_predictors <- lapply(mediators, function(m) {
    param_table[param_table$lhs == m & param_table$op == "~", "rhs"]
  })
  outcome_predictors <- param_table[param_table$lhs == outcome &
                                      param_table$op == "~", "rhs"]

  # --- Data, sample size, convergence ---
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    if (is.matrix(d)) as.data.frame(d) else if (is.data.frame(d)) d else NULL
  }, error = function(e) NULL)

  n_obs <- .frozen_lavaan_n_obs(object)

  converged <- lavaan::lavInspect(object, "converged")

  # --- Assemble SerialMediationData ---
  SerialMediationData(
    a_path = a_path,
    d_path = d_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
    sigma_mediators = sigma_mediators,
    sigma_y = sigma_y,
    treatment = treatment,
    mediators = mediators,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}


.frozen_classify_multimediator_structure_lavaan <- function(object, mediators, # nolint: object_length_linter.
                                                     standardized = FALSE) {
  param_table <- tryCatch(
    if (standardized) lavaan::standardizedSolution(object)
    else lavaan::parameterEstimates(object),
    error = function(e) NULL
  )
  if (is.null(param_table)) return("serial")

  reg <- param_table[param_table$op == "~", , drop = FALSE]
  # Any mediator regressed on another mediator => chain-like => serial.
  med_on_med <- reg$lhs %in% mediators & reg$rhs %in% mediators
  if (any(med_on_med)) return("serial")

  # Positive parallel evidence: some non-mediator outcome equation carries ALL
  # mediators as predictors (Y ~ X + M1 + ... + Mk). A serial outcome equation
  # holds only the last mediator, so it fails this test and defaults to serial.
  outcome_candidates <- unique(reg$lhs[reg$rhs %in% mediators &
                                         !reg$lhs %in% mediators])
  for (o in outcome_candidates) {
    if (all(mediators %in% reg$rhs[reg$lhs == o])) return("parallel")
  }

  "serial"
}


.frozen_extract_parallel_mediation_lavaan <- function( # nolint: object_length_linter.
  object,
  treatment,
  mediators,
  outcome = NULL,
  standardized = FALSE,
  ...) {

  # --- Input validation ---
  checkmate::assert_character(mediators, min.len = 2, unique = TRUE,
                              any.missing = FALSE, .var.name = "mediator")

  k <- length(mediators)

  # --- Parameter table & raw coefficient vector ---
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }
  all_coef <- lavaan::coef(object)
  vcov_mat <- lavaan::vcov(object)

  # Pull a single regression coefficient (`lhs ~ rhs`) from the parameter table;
  # return NA so callers decide whether the path is required.
  get_path <- function(lhs, rhs) {
    row <- param_table[param_table$lhs == lhs &
                         param_table$op == "~" &
                         param_table$rhs == rhs, ]
    if (nrow(row) == 0) return(NA_real_)
    row[[est_col]][1]
  }

  # --- a paths: treatment predicts each mediator (validated up front) ---
  a_paths <- vapply(seq_len(k), function(j) {
    val <- get_path(mediators[j], treatment)
    if (is.na(val)) {
      stop(sprintf("Could not find a path (%s ~ %s).", mediators[j], treatment),
           call. = FALSE)
    }
    val
  }, numeric(1))

  # --- Auto-detect outcome: the common non-mediator predicted by a mediator ---
  if (is.null(outcome)) {
    is_pred <- param_table$op == "~" & param_table$rhs %in% mediators
    med_effects <- param_table[is_pred & !param_table$lhs %in% mediators, ]
    if (nrow(med_effects) == 0) {
      stop(sprintf(
        paste0("Could not auto-detect outcome: no regression has a mediator ",
               "(%s) as a predictor. Please specify the 'outcome' argument."),
        paste(mediators, collapse = ", ")
      ), call. = FALSE)
    }
    outcome <- med_effects$lhs[1]
  }
  checkmate::assert_string(outcome, .var.name = "outcome")

  # --- b paths: outcome regressed on each mediator ---
  b_paths <- vapply(seq_len(k), function(j) {
    val <- get_path(outcome, mediators[j])
    if (is.na(val)) {
      stop(sprintf("Could not find b path (%s ~ %s).", outcome, mediators[j]),
           call. = FALSE)
    }
    val
  }, numeric(1))

  # --- c-prime path: direct treatment-to-outcome effect (may be absent) ---
  c_prime <- get_path(outcome, treatment)
  if (is.na(c_prime)) {
    c_prime <- 0
    warning("Direct effect (c-prime path) not found in model. Setting to 0.",
            call. = FALSE)
  }

  # --- Estimates + vcov with interleaved structural aliases ----------------
  # Expose named aliases a1, b1, ..., ak, bk, c_prime (matching paths()) on top
  # of lavaan's raw parameter vector, and copy the FULL covariance row/column of
  # each source parameter. In single-equation SEM the system is estimated
  # jointly, so every off-diagonal (cov(a_j, b_j), cov(a_j, a_j'), cov(b_j, c'))
  # is real and is preserved here.
  alias_var <- character(0)
  alias_val <- numeric(0)
  for (j in seq_len(k)) {
    alias_var[paste0("a", j)] <- paste0(mediators[j], "~", treatment)
    alias_val[paste0("a", j)] <- a_paths[j]
    alias_var[paste0("b", j)] <- paste0(outcome, "~", mediators[j])
    alias_val[paste0("b", j)] <- b_paths[j]
  }
  alias_var["c_prime"] <- paste0(outcome, "~", treatment)
  alias_val["c_prime"] <- c_prime

  estimates <- all_coef
  aliases_to_add <- names(alias_var)[!names(alias_var) %in% names(estimates)]
  for (al in names(alias_var)) estimates[al] <- alias_val[[al]]

  source_idx <- .frozen_lavaan_alias_source_idx_from_names(object, alias_var, names(all_coef))

  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat,
    source_idx = source_idx,
    aliases_to_add = aliases_to_add
  )

  # --- Residual standard deviations (sqrt of estimated error variances) ---
  get_resid_sd <- function(v) {
    row <- param_table[param_table$lhs == v &
                         param_table$op == "~~" &
                         param_table$rhs == v, ]
    if (nrow(row) == 0) return(NA_real_)
    val <- row[[est_col]][1]
    if (is.na(val) || val < 0) return(NA_real_)
    sqrt(val)
  }
  sigma_mediators <- unname(vapply(mediators, get_resid_sd, numeric(1)))
  if (all(is.na(sigma_mediators))) sigma_mediators <- NULL
  sigma_y <- get_resid_sd(outcome)
  if (is.na(sigma_y)) sigma_y <- NULL

  # --- Predictor bookkeeping ---
  mediator_predictors <- lapply(mediators, function(m) {
    param_table[param_table$lhs == m & param_table$op == "~", "rhs"]
  })
  outcome_predictors <- param_table[param_table$lhs == outcome &
                                      param_table$op == "~", "rhs"]

  # --- Data, sample size, convergence ---
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    if (is.matrix(d)) as.data.frame(d) else if (is.data.frame(d)) d else NULL
  }, error = function(e) NULL)

  n_obs <- .frozen_lavaan_n_obs(object)

  converged <- lavaan::lavInspect(object, "converged")

  # --- Assemble ParallelMediationData ---
  ParallelMediationData(
    a_paths = a_paths,
    b_paths = b_paths,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
    sigma_mediators = sigma_mediators,
    sigma_y = sigma_y,
    treatment = treatment,
    mediators = mediators,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}


.frozen_find_product_terms_lavaan <- function(object, vars, interaction = NULL) {
  pt <- tryCatch(lavaan::parameterTable(object), error = function(e) NULL)
  if (is.null(pt)) return(character(0))
  reg <- pt[pt$op == "~", , drop = FALSE]
  is_prod <- vapply(strsplit(reg$rhs, ":", fixed = TRUE),
                    function(parts) length(parts) > 1L && any(parts %in% vars),
                    logical(1))
  if (length(interaction)) is_prod <- is_prod | reg$rhs %in% interaction
  # Return early: paste0() on zero-length vectors still yields ": ".
  if (!any(is_prod)) return(character(0))
  unique(paste0(reg$lhs[is_prod], ": ", reg$rhs[is_prod]))
}


.frozen_find_interaction_term_lavaan <- function(object, treatment, mediator, # nolint: object_length_linter.
                                          interaction = NULL,
                                          standardized = FALSE) {
  pt <- tryCatch(
    if (standardized) lavaan::standardizedSolution(object)
    else lavaan::parameterEstimates(object),
    error = function(e) NULL
  )
  if (is.null(pt)) return(NA_character_)
  reg <- pt[pt$op == "~", , drop = FALSE]
  outc <- unique(reg$lhs[reg$rhs == mediator & reg$lhs != mediator])
  if (length(outc) == 0) return(NA_character_)
  preds <- reg$rhs[reg$lhs == outc[1]]
  cand <- c(interaction, paste0(treatment, ":", mediator),
            paste0(mediator, ":", treatment))
  cand <- cand[!is.null(cand) & nzchar(cand)]
  hit <- cand[cand %in% preds]
  if (length(hit)) hit[1] else NA_character_
}


.frozen_extract_interaction_mediation_lavaan <- function( # nolint: object_length_linter.
  object,
  treatment,
  mediator,
  int_term,
  outcome = NULL,
  m_star = 0,
  standardized = FALSE) {

  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(int_term, .var.name = "interaction")
  checkmate::assert_number(m_star, .var.name = "m_star")

  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }
  all_coef <- lavaan::coef(object)
  vcov_mat <- lavaan::vcov(object)

  get_path <- function(lhs, rhs) {
    row <- param_table[param_table$lhs == lhs & param_table$op == "~" &
                         param_table$rhs == rhs, ]
    if (nrow(row) == 0) return(NA_real_)
    row[[est_col]][1]
  }

  # Outcome: a non-mediator variable predicted by the mediator.
  if (is.null(outcome)) {
    is_pred <- param_table$op == "~" & param_table$rhs == mediator &
      param_table$lhs != mediator
    cand <- param_table$lhs[is_pred]
    if (!length(cand)) {
      stop(paste0("Could not auto-detect outcome (no regression has '", mediator,
                  "' as a predictor). Please specify the 'outcome' argument."),
           call. = FALSE)
    }
    outcome <- cand[1]
  }

  beta1  <- get_path(mediator, treatment)   # a path, treatment on mediator
  if (is.na(beta1)) {
    stop(sprintf("Could not find a path (%s ~ %s).", mediator, treatment), call. = FALSE)
  }
  theta2 <- get_path(outcome, mediator)     # b
  if (is.na(theta2)) {
    stop(sprintf("Could not find b path (%s ~ %s).", outcome, mediator), call. = FALSE)
  }
  theta3 <- get_path(outcome, int_term)     # interaction
  if (is.na(theta3)) {
    stop(sprintf("Could not find interaction path (%s ~ %s).", outcome, int_term),
         call. = FALSE)
  }
  theta1 <- get_path(outcome, treatment)    # c' (may be absent)
  if (is.na(theta1)) {
    theta1 <- 0
    warning("Direct effect (c-prime path) not found in model. Setting to 0.",
            call. = FALSE)
  }

  # Mediator intercept E[M | X=0, C=0], from the `~1` row (needs meanstructure).
  b0_row <- param_table[param_table$lhs == mediator & param_table$op == "~1", ]
  if (nrow(b0_row) == 0) {
    stop(paste0("Four-way decomposition needs the mediator intercept E[M | X=0]; ",
                "refit the lavaan model with meanstructure = TRUE."), call. = FALSE)
  }
  beta0 <- b0_row[[est_col]][1]

  # Covariate contribution to E[M | X=0]: mediator predictors other than the
  # treatment, evaluated at their sample means.
  m_covs <- setdiff(param_table$rhs[param_table$lhs == mediator &
                                      param_table$op == "~"], treatment)
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    if (is.matrix(d)) as.data.frame(d) else if (is.data.frame(d)) d else NULL
  }, error = function(e) NULL)
  m_ref <- beta0
  if (length(m_covs) && !is.null(data)) {
    for (cv in m_covs) {
      cf <- get_path(mediator, cv)
      if (!is.na(cf) && cv %in% names(data) && is.numeric(data[[cv]])) {
        m_ref <- m_ref + cf * mean(data[[cv]], na.rm = TRUE)
      }
    }
  }

  cde     <- theta1 + theta3 * m_star
  int_med <- theta3 * beta1
  pie     <- theta2 * beta1
  int_ref <- theta3 * (m_ref - m_star)
  nde   <- cde + int_ref
  nie   <- int_med + pie
  total <- nde + nie

  # Estimates + interaction aliases; single SEM keeps the full joint covariance.
  alias_var <- c(
    a = paste0(mediator, "~", treatment),
    b = paste0(outcome, "~", mediator),
    c_prime = paste0(outcome, "~", treatment),
    theta3 = paste0(outcome, "~", int_term),
    b0 = paste0(mediator, "~1")
  )
  alias_val <- c(a = beta1, b = theta2, c_prime = theta1, theta3 = theta3, b0 = beta0)
  estimates <- all_coef
  aliases_to_add <- names(alias_var)[!names(alias_var) %in% names(estimates)]
  for (al in names(alias_var)) estimates[al] <- alias_val[[al]]
  source_idx <- .frozen_lavaan_alias_source_idx_from_names(object, alias_var, names(all_coef))
  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat, source_idx = source_idx, aliases_to_add = aliases_to_add
  )

  get_resid_sd <- function(v) {
    row <- param_table[param_table$lhs == v & param_table$op == "~~" &
                         param_table$rhs == v, ]
    if (nrow(row) == 0) return(NA_real_)
    val <- row[[est_col]][1]
    if (is.na(val) || val < 0) return(NA_real_)
    sqrt(val)
  }
  sigma_m <- get_resid_sd(mediator)
  if (is.na(sigma_m)) sigma_m <- NULL
  sigma_y <- get_resid_sd(outcome)
  if (is.na(sigma_y)) sigma_y <- NULL

  mediator_predictors <- param_table$rhs[param_table$lhs == mediator &
                                           param_table$op == "~"]
  outcome_predictors <- param_table$rhs[param_table$lhs == outcome &
                                          param_table$op == "~"]
  n_obs <- .frozen_lavaan_n_obs(object)
  converged <- lavaan::lavInspect(object, "converged")

  InteractionMediationData(
    a_path = beta1, b_path = theta2, c_prime = theta1, interaction = theta3,
    cde = cde, int_ref = int_ref, int_med = int_med, pie = pie,
    nde = nde, nie = nie, total_effect = total, m_star = m_star,
    estimates = estimates, vcov = vcov_expanded,
    sigma_m = sigma_m, sigma_y = sigma_y,
    treatment = treatment, mediator = mediator, outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data, n_obs = as.integer(n_obs),
    converged = converged, source_package = "lavaan"
  )
}

# Map structural aliases to lavaan's free-parameter vector ----------------
#
# lavaan names a free parameter by its user label when one is set (e.g. "aa"
# in `M ~ aa*X`) and otherwise by the "lhs op rhs" form ("M~X", "M~1"). The
# name therefore cannot be rebuilt from variable names alone; look each path
# up in parTable() and use its label if non-empty. Returns an integer index
# into `orig_names` per alias (NA when the path is absent or not free), for
# .expand_vcov_with_aliases().
.frozen_lavaan_alias_source_idx <- function(object, lhs, rhs, op = "~", orig_names) {
  pt <- lavaan::parTable(object)
  op <- rep_len(op, length(lhs))
  idx <- vapply(seq_along(lhs), function(i) {
    row <- which(pt$lhs == lhs[[i]] & pt$op == op[[i]] & pt$rhs == rhs[[i]])
    if (length(row) == 0L) return(NA_integer_)
    lab <- pt$label[row[1L]]
    nm <- if (!is.na(lab) && nzchar(lab)) lab else paste0(lhs[[i]], op[[i]], rhs[[i]])
    match(nm, orig_names)
  }, integer(1))
  stats::setNames(idx, names(lhs))
}

# Names under which name-based consumers (probmed) look up the simple path
# coefficients: m_<treatment> (the a path), y_<mediator> (b), y_<treatment>
# (c'). Returned named by the structural alias each one repeats ("a", "b",
# "c_prime"). Only an observed, continuous treatment, mediator and outcome
# get them: a latent variable has no column for a probmed bootstrap to
# simulate, and an ordered one is not Gaussian, so those fits return
# character(0) and stay plugin-only. So do standardized extractions: their
# estimates are standardized but @vcov is lavaan's unstandardized covariance,
# and a bootstrap drawing from that pair would mix scales.
.frozen_lavaan_probmed_alias_names <- function(object, treatment, mediator, outcome,
                                        standardized = FALSE) {
  checkmate::assert_class(object, "lavaan", .var.name = "object")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(outcome, .var.name = "outcome")
  checkmate::assert_flag(standardized, .var.name = "standardized")

  if (standardized) return(character(0))
  vars <- c(treatment, mediator, outcome)
  observed <- all(vars %in% lavaan::lavNames(object, "ov"))
  if (!observed || any(vars %in% lavaan::lavNames(object, "ov.ord"))) {
    return(character(0))
  }
  c(
    a = paste0("m_", treatment),
    b = paste0("y_", mediator),
    c_prime = paste0("y_", treatment)
  )
}

# Same, for aliases given in "lhs~rhs" / "lhs~1" form (named character vector).
.frozen_lavaan_alias_source_idx_from_names <- function(object, alias_var, orig_names) { # nolint: object_length_linter.
  is_int <- grepl("~1$", alias_var)
  .frozen_lavaan_alias_source_idx(
    object,
    lhs = stats::setNames(sub("~.*$", "", alias_var), names(alias_var)),
    rhs = ifelse(is_int, "", sub("^[^~]*~", "", alias_var)),
    op = ifelse(is_int, "~1", "~"),
    orig_names = orig_names
  )
}

# Sample size of a lavaan fit, as a whole number. lavaan normalizes sampling
# weights to sum to N, so lavInspect(fit, "nobs") can read N - 1e-13 (e.g.
# 355.99999999999994); as.integer() would truncate that to N - 1 and the
# MediationData validator would reject the object. Multiple groups: the total.
.frozen_lavaan_n_obs <- function(object) {
  as.integer(round(sum(lavaan::lavInspect(object, "nobs"))))
}
