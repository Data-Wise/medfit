# Consistency guard for the repository-only book (book/chapters/01..10): the chapters exist and are listed in
# book/_quarto.yml in order, every chapter link resolves, the book is off the package website, the identities
# chapters 5, 6 and 7 teach hold, chapter 9 (the lavaan two-level adapter) and chapter 10 (2-1-1 cluster mediation)
# run from their setup chunk alone and reproduce their oracles.

root_path <- function(...) testthat::test_path("..", "..", ...)

book_dir <- function() {
  d <- root_path("book")
  testthat::skip_if_not(dir.exists(d), "book/ is not available (installed or built package)")
  d
}

book_chapters <- function() list.files(file.path(book_dir(), "chapters"), pattern = "^[0-9]{2}-.*\\.qmd$")

read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")

test_that("the ten chapters exist, numbered 1 to 10, and are listed in _quarto.yml in order", {
  ch <- book_chapters()
  expect_length(ch, 10L)
  expect_identical(as.integer(sub("^([0-9]{2})-.*$", "\\1", ch)), 1:10)
  yml <- read_text(file.path(book_dir(), "_quarto.yml"))
  pos <- vapply(ch, function(g) regexpr(paste0("chapters/", g), yml, fixed = TRUE)[[1]], numeric(1))
  expect_true(all(pos > 0))
  expect_false(is.unsorted(pos))
})

test_that("every relative chapter link resolves", {
  for (g in book_chapters()) {
    txt <- read_text(file.path(book_dir(), "chapters", g))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([0-9]{2}-[a-z0-9-]+\\.qmd)", txt))[[1]])
    targets <- gsub("^\\]\\(", "", links)
    missing <- targets[!file.exists(file.path(book_dir(), "chapters", targets))]
    expect_identical(missing, character(), info = g)
  }
})

test_that("the book is not on the package website", {
  skip_if_not(file.exists(root_path("_pkgdown.yml")), "_pkgdown.yml is not shipped")
  expect_false(grepl("native-book", read_text(root_path("_pkgdown.yml")), fixed = TRUE))
  d <- root_path("vignettes", "articles")
  skip_if_not(dir.exists(d))
  expect_length(list.files(d, pattern = "^native-book"), 0L)
})

test_that("chapter 5: the delta-method standard error and the MBCO/anova statistic agree by hand", {
  d <- mediation_demo
  full <- "
    mediator1 ~ a * treatment
    outcome ~ b * mediator1 + cp * treatment
    ab := a * b
  "
  fit <- fit_sem(full, d)
  g <- c(coef(fit)[["b"]], coef(fit)[["a"]])
  v <- fit@vcov[c("a", "b"), c("a", "b")]
  expect_equal(sqrt(drop(t(g) %*% v %*% g)), fit@defined$se, tolerance = 1e-6)

  restricted <- fit_sem(paste0(full, "a == 0\n"), d)
  mb <- mbco_sem(fit, "a", "b")
  by_hand <- nrow(d) * (restricted@f - fit@f)
  expect_equal(mb$tests$diff_ll[1], by_hand, tolerance = 1e-6)
  expect_equal(anova(restricted, fit)$`Chisq diff`[2], by_hand, tolerance = 1e-6)
})

