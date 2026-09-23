#!/usr/bin/env Rscript
# ai-written
#'
#' The capacity figures this repository is named for.
#'
#' Three layers describe the response's ability to hold and treat patients,
#' and until now this repository held only the first two.
#'
#'   facility    which facilities exist, when each opened, its latest bed
#'               count and whether it was ever reported strained. From the
#'               INSP reports, in `facilities.csv` and `facility_events.csv`
#'   label       what the INSP tables measure, surveyed in `indicators.csv`.
#'               `patients au lit (j-1)` runs 2 June to 2 August and
#'               `taux d'occupation global` to 11 July, and then the bed
#'               tables stop appearing
#'   system      how many beds exist and how full they are, week by week
#'
#' The third layer is this script, and the gap is why it matters: the INSP
#' bed tables end in early August while the outbreak runs into late September.
#' WHO AFRO's weekly reports carry bed capacity and occupancy in their
#' headline figures through 20 September, so the series continues where the
#' national tables stop.
#'
#' The vocabulary is fixed here, in `INDICATORS`, rather than taken from
#' whatever a document happens to call a thing. A later pass over the INSP
#' tables writes rows into the same table with the same vocabulary, which is
#' the point of fixing it now: one indicator series, two sources, and a
#' `source` column saying which said what.
#'
#' Same machinery as everything else: one model call a document, a fixed
#' schema, a quote checked character for character against the text the model
#' was shown. A figure whose quote is not a span of the document is dropped.
#'
#' Usage:
#'     Rscript R/30_capacity.R [--source=who_afro] [--only=ID] [--force]

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "gemini.R"))
source(here::here("R", "lib", "corpus.R"))
source(here::here("R", "lib", "external.R"))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
    hit <- grep(paste0("^", flag, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^", flag, "="), "", hit[1]) else NULL
}
SOURCE <- arg_value("--source") %||% "who_afro"
only <- arg_value("--only")
ONLY <- if (!is.null(only)) trimws(strsplit(only, ",")[[1]]) else NULL
FORCE <- "--force" %in% args

EXTRACT_THINKING <- Sys.getenv("GEMINI_THINKING_EXTRACT", unset = "low")

PROMPT <- paste(readLines(here::here("assets", "prompt-capacity.md"),
    warn = FALSE), collapse = "\n")

INDICATORS <- c("beds_capacity", "beds_occupied", "bed_occupancy_pct",
    "patients_in_isolation", "admissions", "discharges_recovered",
    "deaths_in_facility", "escapes", "facilities_operational",
    "laboratories_testing")
LEVELS <- c("national", "province", "health_zone", "facility")
UNITS <- c("beds", "patients", "percent", "facilities", "laboratories")
PERIODS <- c("point", "24h", "7d", "cumulative")

FIELDS <- c("indicator", "level", "country", "place_raw", "value", "unit",
    "period", "as_of_date", "evidence_quote", "confidence")

str_field <- function() list(type = "STRING")

SCHEMA <- list(
    type = "OBJECT",
    properties = list(
        indicators = list(type = "ARRAY", items = list(
            type = "OBJECT",
            properties = list(
                indicator = list(type = "STRING", enum = I(INDICATORS)),
                level = list(type = "STRING", enum = I(LEVELS)),
                country = str_field(),
                place_raw = str_field(),
                value = str_field(),
                unit = list(type = "STRING", enum = I(UNITS)),
                period = list(type = "STRING", enum = I(PERIODS)),
                as_of_date = str_field(),
                evidence_quote = str_field(),
                confidence = list(type = "STRING", enum = I(c("high", "low")))
            ),
            required = as.list(FIELDS),
            propertyOrdering = as.list(FIELDS)
        ))
    ),
    required = list("indicators")
)

SCHEMA_MD5 <- digest::digest(
    as.character(jsonlite::toJSON(SCHEMA, auto_unbox = TRUE)),
    algo = "md5", serialize = FALSE)
PROMPT_MD5 <- digest::digest(PROMPT, algo = "md5", serialize = FALSE)

capacity_cache_dir <- function(...) here::here("data", "cache-capacity", ...)
capacity_path <- function() here::here("data", "capacity_indicators.csv")

extract_key <- function(text) {
    paste(c(digest::digest(text, algo = "md5", serialize = FALSE),
        PROMPT_MD5, SCHEMA_MD5,
        gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING)),
        collapse = ":")
}

