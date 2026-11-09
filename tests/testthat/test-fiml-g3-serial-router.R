# FI-G3 slice S1a: the serial router, the Q2 residual-zero refusals, the variant detection (spec 4.1), the serial
# table builder `.sem_fiml_tables_ser()`, the serial source-fit refusal order (F2) and the refusals at fit. No public
# serial fit exists after this slice: every serial syntax is refused at fit with a classed reason until S1b, and the
# serial parser is exercised through the internals. Oracles, each independent of the production kernel: the spec's
# own parameter-count formula, equation-wise lm for complete data, and matched lavaan raw-data FIML (missing = "ml")
# for the table solve with incomplete data. Helpers are prefixed sr_.

sr_zeros <- c("M1 ~~ 0*M2", "M1 ~~ 0*Y", "M2 ~~ 0*Y")
sr_exo <- function(k) c("X", if (k == 1L) "Z" else if (k == 2L) c("Z1", "Z2"))
# model text; `direct`: "free", "zero" (Y ~ 0*X) or "omit"; `variant`: "sat" or "chain"; `zeros`: written residual lines
sr_model <- function(variant = "sat", k = 0L, direct = "free", zeros = sr_zeros) {
  ex <- sr_exo(k)
  z <- ex[-1L]
  m1 <- paste("M1 ~", paste(ex, collapse = " + "))
  m2 <- paste("M2 ~", paste(c("M1", if (variant == "sat") "X", z), collapse = " + "))
  ypaths <- c(
    if (variant == "sat") "M1", "M2",
    switch(direct, free = "X", zero = "0*X", omit = NULL), z
  )
  paste(c(m1, m2, paste("Y ~", paste(ypaths, collapse = " + ")), zeros), collapse = "\n")
}
sr_ram_q <- function(t) .sem_ram(t$vars, t$vars, t$a, t$s, t$m)$q
sr_q <- function(variant, k, direct) {
  (if (variant == "sat") 13L else 11L) + 5L * k + choose(k + 1L, 2L) + as.integer(direct)
}
sr_cells <- expand.grid(variant = c("sat", "chain"), k = 0:2, direct = c(TRUE, FALSE), stringsAsFactors = FALSE)
sr_dir <- function(d) if (d) "free" else "zero"
sr_data <- function(n = 160L, seed = 8811L, mar = TRUE) {
  set.seed(seed)
  d <- data.frame(X = .5 + stats::rnorm(n))
  d$Z <- 1 + .4 * d$X + stats::rnorm(n)
  d$Z1 <- d$Z
  d$Z2 <- -.5 + .3 * d$X - .3 * d$Z1 + stats::rnorm(n)
  d$M1 <- .3 + .8 * d$X + .4 * d$Z1 - .25 * d$Z2 + stats::rnorm(n, sd = .8)
  d$M2 <- -.2 + .6 * d$M1 + .3 * d$X - .3 * d$Z1 + .2 * d$Z2 + stats::rnorm(n, sd = .9)
  d$Y <- .1 + .5 * d$M2 + .3 * d$M1 + .25 * d$X + .3 * d$Z1 - .2 * d$Z2 + stats::rnorm(n, sd = .8)
  if (mar) {
    d[stats::runif(n) < stats::plogis(-1.6 + .5 * d$X), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.5 - .4 * d$X), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 - .4 * d$X), "Y"] <- NA_real_
  }
  d
}
sr_parse <- function(model) tryCatch(.sem_fiml_model(model), error = identity)
sr_fit <- function(model, data = sr_data()) {
  tryCatch(fit_sem(model, data, missing = "fiml", fixed_x = FALSE), error = identity)
}
sr_refused <- function(model, pattern = NULL, at_fit = FALSE) {
  # a plain parser error (duplicate statement, product rule) is classed by the fit wrapper, not by the model parser
  e <- if (at_fit) sr_fit(model, sr_data(mar = FALSE)) else sr_parse(model)
  inherits(e, "medfit_sem_fiml_error") && (is.null(pattern) || grepl(pattern, conditionMessage(e), fixed = FALSE))
}

