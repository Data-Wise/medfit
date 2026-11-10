# FI-G3 slice S3: planted defects in the serial FIML code with ONE covariate (both variants). A battery of independent
# checks (lavaan values, the relabeled-treatment reference, hand gradients, predictor lists, validator forgeries, the
# chain's covariate-as-treatment refusal, the k = 3 admission) is run on the unmutated code first (the positive control:
# it passes) and then on one deliberately broken copy of one function at a time; every defect must fail at least one
# check. The data are incomplete (cross-equation covariance defects are invisible on complete data) and the covariate
# effects are large and distinct from the paths (a covariate coefficient taken for a path cannot hide). Helpers:
# helper-fiml-serial.R (sb_*) and helper-fiml-serial3.R (s3_*). The covr guard is that of the earlier defect batteries
# (function bodies are mutated).

s3d_env <- new.env(parent = emptyenv())
s3d_setup <- function() {
  if (is.null(s3d_env$d)) {
    skip_if_not_installed("lavaan")
    d <- s3_data("mar", a2 = .3, b1 = .25)
    s3d_env$d <- d
    for (v in c("saturated", "chain")) {
      s3d_env[[v]] <- list(
        ref = s3_reference(d, v, "free"),
        plain_fit = sb_lavaan(s3_model(v, "free"), d)
      )
      s3d_env[[v]]$plain <- lavaan::coef(s3d_env[[v]]$plain_fit)
    }
    s3d_env$ref_z <- s3_reference(d, "saturated", "free", tr = "Z", cv = "X")
    # forged objects for the validator battery: built without the validator, then judged by it
    forge <- function(z, ...) {
      for (nm in names(list(...))) attr(z, nm) <- list(...)[[nm]]
      z
    }
    for (v in c("saturated", "chain")) {
      z <- s3_extract(s3_fit(d, v, "free"))
      s3d_env[[paste0("forged_", v)]] <- list(
        m1 = forge(z, mediator_predictors = list("X", z@mediator_predictors[[2L]])),
        m2 = forge(z, mediator_predictors = list(
          z@mediator_predictors[[1L]], setdiff(z@mediator_predictors[[2L]], "Z")
        )),
        y = forge(z, outcome_predictors = setdiff(z@outcome_predictors, "Z")),
        wrong_treatment = forge(z, treatment = "Z")
      )
    }
  }
  invisible(NULL)
}
s3d_ok <- function(expr) isTRUE(tryCatch(suppressWarnings(expr), error = function(e) FALSE))
s3d_class_error <- function(expr, class) {
  e <- tryCatch({
    suppressWarnings(expr)
    NULL
  }, error = identity)
  inherits(e, class)
}
s3d_battery <- function() {
  out <- c()
  for (v in c("saturated", "chain")) {
    sat <- v == "saturated"
    ref <- s3d_env[[v]]$ref
    plain <- s3d_env[[v]]$plain
    roles <- names(ref$est)
    f <- tryCatch(s3_fit(s3d_env$d, v, "free"), error = identity)
    r <- c(fits = !inherits(f, "error"))
    if (isTRUE(r[["fits"]])) {
      q <- coef(f)
      z <- tryCatch(s3_extract(f), error = identity)
      r <- c(
        r,
        q_count = length(f@theta) == if (sat) 20L else 18L,
        estimates = s3d_ok(max(abs(q - s3_align_v(plain, names(q)))) < 1e-5),
        loglik = s3d_ok(abs(as.numeric(logLik(f)) - ref$logl) < 1e-6),
        vcov_full = s3d_ok(
          sb_rel_gap(unname(vcov(f)), unname(s3_align_m(lavaan::vcov(s3d_env[[v]]$plain_fit), names(q)))) < 2e-3
        ),
        extraction = !inherits(z, "error")
      )
      if (!inherits(z, "error")) {
        tb <- suppressWarnings(generics::tidy(z, type = "effects"))
        se <- stats::setNames(tb$std_error, tb$term)
        est <- stats::setNames(tb$estimate, tb$term)
        g <- s3_grad(z)
        want_alias <- if (sat) c("a", "a2", "d1", "b1", "b", "c_prime") else c("a", "d1", "b", "c_prime")
        r <- c(
          r,
          alias_est = s3d_ok(max(abs(z@estimates[roles] - ref$est)) < 1e-5),
          alias_vcov = s3d_ok(sb_rel_gap(z@vcov[roles, roles], ref$vcov) < 2e-3),
          nie_total_est = s3d_ok(abs(est[["nie_total"]] - ref$ind_tot$est) < 1e-5),
          te_est = s3d_ok(abs(est[["te"]] - ref$te$est) < 1e-5),
          nie_se = s3d_ok(abs(se[["nie"]] - ref$ind$se) / ref$ind$se < 3e-3),
          nie_total_se = s3d_ok(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se < 3e-3),
          te_se = s3d_ok(abs(se[["te"]] - ref$te$se) / ref$te$se < 3e-3),
          hand_te_se = s3d_ok(abs(se[["te"]] - sb_se(z, g$te)) < 1e-12),
          hand_total_se = s3d_ok(abs(se[["nie_total"]] - sb_se(z, g$nie_total)) < 1e-12),
          covariate_recorded = s3d_ok(identical(z@fit_context$covariate, "Z")),
          covariate_everywhere = s3d_ok("Z" %in% z@mediator_predictors[[1L]] && "Z" %in% z@mediator_predictors[[2L]] &&
                                          "Z" %in% z@outcome_predictors),
          alias_names = s3d_ok(identical(names(z@estimates), want_alias)),
          path_rows = s3d_ok({
            tp <- suppressWarnings(generics::tidy(z, type = "paths"))
            nrow(tp) == length(roles) && max(abs(tp$std_error - sqrt(diag(z@vcov)[names(z@estimates)]))) < 1e-12
          }),
          validator_forgeries = s3d_ok(all(vapply(s3d_env[[paste0("forged_", v)]], function(o) {
            !is.null(FIMLSerialMediationData@validator(o))
          }, logical(1)))),
          reversed_refused = s3d_class_error(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")),
                                             "medfit_error_fiml_extract_unsupported"),
          consumers_refuse = s3d_ok(grepl("not supported", tryCatch(pm(z), error = conditionMessage)) &&
                                      grepl("not supported", tryCatch(quick(z), error = conditionMessage)))
        )
      }
      if (sat) {
        zt <- tryCatch(s3_extract(f, treatment = "Z"), error = identity)
        r <- c(
          r,
          cov_treatment = s3d_ok({
            rz <- s3d_env$ref_z
            max(abs(zt@estimates[names(rz$est)] - rz$est)) < 1e-5 &&
              sb_rel_gap(zt@vcov[names(rz$est), names(rz$est)], rz$vcov) < 2e-3 && identical(zt@treatment, "Z")
          })
        )
      } else {
        r <- c(
          r,
          chain_cov_refused = s3d_class_error(s3_extract(f, treatment = "Z"), "medfit_error_fiml_extract_unsupported"),
          chain_structural_ok = s3d_ok(identical(s3_extract(f, treatment = "X")@treatment, "X"))
        )
      }
    }
    # admission: a third covariate stays closed in both predicates (the parser refuses its fit outright)
    r <- c(
      r,
      k3_shape_closed = !.fiml_serial_shape_admitted(v, 3L),
      k3_extract_closed = !.fiml_serial_extract_supported(v, 3L)
    )
    names(r) <- paste0(v, "_", names(r))
    out <- c(out, r)
  }
  out
}
s3d_mut <- function(name, ...) {
  fn <- get(name, envir = asNamespace("medfit"))
  pairs <- list(...)
  for (i in seq(1L, length(pairs), by = 2L)) fn <- sem_mutate(fn, pairs[[i]], pairs[[i + 1L]])
  fn
}
s3d_with <- function(name, fn) {
  args <- stats::setNames(list(fn), name)
  do.call(testthat::with_mocked_bindings, c(list(code = quote(s3d_battery())), args))
}
s3d_caught <- function(name, ...) {
  r <- s3d_with(name, s3d_mut(name, ...))
  list(failed = names(r)[!r], all_pass = all(r))
}
# a copy of the table builder that loses one row of the kernel tables (the parser sees the same copy, so the fit fails
# closed on the parameter count, not silently)
s3d_tables_without <- function(part, pred) {
  orig <- .sem_fiml_tables_ser
  function(direct, k, shortcuts) {
    t <- orig(direct, k, shortcuts)
    t[[part]] <- t[[part]][!pred(t[[part]]), , drop = FALSE]
    t
  }
}

