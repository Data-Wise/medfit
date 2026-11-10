# FI-G3 slice S4: planted defects in the serial FIML code with TWO covariates (both variants). A battery of independent
# checks (lavaan values, the relabeled-treatment references for each covariate, hand gradients, predictor lists,
# validator forgeries, the chain's covariate-as-treatment refusal for both covariates, the partial exogenous covariance
# reason, the fixed-zero other-treatment reason, the k = 3 admission) is run on the unmutated code first (the positive
# control: it passes) and then on one deliberately broken copy of one function at a time; every defect must fail at
# least one check. The data are incomplete (cross-equation covariance defects are invisible on complete data) and the
# covariate effects are large and distinct from the paths and from each other (a covariate coefficient taken for a
# path, or one covariate for the other, cannot hide). Helpers: helper-fiml-serial.R (sb_*), -serial3.R (s3_*),
# -serial4.R (s4_*). The covr guard is that of the earlier defect batteries (function bodies are mutated).

s4d_env <- new.env(parent = emptyenv())
s4d_setup <- function() {
  if (is.null(s4d_env$d)) {
    skip_if_not_installed("lavaan")
    d <- s4_data("mar", a2 = .3, b1 = .25)
    s4d_env$d <- d
    for (v in c("saturated", "chain")) {
      s4d_env[[v]] <- list(
        ref = s4_reference(d, v, "free"),
        plain_fit = sb_lavaan(s4_model(v, "free"), d)
      )
      s4d_env[[v]]$plain <- lavaan::coef(s4d_env[[v]]$plain_fit)
    }
    s4d_env$ref_z1 <- s4_reference(d, "saturated", "free", tr = "Z1", cvs = c("X", "Z2"))
    s4d_env$ref_z2 <- s4_reference(d, "saturated", "free", tr = "Z2", cvs = c("X", "Z1"))
    s4d_env$f_zero <- s4_fit(d, "saturated", "zero")
    forge <- function(z, ...) {
      for (nm in names(list(...))) attr(z, nm) <- list(...)[[nm]]
      z
    }
    for (v in c("saturated", "chain")) {
      z <- s4_extract(s4_fit(d, v, "free"))
      s4d_env[[paste0("forged_", v)]] <- list(
        m1 = forge(z, mediator_predictors = list(c("X", "Z1"), z@mediator_predictors[[2L]])),
        m2 = forge(z, mediator_predictors = list(
          z@mediator_predictors[[1L]], setdiff(z@mediator_predictors[[2L]], "Z2")
        )),
        y = forge(z, outcome_predictors = setdiff(z@outcome_predictors, "Z1")),
        one_covariate = forge(z, fit_context = replace(z@fit_context, "covariate", list("Z1"))),
        wrong_treatment = forge(z, treatment = "Z1")
      )
    }
  }
  invisible(NULL)
}
s4d_ok <- function(expr) isTRUE(tryCatch(suppressWarnings(expr), error = function(e) FALSE))
s4d_class_error <- function(expr, class) {
  e <- tryCatch({
    suppressWarnings(expr)
    NULL
  }, error = identity)
  inherits(e, class)
}
s4d_cov_treatment <- function(f, tr, ref) {
  zt <- tryCatch(s4_extract(f, treatment = tr), error = identity)
  s4d_ok(
    max(abs(zt@estimates[names(ref$est)] - ref$est)) < 1e-5 &&
      sb_rel_gap(zt@vcov[names(ref$est), names(ref$est)], ref$vcov) < 2e-3 && identical(zt@treatment, tr) &&
      setequal(zt@fit_context$covariate, c("X", setdiff(c("Z1", "Z2"), tr))) &&
      setequal(zt@mediator_predictors[[1L]], c("X", "Z1", "Z2"))
  )
}
s4d_battery <- function() {
  cls <- "medfit_error_fiml_extract_unsupported"
  out <- c()
  for (v in c("saturated", "chain")) {
    sat <- v == "saturated"
    ref <- s4d_env[[v]]$ref
    plain <- s4d_env[[v]]$plain
    roles <- names(ref$est)
    f <- tryCatch(s4_fit(s4d_env$d, v, "free"), error = identity)
    r <- c(fits = !inherits(f, "error"))
    if (isTRUE(r[["fits"]])) {
      q <- coef(f)
      z <- tryCatch(s4_extract(f), error = identity)
      r <- c(
        r,
        q_count = length(f@theta) == if (sat) 27L else 25L,
        estimates = s4d_ok(max(abs(q - s4_align_v(plain, names(q)))) < 1e-5),
        loglik = s4d_ok(abs(as.numeric(logLik(f)) - ref$logl) < 1e-6),
        vcov_full = s4d_ok(
          sb_rel_gap(unname(vcov(f)), unname(s4_align_m(lavaan::vcov(s4d_env[[v]]$plain_fit), names(q)))) < 2e-3
        ),
        extraction = !inherits(z, "error")
      )
      if (!inherits(z, "error")) {
        tb <- suppressWarnings(generics::tidy(z, type = "effects"))
        se <- stats::setNames(tb$std_error, tb$term)
        est <- stats::setNames(tb$estimate, tb$term)
        g <- s4_grad(z)
        want_alias <- if (sat) c("a", "a2", "d1", "b1", "b", "c_prime") else c("a", "d1", "b", "c_prime")
        r <- c(
          r,
          alias_est = s4d_ok(max(abs(z@estimates[roles] - ref$est)) < 1e-5),
          alias_vcov = s4d_ok(sb_rel_gap(z@vcov[roles, roles], ref$vcov) < 2e-3),
          nie_total_est = s4d_ok(abs(est[["nie_total"]] - ref$ind_tot$est) < 1e-5),
          te_est = s4d_ok(abs(est[["te"]] - ref$te$est) < 1e-5),
          nie_se = s4d_ok(abs(se[["nie"]] - ref$ind$se) / ref$ind$se < 3e-3),
          nie_total_se = s4d_ok(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se < 3e-3),
          te_se = s4d_ok(abs(se[["te"]] - ref$te$se) / ref$te$se < 3e-3),
          hand_te_se = s4d_ok(abs(se[["te"]] - sb_se(z, g$te)) < 1e-12),
          hand_total_se = s4d_ok(abs(se[["nie_total"]] - sb_se(z, g$nie_total)) < 1e-12),
          covariates_recorded = s4d_ok(identical(unname(z@fit_context$covariate), c("Z1", "Z2"))),
          covariates_everywhere = s4d_ok(all(c("Z1", "Z2") %in% z@mediator_predictors[[1L]]) &&
                                           all(c("Z1", "Z2") %in% z@mediator_predictors[[2L]]) &&
                                           all(c("Z1", "Z2") %in% z@outcome_predictors)),
          alias_names = s4d_ok(identical(names(z@estimates), want_alias)),
          path_rows = s4d_ok({
            tp <- suppressWarnings(generics::tidy(z, type = "paths"))
            nrow(tp) == length(roles) && max(abs(tp$std_error - sqrt(diag(z@vcov)[names(z@estimates)]))) < 1e-12
          }),
          validator_forgeries = s4d_ok(all(vapply(s4d_env[[paste0("forged_", v)]], function(o) {
            !is.null(FIMLSerialMediationData@validator(o))
          }, logical(1)))),
          reversed_refused = s4d_class_error(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")),
                                             "medfit_error_fiml_extract_unsupported"),
          consumers_refuse = s4d_ok(grepl("not supported", tryCatch(pm(z), error = conditionMessage)) &&
                                      grepl("not supported", tryCatch(quick(z), error = conditionMessage)))
        )
      }
      if (sat) {
        r <- c(
          r,
          cov_treatment_z1 = s4d_cov_treatment(f, "Z1", s4d_env$ref_z1),
          cov_treatment_z2 = s4d_cov_treatment(f, "Z2", s4d_env$ref_z2),
          fixed_zero_message = s4d_ok({
            e <- tryCatch(s4_extract(s4d_env$f_zero, treatment = "Z1"), error = identity)
            inherits(e, "medfit_error_fiml_extract_unsupported") && grepl("fixed-zero direct path", conditionMessage(e))
          })
        )
      } else {
        r <- c(
          r,
          chain_cov_refused_z1 = s4d_class_error(s4_extract(f, treatment = "Z1"), cls),
          chain_cov_refused_z2 = s4d_class_error(s4_extract(f, treatment = "Z2"), cls),
          chain_structural_ok = s4d_ok(identical(s4_extract(f, treatment = "X")@treatment, "X"))
        )
      }
    }
    # a partial exogenous covariance set is refused with a reason that names it
    body <- if (sat) {
      s4_body(tail = c(s4_zeros, "X ~~ Z1"))
    } else {
      s4_body(m2 = "M2 ~ M1 + Z1 + Z2", y = "Y ~ M2 + X + Z1 + Z2", tail = c(s4_zeros, "X ~~ Z1"))
    }
    e <- tryCatch(fit_sem(body, s4d_env$d, missing = "fiml", fixed_x = FALSE), error = identity)
    r <- c(
      r,
      partial_exo_named = inherits(e, "medfit_sem_fiml_error") && grepl("exogenous covariance", conditionMessage(e)),
      # admission: a third covariate stays closed in both predicates (the parser refuses its fit outright)
      k3_shape_closed = !.fiml_serial_shape_admitted(v, 3L),
      k3_extract_closed = !.fiml_serial_extract_supported(v, 3L)
    )
    names(r) <- paste0(v, "_", names(r))
    out <- c(out, r)
  }
  out
}
s4d_mut <- function(name, ...) {
  fn <- get(name, envir = asNamespace("medfit"))
  pairs <- list(...)
  for (i in seq(1L, length(pairs), by = 2L)) fn <- sem_mutate(fn, pairs[[i]], pairs[[i + 1L]])
  fn
}
s4d_with <- function(name, fn) {
  args <- stats::setNames(list(fn), name)
  do.call(testthat::with_mocked_bindings, c(list(code = quote(s4d_battery())), args))
}
s4d_caught <- function(name, ...) {
  r <- s4d_with(name, s4d_mut(name, ...))
  list(failed = names(r)[!r], all_pass = all(r))
}
# a copy of the table builder that loses one row of the kernel tables (the parser sees the same copy, so the fit fails
# closed on the parameter count, not silently)
s4d_tables_without <- function(part, pred) {
  orig <- .sem_fiml_tables_ser
  function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    t[[part]] <- t[[part]][!pred(t[[part]]), , drop = FALSE]
    t
  }
}

