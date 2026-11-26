# S4a.1 (planning/PLAN-S4a-native-twolevel-core-2026-11-18.md): the native two-level route parses `level:` names,
# refuses every input of the plan's Refused table with a classed error, classifies the within (W) and between-only (Z)
# variables; a model that passes is fitted (S4a.4, a `SEMFit`). Each refusal is triggered from
# a valid base model that changes in one place only, and the message is matched as well as the class, so a planted
# defect in one guard cannot pass through another guard of the same class.

skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
tl_guard_data <- function() {
  dat <- tl_data_balanced()
  withr::local_seed(23)
  dat$Zc <- stats::rnorm(40)[dat$cluster] # constant within each cluster: a between-only variable
  dat$Q <- stats::rnorm(nrow(dat)) # varies within clusters
  dat
}

tl_not_impl <- "medfit_error_twolevel_not_implemented"
# A model the guards allow is fitted (S4a.4); the numbers are checked in test-twolevel-native-fit.R.
tl_expect_fit <- function(fit) expect_true(S7::S7_inherits(fit, SEMFit) && isTRUE(fit@internals$ram$twolevel))

# Runs `fit_sem()` with the valid base unless overridden.
tl_fit <- function(model = tl_lavaan_model, data = tl_guard_data(), cluster = "cluster", ...) {
  fit_sem(model, data, cluster = cluster, ...)
}

test_that("the valid base model is fitted without a warning", {
  expect_no_warning(tl_expect_fit(tl_fit()))
  expect_no_warning(tl_expect_fit(tl_fit(data = tl_data_unbalanced())))
})

test_that("level names parse to the same parameter table as the integers", {
  num <- .sem_parse(tl_lavaan_model)
  for (spell in list(c("within", "between"), c("1", "between"), c("within", "cluster"), c("within", "2"))) {
    m <- sub("level: 2", paste("level:", spell[2]), sub("level: 1", paste("level:", spell[1]), tl_lavaan_model))
    parsed <- .sem_resolve_levels(.sem_parse(m), "cluster")
    expect_identical(parsed$parameters, num$parameters, info = paste(spell, collapse = "/"))
    expect_no_warning(tl_expect_fit(tl_fit(m)))
  }
  # rows under `level: within` are level 1 (labels a_w, b_w, cp_w), rows under `level: between` level 2
  renamed <- sub("level: 2", "level: between", sub("level: 1", "level: within", tl_lavaan_model))
  named <- .sem_resolve_levels(.sem_parse(renamed), NULL)
  p <- named$parameters
  expect_true(all(p$level[grepl("_w$", p$label)] == 1L))
  expect_true(all(p$level[grepl("_b$", p$label)] == 2L))
})

test_that("an unknown level name is the malformed-level syntax error", {
  bad_name <- sub("level: 2", "level: school", tl_lavaan_model)
  expect_error(tl_fit(bad_name), "malformed level line; expected 'level: 1', 'level: 2', 'level: within'")
  # no cluster: only the four fixed spellings are names, so a cluster-like name is malformed, not a cluster error
  expect_error(fit_sem(sub("level: 2", "level: cluster", tl_lavaan_model), tl_guard_data()), "malformed level line")
  expect_error(tl_fit(sub("level: 2", "level: 0", tl_lavaan_model)), "malformed level line")
  expect_error(.sem_parse("level: 1.5\nY ~ X"), "malformed level line")
  expect_error(.sem_parse("level:\nY ~ X"), "malformed level line")
})

test_that("the level-order guards name their cause", {
  expect_error(tl_fit(paste("X ~~ X", tl_lavaan_model, sep = "\n")), "before the first `level:` line",
               class = "medfit_error_twolevel_syntax")
  expect_error(tl_fit("level: 1\nM ~ X\nlevel: 1\nY ~ M\nlevel: 2\nM ~ X\nY ~ M"), "level 1 appears more than once",
               class = "medfit_error_twolevel_syntax")
  expect_error(tl_fit("level: 1\nM ~ X\nY ~ M\nlevel: 2\nM ~ X\nlevel: between\nY ~ M"),
               "level 2 appears more than once", class = "medfit_error_twolevel_syntax")
  expect_error(tl_fit("level: 2\nM ~ X\nY ~ M + X"), "has `level: 2` rows but no `level: 1` block",
               class = "medfit_error_twolevel_syntax")
  expect_error(tl_fit(paste(tl_lavaan_model, "level: 3\nY ~ X", sep = "\n")), "more than two levels",
               class = "medfit_error_twolevel_cluster")
})

