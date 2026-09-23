#!/usr/bin/env Rscript
# ai-written
#'
#' Read the external documents the same way the situation reports are read.
#'
#' Same schema, same event vocabulary, same one call a document, same cache
#' key, and the same quote gate downstream. Only the prompt differs, because
#' the source is English prose by another publisher rather than a French
#' report with tables: `assets/prompt-external.md`.
#'
#' Nothing here knows about the register. A document is read on its own terms
#' and matched afterwards by `R/22_external_match.R`, so a WHO spelling never
#' bends towards an INSP one at the point of reading.
#'
#' Usage:
#'     Rscript R/21_external_extract.R [--source=who_don] [--only=ID,ID] [--force]

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
SOURCE <- arg_value("--source") %||% "who_don"
only <- arg_value("--only")
ONLY <- if (!is.null(only)) trimws(strsplit(only, ",")[[1]]) else NULL
FORCE <- "--force" %in% args

EXTRACT_THINKING <- Sys.getenv("GEMINI_THINKING_EXTRACT", unset = "low")

PROMPT <- paste(readLines(here::here("assets", "prompt-external.md"),
    warn = FALSE), collapse = "\n")

SITE_KINDS <- c("treatment_centre", "transit_centre", "isolation_centre",
    "hospital_isolation", "other")
EVENTS <- c("planned", "under_construction", "opened", "operating", "expanded",
    "strained", "incident", "closed", "mention_only")
NAME_STATUS <- c("named", "unnamed", "ambiguous")
EVENT_FIELDS <- c("facility_raw", "facility_type_raw", "site_kind",
    "name_status", "place_raw", "health_zone", "province", "event",
    "event_date", "beds", "status_note", "evidence_quote", "confidence")

str_field <- function() list(type = "STRING")

SCHEMA <- list(
    type = "OBJECT",
    properties = list(
        events = list(type = "ARRAY", items = list(
            type = "OBJECT",
            properties = list(
                facility_raw = str_field(),
                facility_type_raw = str_field(),
                site_kind = list(type = "STRING", enum = I(SITE_KINDS)),
                name_status = list(type = "STRING", enum = I(NAME_STATUS)),
                place_raw = str_field(),
                health_zone = str_field(),
                province = str_field(),
                event = list(type = "STRING", enum = I(EVENTS)),
                event_date = str_field(),
                beds = str_field(),
                status_note = str_field(),
                evidence_quote = str_field(),
                confidence = list(type = "STRING", enum = I(c("high", "low")))
            ),
            required = as.list(EVENT_FIELDS),
            propertyOrdering = as.list(EVENT_FIELDS)
        ))
    ),
    required = list("events")
)

SCHEMA_MD5 <- digest::digest(
    as.character(jsonlite::toJSON(SCHEMA, auto_unbox = TRUE)),
    algo = "md5", serialize = FALSE)
PROMPT_MD5 <- digest::digest(PROMPT, algo = "md5", serialize = FALSE)

#' The document itself is the build key here. There is no upstream
#' transcription to invalidate, so the md5 of the rendered text stands in for
#' one: WHO editing a published DON changes it, and the document is read again.
extract_key <- function(text) {
    paste(c(digest::digest(text, algo = "md5", serialize = FALSE),
        PROMPT_MD5, SCHEMA_MD5,
        gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING)),
        collapse = ":")
}

cache_path <- function(source, id) {
    external_cache_dir(paste0(source, "-", id, ".json"))
}

cached_key <- function(source, id) {
    path <- cache_path(source, id)
    if (!file.exists(path)) return(NA_character_)
    got <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
        error = function(e) NULL)
    got$extract_key %||% NA_character_
}

tidy_event <- function(e) {
    out <- lapply(EVENT_FIELDS, function(f) {
        v <- e[[f]]
        if (is.null(v) || !length(v)) "" else trimws(as.character(v)[1])
    })
    setNames(out, EVENT_FIELDS)
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
        label = paste0(source, "-", id, "/external"),
        thinking_level = EXTRACT_THINKING
    )
    events <- lapply(res$events %||% list(), tidy_event)

    bad <- sum(!vapply(events, function(e) quote_matches(e$evidence_quote, text),
        logical(1)))

    dir.create(external_cache_dir(), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(list(
        id = id,
        source = source,
        report_date = meta$report_date %||% "",
        url = meta$url %||% "",
        publisher = meta$publisher %||% "",
        licence = meta$licence %||% "",
        extract_key = key,
        model = gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING),
        events = events
    ), cache_path(source, id), auto_unbox = TRUE, pretty = TRUE)

    sprintf("%d events, %d quotes unmatched", length(events), bad)
}

ids <- external_ids(SOURCE)
if (!is.null(ONLY)) ids <- intersect(ids, ONLY)
if (!length(ids)) {
    stop("No documents for source ", SOURCE,
        ". Run R/20_external_fetch.R first.", call. = FALSE)
}

message("Reading ", length(ids), " ", SOURCE, " documents.\n")

quota <- NULL
results <- character(length(ids))
for (i in seq_along(ids)) {
    id <- ids[i]
    results[i] <- tryCatch(extract_one(SOURCE, id),
        gemini_quota_stop = function(e) { quota <<- e; "stopped" },
        error = function(e) paste("failed:", conditionMessage(e)))
    message(sprintf("[%2d/%2d] %s %s", i, length(ids), id, results[i]))
    if (!is.null(quota)) break
}

read <- sum(!results %in% c("cached", "stopped", "") & !grepl("^failed", results))
failed <- sum(grepl("^failed", results))
message("\nread ", read, ", cached ", sum(results == "cached"),
    ", failed ", failed, ", not attempted ", sum(results == ""))

if (!is.null(quota)) {
    message("Stopped on quota: ", conditionMessage(quota))
    quit(status = 3L)
}
if (failed) quit(status = 1L)
