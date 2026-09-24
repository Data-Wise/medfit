# Utility Functions for medfit
#
# Internal utility functions for:
# - Input validation
# - Data formatting
# - Error messaging
# - Helper calculations

#' Expand a Source Covariance Matrix with Full-Copy Path Aliases
#'
#' Appends named structural aliases (e.g. `a`, `b`, `c_prime`, `d1`, ...) to a
#' source variance-covariance matrix, copying the FULL covariance row/column of
#' each alias's source parameter rather than just its diagonal variance. This
#' preserves every covariance the aliased parameter has -- both with the
#' original parameters and with the other aliases.
#'
#' This is the shared engine behind the alias-vcov contract used by the lm/glm
#' and lavaan `extract_mediation()` methods (simple and serial). Factoring it
#' here keeps the two extractors from drifting: each computes its own
#' `source_idx` mapping (the lavaan path tries labels then variable names; the
#' lm path maps to the prefixed coefficient names) and then hands the mechanical
#' expansion to this single routine.
#'
#' @param vcov_src Numeric matrix: the source covariance with row/column names.
#'   For lm this is the block-diagonal stack of the per-model `vcov()`s; for
#'   lavaan it is `lavaan::vcov(object)`.
#' @param source_idx Named integer vector mapping each alias name to the row
#'   index of its source parameter in `vcov_src`. Entries may be `NA_integer_`
#'   when a source could not be resolved (that alias is then left as a
#'   zero-variance placeholder). Must contain an entry for every name in
#'   `aliases_to_add`.
#' @param aliases_to_add Character vector of alias names to append as new
#'   rows/columns (those not already present in `vcov_src`). An alias in
#'   `source_idx` that is *not* appended, because `vcov_src` already has a
#'   parameter of that name, must resolve to that same parameter. Otherwise the
#'   alias estimate and its row would describe different parameters (e.g. a
#'   lavaan user label `a1` on the path medfit calls `a2`), so this is an error.
#'
#' @return A symmetric numeric matrix of dimension
#'   `nrow(vcov_src) + length(aliases_to_add)`, with the original block intact,
#'   each alias row/column populated from its source, and the alias-to-alias
#'   intersections filled from the corresponding source-to-source covariances.
#'
#' @keywords internal
.expand_vcov_with_aliases <- function(vcov_src, source_idx, aliases_to_add) {
  orig_names <- rownames(vcov_src)
  n_orig <- nrow(vcov_src)
  n_total <- n_orig + length(aliases_to_add)
  vcov_names <- c(orig_names, aliases_to_add)

  vcov_expanded <- matrix(
    0,
    nrow = n_total, ncol = n_total,
    dimnames = list(vcov_names, vcov_names)
  )
  vcov_expanded[seq_len(n_orig), seq_len(n_orig)] <- vcov_src

  # An alias already present in vcov_src keeps that parameter's row, so it must
  # be the alias's own source; a name taken by another parameter would pair the
  # alias estimate with the wrong variance.
  for (al in setdiff(names(source_idx), aliases_to_add)) {
    own <- which(orig_names == al)
    if (length(own) == 0L) next
    s_i <- source_idx[[al]]
    if (is.na(s_i) || !(s_i %in% own)) {
      stop(sprintf(paste0(
        "The model already has a parameter named '%s', but it is not the ",
        "path medfit reports as '%s'%s. Rename that label in the model, or ",
        "list `mediator` in the order your labels assume."
      ), al, al,
      if (is.na(s_i)) "" else sprintf(" (that path is parameter '%s')", orig_names[s_i])),
      call. = FALSE)
    }
  }

  # For each new alias, copy the FULL row/column of its source parameter so the
  # alias inherits every covariance the source has with the original block.
  for (al in aliases_to_add) {
    s_i <- source_idx[[al]]
    if (is.na(s_i)) next
    idx <- which(vcov_names == al)
    vcov_expanded[idx, seq_len(n_orig)] <- vcov_src[s_i, ]
    vcov_expanded[seq_len(n_orig), idx] <- vcov_src[, s_i]
  }

  # Alias-to-alias (co)variances, taken from the corresponding source pairs, so
  # e.g. cov(b, c_prime) survives when both alias the same equation.
  for (al_i in aliases_to_add) {
    s_i <- source_idx[[al_i]]
    if (is.na(s_i)) next
    idx_i <- which(vcov_names == al_i)
    for (al_j in aliases_to_add) {
      s_j <- source_idx[[al_j]]
      if (is.na(s_j)) next
      vcov_expanded[idx_i, which(vcov_names == al_j)] <- vcov_src[s_i, s_j]
    }
  }

  vcov_expanded
}


