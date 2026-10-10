# Native SEM engine: model completion and converters (S11).
# Oracles: lavaan::lavaanify(model, auto = TRUE, fixed.x = FALSE) for the row
# set, lavaan's implied covariance at lavaan's own estimates for the RAM, and a
# lavaan fixed.x = TRUE versus FALSE identity for Q3. Planted defect: a
# completion that skips the marker-loading rule must be caught before
# optimization.

sem_models_oracle <- c(
  simple = "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1",
  serial = "mediator1 ~ treatment\nmediator2 ~ mediator1 + treatment\noutcome ~ mediator2 + mediator1 + treatment",
  parallel = paste(
    "mediator1 ~ treatment", "mediator2 ~ treatment", "mediator1 ~~ mediator2",
    "outcome ~ mediator1 + mediator2 + treatment", sep = "\n"
  ),
  latent = "eta =~ mediator1 + mediator2 + mediator3\neta ~ a*treatment\noutcome ~ b*eta + cp*treatment",
  equal_labels = "mediator1 ~ a*treatment\noutcome ~ a*mediator1 + treatment",
  two_outcomes = "mediator1 ~ treatment\noutcome ~ treatment\noutcome_int ~ treatment",
  covariates = "outcome ~ treatment + covariate1 + covariate2\nmediator1 ~ treatment + covariate1",
  fixed_marker = "F =~ 0.5*mediator1 + mediator2 + mediator3\noutcome ~ F + treatment",
  labeled_marker = "F =~ l1*mediator1 + l2*mediator2 + mediator3\noutcome ~ b*F",
  single_indicator = "F =~ mediator1\noutcome ~ F + treatment",
  user_exo_cov = "outcome ~ treatment + covariate1 + covariate2\ncovariate1 ~~ covariate2",
  user_variance = "outcome ~ treatment + covariate1\nmediator1 ~~ 2*mediator1\nmediator1 ~ treatment"
)

# lavaan's table as comparable keys: constraint rows dropped, covariances put in
# a canonical order, fixed values and labels included.
sem_row_keys <- function(lhs, op, rhs, fixed, label) {
  swap <- op == "~~" & lhs > rhs
  paste0(
    ifelse(swap, rhs, lhs), op, ifelse(swap, lhs, rhs), ifelse(is.na(fixed), "", paste0("=", fixed)),
    ifelse(nzchar(label), paste0("[", label, "]"), "")
  )
}

sem_oracle_keys <- function(model) {
  lv <- lavaan::lavaanify(model, auto = TRUE, fixed.x = FALSE)
  lv <- lv[!lv$op %in% c("==", ":=", "<", ">"), ]
  list(
    keys = sort(sem_row_keys(lv$lhs, lv$op, lv$rhs, ifelse(lv$free == 0, lv$ustart, NA), lv$label)),
    free = lv
  )
}

sem_our_keys <- function(tab) sort(sem_row_keys(tab$lhs, tab$op, tab$rhs, tab$fixed, tab$label))

test_that("completion gives lavaan's row set on every spec model", {
  skip_if_not_installed("lavaan")
  for (nm in names(sem_models_oracle)) {
    tab <- .sem_complete(.sem_parse(sem_models_oracle[[nm]])$parameters)
    expect_identical(sem_our_keys(tab), sem_oracle_keys(sem_models_oracle[[nm]])$keys, info = nm)
  }
})

