# Consistency guard for the native-engine mini-book (vignettes/articles/native-book-1..5):
# the chapters exist, sit in the articles index and the Guides menu in order, every
# chapter link resolves, and two identities the last chapter teaches hold.

root_path <- function(...) testthat::test_path("..", "..", ...)

book_chapters <- function() {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  sub("\\.qmd$", "", list.files(d, pattern = "^native-book-[0-9]-.*\\.qmd$"))
}

read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")

test_that("the five chapters exist, numbered 1 to 5", {
  ch <- book_chapters()
  expect_length(ch, 5L)
  expect_identical(as.integer(sub("^native-book-([0-9])-.*$", "\\1", ch)), 1:5)
})

test_that("every chapter is in the articles index and the Guides menu, in order", {
  ch <- book_chapters()
  pk <- read_text(root_path("_pkgdown.yml"))
  for (g in ch) {
    expect_true(grepl(paste0("articles/", g, "`"), pk, fixed = TRUE), info = paste(g, "index"))
    expect_true(grepl(paste0("articles/", g, ".html"), pk, fixed = TRUE), info = paste(g, "menu"))
  }
  pos_menu <- vapply(ch, function(g) regexpr(paste0("articles/", g, ".html"), pk, fixed = TRUE)[[1]], numeric(1))
  pos_index <- vapply(ch, function(g) regexpr(paste0("articles/", g, "`"), pk, fixed = TRUE)[[1]], numeric(1))
  expect_false(is.unsorted(pos_menu))
  expect_false(is.unsorted(pos_index))
})

test_that("every article link on the chapters resolves", {
  for (g in book_chapters()) {
    txt <- read_text(root_path("vignettes", "articles", paste0(g, ".qmd")))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z0-9-]+)\\.html[#)]", txt))[[1]])
    targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
    missing <- targets[!file.exists(root_path("vignettes", "articles", targets))]
    expect_identical(missing, character(), info = g)
  }
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
