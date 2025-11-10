#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(httr2)
})

fetch_worldtime <- function() {
  library(httr2)
  `%||%` <- function(x, y) if (is.null(x)) y else x
  url <- "https://worldtimeapi.org/api/timezone/Etc/UTC"
  for (i in 1:5) {
    r <- try(
      req_perform(
        request(url) |>
          req_user_agent("gh-actions/1.0") |>
          req_timeout(30) |>
          req_options(ipresolve = 1L, http_version = 1L, fresh_connect = TRUE, forbid_reuse = TRUE)
      ),
      silent = TRUE
    )
    if (!inherits(r, "try-error")) {
      j <- resp_body_json(r)
      return(data.frame(datetime = j$datetime,
                        unixtime = j$unixtime,
                        utc_offset  = j$utc_offset,
                        day_of_week = j$day_of_week,
                        day_of_year = j$day_of_year,
                        week_number = j$week_number,
                        fetched_utc = Sys.time()))
    }
    Sys.sleep(2 ^ i)
  }
  # fallback so it never fails
  data.frame(datetime = NA, unixtime = NA, fetched_utc = Sys.time(), status = "error")
}

#j <- resp_body_json(resp, simplifyVector = TRUE)

# helper to replace NULL with NA of the right type
#nz <- function(x, na) if (is.null(x)) na else x

#df <- data.frame(
#  datetime    = nz(j$datetime,    NA_character_),
#  unixtime    = nz(j$unixtime,    NA_real_),
#  utc_offset  = nz(j$utc_offset,  NA_character_),
#  day_of_week = nz(j$day_of_week, NA_integer_),
#  day_of_year = nz(j$day_of_year, NA_integer_),
#  week_number = nz(j$week_number, NA_integer_),
#  fetched_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
#  stringsAsFactors = FALSE
#)

# Keep a tidy subset + a stamp of when *this* job ran
#df <- df |>
#  select(datetime, unixtime, utc_offset, day_of_week, day_of_year, week_number) |>
#  mutate(fetched_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))

df <- fetch_worldtime()

# Write a single CSV (the Action will commit it if changed)
readr::write_csv(df, "data/data.csv", na = "")

message("Wrote data/data.csv at ", format(Sys.time(), tz = "UTC", usetz = TRUE))
