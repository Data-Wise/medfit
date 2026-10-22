# Independent oracle for medfit #213: constrained ML for the observed mediation model
#   M ~ a*X ; Y ~ cp*X + b*M ; M ~~ Vm*M ; Y ~~ Vy*Y ; a*b/sqrt(2*(b^2*Vm+Vy)) == q
# Gaussian likelihood, complete data, unweighted, free intercepts (or none: medfit's covariance-only fit gives the
# same slopes and variances), free direct effect cp, independent errors. No medfit code and no nloptr: the problem
# is reduced to a one-dimensional profile in t = b*sqrt(Vm/Vy) on each sign branch, with a convex inner problem
# solved by uniroot().
#
# Objective: Q = -2 log L(m | x) - 2 log L(y | x, m) up to a constant shared by every fit of the same data (the
# X part and 2*pi terms cancel in a likelihood ratio). LR(q) = min Q under the constraint - min Q unconstrained,
# which equals medfit's 2 * (logLik(h1) - logLik(h2)) (checked below to ~1e-9).
#
# Usage: source("oracle213.R"); or213_lr(d, q)  (d has columns X, M, Y)
#        Rscript oracle213.R            runs the self-checks against medfit (needs the repo at MEDFIT_ROOT)

or213_cross <- function(d) {
  x <- d$X - mean(d$X)
  m <- d$M - mean(d$M)
  y <- d$Y - mean(d$Y)
  A <- sum(x * x)
  B <- sum(x * m)
  K <- sum(m * m)
  mr <- m - x * B / A
  yr <- y - x * sum(x * y) / A
  list(n = length(x), A = A, B = B, K = K, C = sum(mr * mr), D = sum(mr * yr), E = sum(yr * yr),
       xy = sum(x * y), xm = B)
}

# Q at (a, b, Vm, Vy) with cp profiled out
or213_Q <- function(cr, a, b, v, w) {
  with(cr, n * log(v) + (K - 2 * a * B + a^2 * A) / v + n * log(w) + (E - 2 * b * D + b^2 * C) / w)
}

or213_unres <- function(cr) {
  with(cr, {
    a <- B / A
    b <- D / C
    v <- C / n
    w <- (E - D^2 / C) / n
    list(par = c(a = a, b = b, Vm = v, Vy = w, cp = (xy - b * xm) / A), objective = or213_Q(cr, a, b, v, w))
  })
}

# Inner problem at fixed t (strictly convex in u = Vm^-1/2, z = Vy^-1/2). Returns the profile value Q(t).
# Optional variance floors vm_min, vy_min (0 = none, the default) are the box u <= 1/sqrt(vm_min), z <= 1/sqrt(vy_min).
# Minimizing a jointly convex function over a box is exact by nesting: the z-minimizer at fixed u is clipped at z_max,
# and the profile in u (convex) is root-found on the envelope derivative (z held at its clipped value) and clipped at u_max.
or213_profile_t <- function(t, q, cr, vm_min = 0, vy_min = 0) {
  stopifnot(t != 0, q != 0, is.finite(vm_min), is.finite(vy_min), vm_min >= 0, vy_min >= 0)
  u_max <- 1 / sqrt(vm_min)
  z_max <- 1 / sqrt(vy_min)
  n <- cr$n
  A <- cr$A
  B <- cr$B
  K <- cr$K
  C <- cr$C
  D <- cr$D
  E <- cr$E
  ct <- q * sqrt(2 * (1 + t^2)) / t
  H <- K + t^2 * C
  z_of_u <- function(u) {
    r <- t * D * u
    h <- sqrt(r^2 + 4 * E * n)
    min(if (r >= 0) (r + h) / (2 * E) else 2 * n / (h - r), z_max)
  }
  score <- function(u) H * u - ct * B - t * D * z_of_u(u) - n / u
  lo <- hi <- 1
  for (i in 1:2000) if (score(lo) < 0) break else lo <- lo / 2
  for (i in 1:2000) if (score(hi) > 0 || hi >= u_max) break else hi <- hi * 2
  hi <- min(hi, u_max)
  stopifnot(score(lo) < 0)
  u <- if (score(hi) <= 0) hi else stats::uniroot(score, c(lo, hi), tol = 1e-14 * hi, maxiter = 1000)$root
  z <- z_of_u(u)
  value <- -2 * n * (log(u) + log(z)) + H * u^2 - 2 * ct * B * u + E * z^2 - 2 * t * D * u * z + ct^2 * A
  b <- t * u / z
  list(objective = value, par = c(a = ct / u, b = b, Vm = 1 / u^2, Vy = 1 / z^2, cp = (cr$xy - b * cr$xm) / cr$A))
}

