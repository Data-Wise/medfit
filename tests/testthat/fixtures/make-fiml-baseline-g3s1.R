# Generator for the FI-G3 slice S0 baseline fixtures. Run from the package root on the BASE commit, before any serial
# code exists:
#   Rscript tests/testthat/fixtures/make-fiml-baseline-g3s1.R
# Writes fiml-tables-before-g3s1.rds (every table shape of the public FIML entry points) and
# fiml-refusals-before-g3s1.rds (model text, condition class, stage and message of near-miss refusals).
devtools::load_all(quiet = TRUE)
out <- "tests/testthat/fixtures"

# ---- tables -----------------------------------------------------------------------------------------------------
tab <- list()
for (d in c(TRUE, FALSE)) {
  tab[[paste0("simple", d)]] <- .sem_fiml_tables(d)
  for (j in 1:2) tab[[paste0("med", j, d)]] <- .sem_fiml_tables_med(j, d)
  tab[[paste0("medrc2", d)]] <- .sem_fiml_tables_med(2L, d, TRUE)
  for (k in 1:2) {
    tab[[paste0("cov", k, d)]] <- .sem_fiml_tables_cov(k, d)
    for (rc in c(FALSE, TRUE)) {
      tab[[paste0("parcov", k, if (rc) "rc" else "ind", d)]] <- .sem_fiml_tables_med(2L, d, rc, k)
    }
  }
  tab[[paste0("cov1wrap", d)]] <- .sem_fiml_tables_cov1(d)
}
saveRDS(tab, file.path(out, "fiml-tables-before-g3s1.rds"), version = 2)

