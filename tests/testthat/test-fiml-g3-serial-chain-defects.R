# FI-G3 slice S2: planted defects in the pure-chain serial FIML code. A battery of independent checks (lavaan values,
# the restriction test against the saturated fit, hand gradients, the per-effect exact-origin rule, every consumer
# refusal, validator forgeries) is run on the unmutated code first (the positive control: it passes) and then on one
# deliberately broken copy of one function at a time; every defect must fail at least one check. The battery uses
# incomplete data (cross-equation covariance defects are invisible on complete data) and distinct large path values
# (a swapped path cannot hide), plus a data-generating process with real shortcut effects so that a freed shortcut
# (LR = 0, df 0) and a hidden saturated fit are visible. Helpers: helper-fiml-serial.R (sb_*) and
# helper-fiml-serial2-chain.R (sc_*). The covr guard is the one of the S1b defect battery (function bodies are mutated).

sc_env <- new.env(parent = emptyenv())
sc_setup <- function() {
  if (is.null(sc_env$f)) {
    skip_if_not_installed("lavaan")
    # real shortcut effects, so the restriction test has power and the chain and saturated fits differ
    sc_env$d <- sc_data("mar", a2 = .3, b1 = .25)
    sc_env$f <- sc_fit(sc_env$d)
    sc_env$ref <- sc_reference(sc_env$d)
    sc_env$plain <- lavaan::coef(sb_lavaan(sc_model(), sc_env$d))
    sc_env$z <- sb_extract(sc_env$f)
    sc_env$ll_sat <- as.numeric(logLik(sb_fit(sc_env$d)))
    dz <- sc_env$d
    dz$Z <- stats::rnorm(nrow(dz))
    sc_env$dz <- dz
    # forged objects for the validator battery: built without the validator, then judged by it
    forge <- function(z, ...) {
      for (nm in names(list(...))) attr(z, nm) <- list(...)[[nm]]
      z
    }
    zs <- sb_extract(sb_fit(sc_env$d))
    # the chain estimates carrying the saturated six aliases, with the parameter hash rebound as the validator reads it
    z <- sc_env$z
    est6 <- c(z@estimates[1L], a2 = 0, z@estimates[2:3], b1 = 0, z@estimates[4L])
    ctx <- z@fit_context
    ctx$parameter_hash <- rlang::hash(list(est6, z@vcov, z@a_path, z@d_path, z@b_path, z@c_prime, z@variant))
    six <- forge(z, estimates = est6, fit_context = ctx)
    sc_env$forged <- list(
      chain_x_in_m2 = forge(sc_env$z, mediator_predictors = list("X", c("M1", "X"))),
      chain_m1_in_y = forge(sc_env$z, outcome_predictors = c("M1", "M2", "X")),
      chain_m2_missing_in_y = forge(sc_env$z, outcome_predictors = "X"),
      chain_wrong_m1_list = forge(sc_env$z, mediator_predictors = list(c("X", "M2"), "M1")),
      chain_six_aliases = six,
      sat_chain_lists = forge(zs, mediator_predictors = list("X", "M1"), outcome_predictors = c("M2", "X")),
      sat_m2_missing_in_y = forge(zs, outcome_predictors = c("M1", "X")),
      sat_wrong_m1_list = forge(zs, mediator_predictors = list(c("X", "M2"), c("M1", "X")))
    )
    sc_env$real <- list(chain = sc_env$z, saturated = zs)
  }
  invisible(NULL)
}
sc_ok <- function(expr) isTRUE(tryCatch(suppressWarnings(expr), error = function(e) FALSE))
sc_class_error <- function(expr, class) {
  e <- tryCatch({
    suppressWarnings(expr)
    NULL
  }, error = identity)
  inherits(e, class)
}
sc_chain1_fit <- function() {
  fit_sem(paste(c("M1 ~ X + Z", "M2 ~ M1 + Z", "Y ~ M2 + X + Z", sc_zeros), collapse = "\n"), sc_env$dz,
          missing = "fiml", fixed_x = FALSE)
}
sc_validator <- function() FIMLSerialMediationData@validator
sc_battery <- function() {
  ref <- sc_env$ref
  f <- tryCatch(sc_fit(sc_env$d), error = identity)
  if (inherits(f, "error")) return(c(fits = FALSE))
  q <- coef(f)
  roles <- c("a", "d1", "b", "c_prime")
  z <- tryCatch(sb_extract(f), error = identity)
  out <- c(
    fits = TRUE,
    q_formula = length(f@theta) == 12L && 14L - length(f@theta) == 2L,
    # every parameter, intercepts included, and the logLik
    estimates = sc_ok(max(abs(q - sb_align(sc_env$plain, q))) < 1e-5),
    loglik = sc_ok(abs(as.numeric(logLik(f)) - ref$logl) < 1e-6),
    # the restriction: LR against the saturated fit is the lavaan chi-square (df 2); a freed shortcut gives LR = 0
    restriction_lr = sc_ok(abs(2 * (sc_env$ll_sat - as.numeric(logLik(f))) - ref$chisq) < 1e-4 && ref$chisq > 5),
    no_shortcut_parameters = sc_ok(!any(c("M2~X", "Y~M1") %in% names(q)))
  )
  if (inherits(z, "error")) return(c(out, extraction = FALSE))
  tb <- suppressWarnings(tryCatch(generics::tidy(z, type = "effects"), error = function(e) NULL))
  se <- if (is.null(tb)) NULL else stats::setNames(tb$std_error, tb$term)
  est <- if (is.null(tb)) NULL else stats::setNames(tb$estimate, tb$term)
  row_na <- function(zz, term) {
    t <- generics::tidy(zz, type = "effects")
    is.na(t$std_error[t$term == term])
  }
  c(
    out,
    extraction = TRUE,
    variant_chain = sc_ok(identical(z@variant, "chain") && identical(names(z@estimates), roles)),
    paths = sc_ok(max(abs(unname(paths(z)) - unname(ref$est[roles]))) < 1e-5),
    vcov = sc_ok(sb_rel_gap(z@vcov[roles, roles], ref$vcov[roles, roles]) < 1e-3),
    nie_estimate = sc_ok(abs(est[["nie"]] - ref$ind$est) < 1e-5),
    nie_total_estimate = sc_ok(abs(est[["nie_total"]] - ref$ind$est) < 1e-5),
    te_estimate = sc_ok(abs(est[["te"]] - ref$te$est) < 1e-5),
    nie_se = sc_ok(abs(se[["nie"]] - ref$ind$se) / ref$ind$se < 2e-3),
    nie_total_se = sc_ok(abs(se[["nie_total"]] - ref$ind$se) / ref$ind$se < 2e-3),
    te_se = sc_ok(abs(se[["te"]] - ref$te$se) / ref$te$se < 2e-3),
    hand_te_se = sc_ok(abs(se[["te"]] - sb_se(z, sc_grad(z)$te)) < 1e-12),
    tidy_all = sc_ok(identical(generics::tidy(z)$term, c("a", "d", "b", "c_prime", "nie", "nie_total", "nde", "te"))),
    confint_paths = sc_ok({
      ci <- confint(z, parm = "paths")
      identical(rownames(ci), c("a", "d", "b", "c_prime")) &&
        max(abs((ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975) - sqrt(diag(z@vcov)[roles]))) < 1e-10
    }),
    confint_effects = sc_ok(identical(rownames(confint(z, parm = "effects")), c("nie", "nie_total", "nde", "te"))),
    coef_paths = sc_ok(identical(names(coef(z, type = "paths")), c("a", "d", "b", "c_prime"))),
    summary_paths = sc_ok(!any(c("a2", "b1") %in% names(summary(z)$paths)) && "c_prime" %in% names(summary(z)$paths)),
    te_no_warning = isTRUE(tryCatch(!is.na(as.numeric(te(z))), warning = function(w) FALSE, error = function(e) FALSE)),
    quick_refused = sc_ok(grepl("not supported", tryCatch(quick(z), error = conditionMessage))),
    pm_refused = sc_ok(grepl("not supported", tryCatch(pm(z), error = conditionMessage))),
    glance_refused = sc_ok(grepl("not supported", tryCatch(generics::glance(z), error = conditionMessage))),
    boot_text = sc_ok(identical(tryCatch(confint(z, method = "boot"), error = conditionMessage),
                                "bootstrap CI is not supported for bounded FIML objects")),
    # the per-effect exact-origin rule, one rule for both chain rows
    origin_fires_two = sc_ok(row_na(sb_forge(z, list(a = 0, d1 = 0)), "nie") &&
                               row_na(sb_forge(z, list(a = 0, d1 = 0)), "nie_total")),
    origin_fires_ab = sc_ok(row_na(sb_forge(z, list(a = 0, b = 0)), "nie_total")),
    origin_fires_db = sc_ok(row_na(sb_forge(z, list(d1 = 0, b = 0)), "nie")),
    origin_one_zero_finite = sc_ok(!row_na(sb_forge(z, list(a = 0)), "nie") &&
                                     !row_na(sb_forge(z, list(a = 0)), "nie_total")),
    origin_te_never = sc_ok(!row_na(sb_forge(z, list(a = 0, d1 = 0)), "te")),
    reversed_refused = sc_class_error(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")),
                                      "medfit_error_fiml_extract_unsupported"),
    # the saturated variant is not turned into a chain (and conversely, through the validator)
    sat_routed = sc_ok(identical(sb_extract(sb_fit(sc_env$d))@variant, "saturated")),
    # admission: the chain at k = 1 stays refused, at fit and (mock-opened) at extract; half shortcuts are refused
    chain1_refused = sc_class_error(sc_chain1_fit(), "medfit_sem_fiml_error"),
    chain1_extract_refused = sc_ok(testthat::with_mocked_bindings(
      sc_class_error(extract_mediation(sc_chain1_fit(), treatment = "X", mediator = c("M1", "M2")),
                     "medfit_error_fiml_extract_unsupported"),
      .fiml_serial_admitted = function() TRUE
    )),
    half_refused = sc_class_error(
      fit_sem(paste(c("M1 ~ X", "M2 ~ M1 + X", "Y ~ M2 + X", sc_zeros), collapse = "\n"), sc_env$d,
              missing = "fiml", fixed_x = FALSE), "medfit_sem_fiml_error"
    )
  )
}
sc_mut <- function(name, pattern, replacement) {
  fn <- get(name, envir = asNamespace("medfit"))
  sem_mutate(fn, pattern, replacement)
}
sc_with <- function(name, fn) {
  args <- stats::setNames(list(fn), name)
  do.call(testthat::with_mocked_bindings, c(list(code = quote(sc_battery())), args))
}
sc_caught <- function(name, pattern, replacement) {
  r <- sc_with(name, sc_mut(name, pattern, replacement))
  list(failed = names(r)[!r], all_pass = all(r))
}

