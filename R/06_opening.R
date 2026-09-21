#!/usr/bin/env Rscript
# ai-written
#'
#' When each facility opened, as an interval rather than a date.
#'
#' The reports almost never say. Across 116 of them the INSP gives an opening
#' date for no facility at all: an opening is announced on the day it is
#' reported and the date is the report's. So an opening date here is inferred
#' from two kinds of evidence pointing in opposite directions.
#'
#' Evidence that it was not yet open: a `planned` or `under_construction`
#' event. The facility was open no earlier than that report.
#'
#' Evidence that it was open: an `operating`, `expanded`, `strained` or
#' `incident` event, or an announced opening. The facility was open no later
#' than the earlier of those.
#'
#' `mention_only` is not evidence either way. A decontamination or a supply
#' delivery says the response touched the place, not whether it was holding
#' patients.
#'
#' The announcement is not treated as the opening. Where a facility has both,
#' the median gap between the announcement and the first report showing
#' patients is minus four days: half of them were already in service when the
#' opening was announced. So the upper bound takes whichever came first.
#'
#' Every facility is here, including the ones the register has not yet decided
#' are the same as another. `flags` says which those are.
#'
#' Usage:
#'     Rscript R/06_opening.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))

NOT_YET_OPEN <- c("planned", "under_construction")
IN_SERVICE <- c("operating", "expanded", "strained", "incident")

events <- fread(events_path())
facilities <- fread(facilities_path())

res <- events[nzchar(facility_id)]

bounds <- res[, {
    open_by <- suppressWarnings(min(c(
        report_date[event %in% IN_SERVICE],
        report_date[event == "opened"]), na.rm = TRUE))
    if (!is.finite(open_by)) open_by <- NA_integer_
    #' Only a not-yet-open report that predates the upper bound narrows
    #' anything. A `planned` event after the centre was in service is a
    #' second structure being announced, or a report repeating itself.
    prior <- report_date[event %in% NOT_YET_OPEN &
        (is.na(open_by) | report_date < open_by)]
    open_after <- suppressWarnings(max(prior, na.rm = TRUE))
    if (!is.finite(open_after)) open_after <- NA_integer_
    .(
        opened_after = as.Date(open_after),
        opened_by = as.Date(open_by),
        first_service = as.Date(suppressWarnings(
            min(report_date[event %in% IN_SERVICE], na.rm = TRUE))),
        announced = as.Date(suppressWarnings(
            min(report_date[event == "opened"], na.rm = TRUE))),
        last_not_open = as.Date(open_after)
    )
}, by = facility_id]
for (col in c("first_service", "announced")) {
    bounds[!is.finite(get(col)), (col) := NA]
}

out <- merge(facilities[, .(facility_id, facility_name, site_kind, place_key,
    health_zone, province, date_first_mentioned, first_mention_after_gap,
    date_last_mentioned, status_latest, beds_latest, n_sitreps, n_events,
    flags, aliases)], bounds, by = "facility_id")

out[, basis := fcase(
    !is.na(opened_after) & !is.na(opened_by), "bounded both sides",
    is.na(opened_after) & !is.na(opened_by) &
        !is.na(announced) & (is.na(first_service) | announced <= first_service),
        "announced, no earlier bound",
    is.na(opened_after) & !is.na(opened_by), "in service, no earlier bound",
    !is.na(opened_after), "building, never seen open",
    default = "no opening evidence")]

out[, interval_days := as.integer(opened_by - opened_after)]

#' The midpoint is the only defensible point estimate for a bounded interval
#' and there is none for an unbounded one. Anything else invents precision.
out[, opened_midpoint := as.Date(NA)]
out[basis == "bounded both sides",
    opened_midpoint := opened_after + as.integer(interval_days / 2)]

out[, censoring := fcase(
    basis == "bounded both sides" & first_mention_after_gap == TRUE,
        "bounded, but the report before the first mention was never published",
    basis == "bounded both sides", "bounded",
    basis %in% c("in service, no earlier bound", "announced, no earlier bound"),
        "left censored: open by this date, could have opened any time before",
    basis == "building, never seen open",
        "right censored: not open as of this date, never reported in service",
    default = "uninformative: named, but never reported open or building")]

out[, explanation := fcase(
    basis == "bounded both sides", paste0(
        "Reported still building on ", opened_after,
        " and holding patients by ", opened_by, ", so it opened in the ",
        interval_days, " days between."),
    basis == "in service, no earlier bound", paste0(
        "First reported holding patients on ", opened_by,
        ". No report shows it being built, so it may have opened much earlier."),
    basis == "announced, no earlier bound", paste0(
        "Opening announced on ", announced,
        ". No report shows it being built, so it may have opened earlier."),
    basis == "building, never seen open", paste0(
        "Reported under construction or planned up to ", opened_after,
        ", and never reported holding patients."),
    default = "Named by a report, but nothing says it was built or in use.")]

setcolorder(out, c("facility_id", "facility_name", "site_kind", "place_key",
    "health_zone", "province", "opened_after", "opened_by", "opened_midpoint",
    "interval_days", "basis", "censoring", "explanation"))
setorder(out, site_kind, opened_by, facility_id)

dir.create(here::here("outputs"), showWarnings = FALSE, recursive = TRUE)
path <- file.path(here::here("outputs"), "etc-opening.csv")
fwrite(out, path)

# ----------------------------------------------------------------- report

message(nrow(out), " facilities.\n")
print(out[, .N, by = .(site_kind, basis)][order(site_kind, -N)])
message("\nTreatment and transit centres only:")
tc <- out[site_kind %in% c("treatment_centre", "transit_centre")]
print(tc[, .(n = .N, median_interval = as.integer(median(interval_days, na.rm = TRUE))),
    by = basis][order(-n)])
message("\nBounded intervals, how wide:")
print(tc[basis == "bounded both sides", .(
    n = .N, min = min(interval_days), median = as.integer(median(interval_days)),
    max = max(interval_days))])
message("\nWritten: ", path)