# ---- router and variant detection -------------------------------------------------------------------------------
test_that("the serial router returns the structure, variant, structural mediators and the parameter map", {
  for (i in seq_len(nrow(sr_cells))) {
    v <- sr_cells$variant[i]
    k <- sr_cells$k[i]
    dr <- sr_cells$direct[i]
    spec <- sr_parse(sr_model(v, k, sr_dir(dr)))
    info <- paste(v, k, dr)
    expect_false(inherits(spec, "error"), info = info)
    expect_identical(spec$structure, "serial", info = info)
    expect_identical(spec$variant, if (v == "sat") "saturated" else "chain", info = info)
    expect_identical(unname(spec$mediators), c("M1", "M2"), info = info)
    expect_identical(names(spec$mediators), c("M1", "M2"), info = info)
    expect_identical(unname(spec$vars), c("X", "M1", "M2", "Y"), info = info)
    expect_identical(names(spec$vars), c("X", "M1", "M2", "Y"), info = info)
    expect_identical(spec$direct, dr, info = info)
    expect_identical(unname(spec$covariate), if (k > 0L) sr_exo(k)[-1L], info = info)
    # the tie check and the parameter map agree with the spec's formula and with the builder's free labels
    expect_identical(spec$conv$ram$q, as.integer(sr_q(v, k, dr)), info = info)
    tb <- .sem_fiml_tables_ser(dr, k, v == "sat")
    free <- function(t) is.na(t$value)
    expect_setequal(names(spec$map), c(tb$a$label[free(tb$a)], tb$s$label, tb$m$label))
    expect_length(spec$map, sr_q(v, k, dr))
    expect_false(anyDuplicated(unname(spec$map)) > 0L)
  }
})

test_that("an omitted direct path at k = 0 is the fixed-zero policy (Q3) for both variants; k >= 1 refuses it", {
  for (v in c("sat", "chain")) {
    a <- sr_parse(sr_model(v, 0L, "omit"))
    b <- sr_parse(sr_model(v, 0L, "zero"))
    expect_false(inherits(a, "error"))
    expect_false(a$direct)
    expect_identical(a$map, b$map)
    for (k in 1:2) {
      # every Y path from an exogenous variable must be written at k >= 1: drop the X path
      z <- sr_exo(k)[-1L]
      lines <- strsplit(sr_model(v, k), "\n")[[1L]]
      lines[3L] <- paste("Y ~", paste(c(if (v == "sat") "M1", "M2", z), collapse = " + "))
      expect_true(sr_refused(paste(lines, collapse = "\n"), "Y path"), info = paste(v, k))
    }
  }
})

test_that("mediators are structural, not in order of appearance, and either order of a residual pair is accepted", {
  m <- paste("B ~ X", "A ~ B + X", "Y ~ B + A + X", "A ~~ 0*B", "B ~~ 0*Y", "Y ~~ 0*A", sep = "\n")
  spec <- sr_parse(m)
  expect_false(inherits(spec, "error"))
  expect_identical(unname(spec$mediators), c("B", "A"))
  expect_identical(unname(spec$vars), c("X", "B", "A", "Y"))
  # the same in the chain
  m <- paste("B ~ X", "A ~ B", "Y ~ A + X", "A ~~ 0*B", "B ~~ 0*Y", "Y ~~ 0*A", sep = "\n")
  spec <- sr_parse(m)
  expect_identical(unname(spec$mediators), c("B", "A"))
  expect_identical(spec$variant, "chain")
})

test_that("the chain's one variable absent from M2 is identified as the treatment, whatever its name or position", {
  m <- paste("M1 ~ W + Z", "M2 ~ M1 + Z", "Y ~ M2 + W + Z", paste(sr_zeros, collapse = "\n"), sep = "\n")
  spec <- sr_parse(m)
  expect_false(inherits(spec, "error"))
  expect_identical(spec$variant, "chain")
  expect_identical(unname(spec$vars[["X"]]), "W")
  expect_identical(unname(spec$covariate), "Z")
  # a Y path fixed at zero belongs to the treatment only
  m0 <- sub("Y ~ M2 \\+ W \\+ Z", "Y ~ M2 + 0*W + Z", m)
  expect_identical(sr_parse(m0)$direct, FALSE)
  m1 <- sub("Y ~ M2 \\+ W \\+ Z", "Y ~ M2 + W + 0*Z", m)
  expect_true(sr_refused(m1, "pure chain|direct path"))
})