test_that("`level:` blocks and `cluster` need each other", {
  expect_error(fit_sem(tl_lavaan_model, tl_guard_data()), "uses `level:` blocks but `cluster` is not given",
               class = "medfit_error_twolevel_cluster")
  expect_error(tl_fit("M ~ X\nY ~ M + X"), "`cluster` is given but the model has no `level:` blocks",
               class = "medfit_error_twolevel_cluster")
})

test_that("the cluster column is checked", {
  dat <- tl_guard_data()
  expect_error(tl_fit(cluster = "school"), "'school' is not a column of `data`",
               class = "medfit_error_twolevel_cluster")
  na_dat <- dat
  na_dat$cluster[5] <- NA
  expect_error(tl_fit(data = na_dat), "has missing values", class = "medfit_error_twolevel_cluster")
  one <- dat
  one$cluster <- 1L
  expect_error(tl_fit(data = one), "at least 2 clusters", class = "medfit_error_twolevel_cluster")
  expect_error(tl_fit(cluster = c("cluster", "Zc")), "cluster")
})

test_that("each refused feature raises its own class", {
  dat <- tl_guard_data()
  latent <- sub("level: 1", "level: 1\n  f =~ X + M + Y", tl_lavaan_model)
  expect_error(tl_fit(latent), "latent variables", class = "medfit_error_twolevel_latent")
  latent2 <- paste(tl_lavaan_model, "  g =~ X + M + Y", sep = "\n")
  expect_error(tl_fit(latent2), "latent variables", class = "medfit_error_twolevel_latent")
  product <- sub("Y ~ b_w\\*M \\+ cp_w\\*X", "Y ~ b_w*M + cp_w*X + X:M", tl_lavaan_model)
  expect_error(tl_fit(product), "product term", class = "medfit_error_twolevel_product")
  product2 <- paste(tl_lavaan_model, "  Y ~ X:M", sep = "\n")
  expect_error(tl_fit(product2), "product term", class = "medfit_error_twolevel_product")
  expect_error(tl_fit(weights = rep(1, nrow(dat))), "`weights`", class = "medfit_error_twolevel_weights")
  # IG2: se_type = "sandwich" is the cluster-robust sandwich, no longer refused (test-twolevel-native-sandwich.R)
  expect_identical(tl_fit(se_type = "sandwich")@diagnostics$se_type, "sandwich")
  expect_error(tl_fit(missing = "fiml"), "fiml", class = "medfit_error_twolevel_missing")
  expect_error(tl_fit(missing = "fiml", fixed_x = FALSE), "fiml", class = "medfit_error_twolevel_missing")
  expect_error(tl_fit(paste(tl_lavaan_model, "a_w*b_w == 0.1", sep = "\n")), "nonlinear",
               class = "medfit_error_twolevel_nonlinear")
  expect_error(tl_fit(paste(tl_lavaan_model, "a_w*b_w == 0", sep = "\n")), "nonlinear",
               class = "medfit_error_twolevel_nonlinear")
  expect_error(tl_fit(paste(tl_lavaan_model, "ab := a_w*b_w\nab > 0.1", sep = "\n")), "nonlinear",
               class = "medfit_error_twolevel_nonlinear")
  expect_error(tl_fit(fixed_x = TRUE), "fixed_x", class = "medfit_error_twolevel_fixed_x")
  expect_error(tl_fit(fixed_x = "X"), "fixed_x", class = "medfit_error_twolevel_fixed_x")
  expect_error(tl_fit(meanstructure = FALSE), "meanstructure", class = "medfit_error_twolevel_meanstructure")
  expect_error(tl_fit(information = "expected"), "expected", class = "medfit_error_twolevel_information")
})

