# Fixture 3 (audit F1, plan T6): an inequality row that coincides with the equality rows stops the fit.
#
# `a == b` with `a - b < 0` is consistent, and so is `a + b == 0.8` with `a + b > 0.8`: on the equality set the inequality row
# has a constant value (0), so it is active at every feasible point and its gradient lies in the span of the equality
# gradients. SLSQP then gets a rank-deficient active Jacobian, the same condition #122 fixed for duplicated equality rows.
# This script (1) counts how often the 0.7.0 code fits each set over 12 seeded datasets, (2) repeats the count with a prototype
# that drops an inequality row lying in the span of the equality rows when its constant value satisfies it, and checks the result
# against the equivalent independent set to 1e-6, (3) checks that an inconsistent set still errors.
# The prototype replaces .sem_nlopt_constraints() in the loaded namespace for the second pass only; nothing in R/ changes.
# Run from this directory: Rscript 03-redundant-inequality-sets.R. Exits nonzero if an ASSERT fails.
suppressMessages(pkgload::load_all("../../../..", quiet = TRUE))
failures <- 0L
assert <- function(label, ok) {
  cat(sprintf("ASSERT %-4s %s\n", if (isTRUE(ok)) "PASS" else "FAIL", label))
  if (!isTRUE(ok)) failures <<- failures + 1L
}
base <- "M ~ a*X\nY ~ b*M + cp*X"
cases <- data.frame(
  kind = c("coincident", "coincident", "coincident", "coincident", "coincident", "inactive", "ineq-only", "ineq-only", "inconsistent"),
  set = c("a == b\na - b < 0", "a == b\na - b > 0", "a + b == 0.8\na + b > 0.8", "a + b == 0.8\na + b < 0.8",
          "a + b == 0.2\na + b > 0.2", "a + b == 0.8\na + b < 0.9", "a + b < 0.2\na + b < 0.2",
          "a + b < 0.2\n2*a + 2*b < 0.4", "a + b == 0.8\na + b < 0.5"),
  indep = c("a == b", "a == b", "a + b == 0.8", "a + b == 0.8", "a + b == 0.2", "a + b == 0.8", "a + b < 0.2", "a + b < 0.2", NA),
  stringsAsFactors = FALSE
)
data_for <- function(seed) {
  set.seed(seed)
  n <- 200
  X <- rnorm(n)
  M <- .5 * X + rnorm(n)
  Y <- .4 * M + .1 * X + rnorm(n)
  data.frame(X, M, Y)
}
fit1 <- function(extra, d) {
  tryCatch(suppressWarnings(.sem_fit_syntax(paste0(base, "\n", extra), d, "observed")), error = function(e) e)
}

# Prototype: drop an inequality row that lies in the span of the independent equality rows (residual below `implied_tol`, far
# tighter than the 1e-8 equality rank tolerance: see the near-dependence ladder below) when it holds on the equality set.
# A violated implied row is KEPT, so the acceptance gate reports it; the prototype never raises an up-front error.
implied_tol <- 1e-12
proto <- function(cons, u) {
  if (is.null(cons)) {
    return(NULL)
  }
  eq <- .sem_independent_rows(cons$eq)
  ineq <- cons$ineq
  if (nrow(eq$A) && nrow(ineq$A)) {
    dec <- qr(t(eq$A), tol = .sem_rank_tol)
    Q <- qr.Q(dec)[, seq_len(dec$rank), drop = FALSE]
    resid <- ineq$A - (ineq$A %*% Q) %*% t(Q)
    inspan <- sqrt(rowSums(resid^2)) < implied_tol
    theta0 <- as.vector(t(eq$A) %*% solve(eq$A %*% t(eq$A), -eq$b)) # a point of the equality set
    holds <- as.vector(ineq$A %*% theta0) + ineq$b <= 1e-8
    drop <- inspan & holds
    if (any(drop)) {
      ineq <- list(A = ineq$A[!drop, , drop = FALSE], b = ineq$b[!drop], text = ineq$text[!drop])
    }
  }
  out <- list()
  if (nrow(eq$A)) {
    je <- sweep(eq$A, 2L, u, "*")
    out$eval_g_eq <- function(x) as.vector(je %*% x) + eq$b
    out$eval_jac_g_eq <- function(x) je
  }
  if (nrow(ineq$A)) {
    ji <- sweep(ineq$A, 2L, u, "*")
    out$eval_g_ineq <- function(x) as.vector(ji %*% x) + ineq$b
    out$eval_jac_g_ineq <- function(x) ji
  }
  out
}

run_all <- function() {
  do.call(rbind, lapply(seq_len(nrow(cases)), function(i) {
    do.call(rbind, lapply(1:12, function(seed) {
      d <- data_for(seed)
      r <- fit1(cases$set[i], d)
      ok <- !inherits(r, "error")
      gap <- NA_real_
      if (ok && !is.na(cases$indep[i])) {
        ref <- fit1(cases$indep[i], d)
        if (!inherits(ref, "error")) gap <- max(abs(r$theta - ref$theta[names(r$theta)]))
      }
      data.frame(kind = cases$kind[i], set = gsub("\n", " ; ", cases$set[i]), seed = seed, ok = ok, gap = gap,
                 msg = if (ok) "" else substr(conditionMessage(r), 1, 220), stringsAsFactors = FALSE)
    }))
  }))
}
summ <- function(R) {
  do.call(rbind, lapply(split(R, factor(R$set, unique(R$set))), function(d) {
    data.frame(kind = d$kind[1], set = d$set[1], fits = sum(d$ok), of = nrow(d),
               max_gap = if (all(is.na(d$gap))) NA else signif(max(d$gap, na.rm = TRUE), 2),
               first_error = if (any(!d$ok)) d$msg[!d$ok][1] else "")
  }))
}

