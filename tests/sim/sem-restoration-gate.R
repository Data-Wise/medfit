# Restoration-cap gate for the native SEM engine (restoration-bound plan T5,
# planning/specs/IMPL-restoration-bound-2026-10-23.md).
# A status -4 restoration used to be accepted whenever the acceptance gate accepted the restored point, whatever the
# rise of the discrepancy (slack Inf in `.sem_polish_accept`, #276 follow-up). The cap is `.sem_restore_k` times the
# allowance |g' delta| + 0.5 |delta' H_L delta|, delta = -M^+ c, the first-order cost of restoring feasibility.
#
# Rows (one per check; each must pass; all must be present, run-gates.R re-derives the numeric verdicts from the
# recorded numbers):
#   planted    the allowance against the normal-equations value (one row, two independent rows), invariance to a row's
#              scale and to a duplicated row, rank zero fails closed, a restoration into a far worse point refused
#              although the gate accepts it (the gate is mocked there: a feasible, stationary worse point cannot be
#              constructed on demand; the real gate is exercised by the legitimate restorations below), the boundary on
#              either side of rho / k, and the curvature term deciding a case.
#   observed   every restoration attempt over the profile gate's 24 fixtures x 6 q values (trace of
#              `.sem_polish_accept`, allowance recomputed through the normal equations): none that the old code would
#              have kept (the polished point passes the real gate) is refused by the cap, the largest legitimate rho
#              keeps the margin below k (separation), and the cap stays below the
#              smallest objective gap to an inferior basin seen on the run (basin gap; a platform that sees none
#              passes).
# The margin and k live in tests/sim/gates.csv (row `restoration`: tol_est = k, tol_se = margin). run-gates.R --fast
# checks that tol_est equals `.sem_restore_k`.
# `MUTANT=<name>` plants a defect and the gate must then exit 1:
#   infslack    the cap is Inf again (the pre-fix behavior)
#   rawdist     the row values are divided by their length but the rows are not, so the allowance depends on a
#               row's scale
#   nocurv      the curvature term is dropped
#   nopinv      the rank cutoff of the pseudo-inverse is dropped, so a duplicated row blows the step up
#   nafailopen  an NA allowance is accepted instead of refusing the restoration
#   nonorm      the active rows are not normalized before the rank decision (one row's scale decides the cutoff)
#   nodispatch  the optimizer never calls the restoration (the planted rows call the acceptance step directly)
#   kx100       k is 100 times larger
#   shrink      the cap is 0.2 of what it should be (a cap that is too tight)
# Run from the package root:  Rscript tests/sim/sem-restoration-gate.R   (FAST=1 runs 8 fixtures x 3 q's)

suppressMessages(pkgload::load_all(quiet = TRUE))
ns <- asNamespace("medfit")
source("tests/sim/restoration-common.R")
mutant <- Sys.getenv("MUTANT", "")
fast <- nzchar(Sys.getenv("FAST", ""))
spec <- utils::read.csv("tests/sim/gates.csv", stringsAsFactors = FALSE)
spec <- spec[spec$gate == "restoration", , drop = FALSE]
if (nrow(spec) != 1L) stop("tests/sim/gates.csv has no `restoration` row")
margin <- spec$tol_se # k must be at least margin x the largest legitimate rho