test_that("the two-covariate battery passes on the unmutated code (positive control)", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_battery()
  expect_true(all(r), info = paste(names(r)[!r], collapse = ", "))
  expect_identical(length(r), 56L)
})

test_that("either covariate dropped from the M1, M2 or Y equation, or an exogenous covariance dropped, fails closed", {
  fx_skip_covr()
  s4d_setup()
  for (cell in list(
    list("a", function(a) a$row == "M1" & a$col == "Z2"),
    list("a", function(a) a$row == "M2" & a$col == "Z2"),
    list("a", function(a) a$row == "Y" & a$col == "Z2"),
    list("a", function(a) a$row == "M2" & a$col == "Z1"),
    list("s", function(s) s$row == "X" & s$col == "Z2"),
    list("s", function(s) s$row == "Z1" & s$col == "Z2")
  )) {
    r <- s4d_with(".sem_fiml_tables_ser", s4d_tables_without(cell[[1L]], cell[[2L]]))
    expect_false(all(r))
    expect_true(any(c("saturated_fits", "chain_fits") %in% names(r)[!r]))
  }
})

test_that("a wrong covariate index for a covariate treatment, or a chain that accepts one, is caught", {
  fx_skip_covr()
  s4d_setup()
  # the index of the named covariate ignored (always the first)
  r <- s4d_caught(".sem_fiml_extract_serial", "iz <- match(treatment, covariate)", "iz <- 1L")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment_z2" %in% r$failed)
  r <- s4d_caught(".sem_fiml_extract_serial", "par(paste0(\"gy\", sfx[iz]))", "par(paste0(\"gy\", sfx[1L]))")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment_z2" %in% r$failed)
  r <- s4d_caught(".sem_fiml_extract_serial", "par(paste0(\"gm2z\", iz))", "par(paste0(\"gm2z\", 1L))")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment_z2" %in% r$failed)
  r <- s4d_caught(".sem_fiml_extract_serial", "par(paste0(\"gm1z\", iz))", "par(\"a\")")
  expect_false(r$all_pass)
  expect_true(all(c("saturated_cov_treatment_z1", "saturated_cov_treatment_z2") %in% r$failed))
  # the swap of the treatment and the covariate in the recorded context is forgotten, or swaps the first covariate
  r <- s4d_caught(".sem_fiml_extract_serial", "ctx$covariate <- zz", "ctx$covariate <- covariate")
  expect_false(r$all_pass)
  expect_true(any(grepl("cov_treatment", r$failed)))
  r <- s4d_caught(".sem_fiml_extract_serial", "replace(covariate, iz, x0)", "replace(covariate, 1L, x0)")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment_z2" %in% r$failed)
  # Q6a: the chain accepts a covariate as the treatment (both gates removed)
  r <- s4d_caught(".sem_fiml_extract_serial", "if (chain && named_cov) {", "if (FALSE) {",
                  "(named_cov && !chain && spec$direct)", "(named_cov && spec$direct)")
  expect_false(r$all_pass)
  expect_true(all(c("chain_chain_cov_refused_z1", "chain_chain_cov_refused_z2") %in% r$failed))
})

