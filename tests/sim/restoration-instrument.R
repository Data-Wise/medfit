# Read-only instrument for status -4 restorations (restoration-bound plan T2,
# planning/specs/IMPL-restoration-bound-2026-10-23.md). Not a gate and not in gates.csv: it records every
# restoration attempt (`.sem_polish_accept(restore = TRUE)`) made while the nonlinear-profile gate's fixtures are
# fitted, so the allowance |g'delta| + 0.5|delta' H_L delta| and the rise it must bound can be compared on real
# attempts. It changes no package behavior: `trace()` wraps `.sem_polish_accept` and only reads; the polish and
# the gate are recomputed from the entry arguments to give the hypothetical rise of a rejected attempt.
#
# The fixtures are the profile gate's own (tests/sim/sem-nonlinear-profile-gate.R is evaluated with its result
# writer and `quit()` neutralized, so there is one fixture builder and no results CSV from this script).
#
# Per attempt (one CSV row): fixture, q_tag, status, gate accepted before and after (the after is the gate's verdict
# on the polished point), whether the polish returned a point, whether the unmodified code kept it, f before and
# after, rise, allowance, rho = rise / allowance, restoration distance (natural units), active rows, and the
# per-fit start index. The quantities missing on an early return (no polished point) are NA, never an error.
#
# Run from the package root:  Rscript tests/sim/restoration-instrument.R [out.csv]   (FAST=1: 8 fixtures x 3 q's)
# Output: tests/sim/results/restoration-instrument-<fast|full>-<blas>-<date>.csv unless a path is given. The
# `results/` prefix is not read by run-gates.R (its gates match their own prefixes), but delete smoke runs anyway.

suppressMessages(pkgload::load_all(quiet = TRUE))
ns <- asNamespace("medfit")
out_arg <- commandArgs(trailingOnly = TRUE)
fast <- nzchar(Sys.getenv("FAST", ""))

# allowance of the plan (IMPL section 1.2), recomputed here from the entry arguments, never from package code
allowance <- function(theta, ram, smp, lb, ub, cons) {
  act <- ns$.sem_active_set(theta, ram, smp, lb, ub, cons)
  r <- ns$.sem_eval(theta, ram, smp, deriv = TRUE)
  free <- act$free
  m <- act$ax[act$active_row, free, drop = FALSE]
  cval <- act$cval[act$active_row]
  if (is.null(r) || !nrow(m)) {
    return(c(allow = NA_real_, n_rows = nrow(m)))
  }
  hx <- ns$.sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  gx <- r$g * act$u
  if (!all(is.finite(c(m, cval, hx, gx)))) {
    return(c(allow = NA_real_, n_rows = nrow(m)))
  }
  sv <- svd(m)
  keep <- sv$d > 1e-8 * max(sv$d)
  if (!any(keep)) {
    return(c(allow = NA_real_, n_rows = nrow(m)))
  }
  delta <- -drop(sv$v[, keep, drop = FALSE] %*% (crossprod(sv$u[, keep, drop = FALSE], cval) / sv$d[keep]))
  hl <- ns$.sem_lagrangian_hessian(hx, gx, act, cons, theta)[free, free, drop = FALSE]
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
  pol <- tryCatch(ns$.sem_polish(orig_res$solution, ram, smp, lb, ub, cons, reach = ns$.sem_restore_reach),
                  error = function(e) NULL)
  a <- tryCatch(allowance(orig_res$solution, ram, smp, lb, ub, cons), error = function(e) c(allow = NA_real_, n_rows = NA_real_))
  f1 <- NA_real_
  acc_after <- NA
  dist <- NA_real_
  if (!is.null(pol)) {
    ev <- ns$.sem_eval(pol, ram, smp, deriv = FALSE)
    f1 <- if (is.null(ev)) NA_real_ else ev$f
    g2 <- tryCatch(ns$.sem_gate(pol, orig_res$status, ram, smp, lb, ub, cons), error = function(e) NULL)
    acc_after <- if (is.null(g2)) NA else isTRUE(g2$accepted)
    u <- ns$.sem_active_set(orig_res$solution, ram, smp, lb, ub, cons)$u
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
assign("restore_record", record, envir = globalenv())

suppressMessages(trace(
  ".sem_polish_accept",
  tracer = quote(.orig <- list(res = res, gate = gate)),
  exit = quote({
    ctx <- list(f = get0("f", envir = globalenv()), tag = get0("tag", envir = globalenv()))
    restore_record(.orig$res, .orig$gate, returnValue(), ram, smp, lb, ub, cons, restore,
                   if (is.list(ctx$f)) ctx$f$id else NA_character_, if (is.character(ctx$tag)) ctx$tag else NA_character_)
  }),
  print = FALSE, where = ns
))
on.exit(suppressMessages(untrace(".sem_polish_accept", where = ns)), add = TRUE)

# the profile gate, with the result writer and quit() neutralized (a pattern that does not match exactly once is an error)
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
if (fast) Sys.setenv(FAST = "1")
# eval() of this repository's own gate script (read from disk above), not of external input
invisible(utils::capture.output(eval(parse(text = src), envir = globalenv())))

d <- if (length(log_env$rows)) do.call(rbind, log_env$rows) else data.frame()
blas <- if (grepl("openblas", tolower(paste(extSoftVersion()["BLAS"], La_library())), fixed = TRUE)) "openblas" else "ref"
path <- if (length(out_arg)) {
  out_arg[1L]
} else {
  dir.create("tests/sim/results", showWarnings = FALSE)
  file.path("tests/sim/results", sprintf("restoration-instrument-%s-%s-%s.csv", if (fast) "fast" else "full", blas, Sys.Date()))
}
utils::write.csv(d, path, row.names = FALSE)
cat(sprintf("restoration instrument: %d restoration attempts over %d polish calls -> %s\n", nrow(d), log_env$calls, path))
if (nrow(d)) {
  cat(sprintf("polished %d, kept %d, gate_after accepted %d, rho max %.3g (finite %d)\n", sum(d$polished), sum(d$kept),
              sum(d$gate_after %in% TRUE), suppressWarnings(max(d$rho[is.finite(d$rho)], -Inf)), sum(is.finite(d$rho))))
}
