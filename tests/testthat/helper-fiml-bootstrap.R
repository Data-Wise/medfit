# Frozen bounded implementation/QA sources; see planning/fixtures/FI-B-implementation-freeze-2026-11-01.md.
fb_fixture <- function(kind, direct) {
  set.seed(271L)
  n <- 300L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + (if (direct) .25 else 0) * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M = m, Y = y)
  if (kind == "mar") {
    d[stats::runif(n) < stats::plogis(-1.3 + .7 * x), "M"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.1 - .6 * x), "Y"] <- NA_real_
  } else if (kind == "mcar") {
    set.seed(613L)
    masks <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))[-1L, ]
    d[!masks[sample.int(7L, n, replace = TRUE), ]] <- NA_real_
    d <- rbind(d, data.frame(X = rep(NA_real_, 3L), M = NA_real_, Y = NA_real_))
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}

fb_model <- function(direct) paste0("M ~ a*X\nY ~ b*M + ", if (direct) "cp" else "0", "*X")

# Compare constructor definitions and metadata, not R's private closure serialization header flags.
fb_constructor_state <- function(x) {
  if (is.null(x)) return(NULL)
  # Map attribute values directly: recursively describing the named container itself would never terminate.
  attrs <- lapply(attributes(x), fb_constructor_state)
  if (is.function(x)) {
    return(list(type = typeof(x), formals = fb_constructor_state(formals(x)),
                body = fb_constructor_state(body(x)), environment = environment(x),
                attributes = attrs))
  }
  if (is.environment(x)) return(list(type = "environment", address = rlang::obj_address(x), attributes = attrs))
  if (is.call(x) || is.expression(x) || is.list(x) || is.pairlist(x)) {
    return(list(type = typeof(x), values = lapply(as.list(x), fb_constructor_state), attributes = attrs))
  }
  if (is.symbol(x)) return(list(type = "symbol", value = as.character(x), attributes = attrs))
  attributes(x) <- NULL
  list(type = typeof(x), value = serialize(x, NULL), attributes = attrs)
}

fb_snapshot <- function(fit) {
  attrs <- attributes(fit)
  constructor <- attrs$S7_class
  attrs$S7_class <- NULL
  list(properties = lapply(S7::props(fit), serialize, connection = NULL),
       attributes = lapply(attrs, serialize, connection = NULL),
       constructor_address = rlang::obj_address(constructor),
       constructor = fb_constructor_state(constructor))
}
