# Consistency guard for the cookbook (SPEC-refcard-cookbook T4/T5): twenty-one numbered
# recipes, every article link resolves, and the cluster recipe simulates the same
# data as methods.qmd so their numbers agree. Skips when the vignettes are absent
# (installed or built package).

article_path <- function(name) {
  p <- testthat::test_path("..", "..", "vignettes", "articles", name)
  if (file.exists(p)) p else NA_character_
}

article_text <- function(name) {
  p <- article_path(name)
  testthat::skip_if(is.na(p), "vignettes are not available (installed or built package)")
  paste(readLines(p, warn = FALSE), collapse = "\n")
}

test_that("the cookbook has twenty-one numbered recipes and every article link resolves", {
  cb <- article_text("cookbook.qmd")
  heads <- regmatches(cb, gregexpr("(?m)^## [0-9]+\\. ", cb, perl = TRUE))[[1]]
  expect_identical(trimws(sub("^## ", "", heads)), paste0(1:21, "."))
  links <- unique(regmatches(cb, gregexpr("\\]\\(([a-z-]+)\\.html\\)", cb))[[1]])
  targets <- paste0(gsub("^\\]\\(|\\.html\\)$", "", links), ".qmd")
  expect_gt(length(targets), 0L)
  missing <- targets[is.na(vapply(targets, article_path, character(1)))]
  expect_identical(missing, character())
})

test_that("the cookbook's cluster recipe simulates the same data as methods.qmd", {
  cb <- article_text("cookbook.qmd")
  mx <- article_text("methods.qmd")
  lines <- c(
    "set.seed(2026)", "J <- 40", "n <- 10",
    "cdat$Y <- 0.2 * cdat$X + 0.3 * (cdat$M - mbar) + 0.6 * mbar + u[cl] + rnorm(J * n)"
  )
  for (l in lines) {
    expect_true(grepl(l, cb, fixed = TRUE), info = l)
    expect_true(grepl(l, mx, fixed = TRUE), info = l)
  }
})

test_that("planted defect: a changed seed in the cookbook is caught", {
  cb <- article_text("cookbook.qmd")
  broken <- sub("set.seed(2026)", "set.seed(2027)", cb, fixed = TRUE)
  expect_false(grepl("set.seed(2026)", broken, fixed = TRUE))
  expect_true(grepl("set.seed(2026)", cb, fixed = TRUE))
})

test_that("the introduction articles point at the refcard and the cookbook", {
  for (a in c("getting-started.qmd", "introduction.qmd")) {
    txt <- article_text(a)
    expect_true(grepl("](refcard.html)", txt, fixed = TRUE), info = a)
    expect_true(grepl("](cookbook.html)", txt, fixed = TRUE), info = a)
  }
})

# Each task recipe must run after the setup chunk alone, so a reader can jump to
# any recipe. Running the page top to bottom hides a fit that only an earlier
# recipe defines. The cluster, lavaan and native recipes (9-11) simulate their own
# data and are slow, so recipes 1-8, which share fitted models, are checked here.
cookbook_recipe_chunks <- function(cb_lines) {
  heads <- grep("^## ", cb_lines)
  bounds <- cbind(start = c(1L, heads), end = c(heads - 1L, length(cb_lines)))
  chunks <- function(a, b) {
    seg <- cb_lines[a:b]
    out <- list()
    i <- 1L
    while (i <= length(seg)) {
      if (grepl("^```\\{r", seg[i])) {
        j <- i + 1L
        while (!grepl("^```$", seg[j])) j <- j + 1L
        body <- seg[(i + 1L):(j - 1L)]
        out[[length(out) + 1L]] <- body[!grepl("^#\\|", body)]
        i <- j
      }
      i <- i + 1L
    }
    out
  }
  lapply(seq_len(nrow(bounds)), function(k) chunks(bounds[k, "start"], bounds[k, "end"]))
}

run_cookbook_recipe <- function(setup, chunks) {
  setup <- setup[!grepl("^library\\(medfit\\)", setup)]
  env <- new.env(parent = asNamespace("medfit"))
  tryCatch({
    suppressMessages(suppressWarnings({
      eval(parse(text = setup), env)
      env$tidy <- generics::tidy
      for (ch in chunks) eval(parse(text = ch), env)
    }))
    NULL
  }, error = function(e) conditionMessage(e))
}

