# Consistency guard for the lavaan comparison article (T20): every row of the feature table has a probe that
# computes its status from live behavior, the status in the article equals the probe's, and a planted edit to a
# row is caught. Skips when the vignettes or lavaan are absent.

lc_text <- function() {
  p <- testthat::test_path("..", "..", "vignettes", "articles", "lavaan-comparison.qmd")
  testthat::skip_if(!file.exists(p), "vignettes are not available (installed or built package)")
  paste(readLines(p, warn = FALSE), collapse = "\n")
}

# The rows of the table in the "Feature table" section: feature, lavaan, native, status.
lc_rows <- function(txt) {
  lines <- strsplit(sub("(?s)^.*## Feature table", "", txt, perl = TRUE), "\n", fixed = TRUE)[[1]]
  lines <- lines[startsWith(lines, "|") & !grepl("^\\|[- |]+\\|$", lines)]
  cells <- lapply(strsplit(lines, "|", fixed = TRUE), function(x) trimws(x[-1]))
  cells <- cells[vapply(cells, length, 1L) == 4L]
  tab <- as.data.frame(do.call(rbind, cells), stringsAsFactors = FALSE)
  names(tab) <- c("feature", "lavaan", "native", "status")
  tab[tab$feature != "Feature", ]
}

lc_err <- function(expr) inherits(try(expr, silent = TRUE), "try-error")
lc_se <- function(x) sqrt(diag(if (inherits(x, "lavaan")) lavaan::vcov(x) else vcov(x)))

lc_probes <- function() {
  d <- medfit::mediation_demo
  lab <- "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment"
  over <- "mediator1 ~ treatment\nmediator2 ~ treatment\noutcome ~ mediator1 + mediator2"
  m <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1"
  lv <- function(text, ...) suppressWarnings(lavaan::sem(text, d, fixed.x = FALSE, ...))
  close <- function(x, y, tol = 1e-6) isTRUE(all(abs(x - y) < tol))
  list(
    "Paths, covariances, labels, fixed values, bounds" = function() {
      f <- fit_sem(paste0(lab, "\noutcome ~~ lower(0) * outcome"), d)
      fx <- fit_sem(sub("cp \\*", "0 *", lab), d)
      ok <- close(coef(fit_sem(lab, d))[c("a", "b", "cp")], lavaan::coef(lv(lab))[c("a", "b", "cp")]) &&
        coef(f)[["outcome~~outcome"]] >= 0 && coef(fx)[["a"]] > 0
      if (ok) "Supported" else "Unsupported"
    },
    "Several modifiers on one term" = function() {
      if (lc_err(fit_sem("outcome ~ start(0.1) * lower(0) * treatment", d))) "Unsupported" else "Supported"
    },
    "Means and intercepts" = function() {
      if (lc_err(fit_sem("outcome ~ 1 + treatment", d))) "Unsupported" else "Supported"
    },
    "Multiple groups" = function() {
      if ("group" %in% names(formals(fit_sem))) "Supported" else "Unsupported"
    },
    "Estimators other than ML" = function() {
      ml <- close(coef(fit_sem(m, d)), lavaan::coef(lv(m, estimator = "ML")))
      if (ml && !"estimator" %in% names(formals(fit_sem))) "Partial" else "Supported"
    },
    "Missing data" = function() {
      dn <- d
      dn$outcome[1:5] <- NA
      f <- suppressMessages(fit_sem(m, dn))
      if (f@n_dropped == 5L && !"missing" %in% names(formals(fit_sem))) "Partial" else "Supported"
    },
    "Categorical outcomes" = function() {
      dc <- d
      dc$outcome <- cut(dc$outcome, 3, ordered_result = TRUE)
      if (lc_err(fit_sem("mediator1 ~ treatment\noutcome ~ mediator1", dc))) "Unsupported" else "Supported"
    },
    "Information matrix" = function() {
      obs <- lc_se(fit_sem(over, d))[3]
      exp <- lc_se(fit_sem(over, d, information = "expected"))[3]
      lav <- lc_se(lv(over))[3]
      if (!close(obs, lav, 1e-4) && close(exp, lav)) "Different by design" else "Supported"
    },
    "Robust standard errors" = function() {
      ok <- close(lc_se(fit_sem(over, d, se_type = "sandwich")), lc_se(lv(over, se = "robust.huber.white")))
      if (ok) "Supported" else "Unsupported"
    },
    "Linear constraints" = function() {
      a <- paste0(m, "\na == b")
      if (close(coef(fit_sem(a, d))[1:2], lavaan::coef(lv(a))[1:2], 1e-5)) "Supported" else "Unsupported"
    },
    "Nonlinear constraints" = function() {
      a <- paste0(lab, "\ncp == a*b")
      f <- fit_sem(a, d)
      ok <- close(coef(f)[1:3], lavaan::coef(lv(a))[1:3], 1e-4) &&
        abs(coef(f)[["cp"]] - prod(coef(f)[c("a", "b")])) < 1e-6
      if (ok) "Supported" else "Unsupported"
    },
    "Defined parameters" = function() {
      a <- paste0(lab, "\nab := a*b")
      f <- fit_sem(a, d)
      l <- lv(a)
      tn <- generics::tidy(f)
      tn <- tn[tn$term == "ab", ]
      pe <- lavaan::parameterEstimates(l)
      pe <- pe[pe$label == "ab", ]
      ok <- close(tn$estimate, pe$est) && close(tn$std_error, pe$se)
      if (ok) "Supported" else "Unsupported"
    },
    "Chi-square and df" = function() {
      g <- generics::glance(fit_sem(over, d))
      fm <- lavaan::fitMeasures(lv(over), c("chisq", "df"))
      if (close(g$chisq, fm[["chisq"]]) && g$df == fm[["df"]]) "Supported" else "Unsupported"
    },
    "CFI, RMSEA, SRMR" = function() {
      g <- names(generics::glance(fit_sem(over, d)))
      if (any(c("cfi", "rmsea", "srmr") %in% tolower(g))) "Supported" else "Unsupported"
    },
    "logLik, AIC, BIC" = function() {
      f <- fit_sem(over, d)
      l <- lv(over)
      same_ll <- close(as.numeric(logLik(f)), as.numeric(lavaan::logLik(l)))
      if (same_ll && abs(AIC(f) - AIC(l)) > 1) "Different by design" else "Supported"
    },
    "Standardized estimates, modification indices, fitted values, residuals" = function() {
      f <- fit_sem(m, d)
      none <- lc_err(fitted(f)) && lc_err(residuals(f)) && lc_err(stats::resid(f, type = "standardized")) &&
        !"standardizedSolution" %in% getNamespaceExports("medfit")
      if (none) "Unsupported" else "Supported"
    },
    "Nested model comparison" = function() {
      a <- anova(fit_sem(paste0(m, "\na == 0"), d), fit_sem(m, d))
      l <- lavaan::lavTestLRT(lv(paste0(m, "\na == 0")), lv(m))
      if (close(a$`Chisq diff`[2], l$`Chisq diff`[2], 1e-5)) "Supported" else "Unsupported"
    },
    "Mediation effects and the MBCO test" = function() {
      f <- fit_sem(lab, d)
      mb <- mbco_sem(f, "a", "b")
      me <- extract_mediation(f, treatment = "treatment", mediator = "mediator1", outcome = "outcome")
      if (is.numeric(mb$p.value) && inherits(me, "medfit::MediationData")) "Supported" else "Unsupported"
    }
  )
}

