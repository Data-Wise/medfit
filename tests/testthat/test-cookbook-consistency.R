# Consistency guard for the cookbook (SPEC-refcard-cookbook T4/T5): seventeen numbered
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

test_that("the cookbook has seventeen numbered recipes and every article link resolves", {
  cb <- article_text("cookbook.qmd")
  heads <- regmatches(cb, gregexpr("(?m)^## [0-9]+\\. ", cb, perl = TRUE))[[1]]
  expect_identical(trimws(sub("^## ", "", heads)), paste0(1:17, "."))
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

test_that("recipes 14-17 run after the setup chunk alone and say what they claim", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  for (k in 14:17) {
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
  expect_lt(g$p.value, 1e-10)
  # recipe 14: the restricted model has more degrees of freedom, and the test is not significant
  full <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment", mediation_demo)
  reduced <- fit_sem("mediator1 ~ a * treatment\noutcome ~ b * mediator1", mediation_demo)
  expect_gt(stats::anova(reduced, full)$`Pr(>Chisq)`[2], 0.5)
})

test_that("the native quickstart and guide exist, are indexed, and their links resolve", {
  pk <- article_text("cookbook.qmd") # skips without vignettes
  pkg <- paste(readLines(testthat::test_path("..", "..", "_pkgdown.yml"), warn = FALSE), collapse = "\n")
  for (a in c("native-quickstart", "native-guide")) {
    expect_true(grepl(paste0("articles/", a, "`"), pkg, fixed = TRUE), info = a)
    expect_true(grepl(paste0("articles/", a, ".html"), pkg, fixed = TRUE), info = a)
    txt <- article_text(paste0(a, ".qmd"))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
    targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
    expect_identical(targets[is.na(vapply(targets, article_path, character(1)))], character(), info = a)
  }
})