# ---- refusals ---------------------------------------------------------------------------------------------------
set.seed(20261109)
n <- 150L
nms <- c("X", "Z", "Z1", "Z2", "Z3", "W", "V", "M", "M1", "M2", "M3", "Y")
dat <- as.data.frame(matrix(stats::rnorm(n * 12L), n, dimnames = list(NULL, nms)))
dat$M1 <- .5 * dat$X + dat$M1
dat$M2 <- .4 * dat$M1 + dat$M2
dat$Y <- .3 * dat$M2 + dat$Y
dat[sample(n, 15L), "Y"] <- NA_real_
zeros <- "\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"
sat0 <- "M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X"
sat1 <- "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z"
sat2 <- "M1 ~ X + Z1 + Z2\nM2 ~ M1 + X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2"
chn0 <- "M1 ~ X\nM2 ~ M1\nY ~ M2 + X"
chn1 <- "M1 ~ X + Z\nM2 ~ M1 + Z\nY ~ M2 + X + Z"
chn2 <- "M1 ~ X + Z1 + Z2\nM2 ~ M1 + Z1 + Z2\nY ~ M2 + X + Z1 + Z2"
par0 <- "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X"
par1 <- "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z"
par2 <- "M1 ~ X + Z1 + Z2\nM2 ~ X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2"
models <- c(
  # serial-looking syntax, with and without covariates, with and without the written zero covariances
  ser_sat0_nozeros = sat0, ser_sat0_zeros = paste0(sat0, zeros), ser_sat0_m1m2_zero = paste0(sat0, "\nM1 ~~ 0*M2"),
  ser_sat1_nozeros = sat1, ser_sat1_zeros = paste0(sat1, zeros), ser_sat1_m1m2_zero = paste0(sat1, "\nM1 ~~ 0*M2"),
  ser_sat2_nozeros = sat2, ser_sat2_zeros = paste0(sat2, zeros),
  ser_chain0_nozeros = chn0, ser_chain0_zeros = paste0(chn0, zeros),
  ser_chain0_m1m2_zero = paste0(chn0, "\nM1 ~~ 0*M2"),
  ser_chain1_nozeros = chn1, ser_chain1_zeros = paste0(chn1, zeros),
  ser_chain2_nozeros = chn2, ser_chain2_zeros = paste0(chn2, zeros),
  ser_chain0_direct_fixed_zeros = paste0("M1 ~ X\nM2 ~ M1\nY ~ M2 + 0*X", zeros),
  ser_chain0_direct_omitted_zeros = paste0("M1 ~ X\nM2 ~ M1\nY ~ M2", zeros),
  ser_sat0_free_residual = paste0(sat0, "\nM1 ~~ M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"),
  ser_sat0_labeled_a2 = paste0("M1 ~ X\nM2 ~ M1 + a2*X\nY ~ M1 + M2 + X", zeros),
  ser_sat0_fixed_b1 = paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ 0*M1 + M2 + X", zeros),
  ser_partial_x_to_m2_only = paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + X", zeros),
  ser_partial_m1_to_y_only = paste0("M1 ~ X\nM2 ~ M1\nY ~ M1 + M2 + X", zeros),
  ser_fixed_zero_shortcut = paste0("M1 ~ X + Z\nM2 ~ M1 + 0*X + Z\nY ~ M2 + X + Z", zeros),
  ser_chain_z_omitted = paste0("M1 ~ X + Z\nM2 ~ M1 + X\nY ~ M2 + X + Z", zeros),
  ser_chain_two_absent = paste0("M1 ~ X + Z\nM2 ~ M1\nY ~ M2 + X + Z", zeros),
  ser_reversed_mediators = paste0("M2 ~ X\nM1 ~ M2\nY ~ M1 + X", zeros),
  ser_reversed_sat = paste0("M2 ~ X\nM1 ~ M2 + X\nY ~ M1 + M2 + X", zeros),
  ser_cycle = paste0("M1 ~ X + M2\nM2 ~ X + M1\nY ~ M1 + M2 + X", zeros),
  ser_m1_not_from_x = paste0("M1 ~ Z\nM2 ~ M1 + X\nY ~ M1 + M2 + X + Z", zeros),
  ser_m2_not_to_y = paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + X", zeros),
  ser_three_mediators = "M1 ~ X\nM2 ~ M1 + X\nM3 ~ M2 + X\nY ~ M1 + M2 + M3 + X",
  ser_three_mediators_chain = "M1 ~ X\nM2 ~ M1\nM3 ~ M2\nY ~ M3 + X",
  ser_three_covariates = paste0(
    "M1 ~ X + Z1 + Z2 + Z3\nM2 ~ M1 + X + Z1 + Z2 + Z3\nY ~ M1 + M2 + X + Z1 + Z2 + Z3", zeros
  ),
  ser_partial_exo_cov_sat1 = paste0(sat1, zeros, "\nX ~~ Z"),
  ser_partial_exo_cov_sat2 = paste0(sat2, zeros, "\nX ~~ Z1\nX ~~ Z2"),
  ser_all_exo_cov_sat2 = paste0(sat2, zeros, "\nX ~~ Z1\nX ~~ Z2\nZ1 ~~ Z2"),
  ser_fixed_exo_cov_chain1 = paste0(chn1, zeros, "\nX ~~ 0*Z"),
  ser_labeled_chain_paths = paste0("M1 ~ a*X\nM2 ~ d1*M1\nY ~ b*M2 + X", zeros),
  ser_tied_chain_paths = paste0("M1 ~ p*X\nM2 ~ p*M1\nY ~ M2 + X", zeros),
  ser_interaction = paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X + M1:X", zeros),
  ser_mediator_exo_cov = paste0(sat1, zeros, "\nZ ~~ M1"),
  ser_duplicate_zero = paste0(sat0, zeros, "\nM2 ~~ 0*M1"),
  # parallel and covariate near misses, copied from the existing refusal lists
  par0_omitted_independence = par0, par0_free = paste0(par0, "\nM1 ~~ M2"), par0_zero = paste0(par0, "\nM1 ~~ 0*M2"),
  par1_omitted_independence = par1, par1_free = paste0(par1, "\nM1 ~~ M2"),
  par2_omitted_independence = par2, par2_free = paste0(par2, "\nM1 ~~ M2"),
  par_labeled_covariance = paste0(par1, "\nM1 ~~ c*M2"), par_fixed_nonzero_covariance = paste0(par1, "\nM1 ~~ 0.2*M2"),
  par_bounded_covariance = paste0(par1, "\nM1 ~~ start(.1)*M2"),
  par_tied_covariance = paste0(par1, "\nM1 ~~ r*M2\nM1 ~~ r*M1"),
  par_constrained_covariance = paste0(par1, "\nM1 ~~ cc*M2\ncc == 0.1"),
  par_duplicate_covariance = paste0(par1, "\nM1 ~~ M2\nM2 ~~ M1"),
  par_fixed_exogenous_covariance = paste0(par1, "\nM1 ~~ M2\nX ~~ 0*Z"),
  par_duplicate_exogenous_covariance = paste0(par1, "\nM1 ~~ M2\nX ~~ Z\nZ ~~ X"),
  par_covariate_on_one_mediator = paste0("M1 ~ X + Z\nM2 ~ X\nY ~ M1 + M2 + X + Z", "\nM1 ~~ M2"),
  par_covariate_not_on_y = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X", "\nM1 ~~ M2"),
  par_omitted_treatment_y_path = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + Z", "\nM1 ~~ M2"),
  par_both_y_paths_fixed = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + 0*X + 0*Z", "\nM1 ~~ M2"),
  par_fixed_nonzero_direct = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + 0.5*X + Z", "\nM1 ~~ M2"),
  par_fixed_zero_covariate_path = paste0("M1 ~ X + 0*Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z", "\nM1 ~~ M2"),
  par_fixed_zero_a_path = paste0("M1 ~ 0*X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z", "\nM1 ~~ M2"),
  par_tied_a_paths = paste0("M1 ~ p*X + Z\nM2 ~ p*X + Z\nY ~ M1 + M2 + X + Z", "\nM1 ~~ M2"),
  par_tied_covariate_paths = paste0("M1 ~ X + p*Z\nM2 ~ X + p*Z\nY ~ M1 + M2 + X + Z", "\nM1 ~~ M2"),
  par_covariate_mediator_covariance = paste0(par1, "\nM1 ~~ M2\nZ ~~ M1"),
  par_mediator_outcome_covariance = paste0(par1, "\nM1 ~~ M2\nM1 ~~ Y"),
  par_one_mediator_only_to_y = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + X + Z", "\nM1 ~~ M2"),
  par_interaction = paste0(par1, "\nM1 ~~ M2\nM1:X ~~ Y"),
  par_interaction_y = paste0("M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z + M1:X", "\nM1 ~~ M2"),
  par_three_mediators = paste0("M1 ~ X + Z\nM2 ~ X + Z\nM3 ~ X + Z\nY ~ M1 + M2 + M3 + X + Z", "\nM1 ~~ M2"),
  par_three_covariates = paste0("M1 ~ X + Z + W + V\nM2 ~ X + Z + W + V\nY ~ M1 + M2 + X + Z + W + V", "\nM1 ~~ M2"),
  par_fixed_variance = paste0(par1, "\nM1 ~~ M2\nZ ~~ 1*Z"),
  par2_partial_exo_covariances = paste0(par2, "\nM1 ~~ M2\nX ~~ Z1\nX ~~ Z2"),
  par2_one_exo_covariance = paste0(par2, "\nM1 ~~ M2\nZ1 ~~ Z2"),
  par2_fixed_exo_covariance = paste0(par2, "\nM1 ~~ M2\nX ~~ Z1\nX ~~ Z2\nZ1 ~~ 0*Z2"),
  par2_omitted_covariate_y_path = "M1 ~ X + Z1 + Z2\nM2 ~ X + Z1 + Z2\nY ~ M1 + M2 + X + Z1\nM1 ~~ M2",
  par2_y_paths_fixed = "M1 ~ X + Z1 + Z2\nM2 ~ X + Z1 + Z2\nY ~ M1 + M2 + 0*X + 0*Z1 + Z2\nM1 ~~ M2",
  par2_covariate_on_one_mediator = "M1 ~ X + Z1 + Z2\nM2 ~ X + Z1\nY ~ M1 + M2 + X + Z1 + Z2\nM1 ~~ M2",
  par2_fixed_covariate_path = "M1 ~ X + Z1 + 0*Z2\nM2 ~ X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2\nM1 ~~ M2",
  par2_tied_covariate_paths = "M1 ~ X + p*Z1 + Z2\nM2 ~ X + p*Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2\nM1 ~~ M2",
  # one-mediator and covariate-only near misses
  cov_three_covariates = "M ~ X + Z1 + Z2 + Z3\nY ~ M + X + Z1 + Z2 + Z3",
  cov_on_m_only = "M ~ X + Z1\nY ~ M + X",
  cov_not_on_m = "M ~ X\nY ~ M + X + Z1",
  cov1_partial_exo = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nX ~~ Z1",
  cov1_fixed_exo_cov = "M ~ X + Z\nY ~ M + X + Z\nX ~~ 0*Z",
  cov1_y_omitted_x = "M ~ X + Z\nY ~ M + Z",
  cov1_two_fixed_y = "M ~ X + Z\nY ~ M + 0*X + 0*Z",
  simple_tied = "M ~ a*X\nY ~ a*M + X",
  simple_serial_chain_bare = chn0,
  simple_parallel_bare = par0
)
res <- lapply(models, function(m) {
  e <- tryCatch(fit_sem(m, dat, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
})
saveRDS(list(data = dat, models = models, results = res), file.path(out, "fiml-refusals-before-g3s1.rds"), version = 2)
cat("table shapes:", length(tab), " refusal models:", length(models), "\n")
print(table(vapply(res, function(r) r$class[1L], "")))