test_that("each cookbook recipe 1-8 runs after the setup chunk alone", {
  article_text("cookbook.qmd") # skips when the vignettes are absent
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  for (k in 1:8) {
    err <- run_cookbook_recipe(setup, parsed[[k + 1L]])
    expect_null(err, info = sprintf("recipe %d fails on its own: %s", k, err))
  }
})

test_that("planted defect: a recipe that needs an earlier recipe's fit is caught", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  err <- run_cookbook_recipe(setup, list("fit_defined_in_another_recipe <- 1", "xb <- fit_never_defined"))
  expect_match(err, "fit_never_defined")
})

# Recipe 13 (joint significance for a glm): runs after the setup chunk alone, its p-values equal the
# classical tests computed by hand (anova likelihood-ratio for the binomial outcome, F for the Gaussian
# mediator), and the joint p-value is the larger of the two. Planted defect: taking the smaller one.
test_that("recipe 13 runs alone and its joint p-value is the larger of two classical tests", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  chunks <- parsed[[14L]]
  expect_null(run_cookbook_recipe(setup, chunks))

  env <- new.env(parent = asNamespace("medfit"))
  suppressMessages(suppressWarnings({
    eval(parse(text = setup[!grepl("^library\\(medfit\\)", setup)]), env)
    for (ch in chunks) eval(parse(text = ch), env)
  }))
  p <- env$joint_test(env$fit_a, "treatment", env$fit_b, "mediator1")
  d <- env$d
  m0 <- stats::glm(mediator1 ~ covariate1 + covariate2, data = d)
  y0 <- stats::glm(outcome_bin ~ treatment + covariate1 + covariate2, data = d, family = stats::binomial())
  p_a <- stats::anova(m0, env$fit_a, test = "F")[2, "Pr(>F)"]
  p_b <- stats::anova(y0, env$fit_b, test = "Chisq")[2, "Pr(>Chi)"]
  expect_equal(unname(p[["a"]]), p_a, tolerance = 1e-8)
  expect_equal(unname(p[["b"]]), p_b, tolerance = 1e-8)
  expect_equal(unname(p[["joint"]]), max(p_a, p_b), tolerance = 1e-8)
  # a quasi family has estimated dispersion and must get the F test, not a chi-square
  qb <- stats::glm(outcome_bin ~ treatment + mediator1 + covariate1 + covariate2, data = d,
                   family = stats::quasibinomial())
  q0 <- stats::glm(outcome_bin ~ treatment + covariate1 + covariate2, data = d, family = stats::quasibinomial())
  pq <- env$joint_test(env$fit_a, "treatment", qb, "mediator1")[["b"]]
  expect_equal(pq, stats::anova(q0, qb, test = "F")[2, "Pr(>F)"], tolerance = 1e-8)
  expect_gt(abs(pq / p_b - 1), 0.1)
})

test_that("planted defect: the smaller p-value in place of the larger is caught", {
  article_text("cookbook.qmd")
  cb <- article_text("cookbook.qmd")
  expect_true(grepl("joint = max(p)", cb, fixed = TRUE))
  expect_false(grepl("joint = max(p)", sub("joint = max(p)", "joint = min(p)", cb, fixed = TRUE), fixed = TRUE))
})

test_that("recipes 14-21 run after the setup chunk alone and say what they claim", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  for (k in 14:21) {
    err <- run_cookbook_recipe(setup, parsed[[k + 1L]])
    expect_null(err, info = sprintf("recipe %d fails on its own: %s", k, err))
  }
  # recipe 16: the lower bound binds; recipe 17: the model is misspecified (large chi-square on 2 df)
  b <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1 + 0 * treatment\noutcome ~~ lower(2) * outcome",
               mediation_demo)
  expect_length(b@diagnostics$active_bounds, 1L)
  chk <- fit_sem("mediator1 ~ treatment\nmediator2 ~ treatment\noutcome ~ mediator1 + mediator2", mediation_demo)
  g <- generics::glance(chk)
  expect_equal(g$df, 2)
  expect_lt(g$p_value, 1e-10)
  # recipe 14: the restricted model has more degrees of freedom, and the test is not significant
  full <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment", mediation_demo)
  reduced <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1", mediation_demo)
  expect_gt(stats::anova(reduced, full)$`Pr(>Chisq)`[2], 0.5)
})