cat("== 0.7.0 code ==\n")
before <- run_all()
sb <- summ(before)
print(sb[, c("kind", "set", "fits", "of", "max_gap")], row.names = FALSE)
cat("first error messages seen:\n")
print(unique(before$msg[!before$ok & before$kind == "coincident"]))

ns <- asNamespace("medfit")
orig <- get(".sem_nlopt_constraints", ns)
unlockBinding(".sem_nlopt_constraints", ns)
assign(".sem_nlopt_constraints", proto, ns)
cat("\n== prototype: implied inequality rows dropped ==\n")
after <- run_all()
assign(".sem_nlopt_constraints", orig, ns)
sa <- summ(after)
print(sa[, c("kind", "set", "fits", "of", "max_gap")], row.names = FALSE)
utils::write.csv(rbind(cbind(code = "0.7.0", before), cbind(code = "prototype", after)), "results/03-redundant-inequality-sets.csv", row.names = FALSE)

co <- sb$kind == "coincident"
assert(sprintf("defect reproduces: every coincident set fails on some seed (fits %s of 12)", paste(sb$fits[co], collapse = ", ")), all(sb$fits[co] < 12))
assert("controls: an inactive inequality and inequality-only redundancy fit on all 12 seeds with the 0.7.0 code",
       all(sb$fits[sb$kind %in% c("inactive", "ineq-only")] == 12))
assert("prototype: every consistent set fits on all 12 seeds", all(sa$fits[sa$kind != "inconsistent"] == 12))
assert(sprintf("prototype matches the independent-set optimum to 1e-6 (max gap %.1e)", max(sa$max_gap, na.rm = TRUE)),
       max(sa$max_gap, na.rm = TRUE) <= 1e-6)
assert("an inconsistent set still errors with the 0.7.0 code and with the prototype, naming the violated constraint",
       sb$fits[sb$kind == "inconsistent"] == 0 && sa$fits[sa$kind == "inconsistent"] == 0 &&
         grepl("violated", sa$first_error[sa$kind == "inconsistent"]))

# ---- near-dependence ladder (Codex review, finding 3) -------------------------------------------------------------
# `a == b` with `a - b + k*cp > 1e-7`. For k > 0 the row is NOT in the span of the equality row, and the set is feasible
# (take cp large). A rule that declares an up-front error when the projection residual is below 1e-8 and the constant at the
# minimum-norm equality solution is positive would reject these feasible models; the drop-only rule keeps the row.
cat("\n== near-dependence ladder: a == b ; a - b + k*cp > 1e-7 ==\n")
ladder <- do.call(rbind, lapply(c(1e-6, 1e-8, 1e-9, 1e-10, 1e-12, 1e-14), function(k) {
  Aeq <- matrix(c(1, -1, 0) / sqrt(2), 1)
  r <- c(1, -1, k)
  len <- sqrt(sum(r^2))
  A <- -r / len
  b <- 1e-7 / len
  Q <- qr.Q(qr(t(Aeq)))
  resid <- sqrt(sum((A - as.vector((A %*% Q) %*% t(Q)))^2))
  c0 <- sum(A * rep(0, 3)) + b # value at the minimum-norm point (a, b, cp) = 0 of the equality set
  cp_feasible <- 2e-7 / k # a point with a == b and a - b + k*cp = 2e-7 > 1e-7
  feasible <- (sum(A * c(0.5, 0.5, cp_feasible)) + b) <= 0
  data.frame(k = k, residual = signif(resid, 3), constant_at_min_norm = signif(c0, 3), feasible_point_exists = feasible,
             old_rule_errors = resid < 1e-8 && c0 > 1e-8, drop_only_drops = resid < implied_tol && c0 <= 1e-8)
}))
print(ladder, row.names = FALSE)
assert("every ladder set is feasible (a point with a == b satisfies the inequality)", all(ladder$feasible_point_exists))
assert(sprintf("the 1e-8 up-front-error rule would reject %d feasible sets (k = %s)", sum(ladder$old_rule_errors),
               paste(ladder$k[ladder$old_rule_errors], collapse = ", ")), any(ladder$old_rule_errors))
assert("the drop-only rule with tolerance 1e-12 keeps every ladder row that is not numerically exact (k >= 1e-10), so none is rejected or lost",
       !any(ladder$drop_only_drops[ladder$k >= 1e-10]))

cat(sprintf("\nR %s; nloptr %s; medfit %s\n", getRversion(), utils::packageVersion("nloptr"), utils::packageVersion("medfit")))
if (failures > 0L) {
  cat(sprintf("\nFAILED: %d assertion(s)\n", failures))
  quit(status = 1)
}
cat("\nall assertions passed\n")