test_that("what the guards allow is fitted", {
  tl_expect_fit(tl_fit(fixed_x = FALSE))
  tl_expect_fit(tl_fit(meanstructure = TRUE))
  tl_expect_fit(tl_fit(information = "observed"))
  # a defined product is not a constraint; a linear cross-level equality is a linear constraint
  tl_expect_fit(tl_fit(paste(tl_lavaan_model, "ab_w := a_w*b_w\na_w == a_b", sep = "\n")))
  # the same label at both levels is a linear equality, not a refusal
  shared <- gsub("a_[wb]\\*", "a*", tl_lavaan_model)
  tl_expect_fit(tl_fit(shared))
})

test_that("unset fixed_x resolves silently on both routes; explicit TRUE errors on both", {
  dat <- tl_guard_data()
  expect_no_warning(tl_expect_fit(fit_sem(tl_lavaan_model, dat, cluster = "cluster")))
  med <- function(...) {
    fit_mediation(data = dat, treatment = "X", mediator = "M", engine = "sem", model = tl_lavaan_model,
                  cluster = "cluster", ...)
  }
  # since S4a.5 fit_mediation() returns a TwoLevelMediationData; the only warning is the few-clusters one (40 < 50),
  # never a default-change warning about fixed_x
  few <- "medfit_warning_twolevel_few_clusters"
  expect_warning(out <- med(), class = few)
  expect_true(S7::S7_inherits(out, TwoLevelMediationData))
  expect_warning(out <- med(engine_args = list(fixed_x = FALSE)), class = few)
  expect_true(S7::S7_inherits(out, TwoLevelMediationData))
  expect_error(med(engine_args = list(fixed_x = TRUE)), class = "medfit_error_twolevel_fixed_x")
  expect_error(med(engine_args = list(meanstructure = FALSE)), class = "medfit_error_twolevel_meanstructure")
  expect_warning(out <- fit_mediation(data = dat, treatment = "X", mediator = "M", engine = "native",
                                      model = tl_lavaan_model, cluster = "cluster"), class = few)
  expect_true(S7::S7_inherits(out, TwoLevelMediationData))
  expect_error(fit_mediation(data = dat, treatment = "X", mediator = "M", engine = "sem",
                             model = "M ~ X\nY ~ M + X", cluster = "cluster"),
               class = "medfit_error_twolevel_cluster")
  # the other engines keep refusing `cluster`
  expect_error(fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M", cluster = "cluster"),
               "`cluster` is only used with engine = \"lmer\" or engine = \"sem\"", fixed = TRUE)
})

test_that("W and Z sets match a hand classification", {
  dat <- tl_guard_data()
  m <- paste0("level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X + Zc")
  sets <- .sem_twolevel_sets(.sem_resolve_levels(.sem_parse(m), "cluster"), dat, "cluster")
  expect_setequal(sets$within, c("X", "M", "Y"))
  expect_identical(sets$between, "Zc")
  tl_expect_fit(tl_fit(m))
  base <- .sem_twolevel_sets(.sem_resolve_levels(.sem_parse(tl_lavaan_model), "cluster"), dat, "cluster")
  expect_setequal(base$within, c("X", "M", "Y"))
  expect_identical(base$between, character(0))
  unb <- tl_data_unbalanced()
  unb$Zc <- seq_len(40)[unb$cluster] / 7
  expect_identical(.sem_twolevel_sets(.sem_resolve_levels(.sem_parse(m), "cluster"), unb, "cluster")$between, "Zc")
})

test_that("a between-only variable that varies within a cluster is refused", {
  dat <- tl_guard_data()
  m <- "level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X + Zc"
  bad <- dat
  bad$Zc[2] <- bad$Zc[2] + 1 # cluster 1 now varies
  expect_error(tl_fit(m, bad), "'Zc'.*varies within", class = "medfit_error_twolevel_varset")
  # Q varies within clusters; naming it only at level 2 is refused
  expect_error(tl_fit(sub("Zc", "Q", sub("Zc", "Q", m))), "'Q'.*varies within", class = "medfit_error_twolevel_varset")
})

test_that("a level-1 variable constant within every cluster is refused (a Z variable given a within row)", {
  dat <- tl_guard_data()
  m <- "level: 1\nM ~ X + Zc\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X"
  expect_error(tl_fit(m, dat), "'Zc'.*constant within every cluster", class = "medfit_error_twolevel_varset")
  # a W variable made cluster-constant: the treatment assigned to whole clusters
  cx <- dat
  cx$X <- stats::ave(cx$X, cx$cluster)
  expect_error(tl_fit(data = cx), "'X'.*constant within every cluster", class = "medfit_error_twolevel_varset")
})