test_that("completion gives lavaan's row set on 200 random models", {
  skip_if_not_installed("lavaan")
  gen <- function(seed) {
    set.seed(seed)
    nl <- sample(0:2, 1)
    lines <- character()
    used <- 0
    lat <- character()
    for (k in seq_len(nl)) {
      ni <- sample(1:3, 1)
      lines <- c(lines, paste0("F", k, " =~ ", paste0("y", used + seq_len(ni), collapse = " + ")))
      used <- used + ni
      lat <- c(lat, paste0("F", k))
    }
    vars <- c("x1", "x2", lat, "m", "w", "z")
    tg <- setdiff(vars, c("x1", "x2"))
    tg <- tg[stats::runif(length(tg)) < 0.8 | tg == "m"]
    for (t in tg) {
      earlier <- vars[seq_len(match(t, vars) - 1L)]
      pr <- earlier[stats::runif(length(earlier)) < 0.6]
      if (!length(pr)) pr <- sample(earlier, 1)
      lines <- c(lines, paste0(t, " ~ ", paste(pr, collapse = " + ")))
    }
    if (stats::runif(1) < 0.3) lines <- c(lines, "m ~~ 0.5*w")
    if (stats::runif(1) < 0.2) lines <- c(lines, "x1 ~~ x2")
    if (nl == 2 && stats::runif(1) < 0.3) lines <- c(lines, "F1 ~~ F2")
    if (used >= 2 && stats::runif(1) < 0.25) lines <- c(lines, "y1 ~~ y2")
    if (stats::runif(1) < 0.2) lines <- c(lines, "w ~~ w")
    paste(lines, collapse = "\n")
  }
  bad <- character()
  for (sd in seq_len(200)) {
    m <- gen(sd)
    tab <- .sem_complete(.sem_parse(m)$parameters)
    if (!identical(sem_our_keys(tab), sem_oracle_keys(m)$keys)) bad <- c(bad, m)
  }
  expect_length(bad, 0L)
})

test_that("free-parameter numbering matches lavaan after collapsing equal labels", {
  skip_if_not_installed("lavaan")
  for (nm in names(sem_models_oracle)) {
    m <- sem_models_oracle[[nm]]
    tab <- .sem_complete(.sem_parse(m)$parameters)
    pt <- .sem_to_partable(tab)
    lv <- sem_oracle_keys(m)$free
    key_lv <- sem_row_keys(lv$lhs, lv$op, lv$rhs, NA, "")
    key_us <- sem_row_keys(pt$lhs, pt$op, pt$rhs, NA, "")
    # the same rows are free
    expect_identical(sort(key_us[pt$free > 0]), sort(key_lv[lv$free > 0]), info = nm)
    # lavaan numbers every free row and repeats a shared label; collapsing gives our count
    lab <- lv$label[lv$free > 0]
    q_lavaan <- sum(!nzchar(lab)) + length(unique(lab[nzchar(lab)]))
    expect_identical(max(pt$free), q_lavaan, info = nm)
    # one number per label, one per unlabeled free row, consecutive from 1
    expect_identical(sort(unique(pt$free[pt$free > 0])), seq_len(q_lavaan), info = nm)
    shared <- pt$label[pt$free > 0 & nzchar(pt$label)]
    for (l in unique(shared)) {
      expect_length(unique(pt$free[pt$label == l]), 1L)
    }
  }
  # the latent model reproduces lavaan's own numbering row for row
  pt <- .sem_to_partable(.sem_complete(.sem_parse(sem_models_oracle[["latent"]])$parameters))
  expect_identical(pt$free, c(0L, 1:11))
})

test_that("the table layout is lavaan's, with level, block and group reserved as NA", {
  pt <- .sem_to_partable(.sem_complete(.sem_parse("Y ~ a*X + Z\nM ~ X")$parameters))
  expect_named(pt, c("id", "lhs", "op", "rhs", "user", "level", "block", "group", "free", "ustart", "exo", "label",
                     "lower", "upper"))
  expect_true(all(is.na(pt$level)) && all(is.na(pt$block)) && all(is.na(pt$group)))
  expect_identical(pt$user[1:3], c(1L, 1L, 1L))
  expect_true(all(pt$user[-(1:3)] == 0L))
})

