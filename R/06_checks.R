#!/usr/bin/env Rscript
#'
#' Invariants that must hold before a build is accepted.
#'
#' The checks are the argument for trusting the tables. Each prints a count
#' and, where it fails, the rows that failed. A failure of the evidence check
#' stops the run: a value whose quote is not in the report is a value that
#' came from nowhere. The rest report and continue, because the reports
#' genuinely contradict themselves and the right response to that is a flag,
#' not a silent correction.
#'
#' Usage:
#'     Rscript R/06_checks.R
#'
#' Reads:  data/observations/*.csv, data/derived/*.csv, data/text/*.txt
#' Writes: outputs/check_failures.csv

suppressPackageStartupMessages(library(data.table))

OBS_DIR <- "data/observations"
DER_DIR <- "data/derived"
REG_DIR <- "data/registry"
TEXT_DIR <- "data/text"

unspace <- function(x) {
    gsub("[     - ⁠﻿]", " ", x,
         perl = TRUE)
}
squash <- function(x) trimws(gsub("\\s+", " ", unspace(x)))

failures <- list()
note_failure <- function(check, dt) {
    if (is.null(dt) || nrow(dt) == 0) return(invisible(NULL))
    failures[[length(failures) + 1L]] <<- data.table(check = check, dt)
}

reports <- fread(file.path(REG_DIR, "reports.csv"))
indicators <- fread(file.path(REG_DIR, "indicators.csv"))
obs <- rbindlist(lapply(
    c("capacity.csv", "occupancy.csv", "strain.csv"),
    function(f) fread(file.path(OBS_DIR, f),
                      colClasses = list(numeric = "value"))),
    use.names = TRUE)
message("observations: ", nrow(obs))

# ---- 1. every quote is in its report --------------------------------------

texts <- new.env(parent = emptyenv())
for (i in seq_len(nrow(reports))) {
    key <- paste(reports$sitrep[i], reports$version[i])
    path <- file.path(TEXT_DIR, reports$text_file[i])
    if (!file.exists(path)) next
    assign(key, squash(paste(readLines(path, warn = FALSE)[-1],
                             collapse = " ")), envir = texts)
}

obs[, quote_found := {
    key <- paste(sitrep, version)
    vapply(seq_len(.N), function(k) {
        body <- mget(key[k], envir = texts, ifnotfound = list(NA))[[1]]
        if (is.na(body)) return(NA)
        grepl(squash(evidence_quote[k]), body, fixed = TRUE)
    }, logical(1))
}]
bad_quotes <- obs[quote_found %in% FALSE]
message("1. evidence: ", nrow(bad_quotes), " of ", nrow(obs),
        " quotes not found verbatim")
note_failure("evidence", bad_quotes[, .(sitrep, version, indicator_id,
                                        place_id, evidence_quote)])

# ---- 2. the vocabularies are closed ---------------------------------------

unknown <- obs[!indicator_id %in% indicators$indicator_id,
               .(sitrep, version, indicator_id, place_id)]
message("2. vocabulary: ", nrow(unknown), " rows with an unregistered ",
        "indicator")
note_failure("vocabulary", unknown)

bad_basis <- obs[!basis %in% c("table", "prose", "read", "derived"),
                 .(sitrep, version, indicator_id, place_id,
                   evidence_quote = basis)]
note_failure("basis", bad_basis)

# ---- 3. the day balances ---------------------------------------------------

daily <- fread(file.path(DER_DIR, "occupancy_daily.csv"))

bal <- daily[!is.na(patients_start_day) & !is.na(admissions_24h) &
                 !is.na(exits_24h) & !is.na(patients_isolated)]
bal[, expected := patients_start_day + admissions_24h - exits_24h]
bal[, gap := patients_isolated - expected]
message("3. balance: ", bal[abs(gap) > 0, .N], " of ", nrow(bal),
        " day-place rows where start + admissions - exits != end")
note_failure("balance", bal[abs(gap) > 0,
                            .(sitrep, version, place_id,
                              patients_start_day, admissions_24h,
                              exits_24h, patients_isolated, gap)])

# ---- 4. the case split sums ----------------------------------------------

split <- daily[!is.na(patients_confirmed) & !is.na(patients_suspect) &
                   !is.na(patients_isolated)]
split[, gap := patients_isolated - (patients_confirmed + patients_suspect)]
message("4. case split: ", split[abs(gap) > 0, .N], " of ", nrow(split),
        " rows where confirmed + suspect != patients in isolation")
note_failure("case_split", split[abs(gap) > 0,
                                 .(sitrep, version, place_id,
                                   patients_confirmed, patients_suspect,
                                   patients_isolated, gap)])

# ---- 5. the total is the sum of its parts --------------------------------

#' Only over the places the same table row actually filled in, which is what
#' `places_included` records. A national total is otherwise compared against
#' a set of provinces that did not all report.
tot <- obs[level == "national" & !is.na(value) & places_included != ""]
parts_of <- function(sr, vr, ind, included) {
    want <- strsplit(included, ";")[[1]]
    p <- obs[sitrep == sr & version == vr & indicator_id == ind &
                 place_id %in% want & !is.na(value), value]
    if (length(p) == 0) NA_real_ else sum(p)
}
tot[, parts := vapply(seq_len(.N), function(k)
    parts_of(sitrep[k], version[k], indicator_id[k], places_included[k]),
    numeric(1))]
tot <- tot[indicator_id != "occupancy_rate"]  # a rate is not additive
tot[, gap := value - parts]
message("5. total: ", tot[!is.na(gap) & abs(gap) > 0, .N], " of ",
        nrow(tot), " national totals that differ from the provinces ",
        "they name")
note_failure("total", tot[!is.na(gap) & abs(gap) > 0,
                          .(sitrep, version, indicator_id, value, parts,
                            gap)])

# ---- 6. the two routes to the occupancy rate agree -----------------------

two <- daily[!is.na(occupancy_rate) & !is.na(occupancy_rate_derived)]
message("6. two routes: ", two[abs(rate_gap) > 1, .N], " of ", nrow(two),
        " rows where the printed rate and patients / beds differ by more ",
        "than one point")
note_failure("two_routes", two[abs(rate_gap) > 1,
                               .(sitrep, version, place_id, beds_total,
                                 patients_isolated, occupancy_rate,
                                 occupancy_rate_derived, rate_gap)])

# ---- 7. the coverage table accounts for every report ---------------------

coverage <- fread(file.path(DER_DIR, "coverage.csv"))
expect <- nrow(reports) * nrow(indicators)
message("7. coverage: ", nrow(coverage), " rows, expected ", expect)
if (nrow(coverage) != expect) {
    note_failure("coverage", data.table(sitrep = NA_integer_,
                                        version = NA_integer_,
                                        evidence_quote = paste(
                                            nrow(coverage), "rows, expected",
                                            expect)))
}

# ---- report ---------------------------------------------------------------

dir.create("outputs", showWarnings = FALSE)
if (length(failures) > 0) {
    out <- rbindlist(failures, fill = TRUE)
    fwrite(out, "outputs/check_failures.csv")
    message("\nwrote outputs/check_failures.csv: ", nrow(out), " rows")
    print(out[, .N, by = check])
} else {
    message("\nall checks clean")
    unlink("outputs/check_failures.csv")
}

if (nrow(bad_quotes) > 0) {
    stop("evidence check failed: ", nrow(bad_quotes),
         " quotes not found in their report")
}