#' Locate a treatment-by-mediator interaction term in a model formula
#'
#' Formula-level counterpart of [.find_interaction_term()] (which inspects a
#' fitted model's coefficient names). Returns the term label of the `X:M`
#' product term in `formula`, trying both orderings, or `NA_character_` when
#' no such term is present. Used by the `"regmedint"` engine to decide between
#' [MediationData] and [InteractionMediationData] before any model is fitted,
#' mirroring `extract_mediation(decomposition = "auto")`'s convention.
#'
#' @param formula A model formula (e.g. `Y ~ X * M + C`).
#' @param treatment,mediator Variable names.
#' @return A single string (the matching term label) or `NA_character_`.
#' @keywords internal
.find_interaction_term_formula <- function(formula, treatment, mediator) { # nolint: object_length_linter.
  labs <- attr(stats::terms(formula), "term.labels")
  cand <- c(paste0(treatment, ":", mediator), paste0(mediator, ":", treatment))
  hit <- cand[cand %in% labs]
  if (length(hit) >= 1L) hit[1] else NA_character_
}


# --- Serial path system (te()/pm() for SerialMediationData) ---

# Structural edges of a serial model: every regression path from X or an
# earlier mediator into a later mediator or Y. The chain edges keep their
# historical aliases (a, d1..d{k-1}, b); the edges that skip a link get
# a{j} (X -> Mj), d{i}_{j} (Mi -> Mj, j > i + 1) and b{i} (Mi -> Y, i < k).
.serial_edges <- function(k) {
  # Node indices: 0 = X, 1..k = mediators, k + 1 = Y.
  mm <- which(upper.tri(diag(k)), arr.ind = TRUE)  # (from = row, to = col)
  mm <- mm[order(mm[, 1L], mm[, 2L]), , drop = FALSE]
  adjacent <- mm[, 2L] == mm[, 1L] + 1L
  data.frame(
    from = c(rep(0L, k), mm[, 1L], seq_len(k), 0L),
    to = c(seq_len(k), mm[, 2L], rep(k + 1L, k), k + 1L),
    alias = c("a", if (k > 1L) paste0("a", seq(2L, k)),
              ifelse(adjacent, paste0("d", mm[, 1L]),
                     paste0("d", mm[, 1L], "_", mm[, 2L])),
              if (k > 1L) paste0("b", seq_len(k - 1L)), "b", "c_prime"),
    chain = c(TRUE, rep(FALSE, k - 1L), adjacent, rep(FALSE, k - 1L), TRUE, FALSE),
    stringsAsFactors = FALSE
  )
}


# Recursive path system of a SerialMediationData object.
#
# Returns list(edges, inv) where `edges` holds the edges present in the model
# (with their values) and `inv` is (I - B)^{-1} over the nodes (X, M1..Mk, Y),
# so the total effect of X on Y is inv[Y, X]. An edge is present when its
# source is a predictor of its target (from @mediator_predictors /
# @outcome_predictors); a skip edge absent from the model is a structural zero.
# Returns a character string (the reason) when a present skip edge has no
# stored coefficient, or the predictor bookkeeping is missing: guessing zero
# there would silently understate or overstate the total effect.
.serial_path_system <- function(x) {
  k <- length(x@mediators)
  nodes <- c(x@treatment, x@mediators)
  edges <- .serial_edges(k)
  chain_val <- c(a = x@a_path, stats::setNames(x@d_path, paste0("d", seq_len(k - 1L))),
                 b = x@b_path, c_prime = x@c_prime)

  preds <- x@mediator_predictors
  if (length(preds) < k || length(x@outcome_predictors) == 0L) {
    return("the mediator/outcome predictor lists are not recorded")
  }

  edges$value <- NA_real_
  keep <- logical(nrow(edges))
  for (r in seq_len(nrow(edges))) {
    al <- edges$alias[r]
    if (al %in% names(chain_val)) {
      edges$value[r] <- chain_val[[al]]
      keep[r] <- TRUE
      next
    }
    target_preds <- if (edges$to[r] > k) x@outcome_predictors else preds[[edges$to[r]]]
    if (!nodes[edges$from[r] + 1L] %in% target_preds) next
    val <- if (al %in% names(x@estimates)) unname(x@estimates[[al]]) else NA_real_
    if (is.na(val)) {
      return(sprintf("no coefficient '%s' (%s -> %s) is stored in @estimates",
                     al, nodes[edges$from[r] + 1L],
                     c(nodes, x@outcome)[edges$to[r] + 1L]))
    }
    edges$value[r] <- val
    keep[r] <- TRUE
  }
  edges <- edges[keep, , drop = FALSE]

  n <- k + 2L
  B <- matrix(0, n, n)
  B[cbind(edges$to + 1L, edges$from + 1L)] <- edges$value
  list(edges = edges, inv = solve(diag(n) - B))
}


# Total effect of X on Y (sum over all directed paths), or NA with a warning
# when the skip-path coefficients are unavailable.
.serial_total_effect <- function(x) {
  sys <- .serial_path_system(x)
  if (is.character(sys)) {
    warning("Total effect is unavailable for this SerialMediationData: ", sys,
            ". Use extract_mediation() so every path is recorded.", call. = FALSE)
    return(NA_real_)
  }
  k <- length(x@mediators)
  sys$inv[k + 2L, 1L]
}
