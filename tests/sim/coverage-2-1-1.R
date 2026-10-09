# Simulation gates for cluster-level mediation (2-1-1), test groups 3, 5 and 9
#
# Run from the package root:  Rscript tests/sim/coverage-2-1-1.R [R]
# R is the replications per scenario (default 1000). Writes
# tests/sim/results/coverage-<date>.csv and exits nonzero if a gated check
# fails. Heavy runs live here, not in testthat (SPEC Testing strategy).
#
# Gates (SPEC group 5):  SE ratio in [0.9, 1.1] for NIE, own and spillover;
# |cor(a-hat, b_between-hat)| < 0.1 (D4); Bradley (0.925, 0.975) coverage for
# the four path intervals (product coverage is reported, not gated).
# Group 3: the TE oracle. Group 9: the assumption claims at J = 100.

args <- commandArgs(trailingOnly = TRUE)
R <- if (length(args) >= 1L) as.integer(args[1]) else 1000L
suppressMessages(devtools::load_all(quiet = TRUE))
source("tests/testthat/helper-cluster.R")
cores <- max(1L, min(16L, parallel::detectCores() - 2L))
acc <- new.env()
acc$rows <- list()
add <- function(scenario, metric, term, value, gate = NA_character_, pass = NA) {
  acc$rows[[length(acc$rows) + 1L]] <- data.frame(
    scenario = scenario, metric = metric, term = term, value = value,
    gate = gate, pass = pass, stringsAsFactors = FALSE
  )
}
inside <- function(v, lo, hi) v >= lo & v <= hi

# --- Group 5: SE ratio, D4 correlation and coverage -------------------------
scenarios <- list(
  balanced = list(args = list(J = 60, sizes = 10), fit = list()),
  unbalanced = list(args = list(J = 60, sizes = rep(3:30, length.out = 60)),
                    fit = list()),
  random_slope = list(args = list(J = 60, sizes = 10, slope_sd = 0.3),
                      fit = list(slope = TRUE))
)
gates <- list()
for (nm in names(scenarios)) {
  cat(sprintf("[%s] R = %d ...\n", nm, R))
  g <- sim_gate(scenarios[[nm]]$args, R = R, seed = 1000L,
                fit_args = scenarios[[nm]]$fit, cores = cores)
  gates[[nm]] <- g
  add(nm, "fits", "n", g$n_fits)
  for (e in c("nie", "own", "spillover")) {
    add(nm, "se_ratio", e, g$se_ratio[[e]], "[0.9, 1.1]",
        inside(g$se_ratio[[e]], 0.9, 1.1))
  }
  add(nm, "d4_correlation", "a,b_between", g$cor_a_b_between, "|r| < 0.1",
      abs(g$cor_a_b_between) < 0.1)
  for (p in c("a", "b_within", "b_between", "c_prime")) {
    add(nm, "coverage", p, g$coverage[[p]], "(0.925, 0.975)",
        inside(g$coverage[[p]], 0.925, 0.975))
  }
  for (e in c("nie", "own", "spillover")) {
    add(nm, "product_coverage", e, g$coverage[[e]])
  }
}

# --- Group 3: the TE oracle --------------------------------------------------
cat("[te_oracle] ...\n")
for (nm in c("balanced", "unbalanced")) {
  zs <- vapply(1:5, function(k) {
    sim <- do.call(sim_cluster211, c(scenarios[[nm]]$args, list(seed = 5000L + k)))
    o <- suppressWarnings(suppressMessages(te_oracle(sim$data, B = 100, seed = k)))
    unname((o["te"] - o["oracle"]) / o["se_diff"])
  }, numeric(1))
  add(nm, "te_oracle_max_abs_z", "te", max(abs(zs)), "< 3", max(abs(zs)) < 3)
}

# The same difference through bootstrap_mediation(cluster = ): the two cluster
# bootstraps should agree on its SD (reported, not gated).
for (nm in c("balanced", "unbalanced")) {
  sim <- do.call(sim_cluster211, c(scenarios[[nm]]$args, list(seed = 5001L)))
  dat <- sim$data
  harness <- suppressWarnings(suppressMessages(te_oracle(dat, B = 200, seed = 1)))
  diff_stat <- function(d) {
    obj <- suppressWarnings(suppressMessages(fit_cluster211(d)))
    unclass(te(obj))[[1]] - cluster_reduced_te(d)
  }
  via <- bootstrap_mediation(diff_stat, method = "nonparametric", data = dat,
                             n_boot = 200L, seed = 2, cluster = "cluster")
  add(nm, "te_bootstrap_sd_ratio", "te",
      stats::sd(via@boot_estimates) / unname(harness["se_diff"]))
}

# --- Group 9: assumption claims at J = 100 -----------------------------------
cat("[assumption claims] ...\n")
R9 <- 200L
conf <- sim_gate(list(J = 100, sizes = 10, rho_vu = 0.5, cov = "centered"),
                 R = R9, seed = 7000L, cores = cores)
z <- function(g, term) g$bias[[term]] / g$mc_se[[term]]
combo <- conf$err[, "nde"] + conf$err[, "spillover"]
combo_z <- mean(combo) / (stats::sd(combo) / sqrt(length(combo)))
add("claims_rho0.5", "bias_z", "own", z(conf, "own"), "|z| < 2",
    abs(z(conf, "own")) < 2)
add("claims_rho0.5", "bias_z", "nie", z(conf, "nie"), "z > 4 (upward)",
    z(conf, "nie") > 4)
add("claims_rho0.5", "bias_z", "nde", z(conf, "nde"), "z < -4 (downward)",
    z(conf, "nde") < -4)
add("claims_rho0.5", "bias_z", "te", z(conf, "te"), "|z| < 2",
    abs(z(conf, "te")) < 2)
add("claims_rho0.5", "bias_z", "nde+spillover", combo_z, "|z| < 2",
    abs(combo_z) < 2)

unc <- sim_gate(list(J = 100, sizes = 10, cov = "confounded"), R = R9,
                seed = 9000L, fit_args = list(cov_terms = "C"), cores = cores)
cen <- sim_gate(list(J = 100, sizes = 10, cov = "confounded"), R = R9,
                seed = 9000L, fit_args = list(cov_terms = c("C_w", "C_bar")),
                cores = cores)
add("confounded_uncentered", "bias_z", "own", z(unc, "own"), "|z| > 4",
    abs(z(unc, "own")) > 4)
add("confounded_centered", "bias_z", "own", z(cen, "own"), "|z| < 2",
    abs(z(cen, "own")) < 2)

# --- Report ---------------------------------------------------------------
out <- do.call(rbind, acc$rows)
out$value <- signif(out$value, 4)
dir.create("tests/sim/results", showWarnings = FALSE, recursive = TRUE)
path <- sprintf("tests/sim/results/coverage-%s.csv", format(Sys.Date()))
utils::write.csv(out, path, row.names = FALSE)
options(width = 140)
print(out, row.names = FALSE)
failed <- out[!is.na(out$pass) & !out$pass, ]
cat(sprintf("\n%d gated checks, %d failed. Wrote %s\n",
            sum(!is.na(out$pass)), nrow(failed), path))
if (nrow(failed)) quit(status = 1L)