swap <- function(name, fn, env = ns) {
  if (bindingIsLocked(name, env)) {
    unlockBinding(name, env)
  }
  assign(name, fn, envir = env)
}
mutate_body <- function(name, pattern, replacement, env = ns) {
  src <- paste(deparse(get(name, env), width.cutoff = 500L), collapse = "\n")
  if (lengths(regmatches(src, gregexpr(pattern, src, fixed = TRUE))) != 1L) {
    stop("MUTANT ", mutant, ": the pattern must match exactly once in ", name, " (", pattern, ")")
  }
  # eval() of this package's own function source with one planted edit, as sem-nonlinear-profile-gate.R does
  fn <- eval(parse(text = sub(pattern, replacement, src, fixed = TRUE)))
  environment(fn) <- env
  swap(name, fn, env)
}
if (mutant == "infslack") {
  mutate_body(".sem_polish_accept", "slack <- .sem_restore_k * allow + .sem_polish_f_slack", "slack <- Inf")
} else if (mutant == "rawdist") {
  mutate_body(".sem_restore_allowance", "cval <- act$cval[act$active_row]",
              "cval <- act$cval[act$active_row]/sqrt(rowSums(m^2))")
} else if (mutant == "nocurv") {
  mutate_body(".sem_restore_allowance", "curv <- 0.5 * abs(drop(crossprod(delta, hl %*% delta)))", "curv <- 0")
} else if (mutant == "nopinv") {
  # deparse() prints 1e-8 as 1e-08
  mutate_body(".sem_restore_allowance", "keep <- sv$d > 1e-08 * max(sv$d)", "keep <- sv$d > 0")
} else if (mutant == "nafailopen") {
  mutate_body(".sem_polish_accept", "if (is.na(allow)) {", "if (FALSE) {")
} else if (mutant == "shrink") {
  mutate_body(".sem_polish_accept", "slack <- .sem_restore_k * allow + .sem_polish_f_slack",
              "slack <- 0.2 * .sem_restore_k * allow + .sem_polish_f_slack")
} else if (mutant == "nonorm") {
  mutate_body(".sem_restore_allowance", "m <- m[use, , drop = FALSE]/len[use]", "m <- m[use, , drop = FALSE]")
  mutate_body(".sem_restore_allowance", "cval <- cval[use]/len[use]", "cval <- cval[use]")
} else if (mutant == "nodispatch") {
  mutate_body(".sem_optimize", "restore = !gate$accepted", "restore = FALSE")
} else if (mutant == "kx100") {
  swap(".sem_restore_k", 100 * get(".sem_restore_k", ns))
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}
k_pkg <- function() get(".sem_restore_k", ns)
k_spec <- spec$tol_est # the k the gate is calibrated for; planted cases are sized from it, never from the package value

# ---- planted rows ----
rb_data <- function(n = 100, seed = 17) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
  data.frame(X = x, M = m, Y = 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7))
}
rb_setup <- function(constraint) {
  fit <- fit_sem(paste0("M ~ a*X\nY ~ b*M + cp*X\n", constraint), rb_data(), fixed_x = FALSE, meanstructure = NULL)
  ram <- fit@internals$ram
  nm <- gsub(" ", "", ram$par_names, fixed = TRUE)
  list(ram = ram, smp = ns$.sem_sample(fit@data, ram), cons = ns$.sem_constraint_rows(fit@internals$constraints, ram),
       lb = rep(-Inf, ram$q), ub = rep(Inf, ram$q), star = unname(fit@theta), nm = nm, ic = match("cp", nm),
       ib = match("b", nm))
}
rb_u <- function(s, th) ns$.sem_active_set(th, s$ram, s$smp, s$lb, s$ub, s$cons)$u
rb_stall <- function(s, d) {
  st <- s$star
  st[s$ic] <- st[s$ic] + d * rb_u(s, st)[s$ic]
  st
}
rb_allow <- function(s, th) ns$.sem_restore_allowance(th, s$ram, s$smp, s$lb, s$ub, s$cons)
rb_geom <- function(s, th) {
  act <- ns$.sem_active_set(th, s$ram, s$smp, s$lb, s$ub, s$cons)
  list(act = act, m = act$ax[act$active_row, act$free, drop = FALSE], cval = act$cval[act$active_row],
       gx = ns$.sem_eval(th, s$ram, s$smp, deriv = TRUE)$g * act$u)
}
# the allowance through the normal equations (the second route to the step), for rows of full rank
rb_hand <- function(s, th) {
  g <- rb_geom(s, th)
  hx <- ns$.sem_hess_f(th, s$ram, s$smp) * outer(g$act$u, g$act$u)
  delta <- -drop(crossprod(g$m, solve(tcrossprod(g$m), g$cval)))
  hl <- ns$.sem_lagrangian_hessian(hx, g$gx, g$act, s$cons, th)[g$act$free, g$act$free, drop = FALSE]
  c(total = abs(sum(g$gx[g$act$free] * delta)) + 0.5 * abs(drop(crossprod(delta, hl %*% delta))),
    first = abs(sum(g$gx[g$act$free] * delta)))
}
rb_restore <- function(s, stall) {
  res <- list(solution = stall, status = -4L, objective = ns$.sem_eval(stall, s$ram, s$smp, deriv = FALSE)$f)
  gate <- ns$.sem_gate(stall, -4L, s$ram, s$smp, s$lb, s$ub, s$cons)
  list(res = res, gate = gate,
       out = ns$.sem_polish_accept(res, gate, s$ram, s$smp, s$lb, s$ub, s$cons, restore = TRUE))
}
# run `expr` with some package bindings replaced, then put them back
with_swapped <- function(new, expr) {
  old <- lapply(names(new), function(n) get(n, ns))
  names(old) <- names(new)
  on.exit(for (n in names(old)) swap(n, old[[n]]), add = TRUE)
  for (n in names(new)) swap(n, new[[n]])
  force(expr)
}
rel <- function(a, b) abs(a - b) / max(abs(b), 1e-300)