test_that("completion details", {
  tab <- function(m) .sem_complete(.sem_parse(m)$parameters)
  # marker loading: first indicator fixed to 1 unless the user fixed it; the label survives
  t1 <- tab("F =~ l1*y1 + y2\nz ~ F")
  expect_equal(t1$fixed[t1$op == "=~"], c(1, NA))
  expect_identical(t1$label[t1$op == "=~"], c("l1", ""))
  t2 <- tab("F =~ 0.5*y1 + y2\nz ~ F")
  expect_equal(t2$fixed[t2$op == "=~"], c(0.5, NA))
  # a user variance is kept, not duplicated
  t3 <- tab("y ~ x\ny ~~ 2*y")
  expect_identical(sum(t3$lhs == "y" & t3$op == "~~"), 1L)
  expect_equal(t3$fixed[t3$lhs == "y" & t3$op == "~~"], 2)
  # a single indicator has its residual variance fixed to zero
  t4 <- tab("F =~ y1\nz ~ F")
  expect_equal(t4$fixed[t4$lhs == "y1" & t4$op == "~~"], 0)
  # user rows first, ids consecutive, auto rows flagged
  expect_identical(tab("y ~ x")$id, 1:3)
  expect_identical(tab("y ~ x")$user, c(1L, 0L, 0L))
  # exogenous variances and covariances are free (Q3)
  t5 <- tab("y ~ x1 + x2")
  expect_true(all(is.na(t5$fixed[t5$op == "~~"])))
  expect_setequal(paste(t5$lhs, t5$rhs)[t5$op == "~~"], c("y y", "x1 x1", "x1 x2", "x2 x2"))
  # documented departure from lavaan: start() on the marker loading does not free or move it
  t6 <- tab("F =~ start(.5)*y1 + y2\nz ~ F")
  expect_equal(t6$fixed[t6$op == "=~"], c(1, NA))
  expect_equal(t6$start[t6$op == "=~"], c(0.5, NA))
})

# --- RAM -----------------------------------------------------------------------

sem_demo <- medfit::mediation_demo

# Parameter vector in RAM order from a lavaan fit's estimates.
sem_theta_from_lavaan <- function(conv, fit) {
  pe <- lavaan::parameterEstimates(fit)
  pe <- pe[pe$op %in% c("=~", "~", "~~"), ]
  tab <- conv$table
  key <- function(lhs, op, rhs) sem_row_keys(lhs, op, rhs, NA, "")
  est <- pe$est[match(key(tab$lhs, tab$op, tab$rhs), key(pe$lhs, pe$op, pe$rhs))]
  theta <- numeric(conv$ram$q)
  theta[conv$par_map[!is.na(conv$par_map)]] <- est[!is.na(conv$par_map)]
  theta
}

test_that("the RAM reproduces lavaan's implied covariance at lavaan's estimates to 1e-10", {
  skip_if_not_installed("lavaan")
  for (nm in names(sem_models_oracle)) {
    m <- sem_models_oracle[[nm]]
    fit <- suppressWarnings(lavaan::sem(m, data = sem_demo, fixed.x = FALSE))
    conv <- .sem_to_ram(.sem_complete(.sem_parse(m)$parameters))
    sigma <- .sem_implied(conv$ram, sem_theta_from_lavaan(conv, fit))
    ref <- lavaan::lavInspect(fit, "cov.ov")[conv$ram$obs, conv$ram$obs]
    expect_equal(unname(sigma), unname(ref), tolerance = 1e-10, info = nm)
  }
})

test_that("planted defect: a wrong theta makes the implied-covariance oracle fail", {
  skip_if_not_installed("lavaan")
  m <- sem_models_oracle[["serial"]]
  fit <- suppressWarnings(lavaan::sem(m, data = sem_demo, fixed.x = FALSE))
  conv <- .sem_to_ram(.sem_complete(.sem_parse(m)$parameters))
  theta <- sem_theta_from_lavaan(conv, fit)
  theta[1L] <- theta[1L] + 0.05
  ref <- lavaan::lavInspect(fit, "cov.ov")[conv$ram$obs, conv$ram$obs]
  expect_gt(max(abs(unname(.sem_implied(conv$ram, theta)) - unname(ref))), 1e-4)
})