test_that("F6: variant detection counts every written term, fixed ones included, and checks the treatment's equations", {
  # (b) a 0* shortcut term is a fixed shortcut, not a chain
  fixed_sc <- paste("M1 ~ X + Z", "M2 ~ M1 + 0*X + Z", "Y ~ M2 + X + Z", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(fixed_sc, "shortcut paths are free or absent"))
  fixed_b1 <- paste("M1 ~ X", "M2 ~ M1 + X", "Y ~ 0*M1 + M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(fixed_b1, "shortcut paths are free or absent"))
  lab_a2 <- paste("M1 ~ X", "M2 ~ M1 + a2*X", "Y ~ M1 + M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(lab_a2, "shortcut paths are free or absent"))
  lab_b1 <- paste("M1 ~ X", "M2 ~ M1 + X", "Y ~ b1*M1 + M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(lab_b1, "shortcut paths are free or absent"))
  # (a) Z omitted from M2 (the absent variable) but with no path to M1: it would silently become the kernel X
  z_no_m1 <- paste("M1 ~ X", "M2 ~ M1 + X", "Y ~ M2 + X + Z", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(z_no_m1, "M1"))
  # the treatment must appear in Y's equation at k >= 1 (Q3)
  x_no_y <- paste("M1 ~ X + Z", "M2 ~ M1 + Z", "Y ~ M2 + Z", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(x_no_y, "Y path"))
  # partial shortcut sets, both ways, and two absent exogenous variables
  x_only <- paste("M1 ~ X", "M2 ~ M1 + X", "Y ~ M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n")
  b1_only <- paste("M1 ~ X", "M2 ~ M1", "Y ~ M1 + M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(x_only, "shortcut"))
  expect_true(sr_refused(b1_only, "shortcut"))
  two_absent <- paste("M1 ~ X + Z1 + Z2", "M2 ~ M1 + Z2", "Y ~ M2 + X + Z1 + Z2", paste(sr_zeros, collapse = "\n"), sep = "\n")
  expect_true(sr_refused(two_absent, "shortcut|absent"))
  # a refused variant is never classified as a chain
  for (m in c(fixed_sc, fixed_b1, x_only, b1_only, two_absent)) {
    e <- sr_parse(m)
    expect_s3_class(e, "medfit_sem_fiml_error")
  }
})

test_that("topology refusals: missing paths, a cycle, a third mediator, three covariates, interactions, stray regressions", {
  r <- sr_zeros
  txt <- function(...) paste(c(..., r), collapse = "\n")
  expect_true(sr_refused(txt("M1 ~ X", "M2 ~ M1 + X", "Y ~ M1 + X"), "topology"))           # no M2 -> Y
  expect_true(sr_refused(txt("M1 ~ Z", "M2 ~ M1 + X", "Y ~ M1 + M2 + X"), "topology|M1"))    # no X -> M1
  expect_true(sr_refused(txt("M1 ~ X", "M2 ~ M1 + M1b", "Y ~ M2 + X"), "topology|FIML"))
  expect_true(sr_refused(txt("M1 ~ X + M2", "M2 ~ M1 + X", "Y ~ M1 + M2 + X"), "topology|cycle"))
  expect_true(sr_refused(txt("M1 ~ X", "M2 ~ M1 + X", "Y ~ M1 + M2 + X", "M1 ~ M2"), "topology|cycle", at_fit = TRUE))
  expect_true(sr_refused(txt("M1 ~ X + Z1 + Z2 + W", "M2 ~ M1 + X + Z1 + Z2 + W", "Y ~ M1 + M2 + X + Z1 + Z2 + W"),
                         "covariates"))
  expect_true(sr_refused(txt("M1 ~ X + X:Z1", "M2 ~ M1 + X", "Y ~ M1 + M2 + X"), "interaction|topology|product", at_fit = TRUE))
})

# ---- Q2: the three residual zeros must be written ----------------------------------------------------------------
test_that("Q2: each omitted single zero is refused, naming exactly that pair, for both variants", {
  pairs <- list("M1 ~~ 0*M2", "M1 ~~ 0*Y", "M2 ~~ 0*Y")
  for (v in c("sat", "chain")) for (k in 0:2) for (i in 1:3) {
    e <- sr_parse(sr_model(v, k, "free", zeros = unlist(pairs[-i])))
    info <- paste(v, k, "omit", pairs[[i]])
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), pairs[[i]], fixed = TRUE, info = info)
    # and none of the written pairs is named as missing
    for (j in setdiff(1:3, i)) expect_false(grepl(pairs[[j]], conditionMessage(e), fixed = TRUE), info = info)
  }
})

test_that("Q2: two or three omitted zeros give one message listing every missing pair", {
  pairs <- c("M1 ~~ 0*M2", "M1 ~~ 0*Y", "M2 ~~ 0*Y")
  for (v in c("sat", "chain")) {
    for (omit in list(c(1, 2), c(1, 3), c(2, 3), 1:3)) {
      e <- sr_parse(sr_model(v, 0L, "free", zeros = if (length(omit) < 3L) pairs[-omit] else character()))
      expect_s3_class(e, "medfit_sem_fiml_error")
      for (j in omit) expect_match(conditionMessage(e), pairs[j], fixed = TRUE)
      for (j in setdiff(1:3, omit)) expect_false(grepl(pairs[j], conditionMessage(e), fixed = TRUE))
    }
  }
})

test_that("Q2: a pair written free, labeled, fixed nonzero, duplicated or tied to an exogenous variable is refused", {
  base <- sr_zeros
  bad <- list(
    free_m1m2 = list(c("M1 ~~ M2", base[2:3]), "correlated"),
    free_m1y = list(c(base[1], "M1 ~~ Y", base[3]), "correlated"),
    free_m2y = list(c(base[1:2], "M2 ~~ Y"), "correlated"),
    labeled = list(c("M1 ~~ c*M2", base[2:3]), "correlated"),
    nonzero = list(c("M1 ~~ 0.3*M2", base[2:3]), "correlated"),
    nonzero_y = list(c(base[1], "M1 ~~ 0.2*Y", base[3]), "correlated"),
    dup_same = list(c(base, "M1 ~~ 0*M2"), "specified more than once"),
    dup_reversed = list(c(base, "M2 ~~ 0*M1"), "specified more than once"),
    exo_endo = list(c(base, "X ~~ 0*M1"), "topology"),
    exo_y = list(c(base, "Y ~~ 0*X"), "topology")
  )
  for (v in c("sat", "chain")) for (nm in names(bad)) {
    e <- if (grepl("^dup", nm)) {
      sr_fit(sr_model(v, 0L, "free", zeros = bad[[nm]][[1L]]), sr_data(mar = FALSE))
    } else {
      sr_parse(sr_model(v, 0L, "free", zeros = bad[[nm]][[1L]]))
    }
    info <- paste(v, nm)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), bad[[nm]][[2L]], info = info)
  }
  # either order of a written pair is the same accepted pair
  rev <- c("M2 ~~ 0*M1", "Y ~~ 0*M1", "Y ~~ 0*M2")
  for (v in c("sat", "chain")) expect_false(inherits(sr_parse(sr_model(v, 1L, "free", zeros = rev)), "error"))
})