# Rows whose status differs from the probe's, as a named character vector (empty when the table is consistent).
lc_mismatch <- function(rows, probes) {
  out <- vapply(rows$feature, function(f) probes[[f]](), character(1))
  bad <- rows$status != out
  stats::setNames(out[bad], rows$feature[bad])
}

test_that("the table's rows are exactly the probed features", {
  rows <- lc_rows(lc_text())
  expect_gt(nrow(rows), 10L)
  expect_setequal(rows$feature, names(lc_probes()))
  expect_true(all(rows$status %in% c("Supported", "Partial", "Different by design", "Unsupported")))
})

test_that("every row's status equals its live probe", {
  skip_if_not_installed("lavaan")
  expect_identical(lc_mismatch(lc_rows(lc_text()), lc_probes()), stats::setNames(character(), character()))
})

test_that("planted defect: editing a status in the article is caught", {
  skip_if_not_installed("lavaan")
  rows <- lc_rows(lc_text())
  edited <- rows
  edited$status[edited$feature == "Nonlinear constraints"] <- "Unsupported"
  edited$status[edited$feature == "Multiple groups"] <- "Supported"
  expect_setequal(names(lc_mismatch(edited, lc_probes())), c("Nonlinear constraints", "Multiple groups"))
})

test_that("the categorical outcomes row points to lavaan (WLSMV)", {
  rows <- lc_rows(lc_text())
  row <- rows[rows$feature == "Categorical outcomes", ]
  expect_match(row$native, "lavaan (WLSMV)", fixed = TRUE)
  expect_identical(row$status, "Unsupported")
})
