# Native SEM engine: factor covariates.
#
# Internal. `.sem_expand_factors()` is a data-aware pre-pass on the parsed table: a factor, character or logical
# column named on a regression's right side is replaced by numeric dummy columns before `.sem_complete()` runs, so
# completion, the checks and the RAM only ever see numeric observed variables (spec F1-F3, F6).

.sem_expand_factors <- function(tab, data, fixed_x, factors = NULL) {
  # A refit (`mbco_sem()`) re-parses the stored model text against the stored data, which holds the dummies and not
  # the factor column: the stored map rewrites the factor's rows to its dummies instead of expanding again.
  stored <- .sem_stored_factors(factors, data)
  if (length(stored)) {
    tab <- .sem_expand_table(tab, stored)
    fixed_x <- .sem_expand_fixed_x(fixed_x, stored)
  }
  out <- .sem_expand_new_factors(tab, data, fixed_x)
  out$map <- c(stored, out$map)
  out
}

# Stored factors whose column is absent from `data`; every dummy must be present.
.sem_stored_factors <- function(factors, data) {
  use <- factors[setdiff(names(factors), names(data))]
  for (v in names(use)) {
    miss <- setdiff(use[[v]]$dummies, names(data))
    if (length(miss)) {
      stop("the refit needs the dummy columns of `", v, "`, absent from `data`: ", paste(miss, collapse = ", "),
           call. = FALSE)
    }
  }
  use
}

.sem_expand_new_factors <- function(tab, data, fixed_x) {
  # a name with a colon is a product term, handled with the product rules (never a factor column here)
  rhs_names <- unique(tab$rhs[tab$op == "~" & !grepl(":", tab$rhs, fixed = TRUE)])
  is_cat <- function(v) is.factor(data[[v]]) || is.character(data[[v]]) || is.logical(data[[v]])
  bare <- rhs_names[rhs_names %in% names(data)]
  bare <- bare[vapply(bare, is_cat, TRUE)]
  refs <- .sem_resolve_dummy_refs(setdiff(rhs_names, names(data)), data, is_cat)
  cats <- union(bare, names(refs))
  if (!length(cats)) {
    return(list(table = tab, data = data, fixed_x = fixed_x, map = list()))
  }
  map <- stats::setNames(lapply(cats, function(v) .sem_factor_levels(v, data[[v]])), cats)
  for (v in cats) {
    all_d <- .sem_factor_dummy_names(v, map[[v]])
    map[[v]]$dummies <- if (v %in% bare) all_d else all_d[match(refs[[v]], all_d)]
    map[[v]]$all <- all_d
  }
  dummies <- lapply(map, function(m) m$dummies)
  .sem_check_dummy_names(map, dummies, names(data))
  .sem_check_factor_modifiers(tab, dummies[intersect(names(dummies), bare)])
  for (v in cats) {
    data <- .sem_add_dummies(data, v, map[[v]])
  }
  list(table = .sem_expand_table(tab, map[intersect(names(map), bare)]), data = data,
       fixed_x = .sem_expand_fixed_x(fixed_x, map), map = map)
}

# A model name `<column>_<level>` that is not a column of `data` but names a non-reference level of a categorical
# column refers to that one dummy, so a label or constraint can sit on a single dummy (`b*g_b`). Returns a list
# keyed by the column, each element the referenced dummy names.
.sem_resolve_dummy_refs <- function(missing_names, data, is_cat) {
  cat_cols <- names(data)[vapply(names(data), is_cat, TRUE)]
  out <- list()
  for (nm in missing_names) {
    hits <- cat_cols[startsWith(nm, paste0(cat_cols, "_"))]
    if (!length(hits)) {
      next
    }
    if (length(hits) > 1L) {
      stop("`", nm, "` could be a dummy of more than one column (", paste(hits, collapse = ", "),
           "): rename a column", call. = FALSE)
    }
    info <- .sem_factor_levels(hits, data[[hits]])
    if (nm == paste0(hits, "_", info$reference)) {
      stop("`", nm, "` is the reference level of `", hits, "`, which has no dummy", call. = FALSE)
    }
    if (nm %in% .sem_factor_dummy_names(hits, info)) {
      out[[hits]] <- union(out[[hits]], nm)
    }
  }
  out
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
      lv <- lev[map[[v]]$all == bad[1L]]
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

# A label, fixed value, start or bound on a factor term would have to name several coefficients (a shared label is a
# hidden equality constraint), so it is an error; the user puts the modifier on one dummy.
.sem_check_factor_modifiers <- function(tab, dummies) {
  for (i in which(tab$op == "~" & tab$rhs %in% names(dummies))) {
    r <- tab[i, ]
    has <- nzchar(r$label) || !is.na(r$fixed) || !is.na(r$start) || !is.na(r$lower) || !is.na(r$upper)
    if (has) {
      shown <- if (nzchar(r$label)) {
        paste0(r$label, "*", r$rhs)
      } else if (!is.na(r$fixed)) {
        paste0(format(r$fixed), "*", r$rhs)
      } else {
        r$rhs
      }
      d <- dummies[[r$rhs]]
      stop("`", shown, "`: `", r$rhs, "` expands to ", length(d), " dummies (", paste(d, collapse = ", "),
           "), so a label, fixed value, start or bound would name several coefficients; label one dummy, e.g. `",
           if (nzchar(r$label)) r$label else "b", "*", d[1L], "`", call. = FALSE)
    }
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
  for (d in info$dummies) {
    data[[d]] <- as.numeric(x == info$levels[match(d, info$all) + 1L])
  }
  data
}

# Each regression row naming a factor becomes one row per dummy, other properties kept. A dummy the same equation
# already names explicitly (`y ~ g + b*g_b`) keeps its explicit row, with its label, and is not generated twice.
.sem_expand_table <- function(tab, map) {
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, , drop = FALSE]
    if (r$op == "~" && r$rhs %in% names(map)) {
      d <- setdiff(map[[r$rhs]]$dummies, tab$rhs[tab$op == "~" & tab$lhs == r$lhs])
      if (!length(d)) {
        return(r[0L, , drop = FALSE])
      }
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