# Every local minimum of the profile on one sign branch (t = sgn * exp(r)), by a grid scan and golden refinement.
or213_branch <- function(sgn, q, cr, r_grid = seq(-15, 15, by = 0.02), vm_min = 0, vy_min = 0) {
  f <- function(r) or213_profile_t(sgn * exp(r), q, cr, vm_min, vy_min)$objective
  fv <- vapply(r_grid, f, numeric(1))
  k <- which(diff(sign(diff(fv))) > 0) + 1L # interior grid minima
  if (which.min(fv) %in% c(1L, length(fv))) warning("branch minimum at the edge of the r grid; widen it")
  mins <- lapply(k, function(i) {
    o <- stats::optimize(f, r_grid[c(i - 1L, i + 1L)], tol = 1e-12)
    p <- or213_profile_t(sgn * exp(o$minimum), q, cr, vm_min, vy_min)
    list(objective = p$objective, par = p$par, t = sgn * exp(o$minimum))
  })
  mins[order(vapply(mins, `[[`, 0, "objective"))]
}

# Constrained minimum over both branches; q == 0 uses the exact union of the two linear nulls. vm_min and vy_min floor
# the variances (0 = none); the unconstrained minimum or213_unres() is never floored (medfit applies the floor only
# with a nonlinear row). In a null the remaining variance is the closed form floored at its minimum: the profile in a
# variance is convex in its inverse, so the floored optimum is max(unconstrained, floor).
or213_fit <- function(d, q, vm_min = 0, vy_min = 0) {
  cr <- or213_cross(d)
  if (q == 0) {
    with(cr, {
      # n log v + S / v at v = max(S / n, v_min); the unfloored form n log(S / n) + n is kept when the floor is inactive
      term <- function(S, v_min) if (v_min <= S / n) n * log(S / n) + n else n * log(v_min) + S / v_min
      v_of <- function(S, v_min) max(S / n, v_min)
      R <- E - D^2 / C
      # a = 0: Vm from K; b profiled to D/C leaves the residual R for Vy
      a0 <- term(K, vm_min) + term(R, vy_min)
      # b = 0: a profiled to B/A leaves C for Vm; Vy from E
      b0 <- term(C, vm_min) + term(E, vy_min)
      list(objective = min(a0, b0), branch = if (a0 <= b0) "a=0" else "b=0", cr = cr,
           par = if (a0 <= b0) {
             c(a = 0, b = D / C, Vm = v_of(K, vm_min), Vy = v_of(R, vy_min))
           } else {
             c(a = B / A, b = 0, Vm = v_of(C, vm_min), Vy = v_of(E, vy_min))
           })
    })
  } else {
    or213_fit_q(cr, q, vm_min, vy_min)
  }
}

or213_fit_q <- function(cr, q, vm_min, vy_min) {
  pos <- or213_branch(1, q, cr, vm_min = vm_min, vy_min = vy_min)
  neg <- or213_branch(-1, q, cr, vm_min = vm_min, vy_min = vy_min)
  all <- c(pos, neg)
  best <- all[[which.min(vapply(all, `[[`, 0, "objective"))]]
  list(objective = best$objective, par = best$par, t = best$t, cr = cr,
       branch_min = c(pos = if (length(pos)) pos[[1]]$objective else NA, neg = if (length(neg)) neg[[1]]$objective else NA),
       n_local = c(pos = length(pos), neg = length(neg)), local = all)
}

or213_lr <- function(d, q, vm_min = 0, vy_min = 0) {
  cr <- or213_cross(d)
  or213_fit(d, q, vm_min, vy_min)$objective - or213_unres(cr)$objective
}