test_that("chapter 5: the expected information is the trace formula, and the sandwich is A^-1 B A^-1", {
  d <- mediation_demo
  n <- nrow(d)
  parallel <- "
    mediator1 ~ treatment
    mediator2 ~ treatment
    outcome ~ mediator1 + mediator2
  "
  # the hand formulas below are the covariance-only likelihood: pin it (the 0.15.0 defaults fix x and add a mean block)
  fe <- fit_sem(parallel, d, information = "expected", fixed_x = FALSE, meanstructure = NULL)
  ram <- fe@internals$ram
  smp <- medfit:::.sem_sample(fe@data, ram)
  theta <- fe@theta
  si <- solve(medfit:::.sem_implied(ram, theta))
  ds <- medfit:::.sem_dsigma(theta, ram)
  q <- length(theta)
  by_hand <- 0.5 * n * outer(seq_len(q), seq_len(q), Vectorize(function(k, l) {
    sum(diag(si %*% ds[[k]] %*% si %*% ds[[l]]))
  }))
  expect_equal(by_hand, medfit:::.sem_info_expected(theta, ram, smp, NULL), tolerance = 1e-8, ignore_attr = TRUE)

  set.seed(4)
  w <- rexp(n) + 0.3
  mediation <- "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment"
  fw <- fit_sem(mediation, d, weights = w, se_type = "sandwich", fixed_x = FALSE, meanstructure = NULL)
  rw <- fw@internals$ram
  sw <- medfit:::.sem_sample(fw@data, rw, weights = w)
  scores <- medfit:::.sem_scores(fw@theta, rw, sw)
  bread <- solve(medfit:::.sem_info_observed(fw@theta, rw, sw, NULL))
  expect_equal(bread %*% crossprod(scores) %*% bread, fw@vcov, tolerance = 1e-6, ignore_attr = TRUE)
})

test_that("chapter 6: a product model's paths and observed-information SEs are equation-wise least squares", {
  d <- mediation_demo
  n <- nrow(d)
  model <- "
    mediator1 ~ treatment + covariate1
    outcome_int ~ mediator1 + treatment + treatment:mediator1 + covariate1
  "
  fit <- suppressWarnings(fit_sem(model, d))
  lm_y <- lm(outcome_int ~ mediator1 + treatment + I(treatment * mediator1) + covariate1, d)
  y_par <- c("outcome_int~1", "outcome_int~mediator1", "outcome_int~treatment", "outcome_int~mediator1:treatment",
             "outcome_int~covariate1")
  expect_equal(unname(coef(fit)[y_par]), unname(coef(lm_y)), tolerance = 1e-6)
  expect_equal(coef(fit)[["outcome_int~~outcome_int"]], mean(residuals(lm_y)^2), tolerance = 1e-6)
  expect_equal(unname(sqrt(diag(fit@vcov))[y_par]), unname(sqrt(diag(vcov(lm_y) * (n - 5) / n))), tolerance = 1e-4)
  expect_error(fit_sem(model, d, information = "expected"), "endogenous variable")
})

test_that("chapter 7: the four-way components and their model-based SEs agree with a hand delta method", {
  d <- mediation_demo
  model <- "
    mediator1 ~ treatment + covariate2
    outcome_int ~ treatment + mediator1 + treatment:mediator1 + covariate2
  "
  fit <- suppressWarnings(fit_sem(model, d))
  fw <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1", decomposition = "four_way")
  lm_m <- lm(mediator1 ~ treatment + covariate2, d)
  lm_y <- lm(outcome_int ~ treatment + mediator1 + I(treatment * mediator1) + covariate2, d)
  b0 <- coef(lm_m)[[1]]
  b1 <- coef(lm_m)[["treatment"]]
  g <- coef(lm_m)[["covariate2"]]
  t1 <- coef(lm_y)[["treatment"]]
  t2 <- coef(lm_y)[["mediator1"]]
  t3 <- coef(lm_y)[["I(treatment * mediator1)"]]
  cb <- mean(d$covariate2)
  expect_equal(c(fw@cde, fw@int_ref, fw@int_med, fw@pie), c(t1, t3 * (b0 + g * cb), t3 * b1, t2 * b1),
               tolerance = 1e-6)
  ml <- function(f) vcov(f) * df.residual(f) / nobs(f)
  v <- matrix(0, 6, 6)
  v[1:3, 1:3] <- ml(lm_m)
  y_terms <- c("treatment", "mediator1", "I(treatment * mediator1)")
  v[4:6, 4:6] <- ml(lm_y)[y_terms, y_terms]
  grad_int_ref <- c(t3, 0, t3 * cb, 0, 0, b0 + g * cb)
  td <- tidy(fw)
  expect_equal(td$std_error[td$term == "int_ref"], sqrt(drop(grad_int_ref %*% v %*% grad_int_ref)), tolerance = 1e-4)
})

