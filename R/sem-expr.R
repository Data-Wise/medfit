# Native SEM engine: constraint expressions.
#
# Internal. Constraint and defined-parameter expressions are the arithmetic
# subset of R (spec 4.2). They are never evaluated in the caller's scope:
# checking names alone does not stop code execution, because a caller can rebind
# an allowlisted name such as `exp` (review finding F1). Every expression is
# parsed to exactly one call tree, validated node by node, and evaluated in an
# environment whose parent is `emptyenv()` with each allowlisted function bound
# explicitly to its base or stats object. Every result must be one finite real
# double (spec 4.2a step 4).

# Allowlist: name = c(min arity, max arity). The functions bound below are the
# only ones an expression can call.
.sem_fun_arity <- list(
  `+` = c(1, 2), `-` = c(1, 2), `*` = c(2, 2), `/` = c(2, 2), `^` = c(2, 2), `(` = c(1, 1),
  exp = c(1, 1), log = c(1, 2), log10 = c(1, 1), sqrt = c(1, 1), abs = c(1, 1),
  min = c(1, Inf), max = c(1, Inf), sin = c(1, 1), cos = c(1, 1), tan = c(1, 1),
  pnorm = c(1, 1), qnorm = c(1, 1)
)

.sem_funs <- list(
  `+` = base::`+`, `-` = base::`-`, `*` = base::`*`, `/` = base::`/`, `^` = base::`^`, `(` = base::`(`,
  exp = base::exp, log = base::log, log10 = base::log10, sqrt = base::sqrt, abs = base::abs,
  min = base::min, max = base::max, sin = base::sin, cos = base::cos, tan = base::tan,
  pnorm = stats::pnorm, qnorm = stats::qnorm
)

# Function names a label may not take (the operators cannot be names).
.sem_fnames <- grep("^[a-z]", names(.sem_fun_arity), value = TRUE)

# Parse one expression. A hexadecimal literal is a double to R, so it is
# rejected before parsing; a name such as `a0x1` is not a literal.
.sem_expr_parse <- function(text) {
  if (grepl("(^|[^A-Za-z0-9._])0[xX][0-9a-fA-F]", text)) {
    stop("hexadecimal literals are not supported in expression '", text, "'", call. = FALSE)
  }
  ex <- tryCatch(
    parse(text = text, keep.source = FALSE),
    error = function(e) stop("expression '", text, "' does not parse: ", conditionMessage(e), call. = FALSE)
  )
  if (length(ex) != 1L) {
    stop("expression '", text, "' must be a single expression, got ", length(ex), call. = FALSE)
  }
  ex[[1L]]
}

# Validate the call tree before anything is evaluated. Allowed nodes: a finite
# double literal, a declared label, and a call whose head is a bare allowlisted
# symbol with no named arguments and a legal argument count. The first offending
# construct is named.
.sem_expr_check <- function(e, labels) {
  if (is.double(e) && length(e) == 1L && is.finite(e)) {
    return(invisible(e))
  }
  if (is.symbol(e)) {
    nm <- as.character(e)
    if (nm %in% c("Inf", "NaN")) {
      stop("disallowed literal '", nm, "': only finite double literals are allowed", call. = FALSE)
    }
    if (nm %in% .sem_fnames) {
      stop("'", nm, "' is a function name and cannot be used as a parameter label", call. = FALSE)
    }
    if (!nm %in% labels) {
      stop("unknown parameter label '", nm, "'", call. = FALSE)
    }
    return(invisible(e))
  }
  if (is.call(e)) {
    head <- e[[1L]]
    if (!is.symbol(head)) {
      stop(
        "disallowed call head '", paste(deparse(head), collapse = ""),
        "': only bare allowlisted function names can be called", call. = FALSE
      )
    }
    fn <- as.character(head)
    if (!fn %in% names(.sem_fun_arity)) {
      stop("function or operator '", fn, "' is not in the math allowlist", call. = FALSE)
    }
    if (!is.null(names(e)) && any(nzchar(names(e)[-1L]))) {
      stop("named arguments are not allowed in '", fn, "'", call. = FALSE)
    }
    k <- length(e) - 1L
    ar <- .sem_fun_arity[[fn]]
    if (k < ar[1L] || k > ar[2L]) {
      stop("'", fn, "' called with ", k, " argument(s)", call. = FALSE)
    }
    for (a in as.list(e)[-1L]) {
      .sem_expr_check(a, labels)
    }
    return(invisible(e))
  }
  stop(
    "disallowed literal '", paste(deparse(e), collapse = ""), "' (", typeof(e),
    "): only finite double literals are allowed", call. = FALSE
  )
}