test_that("Q2 at fit: the refusals are classed medfit_sem_fiml_error at stage input", {
  d <- sr_data()
  for (v in c("sat", "chain")) {
    e <- sr_fit(sr_model(v, 0L, "free", zeros = sr_zeros[2:3]), d)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input")
    expect_match(conditionMessage(e), "M1 ~~ 0*M2", fixed = TRUE)
  }
})

test_that("lavaan 0.7-3 frees no residual covariance among the observed serial variables (pins the installed version)", {
  skip_if_not_installed("lavaan")
  d <- sr_data(mar = FALSE)
  for (v in c("sat", "chain")) for (mt in c("listwise", "ml")) {
    fit <- lavaan::sem(sub("\n.*~~.*", "", sr_model(v, 0L, "free", zeros = character())), d, missing = mt, fixed.x = FALSE)
    pe <- lavaan::parameterEstimates(fit)
    expect_identical(sum(pe$op == "~~" & pe$lhs != pe$rhs), 0L, info = paste(v, mt))
  }
})

# ---- the table builder -------------------------------------------------------------------------------------------
test_that(".sem_fiml_tables_ser has the spec's parameter counts for both shortcut states", {
  for (i in seq_len(nrow(sr_cells))) {
    v <- sr_cells$variant[i]
    k <- sr_cells$k[i]
    dr <- sr_cells$direct[i]
    t <- .sem_fiml_tables_ser(dr, k, v == "sat")
    info <- paste(v, k, dr)
    ram <- .sem_ram(t$vars, t$vars, t$a, t$s, t$m)
    expect_identical(ram$q, as.integer(sr_q(v, k, dr)), info = info)
    expect_identical(t$vars, c("X", if (k == 1L) "Z" else if (k == 2L) c("Z1", "Z2"), "M1", "M2", "Y"), info = info)
    expect_identical(names(t), c("vars", "a", "s", "m"))
    expect_false(anyDuplicated(c(t$a$label, t$s$label, t$m$label)) > 0L, info = info)
    lay <- .sem_fiml_layout(t) # free labels are unique and non-empty
    expect_identical(nrow(lay$paths) + nrow(lay$variances) + nrow(lay$covariances) + nrow(lay$intercepts),
                     as.integer(sr_q(v, k, dr)), info = info)
    expect_identical(nrow(lay$covariances), as.integer(choose(k + 1L, 2L)), info = info) # no free residual covariance
  }
  # the spec's table: free direct 14/20/27 saturated, 12/18/25 chain; fixed 13/19/26 and 11/17/24
  expect_identical(vapply(0:2, function(k) sr_ram_q(.sem_fiml_tables_ser(TRUE, k, TRUE)), 0L), c(14L, 20L, 27L))
  expect_identical(vapply(0:2, function(k) sr_ram_q(.sem_fiml_tables_ser(FALSE, k, TRUE)), 0L), c(13L, 19L, 26L))
  expect_identical(vapply(0:2, function(k) sr_ram_q(.sem_fiml_tables_ser(TRUE, k, FALSE)), 0L), c(12L, 18L, 25L))
  expect_identical(vapply(0:2, function(k) sr_ram_q(.sem_fiml_tables_ser(FALSE, k, FALSE)), 0L), c(11L, 17L, 24L))
})
test_that("the shortcuts flag adds exactly the M2 <- X and Y <- M1 rows, and the chain has no fixed-zero row for them", {
  for (k in 0:2) for (d in c(TRUE, FALSE)) {
    s <- .sem_fiml_tables_ser(d, k, TRUE)
    ch <- .sem_fiml_tables_ser(d, k, FALSE)
    key <- function(t) paste(t$a$row, t$a$col)
    expect_setequal(setdiff(key(s), key(ch)), c("M2 X", "Y M1"))
    expect_true(all(setdiff(key(ch), key(s)) == character()))
    expect_identical(sort(setdiff(s$a$label, ch$a$label)), c("a2", "b1"))
    expect_false(any(c("a2", "b1") %in% ch$a$label))
    # the chain has no value-0 row for an absent shortcut; the only fixed row in either variant is cp (when direct = FALSE)
    expect_identical(sum(!is.na(s$a$value)), as.integer(!d))
    expect_identical(sum(!is.na(ch$a$value)), as.integer(!d))
    # the exogenous covariance block is present for k >= 1
    expect_identical(sum(s$s$row != s$s$col), as.integer(choose(k + 1L, 2L)))
    # mediator structure: M2 <- M1 present in both, covariates predict every endogenous variable
    expect_true("M2 M1" %in% key(ch))
    for (zz in sr_exo(k)[-1L]) expect_true(all(paste(c("M1", "M2", "Y"), zz) %in% key(ch)))
  }
})