cache_path <- function(source, id) {
    capacity_cache_dir(paste0(source, "-", id, ".json"))
}

cached_key <- function(source, id) {
    path <- cache_path(source, id)
    if (!file.exists(path)) return(NA_character_)
    got <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
        error = function(e) NULL)
    got$extract_key %||% NA_character_
}

tidy_row <- function(e) {
    out <- lapply(FIELDS, function(f) {
        v <- e[[f]]
        if (is.null(v) || !length(v)) "" else trimws(as.character(v)[1])
    })
    setNames(out, FIELDS)
}

extract_one <- function(source, id) {
    text <- read_external_text(source, id)
    key <- extract_key(text)
    if (!FORCE && identical(cached_key(source, id), key)) return("cached")

    meta <- external_meta(source, id)
    res <- gemini(
        parts = list(gemini_text_part(paste(PROMPT, "\n\n---\n\n", text))),
        schema = SCHEMA,
        model = GEMINI_MODEL_EXTRACT,
        label = paste0(source, "-", id, "/capacity"),
        thinking_level = EXTRACT_THINKING
    )
    rows <- lapply(res$indicators %||% list(), tidy_row)

    bad <- sum(!vapply(rows, function(e) quote_matches(e$evidence_quote, text),
        logical(1)))

    dir.create(capacity_cache_dir(), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(list(
        id = id, source = source,
        report_date = meta$report_date %||% "",
        url = meta$url %||% "", publisher = meta$publisher %||% "",
        licence = meta$licence %||% "", extract_key = key,
        model = gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING),
        indicators = rows
    ), cache_path(source, id), auto_unbox = TRUE, pretty = TRUE)

    sprintf("%d figures, %d quotes unmatched", length(rows), bad)
}

ids <- external_ids(SOURCE)
if (!is.null(ONLY)) ids <- intersect(ids, ONLY)
if (!length(ids)) {
    stop("No documents for source ", SOURCE, " in ", external_corpus_dir(SOURCE),
        ".\nRun R/06-fetch-who.R in bvd-sitreps.", call. = FALSE)
}

message("Reading ", length(ids), " ", SOURCE, " documents for capacity.\n")

quota <- NULL
results <- character(length(ids))
for (i in seq_along(ids)) {
    results[i] <- tryCatch(extract_one(SOURCE, ids[i]),
        gemini_quota_stop = function(e) { quota <<- e; "stopped" },
        error = function(e) paste("failed:", conditionMessage(e)))
    message(sprintf("[%2d/%2d] %s %s", i, length(ids), ids[i], results[i]))
    if (!is.null(quota)) break
}

# ------------------------------------------------------- verify and write

files <- list.files(capacity_cache_dir(),
    pattern = paste0("^", SOURCE, "-.*\\.json$"), full.names = TRUE)
raw <- rbindlist(lapply(files, function(f) {
    got <- jsonlite::fromJSON(f, simplifyVector = FALSE)
    if (!length(got$indicators)) return(NULL)
    rbindlist(lapply(got$indicators, function(e) as.data.table(c(list(
        source = got$source, doc_id = got$id, report_date = got$report_date,
        publisher = got$publisher, licence = got$licence, url = got$url), e))),
        fill = TRUE)
}), fill = TRUE)

if (!nrow(raw)) {
    message("\nNo figures extracted yet.")
    quit(status = if (!is.null(quota)) 3L else 0L)
}

raw[, text := vapply(doc_id, function(id) read_external_text(SOURCE, id),
    character(1))]
raw[, quote_ok := mapply(quote_matches, evidence_quote, text)]

