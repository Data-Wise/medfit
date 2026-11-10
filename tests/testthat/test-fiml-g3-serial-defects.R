# FI-G3 slice S1b: planted defects in the saturated serial FIML code. A battery of independent checks (lavaan values,
# hand gradients, the exact-origin rule, every consumer refusal) is run on the unmutated code first (the positive
# control: it passes) and then on one deliberately broken copy of one function at a time; every defect must fail at
# least one check. The battery includes incomplete data (cross-equation covariance defects are invisible on complete
# data) and distinct large path values (a swapped path cannot hide). Helpers are in helper-fiml-serial.R (sb_*).

sb_env <- new.env(parent = emptyenv())
sb_setup <- function() {
  if (is.null(sb_env$f)) {
    skip_if_not_installed("lavaan")
    sb_env$d <- sb_data("mar")
    sb_env$f <- sb_fit(sb_env$d)
    sb_env$ref <- sb_reference(sb_env$d)
    sb_env$z <- sb_extract(sb_env$f)
    # a data set with covariates, for the admission probes
    dz <- sb_env$d
    dz$Z1 <- stats::rnorm(nrow(dz))
    dz$Z2 <- stats::rnorm(nrow(dz))
    sb_env$dz <- dz
  }
  invisible(NULL)
}
sb_ok <- function(expr) isTRUE(tryCatch(suppressWarnings(expr), error = function(e) FALSE))
sb_class_error <- function(expr, class) {
  e <- tryCatch({
    suppressWarnings(expr)
    NULL
  }, error = identity)
  inherits(e, class)
}
sb_chain_fit <- function() {
  fit_sem(paste(c("M1 ~ X", "M2 ~ M1", "Y ~ M2 + X", sb_zeros), collapse = "\n"), sb_env$d,
          missing = "fiml", fixed_x = FALSE)
}
# the chain with two covariates: still refused at fit (slice S4), and refused at extract when the fit is mocked open
sb_chain2_fit <- function() {
  m <- c("M1 ~ X + Z1 + Z2", "M2 ~ M1 + Z1 + Z2", "Y ~ M2 + X + Z1 + Z2", sb_zeros)
  fit_sem(paste(m, collapse = "\n"), sb_env$dz,
          missing = "fiml", fixed_x = FALSE)
}
sb_battery <- function() {
  f <- sb_env$f
  ref <- sb_env$ref
  z <- tryCatch(sb_extract(f), error = identity)
  if (inherits(z, "error")) return(c(extraction = FALSE))
  roles <- c("a", "a2", "d1", "b1", "b", "c_prime")
  tb <- suppressWarnings(tryCatch(generics::tidy(z, type = "effects"), error = function(e) NULL))
  se <- if (is.null(tb)) NULL else stats::setNames(tb$std_error, tb$term)
  est <- if (is.null(tb)) NULL else stats::setNames(tb$estimate, tb$term)
  row_na <- function(zz, term) {
    t <- generics::tidy(zz, type = "effects")
    is.na(t$std_error[t$term == term])
  }
  c(
    extraction = TRUE,
    paths = sb_ok(max(abs(unname(paths(z)) - unname(ref$est[roles]))) < 1e-5),
    vcov = sb_ok(sb_rel_gap(z@vcov[roles, roles], ref$vcov[roles, roles]) < 1e-3),
    nie_estimate = sb_ok(abs(est[["nie"]] - ref$ind$est) < 1e-5),
    nie_total_estimate = sb_ok(abs(est[["nie_total"]] - ref$ind_tot$est) < 1e-5),
    te_estimate = sb_ok(abs(est[["te"]] - ref$te$est) < 1e-5),
    nie_se = sb_ok(abs(se[["nie"]] - ref$ind$se) / ref$ind$se < 2e-3),
    nie_total_se = sb_ok(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se < 2e-3),
    te_se = sb_ok(abs(se[["te"]] - ref$te$se) / ref$te$se < 2e-3),
    tidy_all = sb_ok(identical(
      generics::tidy(z)$term, c("a", "a2", "d", "b1", "b", "c_prime", "nie", "nie_total", "nde", "te")
    )),
    confint_paths = sb_ok({
      ci <- confint(z, parm = "paths")
      identical(rownames(ci), c("a", "a2", "d", "b1", "b", "c_prime")) &&
        max(abs((ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975) - sqrt(diag(z@vcov)[roles]))) < 1e-10
    }),
    confint_total = sb_ok(identical(rownames(confint(z, parm = "effects")), c("nie", "nie_total", "nde", "te"))),
    boot_text = sb_ok(identical(tryCatch(confint(z, method = "boot"), error = conditionMessage),
                                "bootstrap CI is not supported for bounded FIML objects")),
    coef_paths = sb_ok(identical(names(coef(z, type = "paths")), c("a", "a2", "d", "b1", "b", "c_prime"))),
    summary_paths = sb_ok(all(c("a2", "b1") %in% names(summary(z)$paths))),
    quick_refused = sb_ok(grepl("not supported", tryCatch(quick(z), error = conditionMessage))),
    pm_refused = sb_ok(grepl("not supported", tryCatch(pm(z), error = conditionMessage))),
    glance_refused = sb_ok(grepl("not supported", tryCatch(generics::glance(z), error = conditionMessage))),
    # the exact-origin rule
    origin_fires = sb_ok(row_na(sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0)), "nie_total")),
    origin_nie_total_finite = sb_ok(!row_na(sb_forge(z, list(a = 0, d1 = 0)), "nie_total") &&
                                      row_na(sb_forge(z, list(a = 0, d1 = 0)), "nie")),
    origin_one_zero_finite = sb_ok(!row_na(sb_forge(z, list(a = 0)), "nie")),
    origin_te_never = sb_ok(!row_na(sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0)), "te")),
    # reversed order is refused with the class
    reversed_refused = sb_class_error(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")),
                                      "medfit_error_fiml_extract_unsupported"),
    # admission: only the k = 0 and k = 1 shapes (saturated and, since S2, the pure chain) are public
    sat2_refused = sb_class_error(fit_sem(
      paste(c("M1 ~ X + Z1 + Z2", "M2 ~ M1 + X + Z1 + Z2", "Y ~ M1 + M2 + X + Z1 + Z2", sb_zeros),
            collapse = "\n"), sb_env$dz,
      missing = "fiml", fixed_x = FALSE
    ), "medfit_sem_fiml_error"),
    chain0_fits = sb_ok(identical(sb_extract(sb_chain_fit())@variant, "chain")),
    chain2_refused = sb_class_error(sb_chain2_fit(), "medfit_sem_fiml_error"),
    chain2_extract_refused = sb_ok(testthat::with_mocked_bindings(
      sb_class_error(
        extract_mediation(sb_chain2_fit(), treatment = "X", mediator = c("M1", "M2")),
        "medfit_error_fiml_extract_unsupported"
      ),
      .fiml_serial_admitted = function() TRUE
    ))
  )
}
mut <- function(name, pattern, replacement) {
  fn <- get(name, envir = asNamespace("medfit"))
  sem_mutate(fn, pattern, replacement)
}
# run the battery with one function of the package replaced
sb_with <- function(name, fn) {
  args <- stats::setNames(list(fn), name)
  do.call(testthat::with_mocked_bindings, c(list(code = quote(sb_battery())), args))
}
sb_caught <- function(name, pattern, replacement) {
  r <- sb_with(name, mut(name, pattern, replacement))
  list(failed = names(r)[!r], all_pass = all(r))
}