test_that("Q3: lavaan fixed.x = TRUE and FALSE give the same structural estimates and SEs", {
  skip_if_not_installed("lavaan")
  # The two likelihoods differ only by the exogenous block, so the structural parameters agree up to
  # lavaan's own optimizer tolerance: measured relative differences 0 (simple), 7e-7 (covariates), 2e-7
  # (latent). The plan's 1e-8 holds only where lavaan converges exactly.
  tol <- c(simple = 1e-8, covariates = 2e-6, latent = 2e-6)
  for (nm in names(tol)) {
    m <- sem_models_oracle[[nm]]
    f1 <- suppressWarnings(lavaan::sem(m, data = sem_demo, fixed.x = TRUE))
    f0 <- suppressWarnings(lavaan::sem(m, data = sem_demo, fixed.x = FALSE))
    p1 <- lavaan::parameterEstimates(f1)
    p0 <- lavaan::parameterEstimates(f0)
    s1 <- p1[p1$op %in% c("=~", "~") & p1$se > 0, ]
    s0 <- p0[match(paste(s1$lhs, s1$op, s1$rhs), paste(p0$lhs, p0$op, p0$rhs)), ]
    expect_gte(nrow(s1), 4L)
    expect_equal(s0$est, s1$est, tolerance = tol[[nm]], info = nm)
    expect_equal(s0$se, s1$se, tolerance = tol[[nm]], info = nm)
  }
})

test_that("par_map, starts and bounds follow the table", {
  m <- "Y ~ a*X + start(.5)*Z\nM ~ lower(0)*X\nY ~~ upper(5)*Y"
  conv <- .sem_to_ram(.sem_complete(.sem_parse(m)$parameters))
  expect_identical(length(conv$par_map), nrow(conv$table))
  expect_identical(conv$ram$par_names[conv$par_map[conv$table$label == "a"]], "a")
  expect_equal(conv$start[["Y ~ Z"]], 0.5)
  expect_equal(conv$lower[["M ~ X"]], 0)
  expect_equal(conv$upper[["Y ~~ Y"]], 5)
  expect_true(is.na(conv$start[["a"]]))
  expect_named(conv$start, conv$ram$par_names)
  # shared label: one parameter, bounds from whichever row carries them
  conv <- .sem_to_ram(.sem_complete(.sem_parse("M ~ a*X\nY ~ a*M\na > 0")$parameters))
  expect_equal(conv$lower[["a"]], 0)
  expect_identical(sum(conv$par_map == match("a", conv$ram$par_names), na.rm = TRUE), 2L)
})

test_that("intercepts: a fixed zero is dropped, anything else names the mean-structure limit", {
  conv <- .sem_to_ram(.sem_complete(.sem_parse("m ~ 0*1\nm ~ x")$parameters))
  expect_false(any(conv$table$op == "~1"))
  expect_error(
    .sem_to_ram(.sem_complete(.sem_parse("m ~ 1\nm ~ x")$parameters)),
    "mean structure is not supported.*free"
  )
  expect_error(.sem_to_ram(.sem_complete(.sem_parse("m ~ 2*1\nm ~ x")$parameters)), "nonzero")
})

test_that("a repeated path is rejected by the RAM builder", {
  expect_error(.sem_to_ram(.sem_complete(.sem_parse("Y ~ X\nY ~ X")$parameters)), "a path appears twice")
  expect_error(.sem_to_ram(.sem_complete(.sem_parse("Y ~ X\nY ~~ Y\nY ~~ Y")$parameters)), "appears twice")
})

# --- identification ------------------------------------------------------------

test_that("the scale check passes for a completed latent model and names a latent with no scale", {
  tab <- .sem_complete(.sem_parse(sem_models_oracle[["latent"]])$parameters)
  expect_no_error(.sem_check_scale(tab))
  expect_no_error(.sem_check_scale(.sem_complete(.sem_parse("F =~ y1 + y2\nF ~~ 1*F\nz ~ F")$parameters)))
  expect_equal(.sem_df(.sem_to_ram(tab)$ram), 4)
})

test_that("planted defect: a completion without the marker rule is caught before optimization", {
  tab <- .sem_complete(.sem_parse(sem_models_oracle[["latent"]])$parameters)
  tab$fixed[tab$op == "=~" & tab$user == 1L & !is.na(tab$fixed)] <- NA_real_
  expect_error(.sem_check_scale(tab), "latent variable 'eta' has no fixed loading or fixed variance")
  # the degrees-of-freedom count alone would not catch it: one more free loading leaves df >= 0
  expect_gte(.sem_df(.sem_to_ram(tab)$ram), 0)
})