test_that("the chain battery passes on the unmutated code (positive control) and has teeth in every group", {
  fx_skip_covr()
  sc_setup()
  r <- sc_battery()
  expect_true(all(r), info = paste(names(r)[!r], collapse = ", "))
  expect_gte(length(r), 35L)
})

test_that("variant routing defects: chain labeled saturated and conversely, the shortcut flag inverted", {
  fx_skip_covr()
  sc_setup()
  # D17: the parser classes a chain syntax as saturated (and conversely)
  r <- sc_caught(".sem_fiml_model_ser", "variant <- \"chain\"", "variant <- \"saturated\"")
  expect_false(r$all_pass)
  expect_true("fits" %in% r$failed)
  # D17: the extractor reads a chain fit as saturated (par(\"a2\") does not exist), or the saturated one as a chain
  r <- sc_caught(".sem_fiml_extract_serial", "chain <- identical(ctx0$variant, \"chain\")", "chain <- FALSE")
  expect_false(r$all_pass)
  expect_true("extraction" %in% r$failed)
  r <- sc_caught(".sem_fiml_extract_serial", "chain <- identical(ctx0$variant, \"chain\")", "chain <- TRUE")
  expect_false(r$all_pass)
  expect_true("sat_routed" %in% r$failed)
  # D17: the kernel tables built with the shortcut flag inverted at fit
  r <- sc_caught(".sem_fiml_syntax", "identical(spec$variant, \"saturated\")", "identical(spec$variant, \"chain\")")
  expect_false(r$all_pass)
  expect_true(any(c("fits", "estimates", "restriction_lr") %in% r$failed))
  # D8: a serial fit extracted by the parallel extractor
  r <- sc_caught(".sem_fiml_extract", "identical(object@internals$likelihood$structure, \"serial\")", "FALSE")
  expect_false(r$all_pass)
})

