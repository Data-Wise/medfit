# Native SEM engine: model completion and converters.
#
# Internal. `.sem_complete()` adds what `lavaan::sem()` adds to a parsed model
# (marker loadings, residual variances, exogenous covariances, covariances among
# endogenous variables that no regression connects), with one departure, Q3:
# exogenous observed variables have free variances and covariances, as OpenMx
# estimates them (`fixed.x = FALSE`). Row order follows lavaan so the two
# tables can be compared row for row. `.sem_to_partable()` and `.sem_to_ram()`
# convert the completed table to lavaan's column layout and to the RAM
# specification of sem-ml.R. A `~1` row (or `meanstructure = TRUE`) adds a mean structure over the observed variables.

# Observed and latent variable roles, from a parsed parameter table.
.sem_roles <- function(p) {
  latent <- unique(p$lhs[p$op == "=~"])
  seen <- unique(as.vector(rbind(p$lhs, p$rhs)))
  obs_all <- setdiff(seen, c(latent, ""))
  ind <- setdiff(unique(p$rhs[p$op == "=~"]), latent)
  ov_y <- setdiff(unique(p$lhs[p$op == "~"]), c(latent, ind))
  lv_y <- intersect(latent, p$lhs[p$op == "~"])
  preds <- unique(p$rhs[p$op == "~"])
  ov_x <- setdiff(obs_all[obs_all %in% preds], c(ind, ov_y))
  ov_other <- setdiff(obs_all, c(ind, ov_y, ov_x))
  list(
    latent = latent, obs = obs_all, ind = ind, ov_y = ov_y, ov_x = ov_x,
    # observed variables that only appear in a (co)variance statement
    ov_other = ov_other,
    lv_y = lv_y, lv_x = setdiff(latent, lv_y),
    # endogenous variables that no equation uses as a predictor
    pure_ov_y = setdiff(ov_y, preds), pure_lv_y = setdiff(lv_y, preds)
  )
}

.sem_complete <- function(parameters, meanstructure = NULL) {
  p <- parameters[, c("lhs", "op", "rhs", "level", "fixed", "label", "start", "lower", "upper")]
  p$user <- 1L
  r <- .sem_roles(p)
  written <- p$op == "~1"
  if (identical(meanstructure, FALSE) && any(written)) {
    stop("`meanstructure = FALSE`, but the model writes an intercept ('", p$lhs[written][1L], " ~ 1'); ",
         "drop the intercept statement or leave `meanstructure` unset", call. = FALSE)
  }
  # Mean structure is on when asked for, or when any intercept statement is written (free or fixed, as in
  # lavaan): then every observed variable whose intercept the user did not write gets a free one.
  mean_on <- isTRUE(meanstructure) || any(written)

  # Marker loading: the first indicator of each latent variable is fixed to 1
  # unless the user fixed it.
  for (lv in r$latent) {
    first <- which(p$op == "=~" & p$lhs == lv)[1L]
    if (is.na(p$fixed[first])) {
      p$fixed[first] <- 1
    }
  }

  has_cov <- function(a, b) {
    any(p$op == "~~" & ((p$lhs == a & p$rhs == b) | (p$lhs == b & p$rhs == a)))
  }
  new <- list()
  add <- function(a, b, fixed = NA_real_) {
    if (!has_cov(a, b)) {
      new[[length(new) + 1L]] <<- data.frame(
        lhs = a, op = "~~", rhs = b, level = 1L, fixed = fixed, label = "", start = NA_real_,
        lower = NA_real_, upper = NA_real_, user = 0L, stringsAsFactors = FALSE
      )
    }
  }
  pairs <- function(v) {
    if (length(v) < 2L) {
      return(invisible())
    }
    for (i in seq_len(length(v) - 1L)) {
      for (j in (i + 1L):length(v)) {
        add(v[i], v[j])
      }
    }
  }
  # An observed variable that is the only indicator of a latent variable has its
  # residual variance fixed to zero.
  single <- vapply(r$ind, function(v) {
    lv <- p$lhs[p$op == "=~" & p$rhs == v]
    length(lv) == 1L && sum(p$op == "=~" & p$lhs == lv) == 1L
  }, TRUE)
  for (v in c(r$ind, r$ov_y, r$ov_other)) {
    add(v, v, if (v %in% r$ind && single[[v]]) 0 else NA_real_)
  }
  for (v in r$latent) {
    add(v, v)
  }
  pairs(r$lv_x)
  pairs(c(r$pure_lv_y, r$pure_ov_y))
  # Exogenous observed variables: free variances and covariances (Q3). A variable
  # that already has a (co)variance statement is left out of the pairing, as in
  # lavaan with fixed.x = FALSE.
  paired <- setdiff(r$ov_x, c(p$lhs[p$op == "~~"], p$rhs[p$op == "~~"]))
  for (i in seq_along(r$ov_x)) {
    add(r$ov_x[i], r$ov_x[i])
    for (j in seq_along(r$ov_x)[-seq_len(i)]) {
      if (r$ov_x[i] %in% paired && r$ov_x[j] %in% paired) add(r$ov_x[i], r$ov_x[j])
    }
  }
  if (mean_on) {
    for (v in setdiff(r$obs, p$lhs[written])) {
      new[[length(new) + 1L]] <- data.frame(
        lhs = v, op = "~1", rhs = "", level = 1L, fixed = NA_real_, label = "", start = NA_real_,
        lower = NA_real_, upper = NA_real_, user = 0L, stringsAsFactors = FALSE
      )
    }
  }
  p <- rbind(p, do.call(rbind, c(list(p[0L, ]), new)))
  p$id <- seq_len(nrow(p))
  rownames(p) <- NULL
  p[, c("id", "lhs", "op", "rhs", "level", "fixed", "label", "start", "lower", "upper", "user")]
}