gate_rows <- new.env()
gate_rows$rows <- list()
add <- function(check, kind, value, limit, pass, detail = "") {
  gate_rows$rows[[length(gate_rows$rows) + 1L]] <- data.frame(
    check = check, kind = kind, value = value, limit = limit, pass = isTRUE(pass), detail = detail,
    stringsAsFactors = FALSE
  )
}
guard <- function(check, kind, limit, expr_fun) {
  r <- tryCatch(expr_fun(), error = function(e) list(value = NA_real_, pass = FALSE, detail = conditionMessage(e)))
  add(check, kind, r$value, limit, r$pass, if (is.null(r$detail)) "" else r$detail)
}

one <- rb_setup("cp == a*b")
two <- rb_setup("cp == a*b\na == 0.5")

guard("allowance matches the normal-equations value", "planted", 1e-8, function() {
  err <- function(s, d) {
    st <- rb_stall(s, d)
    rel(rb_allow(s, st), rb_hand(s, st)[["total"]])
  }
  e <- max(unlist(lapply(list(one, two), function(s) vapply(c(0.01, 0.05, 0.3), function(d) err(s, d), numeric(1)))))
  list(value = e, pass = is.finite(e) && e <= 1e-8, detail = "one row and two independent rows, d = 0.01, 0.05, 0.3")
})
guard("scale of a row does not change the allowance", "planted", 1e-6, function() {
  scaled <- rb_setup("1000*cp == 1000*a*b")
  e <- rel(rb_allow(scaled, rb_stall(scaled, 0.05)), rb_allow(one, rb_stall(one, 0.05)))
  list(value = e, pass = is.finite(e) && e <= 1e-6, detail = "1000*cp == 1000*a*b against cp == a*b")
})
guard("a duplicated row does not change the allowance", "planted", 1e-6, function() {
  dup <- rb_setup("cp == a*b\na == 0.5\na == 0.5")
  e <- rel(rb_allow(dup, rb_stall(dup, 0.05)), rb_allow(two, rb_stall(two, 0.05)))
  list(value = e, pass = is.finite(e) && e <= 1e-6, detail = "a == 0.5 entered twice")
})
guard("rank zero fails closed", "planted", 1, function() {
  zero <- rb_setup("a*b == 0")
  th <- zero$star
  th[match(c("a", "b"), zero$nm)] <- 0
  na_ok <- is.na(rb_allow(zero, th))
  # the acceptance step refuses a polished point when the allowance is NA, although the gate would accept it
  stall <- rb_stall(one, 0.05)
  r <- rb_restore(one, stall)
  kept <- with_swapped(list(.sem_restore_allowance = function(...) NA_real_),
                       ns$.sem_polish_accept(r$res, r$gate, one$ram, one$smp, one$lb, one$ub, one$cons, restore = TRUE))
  refused <- identical(kept$res$solution, stall)
  list(value = as.numeric(na_ok && refused), pass = na_ok && refused,
       detail = sprintf("NA allowance %s, restoration refused %s", na_ok, refused))
})
guard("a far worse restoration is refused", "planted", 100, function() {
  stall <- rb_stall(one, 0.05)
  base <- rb_restore(one, stall)
  allow <- rb_allow(one, stall)
  u <- rb_u(one, stall)
  bad <- stall
  rise <- 0
  step <- 0.5
  while (rise <= 100 * k_spec * allow && step < 1e3) {
    bad[one$ib] <- stall[one$ib] + step * u[one$ib]
    rise <- ns$.sem_eval(bad, one$ram, one$smp, deriv = FALSE)$f - base$res$objective
    step <- step * 2
  }
  kept <- with_swapped(list(.sem_polish = function(...) bad, .sem_gate = function(...) list(accepted = TRUE)),
                       ns$.sem_polish_accept(base$res, base$gate, one$ram, one$smp, one$lb, one$ub, one$cons,
                                             restore = TRUE))
  refused <- identical(kept$res$solution, stall)
  list(value = rise / (k_spec * allow), pass = rise > 100 * k_spec * allow && refused,
       detail = "rise as a multiple of the cap; the replacement is feasible-looking and the gate (mocked) accepts it")
})
# a legitimate restoration (the real gate decides) and its measured ratio rho
stall05 <- rb_stall(one, 0.05)
base05 <- rb_restore(one, stall05)
allow05 <- rb_allow(one, stall05)
restored05 <- ns$.sem_polish(stall05, one$ram, one$smp, one$lb, one$ub, one$cons, reach = ns$.sem_restore_reach)
rho05 <- (ns$.sem_eval(restored05, one$ram, one$smp, deriv = FALSE)$f - base05$res$objective) / allow05
guard("boundary: accepted at k = rho / 0.9", "planted", NA_real_, function() {
  out <- with_swapped(list(.sem_restore_k = rho05 / 0.9), rb_restore(one, stall05)$out)
  list(value = rho05, pass = isTRUE(out$gate$accepted), detail = sprintf("rho = %.4f", rho05))
})
guard("boundary: refused at k = rho / 1.1", "planted", NA_real_, function() {
  out <- with_swapped(list(.sem_restore_k = rho05 / 1.1), rb_restore(one, stall05)$out)
  list(value = rho05, pass = !isTRUE(out$gate$accepted) && identical(out$res$solution, stall05),
       detail = sprintf("rho = %.4f", rho05))
})
guard("one row's scale does not move the allowance", "planted", 1e-6, function() {
  st <- rb_stall(two, 0.05)
  base <- rb_allow(two, st)
  real <- get(".sem_active_set", ns)
  dev <- 0
  for (sc in c(1e-9, 1e9)) {
    scaled <- function(...) {
      act <- real(...)
      idx <- which(act$active_row)[2L]
      act$ax[idx, ] <- act$ax[idx, ] * sc
      act$cval[idx] <- act$cval[idx] * sc
      act
    }
    swap(".sem_active_set", scaled)
    v <- tryCatch(rb_allow(two, st), finally = swap(".sem_active_set", real))
    dev <- max(dev, abs(v - base) / base)
  }
  list(value = dev, pass = is.finite(dev) && dev < 1e-6, detail = "relative change, second row scaled by 1e-9 and 1e9")
})
guard("the curvature term decides a case", "planted", 1.1, function() {
  st <- rb_stall(one, 0.3)
  h <- rb_hand(one, st)
  v <- rb_allow(one, st) / h[["first"]]
  list(value = v, pass = is.finite(v) && v > 1.1, detail = "allowance over |g' delta| alone at d = 0.3")
})

