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
#'   rows/columns (those not already present in `vcov_src`).
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
