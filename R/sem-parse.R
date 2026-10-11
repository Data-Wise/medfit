# Native SEM engine: model syntax parser.
#
# Internal. `.sem_parse()` turns "medfit model syntax" (a lavaan-style core plus
# two extensions, spec 4 and 6) into the parameter table and constraint table of
# spec 5. Statements are `=~`, `~`, `~~`, intercepts, `:=`, `==`, `<`, `>`,
# `level:` lines and the `CONSTRAINT(...)` directive. Unsupported syntax errors
# by name, never silently (spec 7). Expressions are validated, not evaluated,
# here; evaluation lives in sem-expr.R.

.sem_name_re <- "^[A-Za-z.][A-Za-z0-9._]*$"
.sem_reserved <- c(.sem_fnames, "start", "lower", "upper", "level", "CONSTRAINT")

.sem_syntax_error <- function(msg, stmt = NULL) {
  if (!is.null(stmt)) {
    msg <- paste0(msg, " (in '", stmt, "')")
  }
  stop(msg, call. = FALSE)
}

# Statements: comments (`#` or `!`) dropped, a line continues while it ends with
# `+`, `,`, `*` or an open parenthesis, `;` separates statements.
.sem_continues <- function(buf) {
  b <- trimws(buf)
  count <- function(ch) lengths(regmatches(b, gregexpr(ch, b, fixed = TRUE)))
  grepl("[+,*(]$", b) || count("(") > count(")")
}

.sem_statements <- function(lines) {
  stmts <- character()
  buf <- ""
  for (line in lines) {
    hit <- regexpr("#|!(?!=)", line, perl = TRUE)
    if (hit > 0L) {
      line <- substr(line, 1L, hit - 1L)
    }
    pieces <- strsplit(paste0(line, " "), ";", fixed = TRUE)[[1L]]
    for (i in seq_along(pieces)) {
      buf <- paste(buf, pieces[i])
      if (i < length(pieces) || !.sem_continues(buf)) {
        b <- trimws(buf)
        if (nzchar(b)) {
          stmts <- c(stmts, b)
        }
        buf <- ""
      }
    }
  }
  if (nzchar(trimws(buf))) {
    stmts <- c(stmts, trimws(buf))
  }
  stmts
}

# Tokens: numbers (unsigned), names, and the symbols ( ) * + - ,. A number
# glued to a name character (`5L`, `0x10`, `1e`) is malformed.
.sem_is_num <- function(tk) grepl("^([0-9]|\\.[0-9])", tk)

.sem_tokens <- function(s, stmt) {
  num <- "^([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?"
  nm <- "^[A-Za-z.][A-Za-z0-9._]*"
  out <- character()
  s <- trimws(s)
  while (nzchar(s)) {
    m <- regexpr(num, s)
    if (m > 0L) {
      len <- attr(m, "match.length")
      if (grepl("^[A-Za-z0-9._]", substring(s, len + 1L))) {
        .sem_syntax_error(paste0("malformed number '", substr(s, 1L, len + 1L), "'"), stmt)
      }
    } else {
      m <- regexpr(nm, s)
      if (m > 0L) {
        len <- attr(m, "match.length")
      } else if (grepl("^[()*+,-]", s)) {
        len <- 1L
      } else {
        .sem_syntax_error(paste0("unexpected character '", substr(s, 1L, 1L), "'"), stmt)
      }
    }
    out <- c(out, substr(s, 1L, len))
    s <- trimws(substring(s, len + 1L))
  }
  out
}

.sem_snumber <- function(tk) {
  sgn <- 1
  if (length(tk) >= 1L && tk[1L] %in% c("-", "+")) {
    sgn <- if (tk[1L] == "-") -1 else 1
    tk <- tk[-1L]
  }
  if (length(tk) == 1L && .sem_is_num(tk)) sgn * as.numeric(tk) else NULL
}

