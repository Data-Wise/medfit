# Generate `mediation_demo`: simulated data for package demonstrations.
#
# SIMULATED DATA. It describes no real study, population, or finding. The
# workplace-training story in ?mediation_demo exists only to make the demos
# read concretely.
#
# Design record: planning/specs/GRILL-bundled-example-data-2026-09-23.md
# (decisions D1-D10). Run this file with source() from the package root.
#
# ---------------------------------------------------------------------------
# nolint start: commented_code_linter.
# Generating equations (D6). All errors are independent N(0, 1).
#
#   treatment   ~ Bernoulli(0.5), randomized (independent of covariates)
#   covariate1  ~ N(0, 1)
#   covariate2  ~ Bernoulli(0.5)
#   mediator1   = 0.5*treatment + 0.3*covariate1 + 0.3*covariate2 + e1
#   mediator2   = 0.2*treatment + 0.5*mediator1  + 0.2*covariate1 + e2
#   mediator3   = 0.5*treatment + e3
#   outcome     = 0.2*treatment + 0.4*mediator1 + 0.3*mediator2
#                 + 0.3*mediator3 + 0.3*covariate1 + 0.2*covariate2 + e4
#   outcome_int = outcome + 0.5*treatment*mediator1
# nolint end
#
# mediator2 is the serial child of mediator1; mediator3 is a parallel
# mediator that depends on treatment only. `outcome` has no product terms;
# `outcome_int` adds the treatment x mediator1 interaction for the four-way
# decomposition demo.
#
# Known-answer targets for each demo are the reduced-form limits of that
# demo's fitted model, not the structural coefficients above (D9-R2); they
# are hard-coded in tests/testthat/test-mediation-demo.R, because this
# directory is excluded from the built package.
# ---------------------------------------------------------------------------
# Seed selection (D6, D9-R4). Seeds are tried in order from `seed_start`,
# and the first one whose named paths all have |estimate / SE| >= 3 is
# kept. Covariate coefficients are exempt. The only retry trigger is this
# floor, which is checked before, and independently of, the known-answer
# test. The chosen seed, the retry count, the R version and the t table are
# printed below and recorded in the comment block at the end of this file.
# ---------------------------------------------------------------------------

n <- 400L
seed_start <- 20260923L
max_tries <- 50L
floor_t <- 3

simulate_demo <- function(seed, n) {
  RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion",
          sample.kind = "Rejection")
  set.seed(seed)
  treatment  <- stats::rbinom(n, 1L, 0.5)
  covariate1 <- stats::rnorm(n)
  covariate2 <- stats::rbinom(n, 1L, 0.5)
  mediator1  <- 0.5 * treatment + 0.3 * covariate1 + 0.3 * covariate2 + stats::rnorm(n)
  mediator2  <- 0.2 * treatment + 0.5 * mediator1 + 0.2 * covariate1 + stats::rnorm(n)
  mediator3  <- 0.5 * treatment + stats::rnorm(n)
  outcome    <- 0.2 * treatment + 0.4 * mediator1 + 0.3 * mediator2 +
    0.3 * mediator3 + 0.3 * covariate1 + 0.2 * covariate2 + stats::rnorm(n)
  outcome_int <- outcome + 0.5 * treatment * mediator1
  data.frame(
    treatment   = as.integer(treatment),
    mediator1   = mediator1,
    mediator2   = mediator2,
    mediator3   = mediator3,
    covariate1  = covariate1,
    covariate2  = as.integer(covariate2),
    outcome     = outcome,
    outcome_int = outcome_int
  )
}

# Named paths per demo (D9-R3): mediator equations give a, a3, d; each
# demo's outcome model gives its b paths and theta3.
named_path_t <- function(d) {
  tval <- function(fit, term) unname(summary(fit)$coefficients[term, "t value"])
  cv <- " + covariate1 + covariate2"
  f <- function(txt) stats::lm(stats::as.formula(paste0(txt, cv)), data = d)
  c(
    a        = tval(f("mediator1 ~ treatment"), "treatment"),
    a3       = tval(f("mediator3 ~ treatment"), "treatment"),
    d        = tval(f("mediator2 ~ treatment + mediator1"), "mediator1"),
    b_simple = tval(f("outcome ~ treatment + mediator1"), "mediator1"),
    b_serial = tval(f("outcome ~ treatment + mediator1 + mediator2"), "mediator2"),
    b1_par   = tval(f("outcome ~ treatment + mediator1 + mediator3"), "mediator1"),
    b3_par   = tval(f("outcome ~ treatment + mediator1 + mediator3"), "mediator3"),
    theta3   = tval(f("outcome_int ~ treatment * mediator1"), "treatment:mediator1")
  )
}

chosen <- NA_integer_
for (i in seq_len(max_tries)) {
  seed <- seed_start + i - 1L
  cand <- simulate_demo(seed, n)
  tt <- named_path_t(cand)
  if (all(abs(tt) >= floor_t)) {
    chosen <- seed
    retries <- i - 1L
    break
  }
}
if (is.na(chosen)) stop("No seed in ", max_tries, " tries met the floor.")

mediation_demo <- simulate_demo(chosen, n)

cat("R version:  ", R.version.string, "\n")
cat("RNGkind:    ", paste(RNGkind(), collapse = " / "), "\n")
cat("seed:       ", chosen, " (retries: ", retries, ")\n", sep = "")
print(round(named_path_t(mediation_demo), 2))

usethis::use_data(mediation_demo, overwrite = TRUE)

# ---------------------------------------------------------------------------
# Recorded run (update whenever the data is regenerated):
# ---------------------------------------------------------------------------
# nolint start: commented_code_linter.
# R version:  R version 4.6.1 (2026-06-24)
# RNGkind:    Mersenne-Twister / Inversion / Rejection
# seed:       20260923 (retries: 0)
# named-path t values (|t| >= 3 required):
#        a       a3        d b_simple b_serial   b1_par   b3_par   theta3
#     5.89     4.59     9.89    10.67     5.01    10.85     4.25     4.88
# Regeneration check: identical() to the shipped data/mediation_demo.rda.
# nolint end