# ---- observed rows ----
d <- rst_run_profile(fast)
k <- k_pkg()
# The population is what the OLD code would have kept (the polished point passes the real gate), not what the capped
# code kept: a cap that is too tight refuses restorations #276 needed, and those would drop out of a "kept" count.
old_kept <- d[d$polished %in% TRUE & d$gate_after %in% TRUE & is.finite(d$rise) & is.finite(d$allow), , drop = FALSE]
refused <- sum(!(old_kept$kept %in% TRUE))
over <- sum(old_kept$rise > k * old_kept$allow + 1e-8)
worst <- if (nrow(old_kept)) max(old_kept$rise / pmax(old_kept$allow, 1e-8)) else NA_real_
add("no restoration the old code kept is refused by the cap", "observed", refused, 0,
    refused == 0 && over == 0,
    sprintf("%d would-have-kept of %d attempts; %d refused, %d above k * allow + 1e-8; worst rise / allow %s",
            nrow(old_kept), nrow(d), refused, over, format(worst, digits = 4)))
big <- old_kept[old_kept$rise > 1e-8, , drop = FALSE]
rho_max <- if (nrow(big)) max(big$rho) else NA_real_
add("separation: k keeps its margin over the largest legitimate rho", "observed", rho_max, k / margin,
    (is.na(rho_max) || rho_max <= k / margin) && isTRUE(k == k_spec),
    sprintf("%d kept restorations with a rise above 1e-8; package k = %g, gates.csv k = %g, margin %g",
            nrow(big), k, k_spec, margin))