test_that("freed shortcut defects (D18): a chain fitted with a2 and b1 free fails q, the likelihood and the LR", {
  fx_skip_covr()
  sc_setup()
  # the kernel gets the saturated tables while the parser still describes the chain: the fit is the saturated fit
  r <- sc_caught(".sem_fiml_syntax", "identical(spec$variant, \"saturated\")", "TRUE")
  expect_false(r$all_pass)
  expect_true(any(c("estimates", "loglik", "restriction_lr", "q_formula", "no_shortcut_parameters") %in% r$failed))
  # the tables builder returning shortcut rows for the chain, wherever it is called
  orig <- .sem_fiml_tables_ser
  freed <- function(direct, k, shortcuts) orig(direct, k, TRUE)
  r <- sc_with(".sem_fiml_tables_ser", freed)
  expect_false(all(r))
  expect_true(any(c("fits", "estimates", "loglik", "restriction_lr", "q_formula") %in% names(r)[!r]))
})

test_that("extraction defects: swapped paths, dropped covariance blocks, the six-alias vector, shortcut predictors", {
  fx_skip_covr()
  sc_setup()
  # D1/D20: d1 and b swapped. The chain nie a*d1*b and its SE are invariant; the path rows and te SE expose it
  r <- sc_caught(".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
                 "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")")
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  expect_false("nie_estimate" %in% r$failed) # the product a * d1 * b is invariant to the swap, as the spec says
  # the direct path taken from the b slot
  r <- sc_caught(".sem_fiml_extract_serial", "c_prime = if (spec$direct) par(\"cp\") else NA_character_",
                 "c_prime = if (spec$direct) par(\"b\") else NA_character_")
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  # D5: the cross-equation covariance blocks zeroed (lm-style), invisible on complete data, caught by the MAR cell
  r <- sc_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE] * ",
           "outer(c(1, 2, 3, 3)[present], c(1, 2, 3, 3)[present], \"==\")")
  )
  expect_false(r$all_pass)
  expect_true(any(c("vcov", "nie_se", "nie_total_se", "te_se") %in% r$failed))
  # D6: the within-equation covariance zeroed too (Cov(b, c_prime) drives the chain te SE)
  r <- sc_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    "V[present, present] <- diag(diag(object@vcov[roles[present], roles[present], drop = FALSE]))"
  )
  expect_false(r$all_pass)
  expect_true("vcov" %in% r$failed)
  # D23: shortcut edges recorded in the predictor lists of a chain (storage says saturated, estimates say chain)
  r <- sc_caught(".sem_fiml_extract_serial", "outcome_predictors <- c(if (!chain) meds[1L], meds[2L], x)",
                 "outcome_predictors <- c(meds, x)")
  expect_false(r$all_pass)
  expect_identical(r$failed, "extraction")
  r <- sc_caught(".sem_fiml_extract_serial", "mediator_predictors <- list(x, c(meds[1L], if (!chain) x))",
                 "mediator_predictors <- list(x, c(meds[1L], x))")
  expect_false(r$all_pass)
  expect_identical(r$failed, "extraction")
  # Q7 removed: the reversed order silently accepted
  r <- sc_caught(".sem_fiml_extract_serial", "ok_mediators && !identical(mediator, meds)",
                 "FALSE && !identical(mediator, meds)")
  expect_false(r$all_pass)
  expect_true("reversed_refused" %in% r$failed)
})

