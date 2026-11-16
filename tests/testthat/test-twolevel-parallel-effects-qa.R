# Independent QA oracle for TwoLevelParallelMediationData effects (IG5 T3).
# Three mediators and a covariate, so the cross-mediator covariance in @vcov is large enough that dropping it moves the
# total SE well past 1e-6. Every effect is checked against a lavaan := refit of the same model, which shares no code
# with medfit's gradient builder; the D5 fixtures equate a and b (by == rows) or a alone across levels.

skip_if_not_installed("lavaan")
skip_on_cran()

qa_sim <- function(seed = 202) {
  set.seed(seed)
  n_cl <- 150
  id <- rep(seq_len(n_cl), each = 6)
  xw <- stats::rnorm(n_cl * 6)
  xb <- stats::rnorm(n_cl)[id]
  w <- stats::rnorm(n_cl)[id] * 0.8 + stats::rnorm(n_cl * 6)
  d <- data.frame(id = id, X = xw + xb, W = w)
  y <- 0.2 * xw + 0.15 * xb + 0.3 * w + stats::rnorm(n_cl)[id] * 0.5 + stats::rnorm(n_cl * 6)
  pars <- rbind(aw = c(0.5, 0.3, 0.4), ab = c(0.4, 0.5, 0.2), bw = c(0.4, 0.3, 0.2), bb = c(0.6, 0.2, 0.5))
  for (j in 1:3) {
    m <- pars["aw", j] * xw + pars["ab", j] * xb + 0.2 * w + stats::rnorm(n_cl)[id] * 0.6 + stats::rnorm(n_cl * 6)
    y <- y + pars["bw", j] * (m - stats::ave(m, id)) + pars["bb", j] * stats::ave(m, id)
    d[[paste0("M", j)]] <- m
  }
  d$Y <- y
  d
}

# lavaan syntax: labels aJ/bJ/cp within, aJB/bJB/cpB between; `eq` adds `pJ == pJB` rows; `defs` adds the := oracle.
qa_model <- function(eq = character(), defs = FALSE) {
  block <- function(s) {
    c(sprintf("M%d ~ a%d%s*X + W", 1:3, 1:3, s),
      sprintf("Y ~ %s + cp%s*X + W", paste(sprintf("b%d%s*M%d", 1:3, s, 1:3), collapse = " + "), s))
  }
  out <- c("level: 1", block(""), "level: 2", block("B"), sprintf("%s == %sB", eq, eq))
  if (defs) {
    spec <- function(j, s) sprintf("a%d%s*b%d%s", j, s, j, s)
    tot <- function(s) paste0("(", paste(vapply(1:3, spec, "", s = s), collapse = " + "), ")")
    for (lev in c("within", "between")) {
      s <- if (lev == "within") "" else "B"
      out <- c(out, sprintf("nie_M%d_%s := %s", 1:3, lev, vapply(1:3, spec, "", s = s)),
               sprintf("nie_%s := %s", lev, tot(s)), sprintf("nde_%s := cp%s", lev, s),
               sprintf("te_%s := %s + cp%s", lev, tot(s), s),
               sprintf("pm_%s := %s / (%s + cp%s)", lev, tot(s), tot(s), s))
    }
    out <- c(out, sprintf("nie_M%d_contrast := %s - %s", 1:3, vapply(1:3, spec, "", s = ""),
                          vapply(1:3, spec, "", s = "B")),
             sprintf("nie_contrast := %s - %s", tot(""), tot("B")))
  }
  paste(out, collapse = "\n")
}

qa_case <- function(eq = character()) {
  d <- qa_sim()
  fit <- suppressWarnings(lavaan::sem(qa_model(eq), data = d, cluster = "id"))
  ref <- suppressWarnings(lavaan::sem(qa_model(eq, defs = TRUE), data = d, cluster = "id"))
  pe <- lavaan::parameterEstimates(ref)
  pe <- pe[pe$op == ":=", c("lhs", "est", "se")]
  td <- suppressWarnings(extract_mediation(fit, treatment = "X", mediator = c("M1", "M2", "M3"), outcome = "Y"))
  list(td = td, pe = pe, ti = suppressWarnings(tidy(td, type = "effects")))
}

qa_check <- function(case, na_terms = character()) {
  ti <- case$ti
  pe <- case$pe
  expect_setequal(ti$term, pe$lhs)
  expect_identical(nrow(ti), nrow(pe))
  na_rows <- ti$term[is.na(ti$estimate)]
  expect_setequal(na_rows, na_terms)
  expect_setequal(ti$term[is.na(ti$std_error)], na_terms)
  live <- setdiff(pe$lhs, na_terms)
  i <- match(live, ti$term)
  o <- match(live, pe$lhs)
  expect_lt(max(abs(ti$estimate[i] - pe$est[o])), 1e-6)
  expect_lt(max(abs(ti$std_error[i] - pe$se[o])), 1e-6)
  ref <- stats::setNames(pe$est, pe$lhs)
  for (lev in c("within", "between")) {
    sp <- suppressWarnings(nie(case$td, level = lev, type = "specific"))
    expect_named(sp, c("M1", "M2", "M3"))
    expect_equal(unclass(sp), ref[paste0("nie_M", 1:3, "_", lev)], tolerance = 1e-6, ignore_attr = TRUE)
  }
}

test_that("QA: three mediators and a covariate match lavaan := for every effect and SE", {
  qa_check(qa_case())
})

test_that("QA: the cross-mediator block of @vcov moves the total SE by more than 1e-4 here", {
  case <- qa_case()
  bad <- case$td
  v <- bad@vcov
  med <- sub("^(a|b)_(M[0-9])_.*$", "\\2", rownames(v))
  med[!grepl("^(a|b)_", rownames(v))] <- ""
  v[outer(med, med, "!=") & outer(med != "", med != "", "&")] <- 0
  bad@vcov <- v
  ti <- suppressWarnings(tidy(bad, type = "effects"))
  ref <- case$pe$se[case$pe$lhs == "nie_within"]
  expect_gt(abs(ti$std_error[ti$term == "nie_within"] - ref), 1e-4)
})

test_that("QA: a_M2 and b_M2 equated by == rows: only nie_M2_contrast is NA, the rest match lavaan :=", {
  case <- qa_case(eq = c("a2", "b2"))
  expect_setequal(case$td@cross_level_equal, c("a_M2", "b_M2"))
  qa_check(case, na_terms = "nie_M2_contrast")
})

test_that("QA: only a_M3 equated: every contrast is estimable and matches lavaan :=", {
  case <- qa_case(eq = "a3")
  expect_identical(case$td@cross_level_equal, "a_M3")
  qa_check(case)
})

test_that("QA: all three mediators equated: every contrast is NA, levels still match lavaan :=", {
  case <- qa_case(eq = c("a1", "b1", "a2", "b2", "a3", "b3"))
  qa_check(case, na_terms = c("nie_M1_contrast", "nie_M2_contrast", "nie_M3_contrast", "nie_contrast"))
})
