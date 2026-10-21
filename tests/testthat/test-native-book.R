# Consistency guard for the native-engine book (book/chapters/01..07): the chapters exist and are listed in book/_quarto.yml in
# order, every chapter link resolves, the book is off the package website, and identities chapters 5, 6 and 7 teach hold.

root_path <- function(...) testthat::test_path("..", "..", ...)

book_dir <- function() {
  d <- root_path("book")
  testthat::skip_if_not(dir.exists(d), "book/ is not available (installed or built package)")
  d
}

book_chapters <- function() list.files(file.path(book_dir(), "chapters"), pattern = "^0[0-9]-.*\\.qmd$")

read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")

test_that("the seven chapters exist, numbered 1 to 7, and are listed in _quarto.yml in order", {
  ch <- book_chapters()
  expect_length(ch, 7L)
  expect_identical(as.integer(sub("^0([0-9])-.*$", "\\1", ch)), 1:7)
  yml <- read_text(file.path(book_dir(), "_quarto.yml"))
  pos <- vapply(ch, function(g) regexpr(paste0("chapters/", g), yml, fixed = TRUE)[[1]], numeric(1))
  expect_true(all(pos > 0))
  expect_false(is.unsorted(pos))
})

test_that("every relative chapter link resolves", {
  for (g in book_chapters()) {
    txt <- read_text(file.path(book_dir(), "chapters", g))
    links <- unique(regmatches(txt, gregexpr("\\]\\((0[0-9]-[a-z0-9-]+\\.qmd)", txt))[[1]])
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
  fe <- fit_sem(parallel, d, information = "expected")
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
  fw <- fit_sem(mediation, d, weights = w, se_type = "sandwich")
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
