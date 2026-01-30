## ----results='asis', echo=FALSE-----------------------------------------------
cat(gsub("\\n   ", "", packageDescription("dat", fields = "Description")))

## ----eval=FALSE---------------------------------------------------------------
# remotes::install_github("wahani/dat")

## ----eval=FALSE---------------------------------------------------------------
# install.packages("dat")

## -----------------------------------------------------------------------------
library("nycflights13")
library("dat")

## ----results='hide'-----------------------------------------------------------
mutar(flights, ~ month == 1 & day == 1)
mutar(flights, ~ 1:10)

## -----------------------------------------------------------------------------
mutar(flights, ~ order(year, month, day))

## ----results='hide'-----------------------------------------------------------
flights %>%
  extract(c("year", "month", "day")) %>%
  extract("^day$") %>%
  extract(is.numeric)

## ----results='hide'-----------------------------------------------------------
mutar(
  flights,
  gain ~ arr_delay - dep_delay,
  speed ~ distance / air_time * 60
)

## ----results = 'hide'---------------------------------------------------------
mutar(flights, n ~ .N, by = "month")

## ----results='hide'-----------------------------------------------------------
mutar(flights, delay ~ mean(dep_delay, na.rm = TRUE), by = "month")

## -----------------------------------------------------------------------------
mutar(
  flights,
  .n ~ mean(.n, na.rm = TRUE) | "^.*delay$",
  .x ~ mean(.x, na.rm = TRUE) | list(.x = "arr_time"),
  by = "month"
)

## ----eval = FALSE-------------------------------------------------------------
# library("data.table")
# 
# setClass("DataTable", "data.table")
# 
# DataTable <- function(...) {
#   new("DataTable", data.table::data.table(...))
# }
# 
# setMethod("[", "DataTable", mutar)
# 
# dtflights <- do.call(DataTable, nycflights13::flights)
# 
# dtflights[1:10, c("year", "month", "day")]
# dtflights[n ~ .N, by = "month"]
# dtflights[n ~ .N, sby = "month"]
# 
# dtflights %>%
#   filtar(~month > 6) %>%
#   mutar(n ~ .N, by = "month") %>%
#   sumar(n ~ data.table::first(n), by = "month")

## ----eval=FALSE---------------------------------------------------------------
# map(1:3, ~ .^2)
# flatmap(1:3, ~ .^2)
# map(1:3 ~ 11:13, c) # zip
# dat <- data.frame(x = 1, y = "")
# map(dat, x ~ x + 1, is.numeric)

## ----eval=FALSE---------------------------------------------------------------
# extract(1:10, ~ . %% 2 == 0) %>% sum
# extract(1:15, ~ 15 %% . == 0)
# l <- list(aList = list(x = 1), aAtomic = "hi")
# extract(l, "^aL")
# extract(l, is.atomic)

## ----eval=FALSE---------------------------------------------------------------
# replace(c(1, 2, NA), is.na, 0)
# replace(c(1, 2, NA), rep(TRUE, 3), 0)
# replace(c(1, 2, NA), 3, 0)
# replace(list(x = 1, y = 2), "x", 0)
# replace(list(x = 1, y = 2), "^x$", 0)
# replace(list(x = 1, y = "a"), is.character, NULL)

