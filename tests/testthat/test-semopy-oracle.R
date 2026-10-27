# The semopy oracle gate (ADR D-13; tests/sim/semopy-oracle-gate.R): the pure-R pieces, without Python. Name mapping
# from semopy's inspect() table to medfit's lavaan-style names, the counting rule (semopy counts only where it agrees
# with lavaan; a row where it does not is "disputed", neither pass nor fail), the n/a skip when uv is absent, the
# driver's re-derived verdict, and the monthly-only registration (the gate must not run in the PR gates shards).
so_lib <- test_path("..", "sim", "semopy-oracle-lib.R")
skip_if_not(file.exists(so_lib), "tests/sim is not shipped with the installed tests")
source(so_lib, local = TRUE)

so_spec <- data.frame(gate = "semopy", expected_rows = 4L, min_pass = 3L, tol_est = 1e-6, tol_se = 1e-3)

test_that("measurement pairs are read from the model syntax", {
  pairs <- so_measurement_pairs("eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X")
  expect_identical(pairs, c("eta=~m1", "eta=~m2", "eta=~m3"))
  expect_identical(so_measurement_pairs("M ~ X\nY ~ M + X"), character(0))
})

test_that("semopy rows map to medfit names: loadings reversed, fixed marker dropped, covariances canonical", {
  model <- "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X\nm2 ~~ m3"
  rows <- data.frame(
    lval = c("eta", "m1", "m2", "Y", "Y", "m3", "eta", "Y"),
    op = c("~", "~", "~", "~", "~", "~~", "~~", "~~"),
    rval = c("X", "eta", "eta", "eta", "X", "m2", "eta", "Y"),
    estimate = c(0.5, 1, 0.9, 0.4, 0.2, 0.05, 0.7, 0.6),
    se = c(0.08, NA, 0.07, 0.06, 0.05, 0.01, 0.09, 0.06),
    fixed = c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  m <- so_map_names(rows, model)
  # Y ~ eta is a regression (eta is not measured by Y); m2 ~ eta is the loading eta =~ m2; m1 ~ eta is the fixed marker
  expect_setequal(m$name, c("eta~X", "eta=~m2", "Y~eta", "Y~X", "m2~~m3", "eta~~eta", "Y~~Y"))
  expect_identical(m$estimate[m$name == "eta=~m2"], 0.9)
  expect_identical(so_key(c("m3~~m2", "m2~~m3", "Y~X", "eta=~m2")), c("m2~~m3", "m2~~m3", "Y~X", "eta=~m2"))
  # a free parameter with a missing SE is kept (it becomes a failed comparison), never dropped as if it were fixed
  rows$se[3] <- NA
  expect_true("eta=~m2" %in% so_map_names(rows, model)$name)
})

test_that("the counting rule: pass needs semopy to agree with both medfit and lavaan", {
  st <- so_status(
    est_gap = c(1e-8, 1e-8, 1e-4, 1e-8, NA, 1e-4),
    se_rel = c(1e-5, 1e-2, 1e-5, 1e-5, 1e-5, 1e-5),
    sl_est_gap = c(1e-8, 1e-8, 1e-8, 1e-4, 1e-8, 1e-4),
    sl_se_rel = c(1e-5, 1e-5, 1e-5, 1e-5, 1e-5, 1e-5),
    tol_est = 1e-6, tol_se = 1e-3
  )
  # 4: semopy off lavaan -> disputed, even though medfit agrees with semopy; 6: off both -> disputed, not fail
  expect_identical(st, c("pass", "fail", "fail", "disputed", "fail", "disputed"))
  expect_identical(so_status(1e-8, 1e-5, NA, 1e-5, 1e-6, 1e-3), "disputed")
})

test_that("comparison flags a parameter missing on any side as unmatched", {
  med <- data.frame(name = c("M~X", "Y~M", "Y~~Y"), estimate = c(0.5, 0.4, 1), se = c(0.1, 0.1, 0.1))
  sem <- data.frame(name = c("M~X", "Y~M"), estimate = c(0.5, 0.4), se = c(0.1, 0.1))
  lav <- data.frame(name = c("M~X", "Y~M", "Y~~Y"), estimate = c(0.5, 0.4, 1), se = c(0.1, 0.1, 0.1))
  r <- so_compare(med, sem, lav, tol_est = 1e-6, tol_se = 1e-3)
  expect_identical(r$status[r$param == "Y~~Y"], "unmatched")
  expect_identical(r$status[r$param == "M~X"], "pass")
  sem_extra <- rbind(sem, data.frame(name = c("Y~~Y", "X~~X"), estimate = 1, se = 0.1))
  r2 <- so_compare(med, sem_extra, lav, tol_est = 1e-6, tol_se = 1e-3)
  expect_identical(r2$status[r2$param == "X~~X"], "unmatched")
  expect_identical(nrow(r2), 4L)
})

test_that("an absent uv gives n/a rows and a skip, unless semopy is required", {
  expect_identical(so_uv(env = ""), so_uv_lookup())
  withr::local_envvar(MEDFIT_UV = file.path(tempdir(), "no-such-uv"))
  expect_identical(so_uv(), "")
  out <- so_run_semopy(data.frame(id = "a", model = "M ~ X", data = "x.csv"), uv = "")
  expect_false(out$ok)
  expect_match(out$why, "uv")
  d <- data.frame(param = c("M~X", "Y~M", "Y~X", "Y~~Y"), status = "n/a", est_gap = NA_real_, se_rel = NA_real_,
                  sl_est_gap = NA_real_, sl_se_rel = NA_real_, reason = out$why)
  v <- so_gate_checks(d, so_spec, required = FALSE)
  expect_true(all(v$pass))
  expect_true(any(grepl("skipped", v$detail)))
  expect_false(all(so_gate_checks(d, so_spec, required = TRUE)$pass))
})

so_ok_rows <- function() {
  data.frame(param = c("M~X", "Y~M", "Y~X", "Y~~Y"), status = c("pass", "pass", "pass", "disputed"),
             est_gap = c(1e-8, 2e-8, 3e-8, 5e-4), se_rel = 1e-5, sl_est_gap = c(1e-8, 1e-8, 1e-8, 5e-4),
             sl_se_rel = 1e-5, reason = "")
}

test_that("the driver verdict re-derives each status and enforces the pass floor", {
  expect_true(all(so_gate_checks(so_ok_rows(), so_spec, required = TRUE)$pass))
  lie <- so_ok_rows()
  lie$est_gap[1] <- 1e-3 # the status column still says pass
  v <- so_gate_checks(lie, so_spec, required = FALSE)
  expect_false(v$pass[v$check == "status re-derived"])
  # every row disputed: no fail row, but the gate tested nothing and must not pass
  all_disp <- so_ok_rows()
  all_disp$sl_est_gap <- 1e-3
  all_disp$status <- "disputed"
  expect_false(all(so_gate_checks(all_disp, so_spec, required = FALSE)$pass))
  # n/a mixed with judged rows is not a skip
  mixed <- so_ok_rows()
  mixed$status[1] <- "n/a"
  expect_false(all(so_gate_checks(mixed, so_spec, required = FALSE)$pass))
  err <- so_ok_rows()
  err$status[2] <- "error"
  expect_false(all(so_gate_checks(err, so_spec, required = FALSE)$pass))
  expect_false(all(so_gate_checks(so_ok_rows()[-1, ], so_spec, required = FALSE)$pass))
})

test_that("the semopy gate is monthly-only: registered, kept out of the PR gates shards, run by qc-monthly", {
  root <- test_path("..", "..")
  gates_yaml <- file.path(root, ".github", "workflows", "gates.yaml")
  qc_yaml <- file.path(root, ".github", "workflows", "qc-monthly.yaml")
  skip_if_not(file.exists(gates_yaml) && file.exists(qc_yaml), "workflows are not shipped with the installed tests")
  monthly <- so_monthly_gates(file.path(root, "tests", "sim", "gates-monthly.txt"))
  ids <- utils::read.csv(file.path(root, "tests", "sim", "gates.csv"), stringsAsFactors = FALSE)$gate
  expect_true("semopy" %in% monthly)
  expect_true(all(monthly %in% ids))
  expect_false(any(grepl("--monthly", readLines(gates_yaml), fixed = TRUE)))
  expect_true(any(grepl("run-gates.R --sim --only \"$only\" --monthly", readLines(qc_yaml), fixed = TRUE)))
  spec <- data.frame(gate = c("parity", "semopy"))
  expect_identical(so_drop_monthly(spec, monthly, enabled = FALSE)$gate, "parity")
  expect_identical(so_drop_monthly(spec, monthly, enabled = TRUE)$gate, c("parity", "semopy"))
})

test_that("the gate script and the semopy runner exist with the declared conventions", {
  root <- test_path("..", "..")
  py <- readLines(file.path(root, "tests", "sim", "semopy-oracle.py"))
  expect_true(any(grepl("obj=\"MLW\"", py, fixed = TRUE)))
  expect_true(any(grepl("\"ftol\": 1e-12", py, fixed = TRUE)))
  expect_true(any(grepl("information=\"observed\"", py, fixed = TRUE)))
  gate <- readLines(file.path(root, "tests", "sim", "semopy-oracle-gate.R"))
  expect_true(any(grepl("fixed_x = TRUE", gate, fixed = TRUE)))
  expect_true(any(grepl("information = \"observed\"", gate, fixed = TRUE)))
})

test_that("semopy itself runs through uv when available", {
  skip_on_cran()
  uv <- so_uv()
  skip_if(!nzchar(uv), "uv is not installed")
  d <- data.frame(X = c(0.1, -1.2, 0.4, 1.5, -0.3, 0.8, -0.9, 0.2, 1.1, -0.6))
  d$M <- 0.5 * d$X + c(0.3, -0.2, 0.1, 0.4, -0.5, 0.2, 0.0, -0.1, 0.3, -0.4)
  f <- file.path(withr::local_tempdir(), "d.csv")
  utils::write.csv(d, f, row.names = FALSE)
  out <- so_run_semopy(data.frame(id = "a", model = "M ~ X", data = f), uv = uv)
  skip_if(!out$ok && grepl("could not start|timed out", out$why), out$why)
  expect_true(out$ok)
  r <- out$rows[out$rows$op == "~", ]
  expect_equal(r$estimate, unname(stats::coef(stats::lm(M ~ X, d))[2]), tolerance = 1e-6)
  expect_true(nzchar(out$versions[["semopy"]]))
})