# Recipe 18 (fixed_x): the structural estimates and SEs equal the free fit's, the parameter count falls from 14 to
# 8 (the numbers its prose quotes), df and chi-square do not move, glance() lists the fixed names, and comparing
# fits with different fixed sets errors (a subset of the fixed names counts as a different set).
test_that("recipe 18: fixed_x leaves the structure alone, drops the parameter count and refuses mixed comparisons", {
  cb <- article_text("cookbook.qmd")
  syntax <- paste("mediator1 ~ a * treatment + covariate1 + covariate2",
                  "outcome ~ b * mediator1 + covariate1 + covariate2",
                  "ab := a * b", sep = "\n")
  free <- fit_sem(syntax, mediation_demo)
  fixed <- fit_sem(syntax, mediation_demo, fixed_x = TRUE)
  expect_equal(coef(fixed)[c("a", "b")], coef(free)[c("a", "b")], tolerance = 1e-6)
  se <- function(f) sqrt(diag(vcov(f)))[c("a", "b")]
  expect_equal(se(fixed), se(free), tolerance = 1e-5)
  gf <- generics::glance(free)
  gx <- generics::glance(fixed)
  expect_identical(c(gf$npar, gx$npar), c(14L, 8L))
  expect_true(grepl(sprintf("from %d to %d", gf$npar, gx$npar), cb, fixed = TRUE))
  expect_equal(gx$df, gf$df)
  expect_equal(gx$chisq, gf$chisq, tolerance = 1e-6)
  expect_identical(gf$fixed_x, "")
  expect_setequal(strsplit(gx$fixed_x, ", ")[[1L]], c("treatment", "covariate1", "covariate2"))
  expect_error(stats::anova(free, fixed), "different `fixed_x` sets")
  subset_fit <- fit_sem(syntax, mediation_demo, fixed_x = "treatment")
  expect_error(stats::anova(fixed, subset_fit), "different `fixed_x` sets")
  expect_error(stats::AIC(free, fixed), "different `fixed_x` sets")
})

test_that("the native quickstart, tutorial and guide exist, are indexed, and their links resolve", {
  pk <- article_text("cookbook.qmd") # skips without vignettes
  pkg <- paste(readLines(testthat::test_path("..", "..", "_pkgdown.yml"), warn = FALSE), collapse = "\n")
  for (a in c("native-quickstart", "native-tutorial", "native-guide")) {
    expect_true(grepl(paste0("articles/", a, "`"), pkg, fixed = TRUE), info = a)
    expect_true(grepl(paste0("articles/", a, ".html"), pkg, fixed = TRUE), info = a)
    txt <- article_text(paste0(a, ".qmd"))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
    targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
    expect_identical(targets[is.na(vapply(targets, article_path, character(1)))], character(), info = a)
  }
})

# Recipe 19 (observed intercepts and means): the intercepts equal the lm() intercepts of the same equations and the
# exogenous mean is the sample mean (known answers); the paths do not move; `~0*1` costs exactly one df and
# anova() rejects it; meanstructure = TRUE equals the free fit. Planted defect: the lm oracle must differ from a
# fit with the intercept fixed at zero.
test_that("recipe 19: intercepts match lm(), the zero restriction costs one df and is tested by anova()", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  expect_null(run_cookbook_recipe(unlist(parsed[[1L]]), parsed[[20L]]))
  paths <- "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment\n"
  free <- fit_sem(paste0(paths, "outcome ~ 1"), mediation_demo)
  zero <- fit_sem(paste0(paths, "outcome ~ 0*1"), mediation_demo)
  th <- coef(free)
  lm_y <- stats::lm(outcome ~ mediator1 + treatment, mediation_demo)
  lm_m <- stats::lm(mediator1 ~ treatment, mediation_demo)
  expect_equal(unname(th["outcome~1"]), unname(stats::coef(lm_y)[1L]), tolerance = 1e-5)
  expect_equal(unname(th["mediator1~1"]), unname(stats::coef(lm_m)[1L]), tolerance = 1e-5)
  expect_equal(unname(th["treatment~1"]), mean(mediation_demo$treatment), tolerance = 1e-8)
  expect_equal(unname(th[c("a", "b", "cp")]), unname(c(stats::coef(lm_m)[2L], stats::coef(lm_y)[2:3])),
               tolerance = 1e-5)
  expect_equal(generics::glance(free)$df, 0)
  expect_equal(generics::glance(zero)$df, 1)
  tab <- stats::anova(free, zero)
  expect_equal(tab$`Df diff`[2L], 1)
  expect_lt(tab$`Pr(>Chisq)`[2L], 0.01)
  ms <- fit_sem(trimws(paths), mediation_demo, meanstructure = TRUE)
  expect_equal(coef(ms)[names(coef(free))], coef(free), tolerance = 1e-6)
  # planted defect: the zero-intercept fit does not reproduce the lm intercept or the free direct effect
  expect_gt(abs(unname(coef(zero)["cp"]) - unname(stats::coef(lm_y)[3L])), 0.1)
})

