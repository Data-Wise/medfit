# 0.15.0 defaults of fit_sem()'s `fixed_x` and `meanstructure` (spec F-1 to F-4, E-13, E-14). An unset setting resolves
# to the new value unconditionally; an explicit value is never overwritten.

# Resolve unset `fixed_x` / `meanstructure` for the model syntax and data. Returns the values to fit with. Unset
# `meanstructure` becomes TRUE and unset `fixed_x` becomes `.sem_default_fixed_x()`'s explicit subset (E-13), never a
# bare TRUE, so refits and comparisons see which variables the default fixed. An explicit value, including FALSE and
# NULL, is returned as given (E-14).
.native_defaults_resolve <- function(model, data, fixed_x, meanstructure, fx_unset, ms_unset) {
  if (ms_unset) meanstructure <- TRUE
  if (fx_unset) {
    # Syntax the raw table cannot classify, or a factor expansion that fails, is left to the fit, which fails on the
    # same input with the specific message; only fixed_x falls through to FALSE and meanstructure keeps its value.
    fixed_x <- tryCatch({
      p <- .sem_parse(model)$parameters
      .sem_roles(p) # validates the table before the subset is built
      .sem_default_fixed_x(p, data)
    }, error = function(e) FALSE)
  }
  list(fixed_x = fixed_x, meanstructure = meanstructure)
}

# The 0.15.0 `fixed_x` default (R-5, R-11b, E-5, E-11): the observed exogenous columns after factor expansion and
# with products (`m:x`, factor dummies), minus those the model writes a `~~` or `~1` statement on (a statement on a
# factor touches all its dummies). A character subset, or FALSE when none is left. A variable left free because of a
# statement is named in a classed message (not a warning, so the once-per-session state is not involved), on every
# fit where it happens. An explicit `fixed_x = TRUE` does not come here and keeps its error.
.sem_default_fixed_x <- function(parameters, data) {
  expanded <- .sem_expand_factors(parameters, data, FALSE)
  p <- expanded$table
  ov_x <- .sem_roles(p)$ov_x
  named <- unique(c(p$lhs[p$op == "~~"], p$rhs[p$op == "~~"], p$lhs[p$op == "~1"]))
  dummies <- unlist(lapply(expanded$map[intersect(names(expanded$map), named)], function(m) m$dummies),
                    use.names = FALSE)
  free <- intersect(ov_x, c(named, dummies))
  # A statement on a factor's name makes the fit fail ("model variables must be numeric"), so no note for it (QA O1).
  if (length(free) && !any(names(expanded$map) %in% named)) {
    message(structure(
      class = c("medfit_message_fixed_x_lenient", "message", "condition"),
      list(message = paste0(
        "fit_sem(): the `fixed_x` default leaves ", paste(free, collapse = ", "), " free, because the model writes ",
        "a `~~` or `~1` statement on ", if (length(free) == 1L) "it" else "them",
        "; the other exogenous observed variables are fixed. Pass `fixed_x` explicitly to choose.\n"
      ), call = NULL, variables = free)
    ))
  }
  sel <- setdiff(ov_x, free)
  if (length(sel)) sel else FALSE
}
