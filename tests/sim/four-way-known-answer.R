# Known-answer simulation for the four-way decomposition (0.10.0 plan U8): components AND standard errors.
#
# Data come from known a, b, c', theta3 (binary X, reference level m_star; tests/testthat/helper-four-way-oracle.R,
# `fwo_kat_*`), so the true CDE, INTref, INTmed, PIE, NDE, NIE and TE are known. The design (X, covariates, weights) is
# held fixed across REPS replications (default 1000) and only the errors are redrawn, so the covariate means the effects
# use are constants and the empirical SD of the estimates is the SD the conditional delta-method SE targets.
# Per route and component: bias_z = (mean estimate - truth) / (SD / sqrt(REPS)), se_ratio = RMS reported SE /
# empirical SD.
#
# Scenarios (n = 400; every one has the mediator-covariate structure the F1 defect needed, except C, the simple case):
#   A  one mediator covariate, unweighted, m_star = 0.7      B  two covariates, case weights, m_star = 0.3
#   C  no covariate, unweighted, m_star = 0
# Routes (the same data, the same truth):
#   hand    the independent oracle: per-equation OLS with the hand-written delta method (ML-scaled model SEs; stacked
#   HC0 when
#           weighted), so the oracle itself is checked against the truth rather than trusted
#   glm     fit_mediation() on the glm engine (model-based SEs; HC3 per equation when weighted)
#   lavaan  extract_mediation() of a lavaan fit (observed information; lavaan's robust sandwich when weighted)
#   native  OPTIONAL (ROUTES=hand,glm,lavaan,native): fit_sem() with the `:` product term. Not part of the committed
#   baseline;
#           it is skipped with a message while the `:` token does not parse (0.10.0 plan U1-U3 and U7), and the route's
#           code in the helper is written against the plan, to be adjusted to the shipped API.
#
# Rule (gates.csv row "four-way-kat", implemented in tests/sim/product-gate-common.R): |bias_z| <= 4, |se_ratio - 1|
# <= 0.12 for
# every row (derivation in that file), at least 99% of the replications fitted.
# `MUTANT=<name>` plants a defect and the gate must then exit 1:
#   nocovgrad    the lavaan/glm SE gradient drops the mediator-covariate term (the live F1 defect of 0.8.0)
#   unwtd_glm    the glm route takes unweighted covariate means under weights (as the lavaan worker did before U0, F5)
#   unwtd_lavaan the lavaan worker takes unweighted covariate means under weights (the F5 defect itself)
#   oracle       the hand oracle's gradient drops the covariate term
#   wrongtruth   the reference truth ignores the weights
# Run from the package root:  Rscript tests/sim/four-way-known-answer.R   (REPS=1000)

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  suppressMessages(pkgload::load_all(quiet = TRUE))
}
source("tests/testthat/helper-four-way-oracle.R", local = TRUE)
source("tests/testthat/helper-sem.R", local = TRUE) # provides sem_mutate
source("tests/sim/product-gate-common.R", local = TRUE)
# nolint start: object_usage_linter. (helpers come from the sourced files)

kat_scenarios <- list(
  A = list(covs = "c1", weighted = FALSE, m_star = 0.7, seed = 7L),
  B = list(covs = c("c1", "c2"), weighted = TRUE, m_star = 0.3, seed = 8L),
  C = list(covs = character(0), weighted = FALSE, m_star = 0, seed = 9L)
)

kat_routes <- function(weighted, oracle_defect = "none", which = c("hand", "glm", "lavaan")) {
  all <- list(
    hand = fwo_route_hand(if (weighted) "hc0_joint" else "ml", oracle_defect),
    glm = function(d, covs, w, ms) fwo_route_glm(d, covs, w, ms, se_type = if (weighted) "sandwich" else "model"),
    lavaan = function(d, covs, w, ms) fwo_route_lavaan(d, covs, w, ms),
    native = function(d, covs, w, ms) fwo_route_native(d, covs, w, ms, se_type = if (weighted) "sandwich" else "model")
  )
  all[which]
}

# Plant a defect in the package code under test; returns a function that restores every binding it replaced.
kat_plant <- function(mutant) {
  ns <- asNamespace("medfit")
  saved <- new.env()
  swap <- function(name, fn) {
    assign(name, get(name, ns), envir = saved)
    unlockBinding(name, ns)
    assign(name, fn, envir = ns)
  }
  restore <- function() {
    for (name in ls(saved)) assign(name, get(name, saved), envir = ns)
  }
  if (mutant == "nocovgrad") {
    swap(".effect_gradients_interaction",
         sem_mutate(get(".effect_gradients_interaction", ns), "cov_grad[pn] <- t3 * cm", "cov_grad[pn] <- 0"))
  } else if (mutant == "unwtd_glm") {
    swap(".interaction_covariate_means",
         sem_mutate(get(".interaction_covariate_means", ns), "sum(mm[, cv] * w)/sum(w)", "mean(mm[, cv])"))
  } else if (mutant == "unwtd_lavaan") {
    swap(".extract_interaction_mediation_lavaan",
         sem_mutate(get(".extract_interaction_mediation_lavaan", ns), "else sum(data[[cv]] * w)/sum(w)",
                    "else mean(data[[cv]])"))
  }
  restore
}

gate_four_way_kat <- function(reps = as.integer(Sys.getenv("REPS", "1000")), n = 400L,
                              mutant = Sys.getenv("MUTANT", ""),
                              route_names = strsplit(Sys.getenv("ROUTES", "hand,glm,lavaan"), ",", fixed = TRUE)[[1]],
                              scenarios = kat_scenarios) {
  stopifnot(mutant %in% c("", "nocovgrad", "unwtd_glm", "unwtd_lavaan", "oracle", "wrongtruth"))
  if ("native" %in% route_names && !fwo_native_available()) {
    message("native route skipped: the `:` product term does not parse in this build")
    route_names <- setdiff(route_names, "native")
  }
  restore <- kat_plant(mutant)
  on.exit(restore(), add = TRUE)
  truth <- fwo_kat_truth()
  rows <- list()
  for (sc in names(scenarios)) {
    s <- scenarios[[sc]]
    design <- fwo_kat_design(n, s$seed, s$covs, s$weighted)
    routes <- kat_routes(s$weighted, if (identical(mutant, "oracle")) "no_cov_term" else "none", route_names)
    for (rt in names(routes)) {
      r <- fwo_kat_run(routes[[rt]], design, truth, s$m_star, reps = reps)
      if (identical(mutant, "wrongtruth")) {
        ref <- design
        ref$w <- NULL
        tv <- fwo_kat_components(truth, ref, s$m_star)[fwo_keys]
        r$bias_z <- (r$mean_est - tv) / (r$sd_est / sqrt(r$reps_ok))
      }
      rows[[length(rows) + 1L]] <- cbind(scenario = sc, route = rt, r, reps = reps, mutant = mutant,
                                         stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  res <- gate_four_way_kat()
  num <- vapply(res, is.numeric, logical(1))
  res[num] <- lapply(res[num], round, 6)
  print(res[, c("scenario", "route", "component", "truth", "mean_est", "bias_z", "sd_est", "rms_se", "se_ratio")],
        digits = 3, row.names = FALSE)
  if (!nzchar(Sys.getenv("MUTANT", ""))) product_write_results(res, "four-way-known-answer")
  quit(status = product_gate_status("four-way-kat", res, product_gate_spec("four-way-kat")))
}
# nolint end