test_that("effect defects: a chain gradient missing c_prime, with a shortcut term, or with wrong factors", {
  fx_skip_covr()
  sc_setup()
  # D21: the chain te gradient without the c_prime entry
  r <- sc_caught(".effect_gradients", "g_te <- .serial_te_gradient(x)",
                 "g_te <- .serial_te_gradient(x)[c(\"a\", \"d1\", \"b\")]")
  expect_false(r$all_pass)
  expect_true(any(c("te_se", "hand_te_se") %in% r$failed))
  # the chain te gradient picking up the a2 * b shortcut term (an alias that does not exist in the chain)
  r <- sc_caught(".effect_gradients", "g_te <- .serial_te_gradient(x)",
                 "g_te <- c(.serial_te_gradient(x), a2 = x@b_path)")
  expect_false(r$all_pass)
  expect_true(any(c("te_se", "hand_te_se", "tidy_all") %in% r$failed))
  # the chain nie gradient with the parallel-style factors (D7)
  r <- sc_caught(".effect_gradients", "g_nie <- vapply(seq_along(vals), function(i) prod(vals[-i]), numeric(1))",
                 "g_nie <- vapply(seq_along(vals), function(i) vals[i], numeric(1))")
  expect_false(r$all_pass)
  expect_true(any(c("nie_se", "te_se") %in% r$failed))
  # the path system reading a skip edge that the chain does not have (no stored coefficient: te() is NA)
  r <- sc_caught(".serial_path_system", "%in% target_preds) \n            next",
                 "%in% target_preds) \n            NULL")
  expect_false(r$all_pass)
  expect_true(any(c("te_estimate", "te_no_warning", "te_se") %in% r$failed))
})