test_that("reason defects: the partial exogenous set and the fixed-zero other treatment lose their reasons", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_caught(".sem_fiml_model_ser", "if (any(!exo_cov %in% keys)) {", "if (FALSE) {")
  expect_false(r$all_pass)
  expect_true(all(c("saturated_partial_exo_named", "chain_partial_exo_named") %in% r$failed))
  r <- s4d_caught(".sem_fiml_extract_serial", "if (!chain && !spec$direct && named_cov) {", "if (FALSE) {")
  expect_false(r$all_pass)
  expect_true("saturated_fixed_zero_message" %in% r$failed)
})

test_that("extraction defects with two covariates: dropped predictors and covariance blocks, swapped paths", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_caught(".sem_fiml_extract_serial", "list(c(x, zz), c(meds[1L]", "list(c(x, zz[1L]), c(meds[1L]")
  expect_false(r$all_pass)
  expect_true(any(grepl("extraction", r$failed)))
  r <- s4d_caught(".sem_fiml_extract_serial", "meds[2L], x, zz)", "meds[2L], x, zz[1L])")
  expect_false(r$all_pass)
  expect_true(any(grepl("extraction", r$failed)))
  r <- s4d_caught(
    ".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
    "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("alias_est|alias_vcov", r$failed)))
  r <- s4d_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    "V[present, present] <- diag(diag(object@vcov[roles[present], roles[present], drop = FALSE]))"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("alias_vcov|te_se|nie_total_se", r$failed)))
  r <- s4d_caught(".sem_fiml_extract_serial", "chain <- identical(ctx0$variant, \"chain\")", "chain <- FALSE")
  expect_false(r$all_pass)
  expect_true("chain_extraction" %in% r$failed)
})

