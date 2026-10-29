# Nonlinear-constraint gate for the native SEM engine (0.11.0 plan T3, issue #213): a fit with the standardized
# mediation constraint a*b/sqrt(2*(b^2*Vm+Vy)) == q must reach the constrained optimum that an independent
# oracle computes (tests/sim/oracle213.R: a profile over t = b*sqrt(Vm/Vy) on each sign branch; no medfit code,
# no nloptr).
#
# Fixtures (24): 12 (a, b) x sigma_Y^2 cells (the six pairs of the issue, seed 7); 6 sign-branch cells; 4
# rescalings of the issue's seed-101 data by (1e-3, 1), (1e3, 1), (1, 1e-3), (1, 1e3); 2 variance extremes
# ((Vm, Vy) = (1e-6, 1) and (1e6, 1e-6), with a = 0 so that M is not collinear with X). Each fixture runs at
# q in {q_hat, q_hat - 0.1, q_hat + 0.05, q_hat + 0.2, -q_hat, 0} (q_hat: the constraint value at the
# unconstrained MLE, so the constrained optimum is the MLE there).
# Per run the rule (a failing run fails the gate):
#   fit      the fit returns (no "no start converged" error) and has no NaN standard errors
#   request  the constraint value at the fitted parameters is the requested q: |q_achieved - q| <= 1e-5 * max(1, |q|)
#            (the oracle is evaluated at q_achieved, so without this check a fit that solved a different q would pass)
#   oracle   |LR - LR_oracle(q_achieved)| <= 1e-6 * max(1, LR), q_achieved the constraint value at the fitted
#            parameters (the fit meets the constraint to 1e-6, which moves LR by lambda * residual, up to about 3e-6
#            at the nominal q)
#   mle      at q = q_hat, |LR| <= 1e-6
#   null     at q = 0 the oracle is the exact union of the two linear nulls (a = 0, b = 0): |LR - LR_oracle(0)| <= 1e-5
# The fixture var-1e6-1e-6 (R^2 of Y about 1 - 1e-6) is a floor case: the true Vy is below the floor (1e-4 x the natural
# unit), so the floor binds and the constrained optimum is the floored model's. The rule there is not oracle
# agreement but the documented floor contract: the fit warns "solver floor", the floored variance (Vy) is an active
# bound, the discrepancy is finite and the requested q is met.
# `MUTANT=<name>` plants a defect and the gate must then exit 1:
#   noref      the reference fit (and so the reference start, its sign flips and the dominance rule) is dropped
#   noflips    the sign-flipped copies of the reference start are dropped
#   nofloor    no variance floor
#   absfloor   an absolute floor of 1e-4 replaces the relative one
#   oracle1    the oracle searches only the positive sign branch
#   oracle0    the q = 0 oracle uses only the a = 0 null
#   halfq      the fit is asked for q / 2 while the gate checks q (the request check must fail)
#   nofloororacle  the floor fixture's oracle is called without floors (#276: strict rows must then disagree)
#   halffloor  the floor fixture's oracle uses half the solver's floor (a wrong floor unit must fail the row)
# Run from the package root:  Rscript tests/sim/sem-nonlinear-profile-gate.R   (FAST=1 runs 8 fixtures x 3 q's)

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/sim/oracle213.R", local = FALSE)
mutant <- Sys.getenv("MUTANT", "")
fast <- nzchar(Sys.getenv("FAST", ""))
ns <- asNamespace("medfit")
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
  fn <- eval(parse(text = sub(pattern, replacement, src, fixed = TRUE)))
  environment(fn) <- env
  swap(name, fn, env)
}
if (mutant == "noref") {
  swap(".sem_reference_fit", function(ram, smp, start, lb, ub, n_starts, control, precondition, constraints) NULL)
} else if (mutant == "noflips") {
  orig <- get(".sem_reference_starts", ns)
  swap(".sem_reference_starts", function(theta, ram, idx, lb, ub) orig(theta, ram, idx, lb, ub)[1L])
} else if (mutant == "nofloor") {
  swap(".sem_floor_ids", function(ram, smp, idx, ub) integer())
} else if (mutant == "absfloor") {
  mutate_body(".sem_optimize", ".sem_var_floor * .sem_step_floor(ram, smp)[floored]", "1e-4")
} else if (mutant == "oracle1") {
  mutate_body("or213_fit_q", "neg <- or213_branch(-1, q, cr, vm_min = vm_min, vy_min = vy_min)",
              "neg <- list()", globalenv())
} else if (mutant == "oracle0") {
  mutate_body("or213_fit", "min(a0, b0)", "a0", globalenv())
} else if (mutant == "halfq") {
  # the defect is applied where the fit is requested (q_fit below); nothing to patch in the package
  invisible(NULL)
} else if (mutant %in% c("nofloororacle", "halffloor")) {
  # the defect is applied where the floor fixture's oracle is called (floor_scale below); nothing to patch
  invisible(NULL)
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

gen <- function(seed, a, b, sm, sy) {
  set.seed(seed)
  n <- 250
  d <- data.frame(X = stats::rbinom(n, 1, 0.5))
  d$M <- a * d$X + sm * stats::rnorm(n)
  d$Y <- 0.3 * d$X + b * d$M + sy * stats::rnorm(n)
  d
}
model <- "M ~ a*X\nY ~ cp*X + b*M\nM ~~ Vm*M\nY ~~ Vy*Y"
pairs6 <- list(c(0, 0), c(0.05, 0.05), c(0, 1), c(1, 0), c(1.5, 1), c(2.5, 1.5))
signs6 <- list(c(-1.5, -1), c(-1.5, 1), c(1.5, -1), c(-2.5, -1.5), c(0.001, 1), c(1, 0.001))
fx <- list()
add <- function(fixtures, id, d, floor_case = FALSE) {
  c(fixtures, list(list(id = id, data = d, floor_case = floor_case)))
}
for (i in seq_along(pairs6)) for (s2 in c(1, 2)) {
  fx <- add(fx, sprintf("ab%d-s%d", i, s2), gen(7, pairs6[[i]][1], pairs6[[i]][2], 1, sqrt(s2)))
}
for (i in seq_along(signs6)) fx <- add(fx, sprintf("sign%d", i), gen(7, signs6[[i]][1], signs6[[i]][2], 1, 1))
d101 <- gen(101, 2.5, 1.5, 1, sqrt(2))
for (sc in list(c(1e-3, 1), c(1e3, 1), c(1, 1e-3), c(1, 1e3))) {
  d <- d101
  d$M <- d$M * sc[1]
  d$Y <- d$Y * sc[2]
  fx <- add(fx, sprintf("scale-%g-%g", sc[1], sc[2]), d)
}
fx <- add(fx, "var-1e-6-1", gen(7, 0, 1, 1e-3, 1))
fx <- add(fx, "var-1e6-1e-6", gen(7, 0, 1e-3, 1e3, 1e-3), floor_case = TRUE)
if (fast) fx <- fx[c(1, 2, 3, 5, 12, 14, 19, 23)]

q_set <- c("qhat", "qhat-0.1", "qhat+0.05", "qhat+0.2", "-qhat", "zero")
if (fast) q_set <- q_set[c(1, 4, 6)]
q_of <- function(tag, qh) {
  switch(tag, qhat = qh, `qhat-0.1` = qh - 0.1, `qhat+0.05` = qh + 0.05, `qhat+0.2` = qh + 0.2, `-qhat` = -qh, zero = 0)
}

rows <- list()
for (f in fx) {
  d <- f$data
  # the oracle works on columns X, M, Y of the data as they are (a rescaled dataset is just another dataset)
  h1 <- fit_sem(model, d, fixed_x = FALSE, meanstructure = NULL)
  cr <- or213_cross(d)
  qh <- or213_qhat(d)
  for (tag in q_set) {
    q <- q_of(tag, qh)
    q_fit <- if (mutant == "halfq") q / 2 else q
    syn <- paste0(model, "\na*b/sqrt(2*(b^2*Vm+Vy)) == ", format(q_fit, digits = 17))
    wmsg <- character()
    h2 <- tryCatch(
      withCallingHandlers(fit_sem(syn, d, n_starts = 5, fixed_x = FALSE, meanstructure = NULL), warning = function(w) {
        wmsg <<- c(wmsg, conditionMessage(w))
        invokeRestart("muffleWarning")
      }),
      error = function(e) conditionMessage(e)
    )
    if (is.character(h2)) {
      # a refusal on the floor fixture is a flagged outcome (see below), any other error is a failure
      refused <- isTRUE(f$floor_case) && grepl("no start converged", h2, fixed = TRUE)
      rows[[length(rows) + 1L]] <- data.frame(fixture = f$id, q_tag = tag, q = q, native_ok = refused, omx_ok = TRUE,
                                              lr = NA_real_, lr_oracle = NA_real_, gap = if (refused) 0 else NA_real_,
                                              improper = "", note = if (refused) "refused" else substr(h2, 1, 80),
                                              disproved = FALSE, q_ach = NA_real_, stringsAsFactors = FALSE)
      next
    }
    cf <- stats::coef(h2)
    q_ach <- unname(cf["a"] * cf["b"] / sqrt(2 * (cf["b"]^2 * cf["Vm"] + cf["Vy"])))
    lr <- 2 * (as.numeric(stats::logLik(h1)) - as.numeric(stats::logLik(h2)))
    lr_or <- or213_lr(d, if (tag == "zero") 0 else q_ach)
    request_ok <- abs(q_ach - q) <= 1e-5 * max(1, abs(q))
    if (isTRUE(f$floor_case)) {
      warned <- any(grepl("solver floor", wmsg, fixed = TRUE))
      at_floor <- "Vy" %in% h2@diagnostics$active_bounds
      # The floor contract; on some CPUs (a GitHub runner's OpenBLAS kernels) the extreme-scale fit lands on a wrong
      # branch with one accepted start. That is not silent: the fit says so (single-start warning) or refuses with an
      # error, which the oracle sweep also counts as flagged. Only a silent wrong fit fails. The driver additionally
      # requires at least half of the fixture's rows to meet the strict contract (note "strict"), so a solver that
      # always refused or always landed on the wrong branch cannot pass.
      flagged <- any(grepl("starts reached an accepted solution", wmsg, fixed = TRUE))
      # The independent floored oracle (#276 T3). The floors are the solver's rule (.sem_var_floor x the natural unit of
      # a variance, sd^2 with the divisor-n covariance), computed from the data here, not read from the fit; the fitted
      # Vy must sit on the computed floor within the solver's bound window, so a floor that is not the fit's floor fails
      # the row instead of agreeing by accident. The oracle can only disprove: a fit above the independent floored
      # optimum (disproved) fails whether or not it was flagged; a fit below it means the oracle is wrong.
      floor_scale <- if (mutant == "halffloor") 0.5 else if (mutant == "nofloororacle") 0 else 1
      unit_m <- mean((d$M - mean(d$M))^2)
      unit_y <- mean((d$Y - mean(d$Y))^2)
      vm_min <- ns$.sem_var_floor * unit_m
      vy_min <- ns$.sem_var_floor * unit_y
      floor_ok <- abs(unname(cf["Vy"]) - vy_min) <= ns$.sem_bound_window * unit_y
      lr_fl <- or213_lr(d, if (tag == "zero") 0 else q_ach, floor_scale * vm_min, floor_scale * vy_min)
      diff <- lr - lr_fl
      tol_fl <- (if (tag == "zero") 1e-5 else 1e-6) * max(1, lr_fl)
      disproved <- is.finite(diff) && diff > tol_fl
      oracle_above <- is.finite(diff) && diff < -tol_fl
      # At q = 0 the oracle is the exact union of the two linear nulls, so the fit must meet the constraint to an
      # explicit bound (the 1e-5 request tolerance would let the oracle assess another constraint than the fit solved).
      zero_ok <- tag != "zero" || abs(q_ach) <= 1e-7
      strict <- warned && at_floor && floor_ok && is.finite(lr) && request_ok && zero_ok && !disproved && !oracle_above
      ok <- strict || (flagged && request_ok && zero_ok && !disproved && !oracle_above)
      floor_note <- if (disproved) {
        sprintf("disproved: lr=%.8g above the floored oracle %.8g (diff %.3g, tol %.3g)", lr, lr_fl, diff, tol_fl)
      } else if (oracle_above) {
        sprintf("oracle above fit: lr=%.8g below the floored oracle %.8g (diff %.3g)", lr, lr_fl, diff)
      } else {
        sprintf(
          paste("floor contract not met and not flagged: warned=%s at_floor=%s floor_ok=%s flagged=%s finite_lr=%s",
                "request_ok=%s zero_ok=%s q_ach=%.8g active=[%s]"),
          warned, at_floor, floor_ok, flagged, is.finite(lr), request_ok, zero_ok, q_ach,
          paste(h2@diagnostics$active_bounds, collapse = ",")
        )
      }
      rows[[length(rows) + 1L]] <- data.frame(fixture = f$id, q_tag = tag, q = q, native_ok = ok, omx_ok = TRUE,
                                              lr = lr, lr_oracle = lr_fl, gap = abs(diff) / max(1, lr_fl),
                                              improper = "",
                                              note = if (strict) "strict" else if (ok) "flagged" else floor_note,
                                              disproved = disproved, q_ach = q_ach, stringsAsFactors = FALSE)
      next
    }
    se_ok <- !anyNA(suppressWarnings(sqrt(diag(stats::vcov(h2)))))
    gap <- abs(lr - lr_or) / max(1, lr_or)
    tol <- if (tag == "zero") 1e-5 else 1e-6
    ok <- se_ok && request_ok && gap <= tol && (tag != "qhat" || abs(lr) <= 1e-6)
    rows[[length(rows) + 1L]] <- data.frame(fixture = f$id, q_tag = tag, q = q, native_ok = ok, omx_ok = TRUE, lr = lr,
                                            lr_oracle = lr_or, gap = gap, improper = "",
                                            disproved = FALSE, q_ach = q_ach,
                                            note = if (!request_ok) {
                                              "requested q not met"
                                            } else if (!se_ok) {
                                              "NaN standard errors"
                                            } else {
                                              ""
                                            },
                                            stringsAsFactors = FALSE)
  }
}
res <- do.call(rbind, rows)
res$mutant <- mutant
print(res[!res$native_ok, c("fixture", "q_tag", "lr", "lr_oracle", "gap", "note")], row.names = FALSE, right = FALSE)
for (n in res$note[!res$native_ok]) cat("NOTE:", n, "\n")
if (!nzchar(mutant) && !fast) {
  dir.create("tests/sim/results", showWarnings = FALSE)
  utils::write.csv(res, file.path("tests/sim/results", sprintf("sem-nonlinear-profile-gate-%s.csv", Sys.Date())),
                   row.names = FALSE)
}
cat(sprintf("NONLINEAR PROFILE GATE: %d of %d runs pass%s; max gap %.2e\n", sum(res$native_ok), nrow(res),
            if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else "", max(res$gap, na.rm = TRUE)))
quit(status = if (all(res$native_ok)) 0L else 1L)
