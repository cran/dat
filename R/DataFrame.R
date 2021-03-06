#' DataFrame and methods
#'
#' This is a 'data.table' like implementation of a data.frame. Either dplyr or
#' data.table is used as backend. The only purpose is to have \code{R CMD check}
#' friendly syntax.
#'
#' @include helper.R
#' @include FormulaList.R
#'
#' @param x (DataFrame | data.frame)
#' @param i (logical | numeric | integer | OneSidedFormula | TwoSidedFormula |
#'   FormulaList) see the examples.
#' @param j (logical | character | TwoSidedFormula | FormulaList | function)
#'   character beginning with '^' are interpreted as regular expression
#' @param ... arbitrary number of args
#'    \cr in \code{[} (TwoSidedFormulas)
#'    \cr in constructor see \link[tibble]{tibble}
#' @param by,sby (character) variables to group by. by will be used to do
#'   transformations within groups. sby will collapse each group to one row.
#' @param drop (ignored) never drops the class.
#'
#' @details
#' \code{OneSidedFormula} is always used for subsetting rows.
#'
#' \code{TwoSidedFormula} is used instead of name-value expressions in
#' \code{summarise} and \code{mutate}.
#'
#' @examples
#' data("airquality")
#' dat <- as.DataFrame(airquality)
#' dat[~ Month > 4, ][meanWind ~ mean(Wind), sby = "Month"]["meanWind"]
#' dat[FL(.n ~ mean(.n), .n = c("Wind", "Temp")), sby = "Month"]
#'
#' @seealso \link{mutar}, \link{FL}
#'
#' @rdname DataFrame
#' @export
DataFrame <- function(...) {
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop("The DataFrame class is based on a tibble. Please install 'tibble'",
         "using 'install.packages(tibble)' for this to work.")
  }
  dat <- tibble::tibble(...)
  addClass(dat, "DataFrame")
}

#' @name DataFrame
#' @export
#' @rdname DataFrame
setOldClass(c("DataFrame", "tbl_df", "tbl", "data.frame"))

#' @rdname DataFrame
#' @export
as.DataFrame <- function(x, ...) UseMethod("as.DataFrame")

#' @rdname DataFrame
#' @export
as.DataFrame.default <- function(x, ...) {
  do.call(DataFrame, as.list(x))
}

#' @rdname DataFrame
#' @export
as.DataFrame.data.frame <- function(x, ...) {
  addClass(x, c("DataFrame", "tbl_df", "tbl", "data.frame"))
}

#' @rdname DataFrame
#' @export
"[.DataFrame" <- function(x, i, j, ..., by, sby, drop) {
  # this is basically the dispatch function. I do NOT use default values because
  # missing arguments have a meaning in the special syntax expected from [

  # Assertions:
  stopifnot(inherits(x, "data.frame"))

  # This is hands on dispatch for missing arguments:
  j <- if (missing(j)) NULL else j
  j <- if (!missing(i) && nargs() == 2) i else j
  i <- if (missing(i) || nargs() == 2) NULL else i
  by <- if (missing(by)) NULL else by
  sby <- if (missing(sby)) NULL else sby

  memClassHandler <- MemClassHandler()
  x <- memClassHandler$memClass(x)
  x <- memClassHandler$stripClass(x)
  x <- handleRows(x, dispatcher(i))
  x <- handleCols(x, dispatcher(i), dispatcher(j), ..., by = by, sby = sby)
  memClassHandler$wrapClass(x)

}

data.frame : handleRows(x, i) %g% standardGeneric("handleRows")

handleRows(x ~ data.frame, i ~ NULL) %m% x

handleRows(x ~ data.frame, i ~ logical | numeric | integer) %m% {
  x[i, , drop = FALSE]
}

handleRows(x ~ data.frame, i ~ OneSidedFormula) %m% {
  envir <- environment(i)
  expr <- parse(text = sub("~", "", deparse(i)))
  handleRows(x, eval(expr, envir = x, enclos = envir))
}

handleRows(x ~ data.frame, i ~ TwoSidedFormula) %m% x

handleRows(x ~ data.frame, i ~ FormulaList) %m% x


################################################################################

data.frame : handleCols(x, i, j, ..., by, sby) %g% standardGeneric("handleCols")

handleCols(x ~ data.frame, i ~ NULL, j ~ NULL, ..., by ~ NULL, sby ~ NULL) %m% x

handleCols(x ~ data.frame, i ~ NULL, j ~ character, ..., by ~ NULL, sby ~ NULL) %m% {
  if (useDplyr()) {
    dplyr::select_(x, .dots = j)
  } else {
    .SD <- NULL # to apeace R CMD check
    x[, .SD, .SDcols = j]
  }
}

handleCols(x ~ data.frame, i ~ NULL, j ~ RegEx, ..., by ~ NULL, sby ~ NULL) %m% {
  handleCols(x, NULL, names(x)[grepl(j, names(x))], ..., by = NULL, sby = NULL)
}

handleCols(x ~ data.frame, i ~ NULL, j ~ logical, ..., by ~ NULL, sby ~ NULL) %m% {
  handleCols(x, NULL, names(x)[j], ..., by = NULL, sby = NULL)
}

handleCols(x ~ data.frame, i ~ NULL, j ~ "function", ..., by ~ NULL, sby ~ NULL) %m% {
  mutar(x, vapply(x, j, logical(1)))
}

handleCols(x ~ data.frame, i ~ NULL, j ~ OneSidedFormula, ..., by ~ NULL, sby ~ NULL) %m% {
  handleRows(x, j)
}

handleCols(x ~ data.frame,
           i ~ NULL | FormulaList, j ~ NULL | FormulaList, ...,
           by ~ ANY, sby ~ ANY) %m% {

             i <- update(i, x)
             j <- update(j, x)

             do.call(
               mutar,
               c(list(x = x, i = NULL, by = by, sby = sby), i, j, list(...))
             )

           }

handleCols(x ~ data.frame,
           i ~ logical | numeric | integer | OneSidedFormula,
           j ~ ANY, ..., by ~ ANY, sby ~ ANY) %m% {
             handleCols(x, NULL, j, ..., by = by, sby = sby)
           }

handleCols(x ~ data.frame,
           i ~ TwoSidedFormula | NULL,
           j ~ TwoSidedFormula | NULL,
           ..., by ~ NULL, sby ~ NULL) %m% {
             args <- constructArgs(i, j, ..., dat = x)
             if (useDplyr()) {
               dplyr::mutate_(x, .dots = args)
             } else {
               dataTableMutate(x, args)
             }
           }


handleCols(x ~ data.frame,
           i ~ TwoSidedFormula | NULL,
           j ~ TwoSidedFormula | NULL,
           ..., by ~ NULL, sby ~ character) %m% {
             args <- constructArgs(i, j, ..., dat = x)
             if (useDplyr()) {
               x <- dplyr::group_by_(x, .dots = sby)
               dplyr::summarise_(x, .dots = args)
             } else {
               dataTableSummariseBy(x, args, sby)
             }
           }

handleCols(x ~ data.frame,
           i ~ TwoSidedFormula | NULL,
           j ~ TwoSidedFormula | NULL,
           ..., by ~ character, sby ~ NULL) %m% {
             args <- constructArgs(i, j, ..., dat = x)
             if (useDplyr()) {
               dplyr::group_by_(x, .dots = by) %>%
                 dplyr::mutate_(.dots = args)
             } else {
               dataTableMutateBy(x, args, by)
             }
           }