test_that(".sem_fiml_tables_ser refuses malformed arguments and leaves the earlier builders alone", {
  expect_error(.sem_fiml_tables_ser(TRUE, 3L, TRUE), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_ser(TRUE, -1L, TRUE), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_ser(TRUE, 0L, NA), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_ser(NA, 0L, TRUE), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_ser(c(TRUE, FALSE), 0L, TRUE), class = "medfit_sem_fiml_error")
  # the existing builder for the four-variable parallel and the pure-chain internal table are untouched in shape
  expect_identical(.sem_fiml_tables_med(2L, TRUE)$a$label, c("a1", "a2", "b1", "b2", "cp"))
})

# Oracle 1, complete data: the serial table fit is equation-wise ML OLS for every equation (the chain's likelihood
# factors over equations for any regressor set, so equation-wise OLS is exact despite the overidentification).
sr_solve <- function(d, tables) {
  z <- as.matrix(d[, tables$vars])
  .sem_fiml_solve(.sem_fiml_prepare_core(z, tables))
}
test_that("complete data: the serial tables reproduce equation-wise ML OLS, both variants, k = 0 to 2, both direct policies", {
  for (i in seq_len(nrow(sr_cells))) {
    v <- sr_cells$variant[i]
    k <- sr_cells$k[i]
    dr <- sr_cells$direct[i]
    d <- sr_data(mar = FALSE)
    tb <- .sem_fiml_tables_ser(dr, k, v == "sat")
    est <- sr_solve(d, tb)$estimate
    n <- nrow(d)
    for (resp in c("M1", "M2", "Y")) {
      rows <- tb$a[tb$a$row == resp, ]
      fit <- stats::lm(stats::reformulate(rows$col[is.na(rows$value)], resp), d)
      for (j in which(is.na(rows$value))) {
        expect_equal(est[[rows$label[j]]], stats::coef(fit)[[rows$col[j]]], tolerance = 1e-6,
                     info = paste(v, k, dr, resp, rows$col[j]))
      }
      vlab <- tb$s$label[tb$s$row == resp & tb$s$col == resp]
      expect_equal(est[[vlab]], sum(stats::resid(fit)^2) / n, tolerance = 1e-6, info = paste(v, k, dr, resp))
    }
  }
})

