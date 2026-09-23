#!/usr/bin/env Rscript
# ai-written
#'
#' Fetch the public accounts of this outbreak that INSP did not write.
#'
#' One source so far: WHO's Disease Outbreak News, twelve of which cover this
#' epidemic. They are short, English, and written a fortnight apart, so they
#' are no substitute for the situation reports. They are worth having because
#' they are independent: where a DON names a treatment centre, it corroborates
#' a facility the register knows from INSP alone, and where it names one the
#' register does not have, that is a gap worth seeing.
#'
#' The raw API record and the rendered text are both kept. The record is what
#' WHO published; the text is what a model will be shown and what every quote
#' is checked against, so it must not change between runs.
#'
#' WHO's Disease Outbreak News is © World Health Organization, licensed
#' CC BY-NC-SA 3.0 IGO. It is redistributed here unmodified for research, and
#' `data/external/LICENCE.md` says so. The repository's own MIT licence covers
#' the code, never the sources.
#'
#' Usage:
#'     Rscript R/20_external_fetch.R [--force]

suppressMessages({
    library(data.table)
    library(jsonlite)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "external.R"))

FORCE <- "--force" %in% commandArgs(trailingOnly = TRUE)

index <- who_don_index()
message(nrow(index), " Disease Outbreak News match, ",
    min(index$published), " to ", max(index$published), ".")

fetched <- 0L
for (i in seq_len(nrow(index))) {
    id <- index$id[i]
    had <- file.exists(external_raw_path("who_don", id))
    who_don_fetch(id, force = FORCE)
    text <- render_don(id)
    write_external_text("who_don", id, text)
    if (!had || FORCE) fetched <- fetched + 1L
    message(sprintf("[%2d/%2d] %s  %s  %6d chars", i, nrow(index), id,
        index$published[i], nchar(text)))
}

#' A render that is not reproducible cannot carry a quote gate, so it is
#' checked here rather than discovered later as a rejected event.
drift <- vapply(index$id, function(id) {
    !identical(render_don(id), read_external_text("who_don", id))
}, logical(1))
if (any(drift)) {
    stop("render is not reproducible for: ", paste(index$id[drift], collapse = ", "))
}

licence <- external_dir("LICENCE.md")
if (!file.exists(licence)) {
    dir.create(dirname(licence), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
        "`#ai-written`",
        "",
        "# Sources in this directory",
        "",
        "Nothing here is the work of this repository's authors, and the MIT",
        "licence at the root does not cover it.",
        "",
        "## who_don",
        "",
        "WHO Disease Outbreak News, © World Health Organization, licensed",
        "CC BY-NC-SA 3.0 IGO. Fetched from the public API at who.int and kept",
        "unmodified, alongside a plain-text rendering used to check quotes.",
        "Non-commercial use only, share alike, attribution to WHO.",
        "<https://www.who.int/about/policies/publishing/copyright>"), licence)
}

message("\n", fetched, " documents fetched, ", nrow(index), " rendered.")
message("Raw: ", external_dir("who_don"), "\nText: ", external_dir("text"))