# One term of a relation: `[modifier *] target`. Returns the target and the
# fields the modifier sets.
.sem_term <- function(tk, stmt) {
  star <- which(tk == "*")
  if (length(star) > 1L) {
    .sem_syntax_error("more than one modifier on a term; use one modifier per term", stmt)
  }
  mod <- if (length(star)) tk[seq_len(star - 1L)] else character()
  target <- if (length(star)) tk[-seq_len(star)] else tk
  if (length(target) != 1L) {
    .sem_syntax_error("malformed term; expected [modifier*]name", stmt)
  }
  set <- list(fixed = NA_real_, label = "", start = NA_real_, lower = NA_real_, upper = NA_real_)
  if (length(star) && !length(mod)) {
    .sem_syntax_error("malformed modifier: nothing before '*'", stmt)
  }
  if (length(mod)) {
    n <- length(mod)
    fun <- mod[1L] %in% c("start", "lower", "upper") && n >= 2L && mod[2L] == "("
    if (fun) {
      inner <- if (n >= 4L && mod[n] == ")") mod[3L:(n - 1L)] else NULL
      val <- if (identical(inner, "NA")) NA_real_ else .sem_snumber(inner)
      if (is.null(val) || (is.na(val) && mod[1L] != "start")) {
        .sem_syntax_error(
          paste0("malformed modifier '", paste(mod, collapse = ""), "'; ", mod[1L], "() takes one number",
                 if (mod[1L] == "start") " or NA" else ""), stmt
        )
      }
      set[[mod[1L]]] <- val
    } else if (!is.null(v <- .sem_snumber(mod))) {
      set$fixed <- v
    } else if (n == 1L && mod == "NA") {
      .sem_syntax_error("NA is allowed in start() only", stmt)
    } else if (n == 1L && grepl(.sem_name_re, mod)) {
      if (mod %in% .sem_reserved) {
        .sem_syntax_error(paste0("label '", mod, "' is a reserved word"), stmt)
      }
      set$label <- mod
    } else {
      .sem_syntax_error(paste0("malformed modifier '", paste(mod, collapse = ""), "'"), stmt)
    }
  }
  c(list(target = target), set)
}

.sem_relation <- function(st) {
  m <- regexpr("=~|~~|~", st)
  op <- regmatches(st, m)
  lhs <- trimws(substr(st, 1L, m - 1L))
  rhs <- trimws(substring(st, m + attr(m, "match.length")))
  if (grepl("=~|~~|~", rhs)) {
    .sem_syntax_error("more than one relation operator in a statement", st)
  }
  # strsplit() drops a trailing empty element, so a dangling comma is checked first.
  dangling <- grepl("(^|,)\\s*(,|$)", lhs)
  lhs <- trimws(strsplit(lhs, ",", fixed = TRUE)[[1L]])
  if (dangling || !length(lhs) || !all(grepl(.sem_name_re, lhs))) {
    .sem_syntax_error(paste0("invalid left side of '", op, "'"), st)
  }
  tk <- .sem_tokens(rhs, st)
  if (!length(tk)) {
    .sem_syntax_error(paste0("empty right side of '", op, "'"), st)
  }
  if ("," %in% tk) {
    .sem_syntax_error("a comma on the right side is not supported; use '+'", st)
  }
  depth <- cumsum((tk == "(") - (tk == ")"))
  cut <- which(tk == "+" & depth == 0L)
  grp <- cumsum(seq_along(tk) %in% cut)
  keep <- !seq_along(tk) %in% cut
  groups <- lapply(0:length(cut), function(g) tk[keep & grp == g])
  if (any(lengths(groups) == 0L)) {
    .sem_syntax_error("empty term on the right side", st)
  }
  terms <- lapply(groups, .sem_term, stmt = st)
  is_one <- vapply(terms, function(t) .sem_is_num(t$target), TRUE)
  if (any(is_one)) {
    if (op != "~" || any(vapply(terms[is_one], function(t) as.numeric(t$target) != 1, TRUE))) {
      .sem_syntax_error("a number on the right side is only valid as the intercept '~ 1'", st)
    }
    if (length(terms) > 1L) {
      .sem_syntax_error("an intercept must be its own statement (e.g. 'y ~ 1')", st)
    }
  }
  rows <- list()
  for (l in lhs) {
    for (k in seq_along(terms)) {
      t <- terms[[k]]
      if (!is_one[k] && !grepl(.sem_name_re, t$target)) {
        .sem_syntax_error(paste0("invalid variable name '", t$target, "'"), st)
      }
      rows[[length(rows) + 1L]] <- list(
        lhs = l, op = if (is_one[k]) "~1" else op, rhs = if (is_one[k]) "" else t$target,
        fixed = t$fixed, label = t$label, start = t$start, lower = t$lower, upper = t$upper
      )
    }
  }
  rows
}

# Split `lhs cmp rhs` at its single depth-0 comparison.
.sem_split_cmp <- function(s, stmt) {
  m <- gregexpr("==|<=|>=|!=|<|>", s)[[1L]]
  if (m[1L] < 0L) {
    .sem_syntax_error("expected one comparison (==, < or >) in a constraint", stmt)
  }
  ops <- regmatches(s, list(m))[[1L]]
  ch <- strsplit(s, "")[[1L]]
  depth <- cumsum((ch == "(") - (ch == ")"))
  at0 <- depth[m] == 0L
  bad <- ops[at0 & ops %in% c("<=", ">=", "!=")]
  if (length(bad)) {
    .sem_syntax_error(paste0("comparison '", bad[1L], "' is not supported; use ==, < or >"), stmt)
  }
  if (sum(at0) != 1L) {
    .sem_syntax_error("a constraint needs exactly one comparison (==, < or >) outside parentheses", stmt)
  }
  i <- which(at0)
  len <- attr(m, "match.length")[i]
  lhs <- trimws(substr(s, 1L, m[i] - 1L))
  rhs <- trimws(substring(s, m[i] + len))
  if (!nzchar(lhs) || !nzchar(rhs)) {
    .sem_syntax_error("a constraint needs an expression on both sides", stmt)
  }
  list(op = ops[i], lhs = lhs, rhs = rhs)
}