test_that("origin defects: too broad, too narrow, the saturated rule, one row only, the scalar helper", {
  fx_skip_covr()
  sc_setup()
  # D12: the chain rule withholds when ONE factor is 0
  r <- sc_caught(".sem_fiml_origin_effects", "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 2L",
                 "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 1L")
  expect_false(r$all_pass)
  expect_true("origin_one_zero_finite" %in% r$failed)
  # too narrow: needs all three factors zero
  r <- sc_caught(".sem_fiml_origin_effects", "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 2L",
                 "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 3L")
  expect_false(r$all_pass)
  expect_true(any(c("origin_fires_two", "origin_fires_ab", "origin_fires_db") %in% r$failed))
  # D22: the chain withholds only nie, not nie_total
  r <- sc_caught(".sem_fiml_origin_effects", "return(c(nie = chain_zero, nie_total = chain_zero))",
                 "return(c(nie = chain_zero, nie_total = FALSE))")
  expect_false(r$all_pass)
  expect_true("origin_fires_two" %in% r$failed)
  # D22: the saturated rule applied to a chain object (a2 and b1 do not exist there)
  r <- sc_caught(".sem_fiml_origin_effects", "identical(x@variant, \"chain\")", "FALSE")
  expect_false(r$all_pass)
  expect_true(any(c("origin_fires_two", "origin_one_zero_finite") %in% r$failed))
  # D26: the serial code calls the scalar helper (the serial origin never fires)
  r <- sc_caught(".sem_fiml_origin_effects", "if (!S7::S7_inherits(x, FIMLSerialMediationData)) ", "if (TRUE) ")
  expect_false(r$all_pass)
  expect_true("origin_fires_two" %in% r$failed)
})