# Oracle 2, incomplete data: matched lavaan raw-data FIML (the saturated tables are the just-identified model).
sr_key <- function(tb) {
  p <- tb$a[is.na(tb$a$value), ]
  kk <- c(paste(p$row, "~", p$col), paste(tb$s$row, "~~", tb$s$col), paste(tb$m$row, "~1"))
  stats::setNames(c(p$label, tb$s$label, tb$m$label), kk)
}
test_that("incomplete data: the serial table solve agrees with lavaan FIML estimates, both variants", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  for (v in c("sat", "chain")) for (k in c(0L, 1L, 2L)) for (dr in c(TRUE, FALSE)) {
    d <- sr_data(seed = 3300L + k)
    tb <- .sem_fiml_tables_ser(dr, k, v == "sat")
    est <- sr_solve(d, tb)$estimate
    mod <- paste(c(sr_model(v, k, sr_dir(dr), zeros = sr_zeros)), collapse = "\n")
    ref <- lavaan::sem(mod, d, missing = "ml", fixed.x = FALSE, information = "observed")
    pe <- lavaan::parameterEstimates(ref)
    pe <- pe[!(pe$op == "~~" & pe$lhs != pe$rhs & pe$lhs %in% c("M1", "M2", "Y") & pe$rhs %in% c("M1", "M2", "Y")), ]
    key <- sr_key(tb)
    # lavaan names an exogenous covariance in either order
    pk <- ifelse(pe$op == "~1", paste(pe$lhs, "~1"), paste(pe$lhs, pe$op, pe$rhs))
    swap <- ifelse(pe$op == "~~", paste(pe$rhs, pe$op, pe$lhs), pk)
    found <- 0L
    for (j in seq_along(key)) {
      row <- which(pk == names(key)[j] | swap == names(key)[j])
      if (!length(row)) next
      found <- found + 1L
      expect_equal(est[[key[[j]]]], pe$est[row[1L]], tolerance = 1e-4, info = paste(v, k, dr, names(key)[j]))
    }
    expect_identical(found, sum(is.na(c(tb$a$value, tb$s$value, tb$m$value))),
                     info = paste("every free table entry matched a lavaan row:", v, k, dr))
  }
})

# ---- every serial syntax is refused at fit until S1b -------------------------------------------------------------
test_that("every serial syntax, in every policy cell, is refused at fit with the not-yet-available reason", {
  d <- sr_data()
  for (i in seq_len(nrow(sr_cells))) {
    v <- sr_cells$variant[i]
    k <- sr_cells$k[i]
    dr <- sr_cells$direct[i]
    e <- sr_fit(sr_model(v, k, sr_dir(dr)), d)
    info <- paste(v, k, dr)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = info)
    expect_match(conditionMessage(e), "serial FIML is not yet available", info = info)
  }
  for (v in c("sat", "chain")) {
    e <- sr_fit(sr_model(v, 0L, "omit"), d)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), "not yet available")
  }
})

# ---- source fit: the serial class is raised before the covariate and parallel classes (F2) ------------------------
sr_open_fit <- function(variant, k, data = sr_data(seed = 5100L + k)) {
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE, .env = parent.frame())
  fit_sem(sr_model(variant, k), data, missing = "fiml", fixed_x = FALSE)
}
test_that("with the serial refusal opened, a serial source fit is built from the serial tables and tagged serial", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  for (v in c("sat", "chain")) for (k in 0:2) {
    f <- sr_open_fit(v, k)
    expect_s7_class(f, SEMFit)
    ll <- f@internals$likelihood
    expect_identical(ll$structure, "serial")
    expect_identical(ll$variant, if (v == "sat") "saturated" else "chain")
    expect_identical(unname(ll$mediators), c("M1", "M2"))
    expect_length(f@theta, sr_q(v, k, TRUE))
    expect_true(.sem_fiml_is(f))
  }
})