.sem_directive <- function(st) {
  ch <- strsplit(st, "")[[1L]]
  open <- regexpr("(", st, fixed = TRUE)
  depth <- cumsum((ch == "(") - (ch == ")"))
  close <- which(depth == 0L & seq_along(ch) > open)[1L]
  if (is.na(close)) {
    .sem_syntax_error("unbalanced parentheses in CONSTRAINT(...)", st)
  }
  if (nzchar(trimws(substring(st, close + 1L)))) {
    .sem_syntax_error("unexpected text after CONSTRAINT(...)", st)
  }
  inner <- substr(st, open + 1L, close - 1L)
  if (grepl("CONSTRAINT", inner, fixed = TRUE)) {
    .sem_syntax_error("CONSTRAINT(...) cannot be nested", st)
  }
  ich <- strsplit(inner, "")[[1L]]
  idepth <- cumsum((ich == "(") - (ich == ")"))
  if (any(ich == "," & idepth == 0L)) {
    .sem_syntax_error("CONSTRAINT(...) takes one constraint; found a comma", st)
  }
  .sem_split_cmp(inner, st)
}

# One statement to a list: kind "level", "relation", "defined" or "constraint".
.sem_statement <- function(st) {
  if (grepl("[`\"']", st)) {
    .sem_syntax_error("quoted names and strings are not supported", st)
  }
  unsup <- c(
    "<~" = "formative composites", "~\\*~" = "~*~", "\\|~" = "|~", ":~" = "regularized loadings",
    "\\|" = "thresholds", "%" = "'%'"
  )
  for (i in seq_along(unsup)) {
    if (grepl(names(unsup)[i], st)) {
      op <- gsub("\\\\", "", names(unsup)[i])
      .sem_syntax_error(paste0("operator '", op, "' is not supported"), st)
    }
  }
  blk <- regmatches(st, regexpr("^(group|class|block)\\s*:(?!=)", st, perl = TRUE))
  if (length(blk)) {
    .sem_syntax_error(paste0("'", gsub("\\s", "", blk), "' blocks are not supported"), st)
  }
  if (grepl("^level\\s*:(?!=)", st, perl = TRUE)) {
    if (!grepl("^level\\s*:\\s*[0-9]+$", st)) {
      .sem_syntax_error("malformed level line; expected 'level: <integer>'", st)
    }
    return(list(kind = "level", level = as.integer(sub("^level\\s*:\\s*", "", st))))
  }
  if (grepl("^CONSTRAINT\\s*\\(", st)) {
    return(c(list(kind = "constraint"), .sem_directive(st)))
  }
  if (grepl(":=", st, fixed = TRUE)) {
    parts <- strsplit(st, ":=", fixed = TRUE)[[1L]]
    nm <- trimws(parts[1L])
    rhs <- trimws(paste(parts[-1L], collapse = ":="))
    if (length(parts) < 2L || !grepl(.sem_name_re, nm) || !nzchar(rhs)) {
      .sem_syntax_error("malformed defined parameter; expected 'name := expression'", st)
    }
    if (nm %in% .sem_reserved) {
      .sem_syntax_error(paste0("defined parameter name '", nm, "' is a reserved word"), st)
    }
    return(list(kind = "defined", op = ":=", lhs = nm, rhs = rhs))
  }
  if (grepl("=~|~~|~", st)) {
    return(list(kind = "relation", rows = .sem_relation(st)))
  }
  c(list(kind = "constraint"), .sem_split_cmp(st, st))
}

# Spec 4.4: `label < number` (or `number > label`) and the mirrored forms become
# `upper` / `lower` on every row with that label. Anything else stays a
# constraint. When a bound already exists the tighter one wins.
.sem_fold_bounds <- function(parameters, constraints) {
  keep <- rep(TRUE, nrow(constraints))
  labels <- unique(parameters$label[nzchar(parameters$label)])
  is_label <- function(x) x %in% labels
  for (i in which(constraints$op %in% c("<", ">"))) {
    l <- constraints$lhs[i]
    r <- constraints$rhs[i]
    op <- constraints$op[i]
    if (is_label(l) == is_label(r)) {
      next
    }
    other <- if (is_label(l)) r else l
    if (length(.sem_expr_labels(other))) {
      next
    }
    value <- .sem_expr_eval(other)
    lab <- if (is_label(l)) l else r
    upper <- (is_label(l) && op == "<") || (is_label(r) && op == ">")
    rows <- which(parameters$label == lab)
    col <- if (upper) "upper" else "lower"
    cur <- parameters[[col]][rows]
    parameters[[col]][rows] <- if (upper) pmin(cur, value, na.rm = TRUE) else pmax(cur, value, na.rm = TRUE)
    keep[i] <- FALSE
  }
  constraints <- constraints[keep, , drop = FALSE]
  rownames(constraints) <- NULL
  list(parameters = parameters, constraints = constraints)
}