test_that("chapters 3 and 5 state the 0.13.0 behavior (-4, capped restoration, failed branches and refits)", {
  ch3 <- read_text(file.path(book_dir(), "chapters", "03-constraints.qmd"))
  ch5 <- read_text(file.path(book_dir(), "chapters", "05-inference.qmd"))
  expect_match(ch3, "roundoff-limited -4", fixed = TRUE)
  expect_match(ch3, sprintf("$k = %g$", .sem_restore_k), fixed = TRUE)
  expect_match(ch3, "medfit_error_no_convergence", fixed = TRUE)
  expect_false(grepl("best of the other branches is returned", ch3, fixed = TRUE))
  expect_match(ch5, "unresolved = TRUE", fixed = TRUE)
  # planted: a chapter stating another k is not accepted as this one
  expect_false(grepl(sprintf("$k = %g$", .sem_restore_k), sub("$k = 4$", "$k = 40$", ch3, fixed = TRUE), fixed = TRUE))
})

test_that("all chapters avoid old warning muffles and complete-data chapters retain their visible wrapper", {
  for (g in book_chapters()) {
    txt <- read_text(file.path(book_dir(), "chapters", g))
    expect_false(grepl("medfit_warning_default_change|native-defaults-setup", txt), info = g)
    if (grepl("^0[1-7]-", g)) {
      wrapper <- "fit_sem <- function(model, data, ..., fixed_x = FALSE, meanstructure = NULL)"
      expect_true(grepl(wrapper, txt, fixed = TRUE), info = g)
    }
  }
  expect_false(grepl("documents medfit 0\\.14", read_text(file.path(book_dir(), "index.qmd"))))
})

test_that("chapter 8 uses explicit bounded FIML settings and is linked from the preface", {
  ch8 <- read_text(file.path(book_dir(), "chapters", "08-fiml.qmd"))
  expect_false(grepl("fit_sem\\s*<-\\s*function", ch8))
  blocks <- regmatches(ch8, gregexpr("(?s)```\\{r\\}\n.*?\n```", ch8, perl = TRUE))[[1]]
  code <- gsub("^```\\{r\\}\n|\n```$", "", blocks, perl = TRUE)
  expressions <- as.list(parse(text = paste(code, collapse = "\n")))
  fitted <- Filter(function(x) {
    is.call(x) && identical(x[[1]], quote(`<-`)) && identical(x[[2]], quote(fit))
  }, expressions)
  expect_length(fitted, 1L)
  if (length(fitted) == 1L) {
    args <- as.list(fitted[[1]][[3]])
    expect_identical(args[[1]], quote(medfit::fit_sem))
    expected <- list(missing = "fiml", fixed_x = FALSE, meanstructure = TRUE,
                     information = "observed", se_type = "model")
    expect_identical(args[names(expected)], expected)
  }
  expect_match(read_text(file.path(book_dir(), "index.qmd")),
               "[Bounded FIML: learning from partially observed rows](chapters/08-fiml.qmd)", fixed = TRUE)
  expect_match(read_text(file.path(book_dir(), "_quarto.yml")), "    - chapters/08-fiml.qmd", fixed = TRUE)
})


test_that("the constrained covariance teaching distinguishes curvature and boundary limits", {
  ch3 <- read_text(file.path(book_dir(), "chapters", "03-constraints.qmd"))
  ch5 <- read_text(file.path(book_dir(), "chapters", "05-inference.qmd"))
  expect_match(ch3, "Lagrangian information", fixed = TRUE)
  expect_match(ch3, "Expected** information\nkeeps its Fisher definition", fixed = TRUE)
  expect_match(ch3, "reparameterized-covariance-check", fixed = TRUE)
  expect_match(ch3, "every coordinate is pinned", fixed = TRUE)
  expect_match(ch3, "full named `NA` covariance matrix", fixed = TRUE)
  expect_match(ch3, "local tangent covariance", fixed = TRUE)
  expect_match(ch5, "ambient scores need not sum to zero", fixed = TRUE)
  expect_match(ch5, "methods.html#constraints", fixed = TRUE)
  expect_match(ch5, '.sem_covariance_diagnostic("negative_variance"', fixed = TRUE)
  expect_match(ch5, '.sem_covariance_diagnostic("information_not_pd"', fixed = TRUE)
  expect_match(ch5, "covariance-raw-error-check", fixed = TRUE)
  expect_false(grepl('stop("injected covariance failure")', ch5, fixed = TRUE))
  expect_false(grepl('stop("injected null covariance failure")', ch5, fixed = TRUE))
})

