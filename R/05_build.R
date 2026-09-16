#!/usr/bin/env Rscript
#'
#' Assemble the parsed observations into the tables the site and the exports
#' read.
#'
#' Three jobs. It turns the facility register's saturation events into
#' facility-level strain observations, so a saturated CTE sits in the same
#' long schema as a province bed count. It builds one row per place per day
#' with beds, patients and occupancy, computing the rate where the report
#' printed the parts but not the ratio, and comparing the two where the
#' report printed both. And it writes the coverage table, which says for each
#' report which indicators it carried -- the artefact that stops a template
#' change reading as an epidemiological change.
#'
#' Nothing is carried across a report that does not report it. A gap in a
#' series is a gap.
#'
#' Usage:
#'     Rscript R/05_build.R [--out=data/derived]
#'
#' Reads:  data/observations/*.csv, data/registry/*.csv
#' Writes: data/observations/strain.csv, data/derived/occupancy_daily.csv,
#'         data/derived/coverage.csv

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit) == 0) return(default)
    sub(paste0("^--", name, "="), "", hit[1])
}

OBS_DIR <- arg_value("obs", "data/observations")
REG_DIR <- arg_value("registry", "data/registry")
OUT_DIR <- arg_value("out", "data/derived")

OBS_COLS <- c("indicator_id", "level", "place_id", "place_name",
              "report_date", "sitrep", "version", "value", "unit",
              "basis", "derivation", "evidence_quote", "page",
              "text_source", "confidence", "flags", "places_included",
              "note")

read_obs <- function(file) {
    path <- file.path(OBS_DIR, file)
    if (!file.exists(path)) return(NULL)
    fread(path, colClasses = list(numeric = "value", character = "flags"))
}

reports <- fread(file.path(REG_DIR, "reports.csv"))
indicators <- fread(file.path(REG_DIR, "indicators.csv"))
eras <- fread(file.path(REG_DIR, "eras.csv"))

# ---- facility strain, from the register ----------------------------------

#' The facility register already holds every statement a report makes about a
#' treatment or transit centre, each with a French quote checked verbatim
#' against that report. Saturation is one of its event values, so strain at
#' facility level needs no new reading: it is a reshape of what is there.
events <- fread(file.path(REG_DIR, "facility_events.csv"))
facilities <- fread(file.path(REG_DIR, "facilities.csv"))

EVENT_INDICATOR <- c(
    strained = "facility_saturated",
    expanded = "facility_expanded",
    closed = "facility_closed",
    incident = "facility_incident"
)

strain <- events[event %in% names(EVENT_INDICATOR)]
strain[, indicator_id := EVENT_INDICATOR[event]]
strain <- strain[, .(
    indicator_id,
    level = "facility",
    place_id = facility_id,
    place_name = facility_name,
    report_date,
    sitrep,
    version,
    value = 1,
    unit = "flag",
    basis = "read",
    derivation = "",
    evidence_quote,
    page = NA_integer_,
    text_source,
    confidence,
    flags = "",
    places_included = "",
    note = status_note
)]

#' Bed capacity stated for a named facility, where the reading recorded one.
fac_beds <- events[!is.na(beds) & beds > 0]
if (nrow(fac_beds) > 0) {
    fac_beds <- fac_beds[, .(
        indicator_id = "beds_total",
        level = "facility",
        place_id = facility_id,
        place_name = facility_name,
        report_date,
        sitrep,
        version,
        value = as.numeric(beds),
        unit = "beds",
        basis = "read",
        derivation = "",
        evidence_quote,
        page = NA_integer_,
        text_source,
        confidence,
        flags = "",
        places_included = "",
        note = status_note
    )]
}
strain <- rbindlist(list(strain, fac_beds), use.names = TRUE)
setcolorder(strain, OBS_COLS)
setorder(strain, sitrep, version, indicator_id, place_id)
fwrite(strain, file.path(OBS_DIR, "strain.csv"))
message("wrote ", file.path(OBS_DIR, "strain.csv"), ": ", nrow(strain))
print(strain[, .N, by = .(indicator_id, basis)])

# ---- one row per place per report ----------------------------------------

obs <- rbindlist(list(read_obs("capacity.csv"), read_obs("occupancy.csv")),
                 use.names = TRUE)

