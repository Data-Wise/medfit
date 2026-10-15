# Native SEM engine: factor covariates.
#
# Internal. `.sem_expand_factors()` is a data-aware pre-pass on the parsed table: a factor, character or logical
# column named on a regression's right side is replaced by numeric dummy columns before `.sem_complete()` runs, so
# completion, the checks and the RAM only ever see numeric observed variables (spec F1-F3, F6).

.sem_expand_factors <- function(tab, data, fixed_x) {
  rhs_names <- unique(tab$rhs[tab$op == "~"])
  # a name with a colon is a product term, handled with the product rules (never a factor column here)
  cand <- rhs_names[rhs_names %in% names(data) & !grepl(":", rhs_names, fixed = TRUE)]
  is_cat <- vapply(cand, function(v) is.factor(data[[v]]) || is.character(data[[v]]) || is.logical(data[[v]]), TRUE)
  cats <- cand[is_cat]
  if (!length(cats)) {
    return(list(table = tab, data = data, fixed_x = fixed_x, map = list()))
  }
  map <- stats::setNames(lapply(cats, function(v) .sem_factor_levels(v, data[[v]])), cats)
  dummies <- lapply(cats, function(v) .sem_factor_dummy_names(v, map[[v]]))
  names(dummies) <- cats
  .sem_check_dummy_names(map, dummies, names(data))
  for (v in cats) {
    map[[v]]$dummies <- dummies[[v]]
    data <- .sem_add_dummies(data, v, map[[v]])
  }
  list(table = .sem_expand_table(tab, map), data = data, fixed_x = .sem_expand_fixed_x(fixed_x, map), map = map)
}

# Levels and reference of one categorical column. A character column is sorted in the C locale so results do not
# depend on the session locale (as `.sem_product_name()`); a logical column has the one level TRUE and no reference.
.sem_factor_levels <- function(name, x) {
  if (is.logical(x)) {
    return(list(levels = c("FALSE", "TRUE"), reference = "FALSE", logical = TRUE))
  }
  if (is.ordered(x)) {
    stop("`", name, "` is an ordered factor: polynomial contrasts are not dummies; use `factor(", name,
         ", ordered = FALSE)`", call. = FALSE)
  }
  lev <- if (is.character(x)) sort(unique(x[!is.na(x)]), method = "radix") else levels(x)
  if (length(lev) < 2L) {
    stop("`", name, "` has only one level, so it cannot enter the model", call. = FALSE)
  }
  list(levels = lev, reference = lev[1L], logical = FALSE)
}

.sem_factor_dummy_names <- function(name, info) {
  lev <- if (info$logical) "TRUE" else info$levels[-1L]
  paste0(name, "_", lev)
}

# A dummy that collides with an existing column or with another factor's dummy is an error, as is a level that does
# not make a valid name (the user renames the level; never a silent rewrite).
.sem_check_dummy_names <- function(map, dummies, existing) {
  for (v in names(map)) {
    lev <- if (map[[v]]$logical) "TRUE" else map[[v]]$levels[-1L]
    bad <- dummies[[v]][make.names(dummies[[v]]) != dummies[[v]]]
    if (length(bad)) {
      lv <- lev[dummies[[v]] == bad[1L]]
      hint <- if (!anyNA(suppressWarnings(as.numeric(lev)))) {
        paste0(" (the levels look numeric: is `", v, "` a number stored as text? convert it with as.numeric())")
      } else {
        ""
      }
      stop("level '", lv, "' of `", v, "` makes the invalid name `", bad[1L], "`: rename the level", hint,
           call. = FALSE)
    }
    hit <- intersect(dummies[[v]], existing)
    if (length(hit)) {
      stop("dummy `", hit[1L], "` for `", v, "` is already a column of `data`: rename the column or the level",
           call. = FALSE)
    }
  }
  all_names <- unlist(dummies, use.names = FALSE)
  dup <- all_names[duplicated(all_names)]
  if (length(dup)) {
    owners <- names(dummies)[vapply(dummies, function(d) dup[1L] %in% d, TRUE)]
    stop("dummy `", dup[1L], "` would be built for both `", owners[1L], "` and `", owners[2L], "`: rename a level",
         call. = FALSE)
  }
  invisible(NULL)
}

# Dummies come from the full column, before listwise deletion; NA in the factor gives NA in every dummy.
.sem_add_dummies <- function(data, name, info) {
  x <- data[[name]]
  if (info$logical) {
    data[[info$dummies]] <- as.numeric(x)
    return(data)
  }
  x <- as.character(x)
  for (i in seq_along(info$dummies)) {
    data[[info$dummies[i]]] <- as.numeric(x == info$levels[i + 1L])
  }
  data
}

# Each regression row naming a factor becomes one row per dummy, other properties kept.
.sem_expand_table <- function(tab, map) {
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, , drop = FALSE]
    if (r$op == "~" && r$rhs %in% names(map)) {
      d <- map[[r$rhs]]$dummies
      r <- r[rep(1L, length(d)), , drop = FALSE]
      r$rhs <- d
    }
    r
  })
  out <- do.call(rbind, rows)
  out$id <- seq_len(nrow(out))
  rownames(out) <- NULL
  attributes(out)[setdiff(names(attributes(tab)), names(attributes(out)))] <-
    attributes(tab)[setdiff(names(attributes(tab)), names(attributes(out)))]
  out
}

.sem_expand_fixed_x <- function(fixed_x, map) {
  if (!is.character(fixed_x)) {
    return(fixed_x)
  }
  unlist(lapply(fixed_x, function(v) if (v %in% names(map)) map[[v]]$dummies else v), use.names = FALSE)
}