# Index of the free parameter behind each row of a completed table: 0 for a fixed
# row, otherwise numbered by first appearance with equal labels collapsed to one
# parameter (lavaan repeats a shared label; its vcov() is then rank deficient).
.sem_free_index <- function(tab) {
  free <- is.na(tab$fixed)
  key <- ifelse(nzchar(tab$label), tab$label, paste(tab$lhs, tab$op, tab$rhs))
  idx <- integer(nrow(tab))
  idx[free] <- match(key[free], unique(key[free]))
  idx
}

# Completed table in lavaan's parameter-table layout. `level`, `block` and
# `group` stay NA in 0.7.0 so two-level and multigroup models can arrive
# without changing the accessor shape (plan 2.4).
.sem_to_partable <- function(tab) {
  data.frame(
    id = tab$id, lhs = tab$lhs, op = tab$op, rhs = tab$rhs, user = tab$user,
    level = NA_integer_, block = NA_integer_, group = NA_integer_,
    free = .sem_free_index(tab), ustart = ifelse(is.na(tab$fixed), tab$start, tab$fixed), exo = 0L,
    label = tab$label, lower = tab$lower, upper = tab$upper, stringsAsFactors = FALSE
  )
}

# Every latent variable needs a scale: a fixed loading or a fixed variance.
.sem_check_scale <- function(tab) {
  for (lv in unique(tab$lhs[tab$op == "=~"])) {
    loading <- any(tab$op == "=~" & tab$lhs == lv & !is.na(tab$fixed))
    variance <- any(tab$op == "~~" & tab$lhs == lv & tab$rhs == lv & !is.na(tab$fixed))
    if (!loading && !variance) {
      stop("latent variable '", lv, "' has no fixed loading or fixed variance, so its scale is not set", call. = FALSE)
    }
  }
  invisible(tab)
}

# Completed table to a RAM specification. Intercept rows (`~1`) make a mean structure: the observed ones
# become the RAM's intercept vector. A latent variable's mean is fixed at 0 (lavaan's default, GRILL G7), so
# a latent `~ 0*1` is accepted and dropped, and any other latent intercept is an error until latent means ship.
.sem_to_ram <- function(tab) {
  latent <- unique(tab$lhs[tab$op == "=~"])
  icpt <- tab$op == "~1"
  lat_icpt <- icpt & tab$lhs %in% latent
  bad <- lat_icpt & (is.na(tab$fixed) | tab$fixed != 0)
  if (any(bad)) {
    stop("the mean of latent variable '", tab$lhs[bad][1L], "' is ",
         if (is.na(tab$fixed[bad][1L])) "free" else "fixed to a nonzero value",
         ": latent means are planned for a later release (a latent mean of 0 is the default)", call. = FALSE)
  }
  tab <- tab[!lat_icpt, , drop = FALSE]
  icpt <- tab$op == "~1"
  obs <- setdiff(unique(as.vector(rbind(tab$lhs, tab$rhs))), c(latent, ""))
  is_a <- tab$op %in% c("=~", "~")
  is_s <- tab$op == "~~"
  is_m <- tab$op == "~1"
  # `=~` is a path from the factor to its indicator; `~` from the predictor to the target.
  row <- ifelse(tab$op == "=~", tab$rhs, tab$lhs)
  col <- ifelse(tab$op == "=~", tab$lhs, tab$rhs)
  # One name per row: the label, else `lhs op rhs` without spaces, as lavaan names its coefficients.
  name <- ifelse(nzchar(tab$label), tab$label, paste0(tab$lhs, tab$op, tab$rhs))
  piece <- function(i) {
    data.frame(row = row[i], col = col[i], label = tab$label[i], value = tab$fixed[i], name = name[i],
               stringsAsFactors = FALSE)
  }
  m_piece <- if (any(is_m)) piece(is_m) else NULL
  ram <- .sem_ram(c(obs, latent), obs, piece(is_a), piece(is_s), m_piece)

  par_map <- ifelse(is.na(tab$fixed), match(name, ram$par_names), NA_integer_)
  pick <- function(col_name) {
    out <- rep(NA_real_, ram$q)
    for (k in seq_len(ram$q)) {
      v <- unique(tab[[col_name]][which(par_map == k)])
      v <- v[!is.na(v)]
      if (length(v) > 1L) {
        stop("parameter '", ram$par_names[k], "' has conflicting ", col_name, " values", call. = FALSE)
      }
      if (length(v)) out[k] <- v
    }
    stats::setNames(out, ram$par_names)
  }
  list(ram = ram, par_map = par_map, start = pick("start"), lower = pick("lower"), upper = pick("upper"), table = tab)
}

# Observed moments: the covariances, plus the means when the model has a mean structure.
.sem_moments <- function(ram) {
  p <- length(ram$obs_idx)
  p * (p + 1) / 2 + if (isTRUE(ram$has_mean)) p else 0
}

# Degrees of freedom: observed moments minus free parameters.
.sem_df <- function(ram, eq_rank = 0L) {
  .sem_moments(ram) - (ram$q - eq_rank)
}