test_that("the battery passes on the unmutated code (positive control) and has teeth in every group", {
  fx_skip_covr()
  sb_setup()
  r <- sb_battery()
  expect_true(all(r), info = paste(names(r)[!r], collapse = ", "))
  expect_gte(length(r), 25L)
})

test_that("extraction defects: swapped paths, aliased paths, dropped covariance blocks", {
  fx_skip_covr()
  sb_setup()
  # D1: d1 and b swapped. The chain NIE a*d1*b and its SE are invariant to the swap, so the path rows and every
  # effect that is not a plain product must expose it
  r <- sb_caught(".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
                 "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")")
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  # D2: a and a2 swapped
  swap_a <- c(
    "a = if (as_covariate) par(paste0(\"gm1z\", iz)) else par(\"a\"), ",
    "if (!chain) c(a2 = if (as_covariate) par(paste0(\"gm2z\", iz)) else par(\"a2\"))"
  )
  swap_b <- c(
    "a = if (as_covariate) par(paste0(\"gm1z\", iz)) else par(\"a2\"), ",
    "if (!chain) c(a2 = if (as_covariate) par(paste0(\"gm2z\", iz)) else par(\"a\"))"
  )
  r <- sb_caught(".sem_fiml_extract_serial", paste(swap_a, collapse = ""), paste(swap_b, collapse = ""))
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  # D3: the shortcut b1 taken from the direct path
  r <- sb_caught(".sem_fiml_extract_serial", "b1 = par(\"b1\")", "b1 = par(\"cp\")")
  expect_false(r$all_pass)
  expect_true("paths" %in% r$failed)
  # D5: the cross-equation covariance blocks zeroed (lm-style): invisible on complete data, caught by the MAR cell
  r <- sb_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE] * ",
           "outer(c(1, 2, 2, 3, 3, 3)[present], c(1, 2, 2, 3, 3, 3)[present], \"==\")")
  )
  expect_false(r$all_pass)
  expect_true(any(c("vcov", "nie_se", "nie_total_se", "te_se") %in% r$failed))
  # D6: the within-equation covariance zeroed too (diagonal only)
  r <- sb_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    "V[present, present] <- diag(diag(object@vcov[roles[present], roles[present], drop = FALSE]))"
  )
  expect_false(r$all_pass)
  expect_true("vcov" %in% r$failed)
  # Q7 removed: the reversed order is silently accepted
  r <- sb_caught(".sem_fiml_extract_serial", "ok_mediators && !identical(mediator, meds)",
                 "FALSE && !identical(mediator, meds)")
  expect_false(r$all_pass)
  expect_true("reversed_refused" %in% r$failed)
  # D8: the serial fit routed to the parallel extractor (the shared alias strings a2, b1 make this fail silently)
  r <- sb_caught(".sem_fiml_extract", "identical(object@internals$likelihood$structure, \"serial\")", "FALSE")
  expect_false(r$all_pass)
  # an extraction that stores the chain predictor lists for a saturated fit is rejected by the validator
  r <- sb_caught(".sem_fiml_extract_serial", "mediator_predictors <- list(c(x, zz), c(meds[1L], if (!chain) x, zz))",
                 "mediator_predictors <- list(c(x, zz), c(meds[1L], zz))")
  expect_false(r$all_pass)
  expect_identical(r$failed, "extraction")
})

