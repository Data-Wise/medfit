# Fixture 3 (audit F1, plan T6): an inequality row that coincides with the equality rows stops the fit.
#
# `a == b` with `a - b < 0` is consistent, and so is `a + b == 0.8` with `a + b > 0.8`: on the equality set the inequality row
# has a constant value (0), so it is active at every feasible point and its gradient lies in the span of the equality
# gradients. SLSQP then gets a rank-deficient active Jacobian, the same condition #122 fixed for duplicated equality rows.
# This script (1) counts how often the package code fits each set over 12 seeded datasets, (2) checks the result against the
# equivalent independent set to 1e-6, (3) checks that an inconsistent set still errors, naming the violated constraint, and (4) runs the
# near-dependence ladder. Since T6 the package drops an implied, satisfied inequality row from the solver's rows
# (.sem_drop_implied_ineq()), so every coincident set must fit on all 12 seeds. Run against the 0.7.0/dev code before T6 the "fixed"
# ASSERT fails (the coincident sets fit 5 to 7 of 12), which is the control that shows the script can fail.
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

# The rule under test (R/sem-constraints.R, .sem_drop_implied_ineq()): drop an inequality row whose gradient lies within
# `.sem_implied_tol` (1e-12, far tighter than the 1e-8 equality rank tolerance: see the ladder below) of the span of the independent
# equality rows when it holds on the equality set. A violated implied row is KEPT, so the acceptance gate reports it; the rule never
# raises an up-front error.
implied_tol <- if (exists(".sem_implied_tol", asNamespace("medfit"))) get(".sem_implied_tol", asNamespace("medfit")) else 1e-12 # pre-T6 code has none

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

cat("== package code ==\n")
res <- run_all()
sr <- summ(res)
print(sr[, c("kind", "set", "fits", "of", "max_gap")], row.names = FALSE)
cat("first error messages seen:\n")
print(unique(res$msg[!res$ok]))
utils::write.csv(cbind(code = "package", res), "results/03-redundant-inequality-sets.csv", row.names = FALSE)

co <- sr$kind == "coincident"
assert(sprintf("fixed: every coincident set fits on all 12 seeds (fits %s of 12)", paste(sr$fits[co], collapse = ", ")), all(sr$fits[co] == 12))
assert("controls: an inactive inequality and inequality-only redundancy fit on all 12 seeds", all(sr$fits[sr$kind %in% c("inactive", "ineq-only")] == 12))
assert(sprintf("every consistent set matches the independent-set optimum to 1e-6 (max gap %.1e)", max(sr$max_gap, na.rm = TRUE)),
       max(sr$max_gap, na.rm = TRUE) <= 1e-6)
assert("an inconsistent set still errors, naming the violated constraint",
       sr$fits[sr$kind == "inconsistent"] == 0 && grepl("violated", sr$first_error[sr$kind == "inconsistent"]))
assert("a genuinely inconsistent equality pair (a == 1 ; a == 2) still errors",
       inherits(fit1("a == 1\na == 2", data_for(1)), "error"))

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
