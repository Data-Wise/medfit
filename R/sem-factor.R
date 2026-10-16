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
    # a product-only factor has no dummy columns in the stored data: its product columns are there instead
    if (isTRUE(use[[v]]$product_only)) {
      next
    }
    miss <- setdiff(use[[v]]$dummies, names(data))
    if (length(miss)) {
      stop("the refit needs the dummy columns of `", v, "`, absent from `data`: ", paste(miss, collapse = ", "),
           call. = FALSE)
    }
  }
  use
}

.sem_expand_new_factors <- function(tab, data, fixed_x) {
  # the names a regression's right side uses: a product is split at the colon, so a factor that appears only inside
  # a product (`y ~ m + g:m`) is found too
  rhs_names <- unique(unlist(strsplit(tab$rhs[tab$op == "~"], ":", fixed = TRUE)))
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
    # a factor that only appears inside products: its dummies are not model variables (only the product columns are)
    map[[v]]$product_only <- v %in% bare && !(v %in% tab$rhs[tab$op == "~"])
  }
  dummies <- lapply(map, function(m) m$dummies)
  latent <- tab$lhs[tab$op == "=~"]
  .sem_check_dummy_names(map, dummies, c(names(data), latent))
  .sem_check_factor_modifiers(tab, map[intersect(names(map), bare)])
  for (v in cats) {
    data <- .sem_add_dummies(data, v, map[[v]])
  }
  list(table = .sem_expand_table(tab, map[intersect(names(map), bare)]), data = data,
       fixed_x = .sem_expand_fixed_x(fixed_x, map), map = map)
}

# The parser rejects a constraint that names a factor column ("unknown parameter label 'g'") before the pre-pass
# runs; a factor expands to several dummies, so say that instead. `msg` is the parse error's message.
.sem_factor_label_hint <- function(msg, data) {
  nm <- sub("^unknown parameter label '(.*)'$", "\\1", msg)
  if (identical(nm, msg) || !nm %in% names(data)) {
    return(NULL)
  }
  x <- data[[nm]]
  if (!(is.factor(x) || is.character(x) || is.logical(x))) {
    return(NULL)
  }
  d <- tryCatch(.sem_factor_dummy_names(nm, .sem_factor_levels(nm, x)), error = function(e) character())
  one <- if (length(d)) d[1L] else paste0(nm, "_<level>")
  paste0("`", nm, "` is a categorical column, which a regression expands to dummies", if (length(d)) {
    paste0(" (", paste(d, collapse = ", "), ")")
  }, ", so a constraint cannot name it: label one dummy and constrain the label, for example `b*", one,
  "` in the regression and `b == 0`")
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
.sem_check_factor_modifiers <- function(tab, map) {
  for (i in which(tab$op == "~")) {
    r <- tab[i, ]
    d <- .sem_row_expansion(r$rhs, map)
    has <- nzchar(r$label) || !is.na(r$fixed) || !is.na(r$start) || !is.na(r$lower) || !is.na(r$upper)
    if (!is.null(d) && has) {
      shown <- if (nzchar(r$label)) {
        paste0(r$label, "*", r$rhs)
      } else if (!is.na(r$fixed)) {
        paste0(format(r$fixed), "*", r$rhs)
      } else {
        r$rhs
      }
      stop("`", shown, "`: `", r$rhs, "` expands to ", length(d), " terms (", paste(d, collapse = ", "),
           "), so a label, fixed value, start or bound would name several coefficients; label one, e.g. `",
           if (nzchar(r$label)) r$label else "b", "*", d[1L], "`", call. = FALSE)
    }
  }
  invisible(NULL)
}

# The terms a regression row's right side expands to when a side is a categorical column of `map`: the dummies for
# `g`, one canonical product per dummy for `g:m`; NULL when no side is categorical. A product of two categorical
# columns is not supported (write the dummy products you need, for example `g_b:h_v`).
.sem_row_expansion <- function(rhs, map) {
  sides <- strsplit(rhs, ":", fixed = TRUE)[[1L]]
  hit <- sides %in% names(map)
  if (!any(hit)) {
    return(NULL)
  }
  if (all(hit) && length(sides) == 2L) {
    stop("the product `", rhs, "`: both sides are categorical columns, which is not supported; write the dummy ",
         "products you need, for example `", map[[sides[1L]]]$dummies[1L], ":", map[[sides[2L]]]$dummies[1L], "`",
         call. = FALSE)
  }
  if (length(sides) == 1L) {
    return(map[[sides]]$dummies)
  }
  other <- sides[!hit]
  vapply(map[[sides[hit]]]$dummies, function(d) .sem_product_name(d, other), "", USE.NAMES = FALSE)
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

# Each regression row naming a factor (alone or in a product) becomes one row per dummy term, other properties kept.
# A term the same equation already names explicitly (`y ~ g + b*g_b`, `g:m + b*g_b:m`) keeps its explicit row, with
# its label, and is not generated twice.
.sem_expand_table <- function(tab, map) {
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, , drop = FALSE]
    d <- if (r$op == "~") .sem_row_expansion(r$rhs, map)
    if (!is.null(d)) {
      d <- setdiff(d, tab$rhs[tab$op == "~" & tab$lhs == r$lhs])
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
  only <- intersect(fixed_x, names(map)[vapply(map, function(m) isTRUE(m$product_only), TRUE)])
  if (length(only)) {
    stop("`fixed_x` names `", only[1L], "`, which appears only inside products: its dummies are not model ",
         "variables. Name the other variable of the product, or add `", only[1L], "` to the regression as a main ",
         "effect.", call. = FALSE)
  }
  unique(unlist(lapply(fixed_x, function(v) if (v %in% names(map)) map[[v]]$dummies else v), use.names = FALSE))
}

# A generated dummy with no variation in the rows the fit uses would only surface as an unnamed "sample covariance
# matrix is singular"; name it and say why. `data` is the full column (before listwise deletion), `keep` the rows the
# fit uses, `weights` their weights (a zero weight removes a row from the likelihood without dropping it). Read from
# `data`, not from the model's columns: a factor that appears only in products has no dummy among them.
.sem_check_dummy_support <- function(map, data, keep, weights = NULL) {
  if (!length(map) || !any(keep)) {
    return(invisible(NULL))
  }
  use <- if (is.null(weights)) rep(TRUE, sum(keep)) else weights > 0
  for (v in names(map)) {
    info <- map[[v]]
    for (d in info$dummies) {
      full <- data[[d]]
      if (is.null(full)) {
        next
      }
      rows <- full[keep]
      kept <- rows[use]
      if (length(unique(kept)) > 1L) {
        next
      }
      lev <- if (info$logical) "TRUE" else info$levels[match(d, info$all) + 1L]
      why <- if (all(kept == 0)) {
        if (sum(full, na.rm = TRUE) == 0) {
          "no row has this level (an unused factor level: drop it with droplevels())"
        } else if (length(unique(rows)) > 1L) {
          "the level occurs only in rows with zero weight"
        } else {
          "the level occurs only in rows dropped for missing values"
        }
      } else {
        "every row the fit uses has this level"
      }
      stop("dummy `", d, "` (level '", lev, "' of `", v, "`) is constant in the rows the fit uses: ", why,
           call. = FALSE)
    }
  }
  invisible(NULL)
}