test_that("effect defects: wrong total-indirect and total gradients", {
  fx_skip_covr()
  sb_setup()
  # D7: the total-indirect gradient replaced by the chain gradient
  r <- sb_caught(".effect_gradients", "g_te[names(g_te) != \"c_prime\"]", "g_nie")
  expect_false(r$all_pass)
  expect_true("nie_total_se" %in% r$failed)
  # D21-style: the total-effect gradient loses its second factor
  r <- sb_caught(".serial_te_gradient", "sys$inv[y, e$to + 1L] * sys$inv[e$from + 1L, 1L]", "sys$inv[y, e$to + 1L]")
  expect_false(r$all_pass)
  expect_true("te_se" %in% r$failed)
})

test_that("origin defects: too broad, narrow, missing, scalar helper, length-two helper into scalar callers", {
  fx_skip_covr()
  sb_setup()
  # D12: the chain rule withholds when ONE factor is 0
  r <- sb_caught(".sem_fiml_origin_effects", "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 2L",
                 "sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 1L")
  expect_false(r$all_pass)
  expect_true("origin_one_zero_finite" %in% r$failed)
  # D13: nie_total uses the nie rule
  total_rule <- "nie_total = all(c(e[[\"a\"]], e[[\"a2\"]], e[[\"b\"]], e[[\"b1\"]]) == 0)"
  r <- sb_caught(".sem_fiml_origin_effects", total_rule, "nie_total = chain_zero")
  expect_false(r$all_pass)
  expect_true("origin_nie_total_finite" %in% r$failed)
  # D13b: the nie_total rule never fires
  r <- sb_caught(".sem_fiml_origin_effects", total_rule, "nie_total = FALSE")
  expect_false(r$all_pass)
  expect_true("origin_fires" %in% r$failed)
  # D26: the serial code calls the scalar helper (the serial origin never fires)
  r <- sb_caught(".sem_fiml_origin_effects", "if (!S7::S7_inherits(x, FIMLSerialMediationData)) ", "if (TRUE) ")
  expect_false(r$all_pass)
  expect_true("origin_fires" %in% r$failed)
  # the helper returning length 2 into the scalar callers: `if (c(TRUE, FALSE) && ...)` is an error
  r <- sb_caught(".sem_fiml_origin", "if (S7::S7_inherits(x, FIMLSerialMediationData)) \n        return(FALSE)",
                 "if (S7::S7_inherits(x, FIMLSerialMediationData)) \n        return(.sem_fiml_origin_effects(x))")
  expect_false(r$all_pass)
  expect_true("tidy_all" %in% r$failed)
  # the note is NIE-only for the nie_total row
  r <- sb_caught(".sem_fiml_origin_notes", "nie_total = \"NIE total inference unavailable: zero delta gradient\"",
                 "nie_total = \"NIE inference unavailable: zero delta gradient\"")
  expect_true(r$all_pass) # the battery has no note check ...
  zz <- sb_forge(sb_env$z, list(a = 0, a2 = 0, b = 0, b1 = 0))
  good <- attr(suppressWarnings(generics::tidy(zz)), "note")
  broken <- mut(".sem_fiml_origin_notes", "nie_total = \"NIE total inference unavailable: zero delta gradient\"",
                "nie_total = \"NIE inference unavailable: zero delta gradient\"")
  bad <- testthat::with_mocked_bindings(attr(suppressWarnings(generics::tidy(zz)), "note"),
                                        .sem_fiml_origin_notes = broken)
  expect_false(identical(good, bad)) # ... so the note is pinned by comparison with the correct text
  expect_identical(good[["nie_total"]], "NIE total inference unavailable: zero delta gradient")
})