test_that("chapters 3 and 5 carry the post-0.13 contracts (branch map, sign branches, pinned SE, floor, compare_lr)", {
  ch3 <- read_text(file.path(book_dir(), "chapters", "03-constraints.qmd"))
  ch5 <- read_text(file.path(book_dir(), "chapters", "05-inference.qmd"))
  needles3 <- c("branch_map", "raw_count", "unique_count", "search_evidence", 'coverage = "charted"', "proved_empty",
                "label: pinned-se-mean", "label: slope-floor", "10^{-10}\\,\\lVert g\\rVert")
  for (s in needles3) expect_match(ch3, s, fixed = TRUE)
  needles5 <- c("compare_lr(fit_full", "above_reference", "medfit_warning_engine_statistic_above_max",
                "label: compare-lr-check")
  for (s in needles5) expect_match(ch5, s, fixed = TRUE)
  # planted: a chapter without the section does not pass the same needle
  expect_false(grepl("proved_empty", gsub("proved_empty", "excluded", ch3, fixed = TRUE), fixed = TRUE))
  # the slope floor the chapter states is the constant the code uses
  expect_identical(medfit:::.sem_slope_tol_rel, 1e-10)
  # chapter 3's hand count: two product rows of two factors give 4 raw combinations and 3 distinct sets
  raw <- expand.grid(r1 = c("a", "b"), r2 = c("a", "b"), stringsAsFactors = FALSE)
  hand_sets <- apply(raw, 1, function(r) paste(sort(unique(r)), collapse = ","))
  expect_identical(c(nrow(raw), length(unique(hand_sets))), c(4L, 3L))
  fit <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment\na*b == 0\na*b == 0\n",
                 mediation_demo, fixed_x = FALSE, meanstructure = NULL)
  map <- fit@diagnostics$ledger$branch_map
  expect_identical(c(map$raw_count, map$unique_count), c(4L, 3L))
})

# --- chapter 9: the lavaan two-level adapter and TwoLevelMediationData ---

# Evaluate every non-`eval: false` R chunk of a chapter in order, in a fresh environment whose parent is the test
# environment (so the package under test, not an installed copy, supplies medfit's functions). `library(medfit)` is
# dropped for that reason; the setup chunk's other statements run unchanged. Returns the environment.
run_chapter_chunks <- function(txt) {
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  starts <- grep("^```\\{r\\}", lines)
  ends <- grep("^```$", lines)
  env <- new.env(parent = parent.frame())
  for (s in starts) {
    code <- lines[(s + 1L):(ends[ends > s][1L] - 1L)]
    if (any(grepl("^#\\| eval: false", code))) next
    code <- code[!grepl("^library\\(medfit\\)$", code)]
    for (ex in parse(text = code)) eval(ex, env)
  }
  env
}

ch9_path <- function() file.path(book_dir(), "chapters", "09-twolevel.qmd")

test_that("chapter 9 is listed in _quarto.yml, linked from the preface, and the book is retitled", {
  expect_true(file.exists(ch9_path()))
  yml <- read_text(file.path(book_dir(), "_quarto.yml"))
  expect_match(yml, "    - chapters/09-twolevel.qmd", fixed = TRUE)
  expect_match(yml, 'title: "The medfit engines and model classes"', fixed = TRUE)
  expect_match(read_text(file.path(book_dir(), "index.qmd")),
               "9. The lavaan two-level adapter and `TwoLevelMediationData`", fixed = TRUE)
  expect_false(grepl("fit_sem\\s*<-\\s*function", read_text(ch9_path())))
  # the thresholds the chapter states are the constants the adapter uses
  expect_identical(medfit:::.twolevel_defaults$icc_error, 0.01)
  expect_identical(medfit:::.twolevel_defaults$icc_warn, 0.05)
  expect_identical(medfit:::.twolevel_defaults$min_clusters, 50L)
})