test_that("the covariate battery passes on the unmutated code (positive control)", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_battery()
  expect_true(all(r), info = paste(names(r)[!r], collapse = ", "))
  expect_gte(length(r), 50L)
})

test_that("a covariate dropped from the M1, M2 or Y equation, or the exogenous covariance dropped, fails closed", {
  fx_skip_covr()
  s3d_setup()
  for (cell in list(
    list("a", function(a) a$row == "M1" & a$col == "Z"),
    list("a", function(a) a$row == "M2" & a$col == "Z"),
    list("a", function(a) a$row == "Y" & a$col == "Z"),
    list("s", function(s) s$row == "X" & s$col == "Z")
  )) {
    r <- s3d_with(".sem_fiml_tables_ser", s3d_tables_without(cell[[1L]], cell[[2L]]))
    expect_false(all(r))
    expect_true(any(c("saturated_fits", "chain_fits") %in% names(r)[!r]))
  }
})

test_that("a covariate path taken for a path alias fails the alias, estimate and SE checks", {
  fx_skip_covr()
  s3d_setup()
  for (m in list(
    list("else par(\"a\"),", "else par(\"gm1z1\"),"),
    list("else par(\"a2\"))", "else par(\"gm2z1\"))"),
    list("c(b1 = par(\"b1\"))", "c(b1 = par(\"gy\"))"),
    list("else if (spec$direct) par(\"cp\")", "else if (spec$direct) par(\"gy\")"),
    list("else par(\"a\"),", "else par(\"a2\"),")
  )) {
    r <- s3d_caught(".sem_fiml_extract_serial", m[[1L]], m[[2L]])
    expect_false(r$all_pass, info = m[[2L]])
    expect_true(any(grepl("alias_est|extraction|te_est|nie_total_est", r$failed)), info = m[[2L]])
  }
})