test_that("consumer defects: chain path rows, the recycled six-alias vector, c_prime dropped, refusals", {
  fx_skip_covr()
  sc_setup()
  # D20: the chain d and b rows swapped in the displayed path rows
  chain_rows <- "return(c(a = e[[\"a\"]], d = e[[\"d1\"]], b = e[[\"b\"]], c_prime = e[[\"c_prime\"]]))"
  r <- sc_caught(".sem_fiml_ser_paths", chain_rows,
                 "return(c(a = e[[\"a\"]], d = e[[\"b\"]], b = e[[\"d1\"]], c_prime = e[[\"c_prime\"]]))")
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  # c_prime dropped from the chain path rows when it is fixed or free (Q12: always listed)
  r <- sc_caught(".sem_fiml_ser_paths", chain_rows, "return(c(a = e[[\"a\"]], d = e[[\"d1\"]], b = e[[\"b\"]]))")
  expect_false(r$all_pass)
  expect_true(any(c("paths", "coef_paths", "tidy_all") %in% r$failed))
  # the four-alias contract: the saturated six aliases used for the chain
  r <- sc_caught(".sem_fiml_ser_alias", "if (identical(x@variant, \"chain\")) \n        c(",
                 "if (FALSE) \n        c(")
  expect_false(r$all_pass)
  expect_true(any(c("tidy_all", "confint_paths") %in% r$failed))
  # refusals
  r <- sc_caught(".quick_serial_mediation_data", ".sem_fiml_refuse(x, \"quick()\")", "invisible(NULL)")
  expect_true("quick_refused" %in% r$failed)
  r <- sc_with(".sem_fiml_refuse", function(x, operation) invisible(NULL))
  expect_false(r[["pm_refused"]])
  expect_false(r[["glance_refused"]])
  expect_false(r[["boot_text"]])
  # the total indirect effect has no confint row
  r <- sc_caught(".sem_fiml_ser_effect_estimates", "nie_total = unname(nie(object, type = \"total\")), ", "")
  expect_true("confint_effects" %in% r$failed)
})

test_that("fit-level defects: a transport offset dropped, d1 and b labels swapped in the tables", {
  fx_skip_covr()
  sc_setup()
  fn <- sc_mut(".sem_fiml_transport", "offset[i$par] <- center[i$var]", "offset[i$par] <- 0")
  r <- testthat::with_mocked_bindings(sc_battery(), .sem_fiml_transport = fn)
  expect_false(all(r))
  expect_true(any(c("estimates", "loglik") %in% names(r)[!r]))
  # D20: d1 and b swapped in the table labels (the extracted paths then carry each other's values)
  orig <- .sem_fiml_tables_ser
  swapped <- function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    i <- which(t$a$label %in% c("d1", "b"))
    t$a$label[i] <- rev(t$a$label[i])
    t
  }
  r <- testthat::with_mocked_bindings(sc_battery(), .sem_fiml_tables_ser = swapped)
  expect_false(all(r))
  expect_true(any(c("paths", "te_se") %in% names(r)[!r]))
})

test_that("validator defects: a weakened validator accepts the forgeries; the real one rejects them", {
  fx_skip_covr()
  sc_setup()
  v <- sc_validator()
  # positive control: the real validator rejects every forgery and accepts the real objects
  for (nm in names(sc_env$forged)) expect_type(v(sc_env$forged[[nm]]), "character")
  for (nm in names(sc_env$real)) expect_null(v(sc_env$real[[nm]]))
  weaken <- function(pattern, replacement) sem_mutate(v, pattern, replacement)
  # the exact set of the M2 predictors dropped
  w <- weaken("!identical(sort(as.character(preds[[2L]])), sort(want_m2)) ||", "FALSE ||")
  expect_null(w(sc_env$forged$chain_x_in_m2))
  # the exact set of the outcome predictors dropped
  w <- weaken("!identical(sort(as.character(self@outcome_predictors)), sort(want_y))", "FALSE")
  expect_null(w(sc_env$forged$chain_m1_in_y))
  expect_null(w(sc_env$forged$sat_m2_missing_in_y))
  # the M1 predictors dropped
  w <- weaken("!identical(sort(as.character(preds[[1L]])), sort(want_m1)) ||", "FALSE ||")
  expect_null(w(sc_env$forged$chain_wrong_m1_list))
  # the alias vector of the variant dropped (the chain accepted with the saturated six, the S1b-era check)
  w <- weaken("!identical(names(est), alias) ||", "FALSE ||")
  expect_null(w(sc_env$forged$chain_six_aliases))
  # the alias vector of the chain replaced by the saturated six: the real chain object is rejected
  w <- weaken("c(\"a\", \"d1\", \"b\", \"c_prime\")", "c(\"a\", \"a2\", \"d1\", \"b1\", \"b\", \"c_prime\")")
  expect_type(w(sc_env$real$chain), "character")
})