test_that("chapter 9 runs from its setup chunk alone and its hand computations hold", {
  skip_if_not_installed("lavaan")
  skip_on_cran()
  env <- run_chapter_chunks(read_text(ch9_path()))
  # contrast SE: the hand delta method equals tidy() and lavaan's own defined parameter
  expect_equal(env$se_hand, env$tidy_se, tolerance = 1e-8)
  expect_equal(env$se_hand, env$lav_se, tolerance = 1e-4)
  expect_gt(abs(env$se_hand - env$se_no_cross), 1e-4)
  # the sub-block by free index is the object's covariance; names are not safe keys
  expect_equal(unname(env$v6), unname(env$td@vcov), tolerance = 1e-12)
  expect_true(anyDuplicated(rownames(env$v_eq)) > 0)
  # equated paths: both detection routes, correlation 1, contrast NA
  expect_identical(env$td_eq@cross_level_equal, "a")
  expect_identical(env$td_eq2@cross_level_equal, "a")
  expect_equal(abs(env$v_pair[1, 2]) / sqrt(env$v_pair[1, 1] * env$v_pair[2, 2]), 1, tolerance = 1e-8)
  expect_false(medfit:::.twolevel_contrast_available(env$td_eq))
  # ICC rule: hand ICC equals the stored one, and the within-only object has no between rows
  expect_equal(unname(env$icc_hand(env$fit)), unname(env$td@icc[c("X", "M", "Y")]), tolerance = 1e-10)
  expect_lt(env$td0@icc[["X"]], medfit:::.twolevel_defaults$icc_error)
  expect_false(env$td0@between_identified)
  expect_identical(dim(env$td0@vcov), c(3L, 3L))
  # the two-level likelihood oracle: reduced = stacked, both equal lavaan, balanced and unbalanced
  expect_equal(env$ll_hand, env$ll_stacked, tolerance = 1e-10)
  expect_lt(env$ll_rel_diff, 1e-10)
  expect_lt(env$ll_rel_diff_unbalanced, 1e-10)
  expect_lt(max(env$closed_gap), 1e-4)
  expect_lt(abs(env$ll_closed_gap), 1e-6)
  # the chapter's likelihood is the test helper's (oracle O8)
  expect_equal(env$ll_hand, tl_loglik(tl_stats(env$d), env$h$sw, env$h$sb, env$h$mu), tolerance = 1e-10)
  cf <- tl_o8_closed_form(env$d)
  expect_equal(unname(env$closed$sw), unname(cf$sw), tolerance = 1e-10)
  expect_equal(unname(env$closed$sb), unname(cf$sb), tolerance = 1e-10)
  # bootstrap: the callback is the product, the relabeled refit has all 60 clusters, the interval is percentile
  expect_equal(env$stat_between(env$td@estimates), env$td@a_between * env$td@b_between, tolerance = 1e-12)
  expect_identical(length(unique(env$relabeled$cluster)), 60L)
  expect_lt(length(unique(env$kept_ids$cluster)), 60L)
  expect_gt(abs(env$cb(env$relabeled) - env$cb(env$kept_ids)), 1e-6)
  expect_identical(env$b_cl@n_boot, 20L)
  expect_equal(c(env$b_cl@ci_lower, env$b_cl@ci_upper),
               unname(stats::quantile(env$b_cl@boot_estimates, c(0.025, 0.975))), tolerance = 1e-12)
  # a fixed path has a zero row and column and is listed
  fixed <- suppressWarnings(lavaan::sem(
    "level: 1\n M ~ X\n Y ~ M + 0*X\nlevel: 2\n M ~ X\n Y ~ M + X\n", env$d, cluster = "cluster", fixed.x = FALSE
  ))
  tdf <- extract_mediation(fixed, treatment = "X", mediator = "M", outcome = "Y")
  expect_identical(tdf@fixed_paths, "c_prime_within")
  expect_true(all(tdf@vcov["c_prime_within", ] == 0))
})