# Evaluate a validated tree in the locked environment and guard the result.
.sem_expr_value <- function(e, values, text = paste(deparse(e), collapse = "")) {
  env <- list2env(c(.sem_funs, as.list(values)), parent = emptyenv())
  # eval() is safe here: `e` passed .sem_expr_check() (allowlisted bare calls,
  # finite literals, declared labels only) and `env` has no parent, so nothing
  # outside the allowlist is reachable.
  r <- tryCatch(suppressWarnings(eval(e, env)), error = function(err) NULL)
  if (!(is.double(r) && length(r) == 1L && is.finite(r))) {
    at <- if (length(values)) paste(names(values), "=", format(values), collapse = ", ") else "no labels"
    got <- if (is.null(r)) "an error" else paste(format(r), collapse = ", ")
    stop(
      "expression '", text, "' did not evaluate to one finite real number (got ", got, ") at ", at,
      call. = FALSE
    )
  }
  r
}

# Parse, validate and evaluate one expression text. `values` is a named numeric
# vector; its names are the declared labels.
.sem_expr_eval <- function(text, values = numeric()) {
  e <- .sem_expr_parse(text)
  .sem_expr_check(e, names(values))
  .sem_expr_value(e, values, text)
}

# Labels an expression uses (call heads excluded).
.sem_expr_labels <- function(text) {
  all.vars(.sem_expr_parse(text))
}

# Replace defined-parameter names by their definitions (parsed expressions),
# recursively. `seen` stops a cycle that the parser should already have rejected.
.sem_expr_subst <- function(e, defs, seen = character()) {
  if (is.symbol(e)) {
    nm <- as.character(e)
    if (is.null(defs[[nm]])) {
      return(e)
    }
    if (nm %in% seen) {
      stop("defined parameters form a cycle through '", nm, "'", call. = FALSE)
    }
    return(.sem_expr_subst(defs[[nm]], defs, c(seen, nm)))
  }
  if (is.call(e)) {
    e[-1L] <- lapply(as.list(e)[-1L], .sem_expr_subst, defs = defs, seen = seen)
  }
  e
}

# Spec 4.5a: syntactic linearity. Conservative: anything not provably linear is
# nonlinear, so an expression that is linear in fact but not provably so
# (`a*b - a*b + a`, `a^1`) costs a warning and extra starts, never a missed
# safeguard. `e` has its defined names substituted already.
.sem_tree_linear <- function(e) {
  const <- function(x) length(all.vars(x)) == 0L
  lin <- function(x) {
    if (const(x) || is.symbol(x)) {
      return(TRUE)
    }
    a <- as.list(x)[-1L]
    switch(as.character(x[[1L]]),
      `(` = lin(a[[1L]]),
      `+` = ,
      `-` = all(vapply(a, lin, TRUE)),
      `*` = sum(!vapply(a, const, TRUE)) <= 1L && all(vapply(a, lin, TRUE)),
      `/` = const(a[[2L]]) && lin(a[[1L]]),
      FALSE
    )
  }
  lin(e)
}

# `defs`: named character vector of defined-parameter expressions.
.sem_expr_linear <- function(text, defs = character()) {
  .sem_tree_linear(.sem_expr_subst(.sem_expr_parse(text), .sem_defs(defs)))
}

# A constraint `lhs cmp rhs` is as linear as `(lhs) - (rhs)`.
.sem_constraint_linear <- function(lhs, rhs, defs = character()) {
  .sem_expr_linear(paste0("(", lhs, ") - (", rhs, ")"), defs)
}

.sem_defs <- function(defs) {
  lapply(as.list(defs), .sem_expr_parse)
}