test_that("serial source-fit inference is refused with the serial class before any RNG draw or refit, k = 0, 1, 2", {
  fx_skip_covr()
  refit_calls <- 0L
  fits <- list()
  for (v in c("sat", "chain")) for (k in 0:2) fits[[paste(v, k)]] <- sr_open_fit(v, k)
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  # guard closed: the stage-0 guard answers first (R4)
  for (f in fits) for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  for (nm in names(fits)) for (m in c("parametric", "nonparametric")) {
    set.seed(99L)
    before <- .Random.seed
    e <- tryCatch(bootstrap_mediation(source_fit = fits[[nm]], effect = "nie", method = m, n_boot = 3L), error = identity)
    expect_s3_class(e, "medfit_error_fiml_serial_source_fit")
    expect_false(inherits(e, "medfit_error_fiml_parallel_source_fit"), info = nm)
    expect_false(inherits(e, "medfit_error_fiml_covariate_source_fit"), info = nm)
    expect_identical(.Random.seed, before, info = paste(nm, m))
  }
  expect_identical(refit_calls, 0L)
})

test_that("the existing covariate and parallel source-fit refusals keep their classes for non-serial fits", {
  fx_skip_covr()
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  d <- sr_data(mar = FALSE)
  par <- fit_sem("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2", d, missing = "fiml", fixed_x = FALSE)
  cov <- fit_sem("M1 ~ X + Z\nY ~ M1 + X + Z", d, missing = "fiml", fixed_x = FALSE)
  expect_error(bootstrap_mediation(source_fit = par, effect = "nie", method = "parametric", n_boot = 3L),
               class = "medfit_error_fiml_parallel_source_fit")
  expect_error(bootstrap_mediation(source_fit = cov, effect = "nie", method = "parametric", n_boot = 3L),
               class = "medfit_error_fiml_covariate_source_fit")
})

test_that("a serial fit cannot be extracted yet: classed extract refusal, not the parallel extractor", {
  fx_skip_covr()
  f <- sr_open_fit("sat", 0L)
  e <- tryCatch(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")), error = identity)
  expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
  for (v in c("sat", "chain")) {
    g <- sr_open_fit(v, 1L)
    expect_s3_class(tryCatch(extract_mediation(g, treatment = "X", mediator = c("M1", "M2")), error = identity),
                    "medfit_error_fiml_extract_unsupported")
  }
})

# ---- planted defects, each with a positive control ---------------------------------------------------------------
# A defect must fail at least one assertion of the battery the unmutated code passes.
sr_battery <- function() {
  one <- function(x) isTRUE(x)
  c(
    router = one(sr_refused(sr_model("sat", 0L, "free", zeros = sr_zeros[2:3]), "M1 ~~ 0\\*M2")),
    two_missing = one(sr_refused(sr_model("chain", 0L, "free", zeros = sr_zeros[3]), "M1 ~~ 0\\*M2.*M1 ~~ 0\\*Y")),
    fixed_shortcut = one(sr_refused(
      paste("M1 ~ X + Z", "M2 ~ M1 + 0*X + Z", "Y ~ M2 + X + Z", paste(sr_zeros, collapse = "\n"), sep = "\n"),
      "shortcut paths are free or absent"
    )),
    sat_ok = one(identical(sr_parse(sr_model("sat", 1L))$variant, "saturated")),
    chain_ok = one(identical(sr_parse(sr_model("chain", 1L))$variant, "chain")),
    q_sat = one(identical(sr_parse(sr_model("sat", 2L, "zero"))$conv$ram$q, 26L)),
    q_chain = one(identical(sr_parse(sr_model("chain", 2L, "free"))$conv$ram$q, 25L)),
    partial = one(sr_refused(
      paste("M1 ~ X", "M2 ~ M1 + X", "Y ~ M2 + X", paste(sr_zeros, collapse = "\n"), sep = "\n"), "shortcut"
    ))
  )
}
test_that("planted defects in the parser and builder are caught by the battery (positive control first)", {
  expect_true(all(sr_battery()))
  orig <- .sem_fiml_tables_ser
  # D17: the shortcuts flag inverted
  inverted <- function(direct, k, shortcuts) orig(direct, k, !shortcuts)
  expect_false(all(testthat::with_mocked_bindings(sr_battery(), .sem_fiml_tables_ser = inverted)))
  # D18: the chain with the shortcuts accidentally freed (saturated rows under a chain flag)
  freed <- function(direct, k, shortcuts) orig(direct, k, TRUE)
  expect_false(all(testthat::with_mocked_bindings(sr_battery(), .sem_fiml_tables_ser = freed)))
  # D19: the saturated variant with b1 wrongly dropped (a hidden chain)
  hidden <- function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    t$a <- t$a[t$a$label != "b1", ]
    t
  }
  expect_false(all(testthat::with_mocked_bindings(sr_battery(), .sem_fiml_tables_ser = hidden)))
  # D16: the exogenous covariance block dropped from the tables
  nocov <- function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    t$s <- t$s[t$s$row == t$s$col, ]
    t
  }
  expect_false(all(testthat::with_mocked_bindings(sr_battery(), .sem_fiml_tables_ser = nocov)))
})
test_that("planted parser defects: only the first missing zero reported, 0* terms ignored, router off", {
  expect_true(all(sr_battery()))
  # D-Q2: a parser that reports only the first missing pair fails the two-omitted case
  orig <- .sem_fiml_ser_missing_zeros
  first_only <- function(...) utils::head(orig(...), 1L)
  r <- testthat::with_mocked_bindings(sr_battery(), .sem_fiml_ser_missing_zeros = first_only)
  expect_false(all(r))
  expect_false(r[["two_missing"]])
  # D27: variant detection that ignores fixed (0*) terms classes `M2 ~ M1 + 0*X + Z` as a chain
  w_orig <- .sem_fiml_ser_written
  free_only <- function(tab, keys, lhs, rhs) paste(lhs, "~", rhs) %in% keys[is.na(tab$fixed)]
  r <- testthat::with_mocked_bindings(sr_battery(), .sem_fiml_ser_written = free_only)
  expect_false(all(r))
  expect_identical(w_orig(data.frame(fixed = 0), "M2 ~ X", "M2", "X"), TRUE)
  # router off: a serial syntax falls through to the parallel parser's parallel-flavored refusal
  r <- testthat::with_mocked_bindings(sr_battery(), .sem_fiml_ser_detect = function(...) FALSE)
  expect_false(all(r))
})