test_that("a wrong treatment mapping for a covariate treatment, or a chain that accepts one, is caught", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_caught(".sem_fiml_extract_serial", "par(paste0(\"gm1z\", iz))", "par(\"a\")")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment" %in% r$failed)
  r <- s3d_caught(".sem_fiml_extract_serial", "par(paste0(\"gy\", sfx[iz]))", "par(\"cp\")")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment" %in% r$failed)
  # the swap of the treatment and the covariate in the recorded context is forgotten
  r <- s3d_caught(".sem_fiml_extract_serial", "ctx$covariate <- zz", "ctx$covariate <- covariate")
  expect_false(r$all_pass)
  expect_true("saturated_cov_treatment" %in% r$failed)
  # Q6a: the chain accepts a covariate as the treatment (both gates removed)
  r <- s3d_caught(".sem_fiml_extract_serial", "if (chain && named_cov) {", "if (FALSE) {",
                  "(named_cov && !chain && spec$direct)", "(named_cov && spec$direct)")
  expect_false(r$all_pass)
  expect_true("chain_chain_cov_refused" %in% r$failed)
})

test_that("extraction defects with a covariate: swapped paths, dropped covariance blocks and predictors", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_caught(
    ".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
    "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("alias_est|alias_vcov", r$failed)))
  r <- s3d_caught(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    "V[present, present] <- diag(diag(object@vcov[roles[present], roles[present], drop = FALSE]))"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("alias_vcov|te_se|nie_total_se", r$failed)))
  r <- s3d_caught(".sem_fiml_extract_serial", "list(c(x, zz), c(meds[1L]", "list(x, c(meds[1L]")
  expect_false(r$all_pass)
  expect_true(any(grepl("extraction", r$failed)))
  r <- s3d_caught(".sem_fiml_extract_serial", "meds[2L], x, zz)", "meds[2L], x)")
  expect_false(r$all_pass)
  expect_true(any(grepl("extraction", r$failed)))
  # the six-alias vector on the chain, and the chain alias set on the saturated fit
  r <- s3d_caught(".sem_fiml_extract_serial", "chain <- identical(ctx0$variant, \"chain\")", "chain <- FALSE")
  expect_false(r$all_pass)
  expect_true("chain_extraction" %in% r$failed)
  r <- s3d_caught(".sem_fiml_extract_serial", "chain <- identical(ctx0$variant, \"chain\")", "chain <- TRUE")
  expect_false(r$all_pass)
  expect_true("saturated_extraction" %in% r$failed || "saturated_alias_names" %in% r$failed)
})