test_that("consumer defects: quick, pm, glance, bootstrap advice, coef/summary paths, recycled aliases", {
  fx_skip_covr()
  sb_setup()
  # D24: quick() not refusing the serial FIML class (it would print PM)
  r <- sb_caught(".quick_serial_mediation_data", ".sem_fiml_refuse(x, \"quick()\")", "invisible(NULL)")
  expect_false(r$all_pass)
  expect_true("quick_refused" %in% r$failed)
  # D14: glance() not refusing
  r <- sb_caught(".glance_serial_mediation_data", ".sem_fiml_refuse(x, \"glance() on extracted data\")",
                 "invisible(NULL)")
  expect_false(r$all_pass)
  expect_true("glance_refused" %in% r$failed)
  # D14: the refusal helper itself a no-op: pm(), glance(), quick() and confint(method = 'boot') (which then gives the
  # lm/glm advice instead of the FIML text) all fail
  r <- sb_with(".sem_fiml_refuse", function(x, operation) invisible(NULL))
  expect_false(r[["pm_refused"]])
  expect_false(r[["glance_refused"]])
  expect_false(r[["quick_refused"]])
  expect_false(r[["boot_text"]])
  # D25: coef(type = "paths") and summary() hiding a2 and b1
  r <- sb_caught(".sem_fiml_ser_coef_paths", ".sem_fiml_ser_paths(x)",
                 ".sem_fiml_ser_paths(x)[c(\"a\", \"d\", \"b\", \"c_prime\")]")
  expect_false(r$all_pass)
  expect_true("coef_paths" %in% r$failed)
  r <- sb_caught(".sem_fiml_ser_summary_paths", ".sem_fiml_ser_paths(x), indirect =",
                 ".sem_fiml_ser_paths(x)[c(\"a\", \"d\", \"b\", \"c_prime\")], indirect =")
  expect_false(r$all_pass)
  expect_true("summary_paths" %in% r$failed)
  # four aliases recycled over six path rows
  r <- sb_caught(".serial_tidy_alias", "if (S7::S7_inherits(x, FIMLSerialMediationData)) ", "if (FALSE) ")
  expect_false(r$all_pass)
  expect_true(all(c("tidy_all", "confint_paths") %in% r$failed))
  # the shortcut path a2 dropped from the path rows (paths(), tidy and confint alike)
  r <- sb_caught(".sem_fiml_ser_paths", "a2 = e[[\"a2\"]], d = e[[\"d1\"]]", "d = e[[\"d1\"]]")
  expect_false(r$all_pass)
  # the total indirect effect has no confint row (spec 3.3 item 3)
  r <- sb_caught(".sem_fiml_ser_effect_estimates", "nie_total = unname(nie(object, type = \"total\")), ", "")
  expect_false(r$all_pass)
  expect_true("confint_total" %in% r$failed)
})

