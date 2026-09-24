#!/usr/bin/env Rscript
# ai-written
#'
#' Read each situation report once and record the facilities it names.
#'
#' One model call a report, cached. The call sees the report as
#' `render_report()` renders it, and every value it returns carries a quote
#' from that same string; R/02_resolve.R checks each quote against a fresh
#' render before anything reaches the dataset. Nothing here decides what a
#' facility is called or whether two names are one site, because that is a
#' judgement across reports and this script sees one report at a time.
#'
#' Model: `gemini-3.1-pro` at low thinking, on the Antigravity route.
#'
#' Chosen by running SitReps 005, 006, 040 and 082 through pro-low, pro-high
#' and flash-low and comparing what came back. Three checks separated nothing:
#' all three read SitRep 006's bed table completely, none mistook a TOTAL
#' column for a facility, and the quote gate rejected almost nothing.
#'
#' What separated them was recall and invention. flash-low missed 8 of 41
#' treatment-type sites that both pro runs found, including named centres at
#' Rwampara, Nia-Nia, Bunia, Mongbwalu and Nyankunde, so it is out whatever
#' its speed. pro-high returned one fabricated quote and found fewer
#' facilities than pro-low while taking longer. pro-low found the most (88
#' events over 75 facilities), invented nothing, and runs the corpus in about
#' four hours.
#'
#' Thinking stayed near 9k tokens a call on pro-low against 14k on pro-high,
#' well short of the 50k that means a model is looping rather than reasoning.
#'
#' `GEMINI_MODEL_EXTRACT` and `AGY_MODEL` both override, and `--cache` sends a
#' comparison run somewhere other than the committed cache.
#'
#' Usage:
#'     Rscript R/01_facilities.R [--only=005,006,040] [--force] [--cache=DIR]

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "gemini.R"))
source(here::here("R", "lib", "corpus.R"))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
    hit <- grep(paste0("^", flag, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^", flag, "="), "", hit[1]) else NULL
}
only <- arg_value("--only")
ONLY <- if (!is.null(only)) trimws(strsplit(only, ",")[[1]]) else NULL
FORCE <- "--force" %in% args
CACHE <- arg_value("--cache") %||% cache_dir()

#' Low thinking to start.
#'
#' Measured on the same plan route in bvd-sitreps: flash at high thinking spent
#' 80,000-120,000 thinking tokens on SitRep 005 and returned nothing twice,
#' while low returned the whole report in 12 seconds. Extraction reasons more
#' than translation does, so this is a starting point for the comparison, not
#' a finding.
EXTRACT_THINKING <- Sys.getenv("GEMINI_THINKING_EXTRACT", unset = "low")

PROMPT <- paste(readLines(here::here("assets", "prompt-facilities.md"),
    warn = FALSE), collapse = "\n")

SITE_KINDS <- c("treatment_centre", "transit_centre", "isolation_centre",
    "hospital_isolation", "other")

EVENTS <- c("planned", "under_construction", "opened", "operating", "expanded",
    "strained", "incident", "closed", "mention_only")

NAME_STATUS <- c("named", "unnamed", "ambiguous")

EVENT_FIELDS <- c("facility_raw", "facility_type_raw", "site_kind",
    "name_status", "place_raw", "health_zone", "province", "event",
    "event_date", "beds", "status_note", "evidence_quote", "confidence")

#' Absent values are `""`, never null.
#'
#' `beds` is a string here for the same reason: a JSON null survives the API
#' schema and the agy one differently, and a missing property is not the same
#' as an empty one on either. One absent marker across every field costs a
#' parse in R and removes a whole class of backend difference.
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

#' What this report, this prompt, this schema and this model together produce.
#'
#' `build_key` already carries the PDF's md5 and the transcription prompt and
#' model, so a rebuilt transcription upstream invalidates this cache too.
#' Keying on less means a prompt fix silently skips every report already read.
#' The schema is hashed as its JSON rather than as an R object, so the key does
#' not move when an unrelated attribute of the list does.
SCHEMA_MD5 <- digest::digest(
    as.character(jsonlite::toJSON(SCHEMA, auto_unbox = TRUE)),
    algo = "md5", serialize = FALSE)
PROMPT_MD5 <- digest::digest(PROMPT, algo = "md5", serialize = FALSE)

extract_key <- function(meta) {
    paste(c(meta$build_key, PROMPT_MD5, SCHEMA_MD5,
        gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING)),
        collapse = ":")
}

cache_path <- function(id) file.path(CACHE, paste0(id, ".json"))

cached_key <- function(id) {
    path <- cache_path(id)
    if (!file.exists(path)) return(NA_character_)
    got <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
        error = function(e) NULL)
    got$extract_key %||% NA_character_
}

#' Every field present, as a single string, whatever the model left out.
tidy_event <- function(e) {
    out <- lapply(EVENT_FIELDS, function(f) {
        v <- e[[f]]
        if (is.null(v) || !length(v)) "" else trimws(as.character(v)[1])
    })
    out <- setNames(out, EVENT_FIELDS)
    out$evidence_quote <- unescape_model_string(out$evidence_quote)
    out
}

extract_one <- function(id) {
    report <- read_report(id)
    key <- extract_key(report$meta)
    if (!FORCE && identical(cached_key(id), key)) return("cached")

    rendered <- render_report(id, report)
    res <- gemini(
        parts = list(gemini_text_part(paste(PROMPT, "\n\n---\n\n", rendered))),
        schema = SCHEMA,
        model = GEMINI_MODEL_EXTRACT,
        label = paste0(id, "/facilities"),
        thinking_level = EXTRACT_THINKING
    )
    events <- lapply(res$events %||% list(), tidy_event)

    # Reported, not enforced. R/02_resolve.R checks every quote against a fresh
    # render and is the only thing allowed to drop an event; counting here just
    # makes a model's copying visible while comparing models.
    bad <- sum(!vapply(events, function(e) quote_matches(e$evidence_quote, rendered),
        logical(1)))

    dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(list(
        id = id,
        report_date = report$meta$report_date,
        extract_key = key,
        model = gemini_model_label(GEMINI_MODEL_EXTRACT, EXTRACT_THINKING),
        events = events
    ), cache_path(id), auto_unbox = TRUE, pretty = TRUE)

    sprintf("%d events, %d quotes unmatched", length(events), bad)
}

ensure_dirs()

ids <- corpus_ids()
if (!is.null(ONLY)) ids <- intersect(ids, ONLY)
if (!length(ids)) {
    stop("No reports to read. Check BVD_SITREPS points at a bvd-sitreps ",
        "checkout with data/corpus/ built.", call. = FALSE)
}

status <- character(length(ids))
quota <- NULL
for (i in seq_along(ids)) {
    status[i] <- tryCatch({
        s <- extract_one(ids[i])
        message(sprintf("[%3d/%3d] %s %s", i, length(ids), ids[i], s))
        s
    }, gemini_quota_stop = function(e) {
        quota <<- e
        "stopped"
    }, error = function(e) {
        message(sprintf("[%3d/%3d] %s FAILED: %s", i, length(ids), ids[i],
            conditionMessage(e)))
        "failed"
    })
    if (!is.null(quota)) break
}

message(sprintf("\nread %d, cached %d, failed %d, not attempted %d",
    sum(!status %in% c("cached", "failed", "stopped", "")),
    sum(status == "cached"), sum(status == "failed"), sum(status == "")))

# Exit 3 is a clean stop on quota: what is cached is good, rerun to go on.
if (!is.null(quota)) {
    message("\nSTOPPED: ", conditionMessage(quota))
    quit(status = 3L)
}
if (any(status == "failed")) quit(status = 1L)
