# FIML stage-0 timing pilot. Run from the repo root: Rscript planning/studies/fiml-timing-pilot/pilot.R [smoke]
args <- commandArgs(TRUE); smoke <- "smoke" %in% args
out <- "_agents_workspace/fiml-timing-pilot"; dir.create(out, recursive = TRUE, showWarnings = FALSE)
dirty <- grep("_agents_workspace", system("git status --porcelain", intern = TRUE), value = TRUE, invert = TRUE)
stopifnot(length(dirty) == 0L)
src <- system("git rev-parse HEAD", intern = TRUE)
devtools::load_all(quiet = TRUE)
# Study-only override of the stage-0 guard (in-process, never committed).
utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")
stopifnot(isTRUE(medfit:::.fiml_source_inference_admitted()))
writeLines(c(paste("source", src), R.version.string, paste("cores", parallel::detectCores()),
             paste("blas", extSoftVersion()[["BLAS"]]), paste("lavaan-free; medfit", as.character(packageVersion("medfit"))),
             paste("smoke", smoke), "guard override applied in-process: TRUE", paste("start", format(Sys.time(), tz = "UTC", usetz = TRUE))),
           file.path(out, "env.txt"))
B <- if (smoke) 20L else 999L; ND <- 20000L; D <- if (smoke) 1L else 3L
TOTAL <- if (smoke) 300 else 7200; CELLCAP <- if (smoke) 60 else 900
gen <- function(n, miss, direct, seed) {
  set.seed(seed); a <- .4; b <- .4; cc <- if (direct) .2 else 0
  draw <- function(k) { x <- rnorm(k); m <- a * x + rnorm(k); y <- cc * x + b * m + rnorm(k); cbind(X = x, M = m, Y = y) }
  mask <- function(d) {
    k <- nrow(d)
    if (miss == "mar") { p <- plogis(log(.2 / .8) + .5 * d[, "X"]); d[runif(k) < p, "M"] <- NA; d[runif(k) < p, "Y"] <- NA }
    else { d[runif(k) < .2, "M"] <- NA; d[runif(k) < .2, "Y"] <- NA }
    d
  }
  if (miss != "empty") return(structure(as.data.frame(mask(draw(n))), collected = n))
  kept <- NULL; coll <- 0L
  while (NROW(kept) < n && coll < 10L * n) {
    d <- mask(draw(1L)); coll <- coll + 1L
    if (runif(1) < .1) d[] <- NA
    if (!all(is.na(d))) kept <- rbind(kept, d)
  }
  if (NROW(kept) < n) stop("collection cap reached")
  structure(as.data.frame(kept), collected = coll)
}
cells <- expand.grid(n = c(200L, 500L), miss = c("mcar", "mar", "empty"), direct = c(TRUE, FALSE), stringsAsFactors = FALSE)
# Each timed unit runs in a forked child that is SIGKILLed at its limit: setTimeLimit errors are
# swallowed by tryCatch(error=) inside the package, so they cannot enforce a cap (QA finding).
run_child <- function(fun, limit) {
  s <- proc.time()[["elapsed"]]
  job <- parallel::mcparallel(fun(), silent = TRUE)
  res <- parallel::mccollect(job, wait = FALSE, timeout = max(limit, 1))
  if (is.null(res)) {
    tools::pskill(job$pid, tools::SIGKILL); parallel::mccollect(job)
    return(list(status = "timeout", seconds = round(proc.time()[["elapsed"]] - s, 3), reason = paste("killed at", round(limit), "s")))
  }
  r <- res[[1]]
  if (inherits(r, "try-error") || !is.list(r)) r <- list(status = "child_error", reason = as.character(r))
  r$seconds <- round(proc.time()[["elapsed"]] - s, 3); r
}
unit <- function(meth, mod, dat, seed) function() {
  tryCatch({
    t0 <- proc.time()[["elapsed"]]
    fit <- fit_sem(mod, dat, missing = "fiml", fixed_x = FALSE)
    fit_s <- proc.time()[["elapsed"]] - t0
    if (meth == "fit") return(list(status = "ok", reason = "", fit_seconds = fit_s))
    t1 <- proc.time()[["elapsed"]]
    r <- bootstrap_mediation(source_fit = fit, effect = "nie", method = meth,
                             n_boot = if (meth == "nonparametric") B else ND, seed = seed + 500000L)
    inf <- r@inference
    full <- identical(inf$status, "complete") && inf$successful == inf$requested
    list(status = if (full) "ok" else "incomplete", reason = if (full) "" else paste("status", inf$status),
         fit_seconds = fit_s, call_seconds = proc.time()[["elapsed"]] - t1, requested = inf$requested,
         successful = inf$successful, failed = inf$failed, interrupted = inf$interrupted, unattempted = inf$unattempted,
         ci_present = is.finite(r@ci_lower) && is.finite(r@ci_upper))
  }, error = function(e) list(status = "error", reason = conditionMessage(e)))
}
log <- list(); t0 <- Sys.time(); k <- 0L
fields <- c("status", "reason", "seconds", "fit_seconds", "call_seconds", "requested", "successful", "failed",
            "interrupted", "unattempted", "ci_present", "collected", "retained")
for (i in seq_len(nrow(cells))) {
  cl <- cells[i, ]; cell_start <- Sys.time()
  mod <- paste0("M ~ a*X\nY ~ b*M + ", if (cl$direct) "cp" else "0", "*X")
  for (d in seq_len(D)) {
    seed <- 9100000L + i * 100L + d
    dat <- tryCatch(gen(cl$n, cl$miss, cl$direct, seed), error = function(e) conditionMessage(e))
    for (meth in c("fit", "nonparametric", "parametric")) {
      k <- k + 1L
      left_total <- TOTAL - as.numeric(difftime(Sys.time(), t0, units = "secs"))
      left_cell <- CELLCAP - as.numeric(difftime(Sys.time(), cell_start, units = "secs"))
      row <- setNames(rep(list(NA), length(fields)), fields)
      row <- c(list(cell = i, n = cl$n, miss = cl$miss, direct = cl$direct, dataset = d, method = meth, seed = seed), row)
      if (left_total <= 1 || left_cell <= 1) {
        row$status <- if (left_total <= 1) "unattempted_total_cap" else "unattempted_cell_cap"
      } else if (is.character(dat)) {
        row$status <- "generation_failed"; row$reason <- dat
      } else {
        r <- run_child(unit(meth, mod, dat, seed), min(left_total, left_cell))
        for (f in intersect(names(r), fields)) row[[f]] <- r[[f]]
        row$collected <- attr(dat, "collected"); row$retained <- NROW(dat)
      }
      log[[k]] <- as.data.frame(lapply(row, function(v) if (is.null(v)) NA else v))
      write.csv(do.call(rbind, log), file.path(out, if (smoke) "smoke-log.csv" else "pilot-log.csv"), row.names = FALSE)
      cat(sprintf("[%s] cell %d n=%d %s direct=%s d=%d %s -> %s %ss\n", format(Sys.time(), "%H:%M:%S"), i, cl$n,
                  cl$miss, cl$direct, d, meth, row$status, row$seconds))
    }
  }
}
L <- do.call(rbind, log)
print(table(L$method, L$status))
ok <- L[L$status == "ok", ]
if (nrow(ok)) print(aggregate(seconds ~ method + n, ok, function(s) round(mean(s), 2)))
cat("elapsed total s:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "\n")