or213_qhat <- function(d) {
  p <- or213_unres(or213_cross(d))$par
  unname(p["a"] * p["b"] / sqrt(2 * (p["b"]^2 * p["Vm"] + p["Vy"])))
}

# ---------------------------------------------------------------------------------------------------------------
# Self-checks against medfit (run with Rscript).
if (sys.nframe() == 0L) {
  root <- Sys.getenv("MEDFIT_ROOT", getwd()) # run from the package root (or set MEDFIT_ROOT)
  suppressMessages(devtools::load_all(root, quiet = TRUE))
  src <- readLines(file.path(root, "tests/testthat/test-sem-nonlinear-variance.R"))
  eval(parse(text = src[1:(grep("^test_that", src)[1] - 1)]))
  cfit <- function(d, q, floor = TRUE, n_starts = 8) {
    syn <- paste0(nv_model, "\na*b/sqrt(2*(b^2*Vm+Vy)) == ", format(q, digits = 17),
                  if (floor) "\nVm > 0.0001\nVy > 0.0001" else "")
    tryCatch(suppressWarnings(fit_sem(syn, d, n_starts = n_starts)), error = function(e) NULL)
  }
  # (0) normalization: the oracle's unconstrained Q matches medfit's -2 logLik up to the X and 2*pi constant
  d <- nv_data(101, 2.5, 1.5, 2)
  h1 <- fit_sem(nv_model, d)
  cr <- or213_cross(d)
  const <- with(cr, 3 * n * log(2 * pi) + n * log(A / n) + n)
  cat(sprintf("(0) -2logLik(h1) = %.10f, oracle Q + const = %.10f\n", -2 * as.numeric(logLik(h1)),
              or213_unres(cr)$objective + const))
  print(rbind(medfit = coef(h1)[c("a", "b", "Vm", "Vy", "cp")], oracle = or213_unres(cr)$par))
  # (1) grid: q = q_hat on seeds 1:3, shifts on seeds 1:2, plus the issue's two datasets
  grid <- expand.grid(ab = 1:6, s2 = c(1, 2), seed = 1:3)
  abs_ <- list(c(0, 0), c(0.05, 0.05), c(0, 1), c(1, 0), c(1.5, 1), c(2.5, 1.5))
  cases <- list()
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    for (sh in if (g$seed <= 2) c(0, -0.1, 0.05, 0.2) else 0) {
      cases[[length(cases) + 1]] <- list(seed = g$seed * 7, a = abs_[[g$ab]][1], b = abs_[[g$ab]][2], s2 = g$s2, shift = sh)
    }
  }
  cases <- c(list(list(seed = 1, a = 1.5, b = 1, s2 = 1, shift = 0), list(seed = 101, a = 2.5, b = 1.5, s2 = 2, shift = 0)), cases)
  out <- do.call(rbind, lapply(cases, function(cs) {
    d <- nv_data(cs$seed, cs$a, cs$b, cs$s2)
    h1 <- fit_sem(nv_model, d)
    q <- or213_qhat(d) + cs$shift
    lr_or <- or213_lr(d, q)
    hf <- cfit(d, q, floor = TRUE)
    hb <- cfit(d, q, floor = FALSE)
    data.frame(seed = cs$seed, a = cs$a, b = cs$b, s2 = cs$s2, shift = cs$shift, q = q, lr_oracle = lr_or,
               lr_floor = if (is.null(hf)) NA else nv_lr(h1, hf), lr_base = if (is.null(hb)) NA else nv_lr(h1, hb))
  }))
  out$diff_floor <- out$lr_floor - out$lr_oracle
  out$diff_base <- out$lr_base - out$lr_oracle
  options(width = 200)
  print(out, digits = 6)
  cat(sprintf("\ncases %d; floor fit errors %d; max |LR_floor - LR_oracle| = %.3e; baseline errors %d, baseline > oracle + 1e-4: %d\n",
              nrow(out), sum(is.na(out$lr_floor)), max(abs(out$diff_floor), na.rm = TRUE), sum(is.na(out$lr_base)),
              sum(out$diff_base > 1e-4, na.rm = TRUE)))
  saveRDS(out, file.path(tempdir(), "oracle213_grid.rds"))
}