test_that("fit-level defects with two covariates: the second covariate's centering, the unit, the exogenous block", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_caught(
    ".sem_fiml_transport", "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- scale[cv$row]^2"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("estimates|vcov_full|loglik", r$failed)))
  # the intercept offset of the SECOND covariate's paths dropped (its centering is not carried into the intercepts)
  r <- s4d_caught(
    ".sem_fiml_transport",
    "transport[layout$intercepts$par[r], path$par] <- -center[path$predictor] * units[path$par]",
    paste0(
      "transport[layout$intercepts$par[r], path$par] <- -center[path$predictor] * units[path$par] * ",
      "(path$predictor != \"Z2\")"
    )
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("estimates|vcov_full", r$failed)))
  # the exogenous covariance block of the fitted covariance zeroed, including the Z1-Z2 pair
  orig <- .sem_fiml_solve
  r <- s4d_with(".sem_fiml_solve", function(prepared) {
    o <- orig(prepared)
    i <- intersect(c("vx", "vz1", "vz2", "cxz1", "cxz2", "cz1z2", "ix", "iz1", "iz2"), rownames(o$covariance))
    o$covariance[i, ] <- 0
    o$covariance[, i] <- 0
    o
  })
  expect_false(all(r))
  expect_true(any(grepl("vcov_full", names(r)[!r])))
})

test_that("effect defects with two covariates: the total-indirect gradient is the chain one, te lacks c_prime", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_caught(".effect_gradients", "g_te[names(g_te) != \"c_prime\"]", "g_nie")
  expect_false(r$all_pass)
  expect_true(any(grepl("nie_total_se|hand_total_se", r$failed)))
  r <- s4d_caught(
    ".effect_gradients", "g_te <- .serial_te_gradient(x)", "g_te <- .serial_te_gradient(x)[c(\"a\", \"d1\", \"b\")]"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("te_se|hand_te_se", r$failed)))
})

test_that("admission defects: the predicates ignoring the covariate count open k = 3", {
  fx_skip_covr()
  s4d_setup()
  r <- s4d_caught(".fiml_serial_shape_admitted", "as.integer(k) %in% 0:2", "TRUE")
  expect_false(r$all_pass)
  expect_true(any(grepl("k3_shape_closed", r$failed)))
  r <- s4d_caught(".fiml_serial_extract_supported", "as.integer(k) %in% 0:2", "TRUE")
  expect_false(r$all_pass)
  expect_true(any(grepl("k3_extract_closed", r$failed)))
  # the predicate that stops at one covariate (a regression of slice S4)
  r <- s4d_caught(".fiml_serial_shape_admitted", "as.integer(k) %in% 0:2", "as.integer(k) %in% 0:1")
  expect_false(r$all_pass)
  expect_true(any(grepl("fits", r$failed)))
})