test_that("planted defects in the source-fit order and the fit entry are caught (positive control first)", {
  fx_skip_covr()
  fits <- list(sat0 = sr_open_fit("sat", 0L), chain1 = sr_open_fit("chain", 1L), sat2 = sr_open_fit("sat", 2L))
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  classes <- function() {
    vapply(fits, function(f) {
      e <- tryCatch(bootstrap_mediation(source_fit = f, effect = "nie", method = "parametric", n_boot = 3L),
                    error = identity)
      class(e)[1L]
    }, character(1))
  }
  expect_true(all(classes() == "medfit_error_fiml_serial_source_fit"))
  # D15: the serial source fit is not refused (check removed): the parallel and covariate classes answer instead
  gone <- sem_mutate(.bootstrap_fiml, "identical(spec$structure, \"serial\")", "FALSE")
  got <- testthat::with_mocked_bindings(classes(), .bootstrap_fiml = gone)
  expect_false(all(got == "medfit_error_fiml_serial_source_fit"))
  # D17: the serial check placed after the covariate and parallel branches never fires
  late <- sem_mutate(
    .bootstrap_fiml, "identical(spec$structure, \"serial\")",
    "identical(spec$structure, \"serial\") && is.null(spec$covariate) && is.null(spec$mediators)"
  )
  got <- testthat::with_mocked_bindings(classes(), .bootstrap_fiml = late)
  expect_false(all(got == "medfit_error_fiml_serial_source_fit"))
  expect_identical(unname(got[["chain1"]]), "medfit_error_fiml_covariate_source_fit")
  expect_identical(unname(got[["sat0"]]), "medfit_error_fiml_parallel_source_fit")
})

test_that("planted defect D8: a serial fit built with the parallel tables is caught", {
  fx_skip_covr()
  built <- function() {
    f <- tryCatch(sr_open_fit("sat", 1L), error = identity)
    !inherits(f, "error") && identical(f@internals$likelihood$structure, "serial") && length(f@theta) == 20L
  }
  expect_true(built())
  # the parallel tables used for the serial specification: the free labels no longer match the serial parameter map
  fn <- sem_mutate(
    .sem_fiml_syntax, "tables <- .sem_fiml_tables_ser(spec$direct, length(spec$covariate), identical(spec$variant, \"saturated\"))",
    "tables <- .sem_fiml_tables_med(2L, spec$direct, FALSE, length(spec$covariate))"
  )
  expect_false(testthat::with_mocked_bindings(built(), .sem_fiml_syntax = fn))
})
