ALLOWED <- list(  # name = c(min_arity, max_arity); each bound to its base/stats object explicitly
  `+`=c(1,2), `-`=c(1,2), `*`=c(2,2), `/`=c(2,2), `^`=c(2,2), `(`=c(1,1),
  exp=c(1,1), log=c(1,2), log10=c(1,1), sqrt=c(1,1), abs=c(1,1), min=c(1,Inf), max=c(1,Inf),
  sin=c(1,1), cos=c(1,1), tan=c(1,1), pnorm=c(1,1), qnorm=c(1,1))
BOUND <- list(`+`=base::`+`, `-`=base::`-`, `*`=base::`*`, `/`=base::`/`, `^`=base::`^`, `(`=base::`(`,
  exp=base::exp, log=base::log, log10=base::log10, sqrt=base::sqrt, abs=base::abs, min=base::min, max=base::max,
  sin=base::sin, cos=base::cos, tan=base::tan, pnorm=stats::pnorm, qnorm=stats::qnorm)
parse_expr <- function(text) {
  # R parses 0x10 as the double 16; the grammar allows decimal literals only, so reject hex before parsing (names such as a0x1 are not literals).
  if (grepl("(^|[^A-Za-z0-9._])0[xX][0-9a-fA-F]", text)) stop("hexadecimal literals are not supported", call. = FALSE)
  ex <- tryCatch(parse(text = text, keep.source = FALSE), error = function(e) stop("constraint expression does not parse: ", conditionMessage(e), call. = FALSE))
  if (length(ex) != 1L) stop("constraint expression must be a single expression, got ", length(ex), call. = FALSE)
  ex[[1L]] }
validate_expr <- function(e, labels) {
  if (is.double(e) && length(e) == 1L && is.finite(e)) return(invisible(TRUE))   # finite double literals only (no 5L, 0x10, 1i, Inf)
  if (is.symbol(e)) { nm <- as.character(e)
    if (nm %in% names(ALLOWED)) stop("'", nm, "' is a function name, not a parameter label", call. = FALSE)
    if (!nm %in% labels) stop("unknown parameter label '", nm, "'", call. = FALSE); return(invisible(TRUE)) }
  if (is.call(e)) { head <- e[[1L]]
    if (!is.symbol(head)) stop("disallowed call head (only bare allowlisted function names): ", deparse(head), call. = FALSE)
    fn <- as.character(head); if (!fn %in% names(ALLOWED)) stop("function '", fn, "' is not in the math allowlist", call. = FALSE)
    if (!is.null(names(e)) && any(nzchar(names(e)[-1L]))) stop("named arguments are not allowed in '", fn, "'", call. = FALSE)
    k <- length(e) - 1L; ar <- ALLOWED[[fn]]; if (k < ar[1L] || k > ar[2L]) stop("'", fn, "' called with ", k, " argument(s)", call. = FALSE)
    for (a in as.list(e)[-1L]) validate_expr(a, labels); return(invisible(TRUE)) }
  stop("disallowed construct: ", deparse(e), " (", typeof(e), ")", call. = FALSE) }
eval_expr <- function(text, values) {
  e <- parse_expr(text); validate_expr(e, names(values))
  env <- list2env(c(BOUND, as.list(values)), parent = emptyenv())
  r <- suppressWarnings(eval(e, env))
  # result-domain guard (spec 4.2a step 4): exactly one finite real double, else an error naming the expression and the label values
  if (!(is.double(r) && length(r) == 1L && is.finite(r))) stop("expression '", text, "' did not evaluate to one finite real number (got ", paste(format(r), collapse = ","), ") at ", paste(names(values), "=", format(values), collapse = ", "), call. = FALSE)
  r }