test_that("a within-only variable is refused", {
  m <- "level: 1\nM ~ X\nY ~ M + X + Q\nlevel: 2\nM ~ X\nY ~ M + X"
  expect_error(tl_fit(m), "'Q'.*only in `level: 1` rows", class = "medfit_error_twolevel_varset")
})

test_that("a model with only `level: 1` rows is refused as within-only, naming the missing `level: 2` row", {
  m <- "level: 1\nM ~ X\nY ~ M + X"
  expect_error(tl_fit(m), "only in `level: 1` rows; every level-1 variable also needs a `level: 2` row",
               class = "medfit_error_twolevel_varset")
})

test_that("size-1 clusters are skipped by the constancy check; all of size 1 is refused", {
  dat <- tl_guard_data()
  m <- "level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X + Zc"
  extra <- dat[1:3, ]
  extra$cluster <- 101:103 # three singleton clusters with arbitrary values
  extra$Zc <- c(-5, 0, 5)
  mixed <- rbind(dat, extra)
  sets <- .sem_twolevel_sets(.sem_resolve_levels(.sem_parse(m), "cluster"), mixed, "cluster")
  expect_identical(sets$between, "Zc")
  tl_expect_fit(tl_fit(m, mixed))
  single <- dat
  single$cluster <- seq_len(nrow(single))
  expect_error(tl_fit(m, single), "every cluster has one complete row", class = "medfit_error_twolevel_varset")
})

test_that("the constancy check reads complete cases only", {
  dat <- tl_guard_data()
  m <- "level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X + Zc"
  na_row <- dat
  na_row$Zc[2] <- na_row$Zc[2] + 1
  na_row$Y[2] <- NA # the row that breaks constancy is not a complete case
  tl_expect_fit(tl_fit(m, na_row))
})

test_that("the single-level fitter never runs on a model with level lines", {
  dat <- tl_guard_data()
  expect_error(.sem_fit_syntax("level: 1\nY ~ X\nlevel: 2\nY ~ M", dat), class = tl_not_impl)
  expect_error(.sem_fit_syntax("level: 1\nY ~ X", dat), class = tl_not_impl)
  # a zero-product constraint would branch-fit pooled rows if the stop came after the branch dispatch
  expect_error(.sem_fit_syntax(paste(tl_lavaan_model, "a_w*b_w == 0", sep = "\n"), dat), class = tl_not_impl)
})

test_that("IG3 T-B: only one equality of two products of two labels is admitted; other nonlinear rows are refused", {
  m <- function(con) paste(tl_lavaan_model, con, sep = "\n")
  # admitted: the row itself, written either way round, and through defined parameters
  for (con in c("a_w*b_w == a_b*b_b", "a_b*b_b == a_w*b_w", "b_w*a_w == b_b*a_b", "(a_w*b_w) == (a_b*b_b)")) {
    tl_expect_fit(tl_fit(m(con)))
  }
  # refused with the same class: a coefficient, three labels, an inequality, a repeated label, a constant, a second row
  for (con in c("2*a_w*b_w == a_b*b_b", "a_w*b_w*cp_w == a_b*b_b", "a_w*b_w < a_b*b_b", "a_w*b_w > a_b*b_b",
                "a_w*b_w == a_w*b_b", "a_w*b_w == 0.1", "a_w*b_w == 0", "a_w*b_w == a_b*b_b\ncp_w*a_w == cp_b*a_b",
                "a_w*b_w == a_b*b_b + cp_b", "ab := a_w*b_w\nab > 0.1",
                # other pairings have no oracle or gate: a with a, a product with cp, a defined parameter
                "a_w*a_b == b_w*b_b", "a_w*b_w == cp_w*cp_b", "a_w*b_w == cp_b*b_b", "a_w*cp_w == a_b*cp_b",
                "a_w*b_b == a_b*b_w", "iw := a_w*b_w\nib := a_b*b_b\niw == ib")) {
    expect_error(tl_fit(m(con)), "nonlinear", class = "medfit_error_twolevel_nonlinear", info = con)
  }
})
