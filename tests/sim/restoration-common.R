# Shared by tests/sim/restoration-instrument.R and tests/sim/sem-restoration-gate.R (restoration-bound plan T2, T5):
# the observation of status -4 restorations over the profile gate's fixtures. `trace()` wraps `.sem_polish_accept` and
# only reads; the polish and the gate are recomputed from the entry arguments to give the hypothetical rise of a
# rejected attempt. The allowance is recomputed here through the normal equations (delta = -M'(MM')^-1 c), a route
# that shares no code with the package's SVD, so the observation is independent of the function under test.
# Source after pkgload::load_all().
rst_ns <- asNamespace("medfit")

rst_allowance <- function(theta, ram, smp, lb, ub, cons) {
  act <- rst_ns$.sem_active_set(theta, ram, smp, lb, ub, cons)
  r <- rst_ns$.sem_eval(theta, ram, smp, deriv = TRUE)
  free <- act$free
  m <- act$ax[act$active_row, free, drop = FALSE]
  cval <- act$cval[act$active_row]
  if (is.null(r) || !nrow(m)) {
    return(c(allow = NA_real_, n_rows = nrow(m)))
  }
  hx <- rst_ns$.sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  gx <- r$g * act$u
  if (!all(is.finite(c(m, cval, hx, gx)))) {
    return(c(allow = NA_real_, n_rows = nrow(m)))
  }
  gram <- tcrossprod(m)
  if (!is.finite(rcond(gram)) || rcond(gram) < 1e-12) {
    return(c(allow = NA_real_, n_rows = nrow(m))) # dependent rows: the normal equations do not apply
  }
  delta <- -drop(crossprod(m, solve(gram, cval)))
  hl <- rst_ns$.sem_lagrangian_hessian(hx, gx, act, cons, theta)[free, free, drop = FALSE]
  c(allow = abs(sum(gx[free] * delta)) + 0.5 * abs(drop(crossprod(delta, hl %*% delta))), n_rows = nrow(m))
}

log_env <- new.env()
log_env$rows <- list()
log_env$calls <- 0L
log_env$start <- 0L
record <- function(orig_res, orig_gate, ret, ram, smp, lb, ub, cons, restore, fixture, q_tag) {
  log_env$calls <- log_env$calls + 1L
  if (!isTRUE(restore)) {
    return(invisible())
  }
  f0 <- orig_res$objective
  pol <- tryCatch(rst_ns$.sem_polish(orig_res$solution, ram, smp, lb, ub, cons, reach = rst_ns$.sem_restore_reach),
                  error = function(e) NULL)
  a <- tryCatch(rst_allowance(orig_res$solution, ram, smp, lb, ub, cons),
                error = function(e) c(allow = NA_real_, n_rows = NA_real_))
  f1 <- NA_real_
  acc_after <- NA
  dist <- NA_real_
  if (!is.null(pol)) {
    ev <- rst_ns$.sem_eval(pol, ram, smp, deriv = FALSE)
    f1 <- if (is.null(ev)) NA_real_ else ev$f
    g2 <- tryCatch(rst_ns$.sem_gate(pol, orig_res$status, ram, smp, lb, ub, cons), error = function(e) NULL)
    acc_after <- if (is.null(g2)) NA else isTRUE(g2$accepted)
    u <- rst_ns$.sem_active_set(orig_res$solution, ram, smp, lb, ub, cons)$u
    dist <- max(abs(pol - orig_res$solution) / u)
  }
  rise <- f1 - f0
  log_env$rows[[length(log_env$rows) + 1L]] <- data.frame(
    fixture = fixture, q_tag = q_tag, status = orig_res$status, gate_before = isTRUE(orig_gate$accepted),
    polished = !is.null(pol), gate_after = acc_after, kept = !identical(ret$res$solution, orig_res$solution),
    f_before = f0, f_after = f1, rise = rise, allow = unname(a["allow"]), rho = rise / unname(a["allow"]),
    dist = dist, n_rows = unname(a["n_rows"]), stringsAsFactors = FALSE
  )
  invisible()
}

# the profile gate is evaluated here, not in the global environment, so its variables (rows, add, d, k, ...) cannot
# overwrite the caller's
rst_env <- new.env(parent = globalenv())
rst_trace_install <- function() {
  assign("restore_record", record, envir = globalenv())
  suppressMessages(trace(
    ".sem_polish_accept",
    tracer = quote(.orig <- list(res = res, gate = gate)),
    exit = quote({
      ctx <- list(f = get0("f", envir = rst_env), tag = get0("tag", envir = rst_env))
      restore_record(.orig$res, .orig$gate, returnValue(), ram, smp, lb, ub, cons, restore,
                     if (is.list(ctx$f)) ctx$f$id else NA_character_,
                     if (is.character(ctx$tag)) ctx$tag else NA_character_)
    }),
    print = FALSE, where = rst_ns
  ))
}
rst_trace_remove <- function() suppressMessages(untrace(".sem_polish_accept", where = rst_ns))

# The profile gate with its result writer and quit() neutralized (a pattern that does not match exactly once is an
# error); returns the data frame of restoration attempts. `fast` runs 8 fixtures x 3 q's.
rst_run_profile <- function(fast = FALSE) {
  rst_trace_install()
  on.exit(rst_trace_remove(), add = TRUE)
  src <- readLines("tests/sim/sem-nonlinear-profile-gate.R")
  patch <- function(src, pattern, replacement) {
    hit <- which(startsWith(src, pattern))
    if (length(hit) != 1L) {
      stop("the profile gate no longer has exactly one line starting with: ", pattern)
    }
    src[hit] <- replacement
    src
  }
  # the gate reloads the package at its top, which would discard the trace installed above
  src <- patch(src, "suppressMessages(pkgload::load_all", "invisible(NULL)")
  src <- patch(src, "if (!nzchar(mutant) && !fast) {", "if (FALSE) {")
  src <- patch(src, "quit(status", "invisible(NULL)")
  # the profile gate reads MUTANT and FAST from the environment: it must see no mutant (a planted defect is applied to
  # the package by the caller) and the requested size
  old <- Sys.getenv(c("MUTANT", "FAST"), unset = NA)
  restore_env <- function() {
    for (n in names(old)) {
      if (is.na(old[[n]])) Sys.unsetenv(n) else do.call(Sys.setenv, stats::setNames(list(old[[n]]), n))
    }
  }
  on.exit(restore_env(), add = TRUE)
  Sys.setenv(MUTANT = "")
  if (fast) Sys.setenv(FAST = "1") else Sys.unsetenv("FAST")
  # eval() of this repository's own gate script (read from disk above), not of external input
  invisible(utils::capture.output(eval(parse(text = src), envir = rst_env)))
  if (length(log_env$rows)) do.call(rbind, log_env$rows) else data.frame()
}
rst_blas <- function() {
  if (grepl("openblas", tolower(paste(extSoftVersion()["BLAS"], La_library())), fixed = TRUE)) "openblas" else "ref"
}