naive_check <- function(text, labels) { e <- parse_expr(text); bad <- setdiff(all.names(e), c(names(ALLOWED), labels)); length(bad) == 0 }
# ---- T1 step 1: the planted defect ----
flag <- FALSE; exp <- function(x) { flag <<- TRUE; base::exp(x) }   # caller rebinds an allowlisted name
txt <- "exp(a) + b"; vals <- c(a = 1, b = 2)
cat("naive all.names-only check passes:", naive_check(txt, names(vals)), "\n")
flag <- FALSE; invisible(eval(parse_expr(txt), c(list(), as.list(vals)), globalenv())); cat("naive eval ran the caller's rebound exp:", flag, "\n")
flag <- FALSE; r <- eval_expr(txt, vals); cat(sprintf("locked evaluator: value %.6f (base exp(1)+2 = %.6f), caller's exp ran: %s\n", r, base::exp(1)+2, flag))
rm(exp)
# ---- T1 step 4: rejection tests ----
cases <- c('base::system("echo hi")', 'get("system")("echo hi")', 'do.call("system", list("echo hi"))', 'Recall(a)', '"abc"', '(function() 1)()',
           'a[1]', 'a$b', 'ifelse(a>0,a,b)', 'a <- 3', 'a = 3', 'TRUE', 'NA', 'exp(a, b)', 'log(x = a)', 'a; system("x")', 'exp', '`a b`', 'if (a) 1 else 2', '~a', 'unknown*a', '1 +', '5L', '0x10', '1i', '1e', 'Inf', '1e999')
n_unexpected <- 0
for (cs in cases) { r <- tryCatch({ eval_expr(cs, c(a=1, b=2)); "ACCEPTED" }, error = function(e) conditionMessage(e)); if (r == "ACCEPTED") n_unexpected <- n_unexpected + 1; cat(sprintf("%-34s -> %s\n", cs, substr(r, 1, 80))) }
cat(sprintf("TALLY rejected: %d of %d inputs; unexpectedly accepted: %d\n", length(cases) - n_unexpected, length(cases), n_unexpected))
cat("label containing 0x is not a hex literal: a0x1 + 1 =", eval_expr("a0x1 + 1", c(a0x1 = 1)), "\n")
cat("\n-- accepted --\n"); acc_cases <- c("-2^2", "a*b", "a^2 + b^2", "exp(a)/sqrt(b+1)", "min(a, b, 3)", "log(a, 2)", "pnorm(a) - 0.5", "2^-1", "1e-3*a", ".5 + a", "1. * a", "1e3*a", "2E-2*a", "a^.5")
for (cs in acc_cases) cat(sprintf("%-20s = %s\n", cs, format(eval_expr(cs, c(a=1.5, b=2)), digits = 8)))
same <- vapply(acc_cases, function(cs) isTRUE(all.equal(eval_expr(cs, c(a=1.5, b=2)), eval(parse(text = cs), list(a=1.5, b=2)), tolerance = 1e-14)), TRUE)
cat(sprintf("TALLY accepted: %d of %d valid expressions evaluated; %d equal R's own evaluation of the same text (tolerance 1e-14)\n", length(acc_cases), length(acc_cases), sum(same)))
cat("R check: parse(-2^2) =", eval(parse(text = "-2^2")), " 2^3^2 =", eval(parse(text = "2^3^2")), "\n")

cat("\n== result-domain guard: every evaluation must return one finite real double ==\n")
dom_bad <- c("1/0", "0/0", "(-1)^.5", "log(-1)", "sqrt(-1)", "exp(1000)", "qnorm(2)", "1/(a - 1.5)")
n_dom <- 0
for (cs in dom_bad) { r <- tryCatch({ eval_expr(cs, c(a = 1.5, b = 2)); "ACCEPTED" }, error = function(e) conditionMessage(e)); if (r != "ACCEPTED") n_dom <- n_dom + 1; cat(sprintf("%-14s -> %s\n", cs, substr(r, 1, 100))) }
dom_ok <- c("log(1)", "1/a", "sqrt(b)", "(-8)^2", "0*a")
ok_dom <- vapply(dom_ok, function(cs) { r <- tryCatch(eval_expr(cs, c(a = 1.5, b = 2)), error = function(e) NA_real_); is.finite(r) }, TRUE)
cat(sprintf("TALLY domain: %d of %d non-finite or non-real results rejected; %d of %d valid boundary expressions accepted\n", n_dom, length(dom_bad), sum(ok_dom), length(dom_ok)))