inferior <- numeric()
if (nrow(d)) {
  grp <- paste(d$fixture, d$q_tag)
  for (g in unique(grp)) {
    f0 <- d$f_before[grp == g]
    best <- min(f0)
    inferior <- c(inferior, f0[f0 - best > 0.1] - best)
  }
}
gap_min <- if (length(inferior)) min(inferior) else NA_real_
cap_max <- if (nrow(big)) k * max(big$allow) else NA_real_
add("basin gap: the cap stays below the nearest inferior basin", "observed", cap_max, gap_min,
    is.na(cap_max) || is.na(gap_min) || cap_max < gap_min,
    sprintf("%d inferior-basin stalls seen (none is a pass: the platform did not produce one)", length(inferior)))
# the production path must be traced: a wiring change that stops `.sem_optimize` calling the restoration leaves the
# trace empty, and an empty trace must fail, not pass (the planted rows call the acceptance step directly)
min_attempts <- if (fast) 0L else 8L # the fast subset has no status -4 stall
add("restoration attempts observed", "observed", nrow(d), min_attempts,
    nrow(d) >= min_attempts && (fast || (nrow(old_kept) >= 1L && any(old_kept$rise > 1e-8 & old_kept$allow > 0))),
    sprintf("%s BLAS; %d traced restorations, %d polished and gate-accepted; at least %d needed, one with a rise",
            rst_blas(), nrow(d), nrow(old_kept), min_attempts))

res <- do.call(rbind, gate_rows$rows)
res$mutant <- mutant
print(res[, c("check", "value", "limit", "pass")], row.names = FALSE, right = FALSE)
for (n in res$detail[!res$pass]) cat("FAIL:", n, "\n")
if (!nzchar(mutant) && !fast) {
  dir.create("tests/sim/results", showWarnings = FALSE)
  utils::write.csv(res, file.path("tests/sim/results", sprintf("sem-restoration-gate-%s.csv", Sys.Date())),
                   row.names = FALSE)
}
cat(sprintf("RESTORATION GATE: %d of %d checks pass%s\n", sum(res$pass), nrow(res),
            if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else ""))
quit(status = if (all(res$pass)) 0L else 1L)
