# Monthly QC run (planning/specs/BRAINSTORM-optimizer-quality-control-2026-10-23.md, Q-5 and Q-6): the pieces the
# scheduled workflow (.github/workflows/qc-monthly.yaml) calls, kept in R so they can be tested
# (tests/testthat/test-qc-lib.R).
# One history row per run: the run's identity, the environment fingerprint, one PASS/FAIL column per gate, and the
# tracked metrics. Alerts fire on a failing gate and on a changed fingerprint (R, BLAS, nloptr, lavaan, OpenMx); the
# runner image is recorded and never alerts. Drift bands are not set: they need about 8 rows (Q-5; eight months at
# the monthly cadence).

qc_alert_keys <- c("r_version", "blas", "nloptr", "lavaan", "openmx")

qc_env_fingerprint <- function() {
  ver <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else NA_character_
  list(r_version = paste(R.version$major, R.version$minor, sep = "."),
       blas = unname(extSoftVersion()["BLAS"]), nloptr = ver("nloptr"), lavaan = ver("lavaan"), openmx = ver("OpenMx"),
       image = Sys.getenv("ImageVersion", NA_character_))
}

# "gate  PASS|FAIL  [file]" lines of a run-gates.R summary -> named character vector
qc_gate_status <- function(lines) {
  m <- regmatches(lines, regexec("^([A-Za-z0-9-]+)\\s+(PASS|FAIL)\\s", lines))
  m <- m[lengths(m) == 3L]
  stats::setNames(vapply(m, `[`, "", 3L), vapply(m, `[`, "", 2L))
}

qc_latest <- function(dir, prefix) {
  f <- sort(list.files(dir, pattern = paste0("^", prefix, "-?[0-9-]*\\.csv(\\.gz)?$"), full.names = TRUE))
  if (length(f)) f[length(f)] else NA_character_
}
qc_safely <- function(expr) tryCatch(expr, error = function(e) NA)

# the metrics of one shard's results directory; a metric whose file is absent is NA, never an error
qc_metrics <- function(dir) {
  rho <- qc_safely({
    x <- utils::read.csv(qc_latest(dir, "sem-restoration-gate"), stringsAsFactors = FALSE)
    as.numeric(x$value[startsWith(x$check, "separation:") & x$kind == "observed"][1L])
  })
  rel <- qc_safely({
    x <- utils::read.csv(qc_latest(dir, "sem-reliability"), stringsAsFactors = FALSE)
    ship <- x$algo == "SLSQP" & x$precond %in% TRUE & x$mode == "retry"
    mean(as.logical(x$match[ship]))
  })
  sweep <- qc_safely({
    x <- utils::read.csv(qc_latest(dir, "sem-oracle-sweep"), stringsAsFactors = FALSE)
    paste(names(table(x$outcome)), as.integer(table(x$outcome)), sep = "=", collapse = ";")
  })
  list(restoration_max_rho = rho, reliability_match = rel, oracle_sweep_outcomes = sweep)
}

# one shard's history row: identity, fingerprint, gate status columns (gate_<name>), metrics
qc_row <- function(summary_lines, dir, sha, ref, date = format(Sys.Date())) {
  st <- qc_gate_status(summary_lines)
  g <- as.list(stats::setNames(unname(st), paste0("gate_", names(st))))
  as.data.frame(c(list(date = date, sha = sha, ref = ref), qc_env_fingerprint(), g, qc_metrics(dir)),
                stringsAsFactors = FALSE, check.names = FALSE)
}

# shard rows of one run -> one row: the first non-NA value wins, except that a gate column is FAIL when any shard
# failed it
qc_merge <- function(rows) {
  cols <- unique(unlist(lapply(rows, names)))
  out <- stats::setNames(vector("list", length(cols)), cols)
  for (cn in cols) {
    v <- unlist(lapply(rows, function(r) if (cn %in% names(r)) r[[cn]] else NA))
    out[[cn]] <- if (all(is.na(v))) {
      NA
    } else if (startsWith(cn, "gate_") && any(v %in% "FAIL")) {
      "FAIL"
    } else {
      v[!is.na(v)][1L]
    }
  }
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

# append to a history, aligning columns (a gate added later gets NA in the older rows)
qc_append <- function(history, row) {
  if (is.null(history) || !nrow(history)) return(row)
  cols <- union(names(history), names(row))
  fill <- function(d) {
    for (cn in setdiff(cols, names(d))) d[[cn]] <- NA
    d[cols]
  }
  rbind(fill(history), fill(row))
}

# alerts for a new row against the previous one: failing gates, and fingerprint keys whose value changed
qc_alerts <- function(new, prev = NULL, planted = FALSE) {
  st <- unlist(new[grep("^gate_", names(new))])
  failing <- sub("^gate_", "", names(st)[st %in% "FAIL"])
  if (planted) failing <- c(failing, "planted-test")
  changed <- character()
  if (!is.null(prev) && nrow(prev)) {
    p <- prev[nrow(prev), , drop = FALSE]
    for (k in qc_alert_keys) {
      a <- as.character(new[[k]])
      b <- as.character(p[[k]])
      if (!identical(a, b) && !(is.na(a) && is.na(b))) changed <- c(changed, sprintf("%s: %s -> %s", k, b, a))
    }
  }
  list(gate_failures = failing, env_changes = changed)
}

# ---- the QC article (vignettes/articles/quality-control.qmd) renders these at site build, so it cannot drift ----

# gate catalog: one row per gates.csv row, with the structures (structures.csv) that name the gate
qc_gate_table <- function(gates, structures) {
  covers <- vapply(gates$gate, function(g) {
    has <- vapply(structures$gates, function(x) g %in% strsplit(x, "|", fixed = TRUE)[[1L]], TRUE)
    paste(structures$structure[has], collapse = "; ")
  }, "")
  data.frame(Gate = gates$gate, `Checked against` = gates$oracle,
             `Planted defects` = gsub("|", ", ", gates$mutants, fixed = TRUE), Structures = covers,
             check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)
}

# the decisions of the YAML front matter of each ADR file, one row per decision
qc_decision_table <- function(adr_files) {
  rows <- lapply(adr_files, function(f) {
    lines <- readLines(f, warn = FALSE)
    end <- which(lines[-1L] == "---")[1L] + 1L
    if (!identical(lines[1L], "---") || is.na(end)) return(NULL)
    dec <- yaml::yaml.load(paste(lines[2:(end - 1L)], collapse = "\n"))$decisions
    do.call(rbind, lapply(dec, function(d) {
      data.frame(Id = as.character(d$id), Decision = d$title, Status = d$status, Date = as.character(d$date),
                 ADR = sub("\\.md$", "", basename(f)), stringsAsFactors = FALSE)
    }))
  })
  do.call(rbind, rows)
}