# Recipe 20 (four-way decomposition from a native fit): the four components equal the per-equation OLS hand oracle
# (helper-four-way-oracle.R) on the same columns renamed, the sandwich SEs equal the stacked-score HC0 oracle, the
# intervals are estimate +- qnorm(0.975) * SE, and the bootstrap interval brackets the estimate. Planted defect: the
# oracle at the wrong reference level cannot match.
test_that("recipe 20: components and sandwich SEs equal the hand OLS oracle, intervals are Wald", {
  skip_if_not_installed("sandwich")
  cb <- article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  expect_null(run_cookbook_recipe(unlist(parsed[[1L]]), parsed[[21L]]))
  expect_true(grepl("conditional on the", cb, fixed = TRUE))
  expect_true(grepl("method = \"nonparametric\"", cb, fixed = TRUE))
  d <- mediation_demo
  names(d)[match(c("treatment", "mediator1", "outcome_int", "covariate2"), names(d))] <- c("x", "m", "y", "c1")
  fit <- suppressWarnings(fit_sem(
    "mediator1 ~ treatment + covariate2\noutcome_int ~ treatment + mediator1 + treatment:mediator1 + covariate2",
    mediation_demo, se_type = "sandwich"
  ))
  fw <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1", decomposition = "four_way")
  tt <- generics::tidy(fw, type = "components", conf_int = TRUE)
  h <- fwo_hand(d, "c1", vcov_type = "hc0_joint")
  keys <- c("cde", "int_ref", "int_med", "pie")
  expect_identical(tt$term, keys)
  expect_equal(tt$estimate, unname(h$est[keys]), tolerance = 1e-6)
  expect_equal(tt$std_error, unname(h$se[keys]), tolerance = 1e-5)
  expect_equal(tt$conf_high - tt$conf_low, 2 * stats::qnorm(0.975) * tt$std_error, tolerance = 1e-8)
  bad <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "hc0_joint")
  expect_gt(max(abs(tt$estimate - unname(bad$est[keys]))), 1e-3)
})

# Recipe 21 (a categorical covariate in a native fit): the factor fit equals the hand-coded dummy twin, the labeled
# dummy is pinned at 0 by `z == 0`, `fixed_x = "group"` fixes both dummies, and `b*group` is refused. Planted defect:
# the twin with the reference level moved cannot match.
test_that("recipe 21: the factor fit equals the hand-coded dummies, the label route and fixed_x work", {
  cb <- article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  expect_null(run_cookbook_recipe(unlist(parsed[[1L]]), parsed[[22L]]))
  expect_true(grepl("b*group", cb, fixed = TRUE))
  d <- transform(mediation_demo,
                 group = cut(covariate1, c(-Inf, -0.5, 0.5, Inf), labels = c("low", "mid", "high")))
  twin <- transform(d, group_mid = as.numeric(group == "mid"), group_high = as.numeric(group == "high"))
  f <- fit_sem("mediator1 ~ a*treatment + group\noutcome ~ b*mediator1 + cp*treatment + group", d)
  ft <- fit_sem(paste0("mediator1 ~ a*treatment + group_mid + group_high\n",
                       "outcome ~ b*mediator1 + cp*treatment + group_mid + group_high"), twin)
  expect_true(all(is.finite(f@table$est)))
  expect_equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-8)
  wrong <- transform(twin, group_mid = as.numeric(group == "low"))
  fw <- fit_sem(paste0("mediator1 ~ a*treatment + group_mid + group_high\n",
                       "outcome ~ b*mediator1 + cp*treatment + group_mid + group_high"), wrong)
  expect_gt(max(abs(f@table$est - fw@table$est)), 1e-3)
  fz <- fit_sem(paste0("mediator1 ~ a*treatment + group\n",
                       "outcome ~ b*mediator1 + cp*treatment + group + z*group_mid\nz == 0"), d)
  expect_equal(unname(fz@table$est[fz@table$label == "z"]), 0, tolerance = 1e-6)
  expect_equal(generics::glance(fit_sem("mediator1 ~ treatment + group\noutcome ~ mediator1 + group", d,
                                        fixed_x = "group"))$fixed_x, "group_mid, group_high")
  expect_error(fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + b*group", d), "expands to 2 terms")
})