.sem_check_defined_cycles <- function(defs) {
  deps <- lapply(defs, function(d) intersect(.sem_expr_labels(d), names(defs)))
  state <- list2env(as.list(stats::setNames(rep(0L, length(defs)), names(defs))), parent = emptyenv())
  visit <- function(nm, path) {
    if (state[[nm]] == 2L) {
      return(invisible())
    }
    if (state[[nm]] == 1L) {
      .sem_syntax_error(paste0("defined parameters form a cycle: ", paste(c(path, nm), collapse = " -> ")))
    }
    assign(nm, 1L, envir = state)
    for (d in deps[[nm]]) {
      visit(d, c(path, nm))
    }
    assign(nm, 2L, envir = state)
  }
  for (nm in names(defs)) {
    visit(nm, character())
  }
  invisible()
}

# Parse model syntax into `list(parameters, constraints)` (spec 5).
.sem_parse <- function(model) {
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  stmts <- .sem_statements(unlist(strsplit(paste(model, collapse = "\n"), "\n", fixed = TRUE)))
  if (!length(stmts)) {
    stop("model syntax is empty", call. = FALSE)
  }
  level <- 1L
  rows <- list()
  cons <- list()
  for (st in stmts) {
    p <- .sem_statement(st)
    switch(p$kind,
      level = {
        level <- p$level
      },
      relation = {
        rows <- c(rows, lapply(p$rows, function(r) c(r, list(level = level))))
      },
      {
        cons[[length(cons) + 1L]] <- list(op = p$op, lhs = p$lhs, rhs = p$rhs, level = level)
      }
    )
  }
  if (!length(rows)) {
    stop("model syntax has no parameters: expected at least one '=~', '~' or '~~' statement", call. = FALSE)
  }
  col <- function(f, type) vapply(rows, function(r) r[[f]], type)
  parameters <- data.frame(
    id = seq_along(rows), lhs = col("lhs", ""), op = col("op", ""), rhs = col("rhs", ""),
    level = col("level", 1L), fixed = col("fixed", 1), label = col("label", ""),
    start = col("start", 1), lower = col("lower", 1), upper = col("upper", 1),
    stringsAsFactors = FALSE
  )
  ccol <- function(f, type) vapply(cons, function(r) r[[f]], type)
  constraints <- data.frame(
    op = ccol("op", ""), lhs = ccol("lhs", ""), rhs = ccol("rhs", ""), level = ccol("level", 1L),
    stringsAsFactors = FALSE
  )
  if (!length(cons)) {
    constraints <- constraints[0L, , drop = FALSE]
    constraints$level <- integer()
  }
  labels <- unique(parameters$label[nzchar(parameters$label)])
  variables <- unique(c(parameters$lhs, parameters$rhs[nzchar(parameters$rhs)]))
  clash <- intersect(labels, variables)
  if (length(clash)) {
    stop("label '", clash[1L], "' is also a variable name; labels and variables need different names", call. = FALSE)
  }
  dn <- constraints$lhs[constraints$op == ":="]
  if (anyDuplicated(dn)) {
    stop("defined parameter '", dn[anyDuplicated(dn)], "' is defined more than once", call. = FALSE)
  }
  clash <- intersect(dn, c(labels, variables))
  if (length(clash)) {
    stop("defined parameter '", clash[1L], "' clashes with a label or variable name", call. = FALSE)
  }
  known <- c(labels, dn)
  for (i in seq_len(nrow(constraints))) {
    sides <- if (constraints$op[i] == ":=") constraints$rhs[i] else c(constraints$lhs[i], constraints$rhs[i])
    for (s in sides) {
      e <- .sem_expr_parse(s)
      .sem_expr_check(e, known)
      if (!length(all.vars(e))) {
        .sem_expr_value(e, numeric(), s) # constant side: the result guard applies at build time (spec 4.2a step 4)
      }
    }
  }
  defs <- stats::setNames(constraints$rhs[constraints$op == ":="], dn)
  if (length(defs)) {
    .sem_check_defined_cycles(defs)
  }
  .sem_fold_bounds(parameters, constraints)
}
