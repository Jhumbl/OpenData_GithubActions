#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(httr2)
})

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Call World Time API (changes every second)
req <- request("https://worldtimeapi.org/api/timezone/Etc/UTC") |>
  req_user_agent("gh-actions-test/1.0") |>
  req_timeout(15) |>
  req_retry(
    max_tries = 5,                   # try up to 5 times
    backoff = ~ min(60, 2^.x),       # 1s, 2s, 4s, 8s, 16s
    is_transient = function(resp) {
      # retry 5xx and curl-level errors
      httr2::resp_is_error(resp) || inherits(resp, "httr2_rerun")
    }
  )
resp <- req_perform(req)
resp_check_status(resp)

j <- resp_body_json(resp, simplifyVector = TRUE)

# helper to replace NULL with NA of the right type
nz <- function(x, na) if (is.null(x)) na else x

df <- data.frame(
  datetime    = nz(j$datetime,    NA_character_),
  unixtime    = nz(j$unixtime,    NA_real_),
  utc_offset  = nz(j$utc_offset,  NA_character_),
  day_of_week = nz(j$day_of_week, NA_integer_),
  day_of_year = nz(j$day_of_year, NA_integer_),
  week_number = nz(j$week_number, NA_integer_),
  fetched_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  stringsAsFactors = FALSE
)

# Keep a tidy subset + a stamp of when *this* job ran
df <- df |>
  select(datetime, unixtime, utc_offset, day_of_week, day_of_year, week_number) |>
  mutate(fetched_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))

# Write a single CSV (the Action will commit it if changed)
readr::write_csv(df, "data/data.csv", na = "")

message("Wrote data/data.csv at ", format(Sys.time(), tz = "UTC", usetz = TRUE))