wide <- dcast(
    obs[level %in% c("province", "national")],
    sitrep + version + report_date + place_id + place_name + level +
        basis ~ indicator_id,
    value.var = "value", fun.aggregate = function(x) x[1]
)
for (col in c("beds_total", "patients_isolated", "occupancy_rate",
              "admissions_24h", "exits_24h", "patients_confirmed",
              "patients_suspect", "patients_start_day")) {
    if (!col %in% names(wide)) wide[, (col) := NA_real_]
}

wide[, occupancy_rate_derived := fifelse(
    !is.na(patients_isolated) & !is.na(beds_total) & beds_total > 0,
    round(100 * patients_isolated / beds_total, 1), NA_real_)]

#' Two routes to the same quantity. Where the report prints the rate and also
#' prints its parts, both are kept and a disagreement is flagged rather than
#' resolved: the reports do disagree with themselves, and which number is
#' right is not a decision this repository should make silently.
wide[, rate_gap := abs(occupancy_rate - occupancy_rate_derived)]
wide[, flags := fifelse(!is.na(rate_gap) & rate_gap > 1,
                        "rate_disagrees", "")]

#' A report that repeats the previous report's figures without a fresh table
#' behind it is not a new observation. Flagged, not dropped, so the run of
#' identical values stays visible.
setorder(wide, place_id, report_date, sitrep)
wide[, carried := !is.na(beds_total) &
         beds_total == shift(beds_total) &
         !is.na(patients_isolated) &
         patients_isolated == shift(patients_isolated),
     by = place_id]
wide[carried == TRUE,
     flags := trimws(paste(flags, "carry_forward"))]
wide[, carried := NULL]

setcolorder(wide, c("report_date", "sitrep", "version", "level",
                    "place_id", "place_name", "basis"))
setorder(wide, report_date, sitrep, place_id)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
fwrite(wide, file.path(OUT_DIR, "occupancy_daily.csv"))
message("wrote ", file.path(OUT_DIR, "occupancy_daily.csv"), ": ",
        nrow(wide))

# ---- coverage ------------------------------------------------------------

#' For every report and every indicator this repository claims to track, one
#' of three states. `reported` is a value. `not_reported` is the report
#' naming the place and printing ND. `absent` is the template not carrying
#' the indicator at all. Only the first is data; the difference between the
#' other two is the difference between a province that went quiet and a
#' template that changed.
era_of <- function(s) {
    i <- which(eras$sitrep_from <= s & eras$sitrep_to >= s)
    if (length(i) == 0) return(NA_character_)
    eras$era_id[i[1]]
}

all_obs <- rbindlist(list(obs, strain), use.names = TRUE)
grid <- CJ(report_key = reports[, paste(sitrep, version)],
           indicator_id = indicators$indicator_id, unique = TRUE)
grid[, sitrep := as.integer(sub(" .*$", "", report_key))]
grid[, version := as.integer(sub("^.* ", "", report_key))]
grid[, report_key := NULL]
grid <- merge(grid, reports[, .(sitrep, version, report_date)],
              by = c("sitrep", "version"))

summ <- all_obs[, .(
    n_values = sum(!is.na(value)),
    n_nd = sum(is.na(value)),
    places = paste(sort(unique(place_id[!is.na(value)])), collapse = ";")
), by = .(sitrep, version, indicator_id)]

coverage <- merge(grid, summ, by = c("sitrep", "version", "indicator_id"),
                  all.x = TRUE)
coverage[is.na(n_values), n_values := 0L]
coverage[is.na(n_nd), n_nd := 0L]
coverage[is.na(places), places := ""]
coverage[, status := fifelse(n_values > 0, "reported",
                     fifelse(n_nd > 0, "not_reported", "absent"))]
coverage[, era := vapply(sitrep, era_of, character(1))]
setcolorder(coverage, c("sitrep", "version", "report_date", "era",
                        "indicator_id", "status", "n_values", "n_nd",
                        "places"))
setorder(coverage, sitrep, version, indicator_id)
fwrite(coverage, file.path(OUT_DIR, "coverage.csv"))
message("wrote ", file.path(OUT_DIR, "coverage.csv"), ": ", nrow(coverage))
print(coverage[, .N, by = .(era, status)][order(era, status)])
