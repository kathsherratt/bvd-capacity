#' Documents about this outbreak that INSP did not write.
#'
#' The situation reports are the record of what the response said day to day.
#' They are not the only public account of it, and a second account is worth
#' having for the same reason a second implementation of the facilities table
#' is worth having: agreement is weak evidence, disagreement is strong.
#'
#' These are read exactly as the INSP corpus is read: by path, from
#' bvd-sitreps, which fetches and renders them. Nothing here opens a PDF, an
#' API or a website. If a document is missing or renders badly, the fix is in
#' bvd-sitreps' `R/06-fetch-who.R`, not here.
#'
#' Two sources so far, both WHO, both CC BY-NC-SA 3.0 IGO:
#'
#'   `who_don`   Disease Outbreak News, a fortnightly national account
#'   `who_afro`  the AFRO weekly external situation reports, which name
#'               treatment centres and carry bed capacity and occupancy

suppressMessages({
    library(data.table)
})

EXTERNAL_SOURCES <- c(who_don = "who-dons", who_afro = "who-afro")

external_corpus_dir <- function(source, ...) {
    dir <- EXTERNAL_SOURCES[[source]]
    if (is.null(dir)) stop("unknown source: ", source)
    corpus_dir(dir, ...)
}

external_cache_dir <- function(...) here::here("data", "cache-external", ...)

external_events_path <- function() here::here("data", "external_events.csv")

corroboration_path <- function() here::here("data", "external_corroboration.csv")

external_ids <- function(source = "who_don") {
    dir <- external_corpus_dir(source)
    if (!dir.exists(dir)) return(character())
    sort(sub("\\.md$", "", list.files(dir, pattern = "\\.md$")))
}

#' The document as bvd-sitreps rendered it, one string, unchanged. Every
#' quote is checked against this, so nothing here may normalise or trim it.
read_external_text <- function(source, id) {
    path <- external_corpus_dir(source, paste0(id, ".md"))
    if (!file.exists(path)) {
        stop("no such document: ", path, "\nRun R/06-fetch-who.R in bvd-sitreps.")
    }
    paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Front matter of a rendered document, as a named list.
external_meta <- function(source, id) {
    lines <- readLines(external_corpus_dir(source, paste0(id, ".md")),
        warn = FALSE)
    ends <- which(lines == "---")
    if (length(ends) < 2L) return(list())
    kv <- lines[(ends[1] + 1L):(ends[2] - 1L)]
    out <- lapply(kv, function(l) sub("^[^:]+: ?", "", l))
    names(out) <- sub(":.*$", "", kv)
    out
}
