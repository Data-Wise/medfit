# Native SEM engine: linear constraints.
#
# Internal. A constraint line (`==`, `<`, `>` from the parser's constraint table)
# that is provably linear in the parameter labels becomes one row `a'theta + b`,
# normalized to unit length: equalities `a'theta + b = 0` and inequalities
# `a'theta + b <= 0` (a `>` constraint is negated). Rows are constant, so the
# solver gets constant Jacobians and one solve suffices (spec 4.5a, 4.5b). A
# nonlinear constraint errors by name; nonlinear constraints arrive in a later
# version. Defined parameters (`:=`) are substituted before the linearity walk.

.sem_nonlinear_msg <- "nonlinear constraints are not supported in this version"

# Rows for the constraints in `constraints` (the parser's table, `:=` rows
# included as definitions). Returns NULL when there is nothing to enforce.
.sem_constraint_rows <- function(constraints, ram) {
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  cons <- constraints[constraints$op %in% c("==", "<", ">"), , drop = FALSE]
  if (!nrow(cons)) {
    return(NULL)
  }
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  rows <- vector("list", nrow(cons))
  for (i in seq_len(nrow(cons))) {
    text <- paste(cons$lhs[i], cons$op[i], cons$rhs[i])
    tree <- .sem_expr_subst(.sem_expr_parse(paste0("(", cons$lhs[i], ") - (", cons$rhs[i], ")")), defs)
    labels <- all.vars(tree)
    if (!length(labels)) {
      stop("constraint contains no parameters: '", text, "'", call. = FALSE)
    }
    if (!.sem_tree_linear(tree)) {
      stop(.sem_nonlinear_msg, ": '", text, "'", call. = FALSE)
    }
    idx <- match(labels, ram$par_names)
    if (anyNA(idx)) {
      stop("constraint '", text, "' refers to '", labels[is.na(idx)][1L], "', which is not a free parameter",
           call. = FALSE)
    }
    zero <- stats::setNames(numeric(length(labels)), labels)
    b <- .sem_expr_value(tree, zero, text)
    a <- numeric(ram$q)
    for (k in seq_along(labels)) {
      unit <- zero
      unit[[k]] <- 1
      a[idx[k]] <- .sem_expr_value(tree, unit, text) - b
    }
    if (cons$op[i] == ">") {
      a <- -a
      b <- -b
    }
    len <- sqrt(sum(a^2))
    if (len < 1e-12) {
      stop("constraint contains no parameters: '", text, "'", call. = FALSE)
    }
    rows[[i]] <- list(a = a / len, b = b / len, op = cons$op[i], text = text)
  }
  pick <- function(eq) {
    keep <- Filter(function(r) (r$op == "==") == eq, rows)
    list(
      A = if (length(keep)) do.call(rbind, lapply(keep, `[[`, "a")) else matrix(0, 0L, ram$q),
      b = vapply(keep, `[[`, 1, "b"),
      text = vapply(keep, `[[`, "", "text")
    )
  }
  list(eq = pick(TRUE), ineq = pick(FALSE))
}

# Residual of the constraints at `theta`: equalities in absolute value, inequalities
# by how far they are violated (zero when satisfied). Rows are unit length, so the
# residual is in parameter units.
.sem_constraint_residual <- function(theta, cons) {
  if (is.null(cons)) {
    return(numeric())
  }
  c(
    if (nrow(cons$eq$A)) abs(as.vector(cons$eq$A %*% theta) + cons$eq$b),
    if (nrow(cons$ineq$A)) pmax(0, as.vector(cons$ineq$A %*% theta) + cons$ineq$b)
  )
}

# nloptr arguments for the rows in the solver's coordinates x = theta / u: the
# Jacobian is the row scaled by u, constant.
.sem_nlopt_constraints <- function(cons, u) {
  if (is.null(cons)) {
    return(NULL)
  }
  out <- list()
  if (nrow(cons$eq$A)) {
    jac <- sweep(cons$eq$A, 2L, u, "*")
    out$eval_g_eq <- function(x) as.vector(jac %*% x) + cons$eq$b
    out$eval_jac_g_eq <- function(x) jac
  }
  if (nrow(cons$ineq$A)) {
    jac <- sweep(cons$ineq$A, 2L, u, "*")
    out$eval_g_ineq <- function(x) as.vector(jac %*% x) + cons$ineq$b
    out$eval_jac_g_ineq <- function(x) jac
  }
  out
}