#' A value that is not a number is a label the model read as one. It is
#' dropped here rather than written as NA, because a capacity series with a
#' silent hole in it is worse than one that is visibly shorter.
raw[, value_num := suppressWarnings(as.numeric(gsub("[ ,]", "", value)))]
raw[, reason := fcase(
    !quote_ok, "quote is not a span of the document",
    is.na(value_num), "value is not a number",
    default = "")]

rejected <- raw[nzchar(reason)]
if (nrow(rejected)) {
    fwrite(rejected[, .(source, doc_id, indicator, place_raw, value,
        evidence_quote, reason)],
        checks_dir(paste0("rejected_capacity_", SOURCE, ".csv")))
}

#' Province names arrive in two languages and three spellings: `Ituri`,
#' `Ituri Province`, `North Kivu`, `Nord-Kivu`. The register already has a
#' canonical six, and a series keyed on the raw string would split one
#' province into three.
PROVINCES <- c(
    "ituri" = "Ituri", "ituri province" = "Ituri",
    "north kivu" = "Nord-Kivu", "nord kivu" = "Nord-Kivu",
    "nord-kivu" = "Nord-Kivu", "north kivu province" = "Nord-Kivu",
    "south kivu" = "Sud-Kivu", "sud kivu" = "Sud-Kivu",
    "sud-kivu" = "Sud-Kivu", "south kivu province" = "Sud-Kivu",
    "tshopo" = "Tshopo", "tshopo province" = "Tshopo",
    "haut-uele" = "Haut-Uele", "haut uele" = "Haut-Uele",
    "haut-uélé" = "Haut-Uele", "haut uélé" = "Haut-Uele",
    "bas-uele" = "Bas-Uele", "bas uele" = "Bas-Uele",
    "bas-uélé" = "Bas-Uele", "bas uélé" = "Bas-Uele")

canonical_place <- function(x, level) {
    key <- tolower(trimws(x))
    out <- unname(PROVINCES[key])
    fifelse(level == "province" & !is.na(out), out, x)
}

out <- raw[!nzchar(reason), .(source, doc_id, report_date,
    as_of_date = fifelse(nzchar(as_of_date), as_of_date, report_date),
    indicator, level, country, place_raw, value = value_num, unit, period,
    confidence, evidence_quote, publisher, licence, url)]
out[, place := canonical_place(place_raw, level)]

#' A document sometimes states two figures for one indicator in one sentence:
#' `Two patients remained hospitalised. As of 05 July 2026, 646 patients were
#' in isolation nationally`. Both are faithful to their quotes and neither can
#' be dropped here without choosing between them on no evidence. They are
#' marked instead, so that anything building a series has to decide, rather
#' than silently taking whichever row sorted first.
out[, ambiguous_key := .N > 1L,
    by = .(source, doc_id, as_of_date, indicator, level, place, period)]

setcolorder(out, c("source", "doc_id", "report_date", "as_of_date",
    "indicator", "level", "country", "place", "place_raw", "value", "unit",
    "period", "ambiguous_key", "confidence", "evidence_quote"))
setorder(out, as_of_date, indicator, level, place)
fwrite(out, capacity_path())

# ----------------------------------------------------------------- report

message("\n", nrow(out), " figures kept, ", nrow(rejected), " rejected.")
print(out[, .(figures = .N, first = min(as_of_date), last = max(as_of_date)),
    keyby = .(indicator, level)])

if (out[(ambiguous_key), .N]) {
    message("\n", out[(ambiguous_key), .N],
        " figures share a key with another and need a person to choose:")
    print(out[(ambiguous_key), .(doc_id, as_of_date, indicator, level, value)])
}

beds <- out[indicator %in% c("beds_capacity", "bed_occupancy_pct") &
    level == "national" & !(ambiguous_key)]
if (nrow(beds)) {
    message("\nNational bed capacity and occupancy, week by week:")
    print(dcast(beds, as_of_date ~ indicator, value.var = "value",
        fun.aggregate = function(x) x[1]))
}

message("\nWritten: ", capacity_path())
if (!is.null(quota)) quit(status = 3L)