test_that("chapter 9: planted defects in the chapter's hand likelihood are caught", {
  skip_if_not_installed("lavaan")
  skip_on_cran()
  txt <- read_text(ch9_path())
  defects <- list(
    nj_free = c("v <- sw + s$n * sb", "v <- sw + sb"),
    no_mean = c("dev <- s$zbar - mu", "dev <- s$zbar")
  )
  for (nm in names(defects)) {
    expect_true(grepl(defects[[nm]][1], txt, fixed = TRUE), info = nm)
    env <- run_chapter_chunks(sub(defects[[nm]][1], defects[[nm]][2], txt, fixed = TRUE))
    expect_gt(env$ll_rel_diff, 1e-6, label = paste("relative gap with defect", nm))
  }
})

ch10_path <- function() file.path(book_dir(), "chapters", "10-cluster.qmd")

test_that("chapter 10 is listed in _quarto.yml and linked from the preface", {
  expect_true(file.exists(ch10_path()))
  expect_match(read_text(file.path(book_dir(), "_quarto.yml")), "    - chapters/10-cluster.qmd", fixed = TRUE)
  expect_match(read_text(file.path(book_dir(), "index.qmd")),
               "10. Cluster-randomized mediation (2-1-1)", fixed = TRUE)
  expect_false(grepl("fit_sem\\s*<-\\s*function", read_text(ch10_path())))
})