test_that("fit-level defects with a covariate: wrong covariance unit, dropped offsets, dropped exogenous block", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_caught(
    ".sem_fiml_transport", "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- scale[cv$row]^2"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("estimates|vcov_full|loglik", r$failed)))
  r <- s3d_caught(".sem_fiml_transport", "offset[i$par] <- center[i$var]", "offset[i$par] <- 0")
  expect_false(r$all_pass)
  expect_true(any(grepl("estimates", r$failed)))
  # the intercept offset of the covariate paths dropped (the covariate's centering is not carried into the intercepts)
  r <- s3d_caught(
    ".sem_fiml_transport",
    "transport[layout$intercepts$par[r], path$par] <- -center[path$predictor] * units[path$par]",
    paste0(
      "transport[layout$intercepts$par[r], path$par] <- -center[path$predictor] * units[path$par] * ",
      "(path$predictor != \"Z\")"
    )
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("estimates|vcov_full", r$failed)))
  # the exogenous covariance block of the fitted covariance zeroed
  orig <- .sem_fiml_solve
  r <- s3d_with(".sem_fiml_solve", function(prepared) {
    o <- orig(prepared)
    i <- intersect(c("vx", "vz", "cxz", "ix", "iz"), rownames(o$covariance))
    o$covariance[i, ] <- 0
    o$covariance[, i] <- 0
    o
  })
  expect_false(all(r))
  expect_true(any(grepl("vcov_full", names(r)[!r])))
})

test_that("effect defects with a covariate: a total-indirect gradient replaced by the chain one, te without c_prime", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_caught(".effect_gradients", "g_te[names(g_te) != \"c_prime\"]", "g_nie")
  expect_false(r$all_pass)
  expect_true(any(grepl("nie_total_se|hand_total_se", r$failed)))
  r <- s3d_caught(
    ".effect_gradients", "g_te <- .serial_te_gradient(x)", "g_te <- .serial_te_gradient(x)[c(\"a\", \"d1\", \"b\")]"
  )
  expect_false(r$all_pass)
  expect_true(any(grepl("te_se|hand_te_se", r$failed)))
})

test_that("admission defects: the predicates ignoring the covariate count open k = 3", {
  fx_skip_covr()
  s3d_setup()
  r <- s3d_caught(".fiml_serial_shape_admitted", "as.integer(k) %in% 0:2", "TRUE")
  expect_false(r$all_pass)
  expect_true(any(grepl("k3_shape_closed", r$failed)))
  r <- s3d_caught(".fiml_serial_extract_supported", "as.integer(k) %in% 0:2", "TRUE")
  expect_false(r$all_pass)
  expect_true(any(grepl("k3_extract_closed", r$failed)))
})