test_that("admission defects: the predicate ignoring k or dropping the chain, the extract predicate ignoring k", {
  fx_skip_covr()
  sb_setup()
  r <- sb_caught(".fiml_serial_shape_admitted", "as.integer(k) %in% 0:1", "TRUE")
  expect_false(r$all_pass)
  expect_true(all(c("sat2_refused", "chain2_refused") %in% r$failed))
  # the chain dropped from the admitted set (a regression of slice S2)
  r <- sb_caught(".fiml_serial_shape_admitted", "variant %in% c(\"saturated\", \"chain\")",
                 "identical(variant, \"saturated\")")
  expect_false(r$all_pass)
  expect_true("chain0_fits" %in% r$failed)
  r <- sb_caught(".fiml_serial_extract_supported", "as.integer(k) %in% 0:1", "TRUE")
  expect_false(r$all_pass)
  expect_true("chain2_extract_refused" %in% r$failed)
})

test_that("fit-level defects: a transport offset dropped and a hidden chain (b1 removed from the saturated tables)", {
  fx_skip_covr()
  skip_if_not_installed("lavaan")
  sb_setup()
  ref <- sb_env$ref
  plain <- lavaan::coef(sb_lavaan(sb_model(), sb_env$d))
  agrees <- function() {
    f <- tryCatch(sb_fit(sb_env$d), error = identity)
    if (inherits(f, "error")) return(FALSE)
    q <- coef(f)
    # every parameter, intercepts included: a dropped transport offset moves only the intercepts
    abs(as.numeric(logLik(f)) - ref$logl) < 1e-6 && max(abs(q - sb_align(plain, q))) < 1e-5
  }
  expect_true(agrees())
  fn <- mut(".sem_fiml_transport", "offset[i$par] <- center[i$var]", "offset[i$par] <- 0")
  expect_false(testthat::with_mocked_bindings(agrees(), .sem_fiml_transport = fn))
  orig <- .sem_fiml_tables_ser
  hidden <- function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    t$a <- t$a[t$a$label != "b1", ]
    t
  }
  expect_false(testthat::with_mocked_bindings(agrees(), .sem_fiml_tables_ser = hidden))
})