test_that("chapter 10 runs from its setup chunk alone and its oracles hold", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("pbkrtest")
  skip_on_cran()
  env <- run_chapter_chunks(read_text(ch10_path()))
  keys <- c("a", "c_prime", "b_within", "b_between")
  # paths: lm on cluster means and the within regression, the reduced-form coefficient for te()
  expect_lt(env$paths_gap, 1e-8)
  expect_lt(env$te_gap, 1e-8)
  expect_equal(unname(paths(env$x_fit)), unname(paths(env$x_ext)), tolerance = 1e-8)
  # the chapter's hand oracle is the helper harness's fit on the harness's own balanced data
  sim <- sim_cluster211(J = 30, sizes = 8, seed = 5)
  expect_equal(unname(env$hand_paths(sim$data, "cluster")),
               unname(paths(fit_cluster211(sim$data))[c("a", "b_within", "b_between", "c_prime")]),
               tolerance = 1e-6)
  # term detection by value: raw parameterization and a rescaled mean term give the same paths and covariance
  expect_identical(env$x_raw@parameterization, "raw")
  expect_equal(unname(paths(env$x_raw)), unname(paths(env$x_ext)), tolerance = 1e-8)
  expect_equal(env$x_raw@vcov[keys, keys], env$x_ext@vcov[keys, keys], tolerance = 1e-8)
  expect_equal(unname(paths(env$x_10)), unname(paths(env$x_ext)), tolerance = 1e-8)
  expect_match(env$no_mean_msg, "no cluster-mean term", fixed = TRUE)
  # exact own and spillover by counterfactual prediction
  expect_equal(env$own_exact, env$a_hat * (env$b_w + (env$b_b - env$b_w) / env$n_j), tolerance = 1e-8)
  expect_equal(env$spill_exact, env$a_hat * (env$b_b - env$b_w) * (env$n_j - 1) / env$n_j, tolerance = 1e-8)
  expect_equal(env$own_exact + env$spill_exact, env$a_hat * env$b_b, tolerance = 1e-8)
  expect_equal(unname(env$dec[["own"]] + env$dec[["spillover"]]), unname(env$dec[["nie"]]), tolerance = 1e-12)
  # D11: quiet at ten members per cluster; the warning is the one the chapter captured, and its gap is the hand gap
  expect_no_warning(decompose(env$x_ext))
  expect_equal(medfit:::.cluster_own_gap(env$x_trio), env$gap_hand, tolerance = 1e-12)
  expect_gt(env$gap_hand, 0.5 * env$own_se)
  expect_match(env$trio_warning, sprintf("off by about %.3g", env$gap_hand), fixed = TRUE)
  # covariance: only the mediator-outcome blocks are zero by construction
  expect_true(all(env$cross_block == 0))
  expect_lt(abs(env$V["b_within", "b_between"]), 1e-10)
  expect_gt(abs(env$V["c_prime", "b_between"]), 1e-4)
  # delta method by hand equals tidy() and the package's own gradient code
  expect_lt(env$delta_gap, 1e-8)
  expect_equal(unname(env$se_hand), unname(medfit:::.effect_se(env$x_ext, names(env$se_hand))), tolerance = 1e-8)
  # Kenward-Roger: df equal the OLS df on cluster means and the within-cluster regression, interval equals lm's
  n_cl <- env$n_cl
  expect_equal(unname(env$x_kr@kr_df[keys]), c(n_cl - 2, n_cl - 3, nrow(env$pair) - n_cl - 1, n_cl - 3),
               tolerance = 1e-6)
  expect_equal(unname(confint(env$x_kr)["a", ]), unname(confint(env$lm_a)["X", ]), tolerance = 1e-6)
  expect_equal(unname(env$var_adjusted), unname(env$var_model), tolerance = 1e-6)
  est <- paths(env$x_kr)
  se <- sqrt(diag(env$x_kr@vcov))[names(est)]
  expect_equal(unname(confint(env$x_kr)[names(est), 1]),
               unname(est - stats::qt(0.975, env$x_kr@kr_df[names(est)]) * se), tolerance = 1e-10)
  eff <- confint(env$x_kr, parm = "effects")
  expect_equal(unname(eff[, 1]),
               unname(medfit:::.cluster_effect_vec(env$x_kr)[rownames(eff)] -
                        stats::qnorm(0.975) * medfit:::.effect_se(env$x_kr, rownames(eff))), tolerance = 1e-10)
  # bootstrap: the hand replay of the draws equals the stored replicates; the interval is percentile
  expect_lt(max(abs(env$replay - env$boot@boot_estimates)), 1e-8)
  expect_equal(c(env$boot@ci_lower, env$boot@ci_upper),
               unname(stats::quantile(env$boot@boot_estimates, c(0.025, 0.975))), tolerance = 1e-12)
  expect_identical(env$boot@n_boot, 40L)
  expect_identical(length(unique(env$relabeled$school)), 40L)
  expect_lt(length(unique(env$kept_ids$school)), 40L)
  expect_gt(abs(env$nie_of(env$relabeled) - env$nie_of(env$kept_ids)), 1e-6)
})

test_that("chapter 10: planted defects in the chapter's hand computations are caught", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("pbkrtest")
  skip_on_cran()
  txt <- read_text(ch10_path())
  defect <- function(from, to) {
    expect_true(grepl(from, txt, fixed = TRUE), info = from)
    # the no-relabeling defect refits on fewer than 25 clusters, which raises the few-cluster advisory
    suppressWarnings(run_chapter_chunks(sub(from, to, txt, fixed = TRUE)))
  }
  # the NIE gradient read from the within path instead of the between path
  env <- defect("nie = c(a = b_b, b_between = a_hat),", "nie = c(a = b_b, b_within = a_hat),")
  expect_gt(env$delta_gap, 1e-3)
  # the bootstrap replay without relabeling: a cluster drawn twice is counted once
  env <- defect("function(ids) nie_of(medfit:::.relabel_clusters(dat_fit, \"school\", ids))",
                "function(ids) nie_of(dat_fit[dat_fit$school %in% ids, ])")
  expect_gt(max(abs(env$replay - env$boot@boot_estimates)), 1e-4)
  # a biased within slope in the hand oracle
  env <- defect("b_w <- sum(m_dev * (d[[y]] - y_bar)) / sum(m_dev^2)",
                "b_w <- 1.05 * sum(m_dev * (d[[y]] - y_bar)) / sum(m_dev^2)")
  expect_gt(env$paths_gap, 1e-3)
})
