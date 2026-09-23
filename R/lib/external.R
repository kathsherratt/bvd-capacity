#' Documents about this outbreak that INSP did not write.
#'
#' The situation reports are the record of what the response said day to day.
#' They are not the only public account of it, and a second account is worth
#' having for the same reason a second implementation of the facilities table
#' is worth having: agreement is weak evidence, disagreement is strong.
#'
#' Everything here follows the corpus's rules. A document is fetched once and
#' kept, rendered to one deterministic string, and every claim read from it
#' carries a quote checked character for character against that string. What
#' changes is the language, the publisher and the licence, so each document
#' records where it came from and under what terms.
#'
#' Sources are added one at a time. `who_don` is WHO's Disease Outbreak News,
#' a public API, CC BY-NC-SA 3.0 IGO.

suppressMessages({
    library(data.table)
})

WHO_DON_API <- paste0("https://www.who.int/api/news/diseaseoutbreaknews",
    "?sf_provider=dynamicProvider372&sf_culture=en")

#' The sections of a DON, in the order WHO prints them. Fixed here so the
#' rendered text does not depend on the order a JSON parser returns fields.
DON_SECTIONS <- c("Summary", "Overview", "Epidemiology", "Assessment",
    "Response", "Advice", "FurtherInformation")

external_dir <- function(...) here::here("data", "external", ...)

external_raw_path <- function(source, id) {
    external_dir(source, paste0(id, ".json"))
}

external_text_path <- function(source, id) {
    external_dir("text", paste0(source, "-", id, ".md"))
}

external_cache_dir <- function(...) here::here("data", "cache-external", ...)

external_events_path <- function() here::here("data", "external_events.csv")

corroboration_path <- function() here::here("data", "external_corroboration.csv")

#' `curl` rather than an R HTTP package: the only dependency this adds is one
#' already on every machine that clones this, and the call is a GET.
fetch_json <- function(url, timeout = 40L) {
    tmp <- tempfile(fileext = ".json")
    on.exit(unlink(tmp), add = TRUE)
    status <- system2("curl", c("-s", "--max-time", timeout, "-o", shQuote(tmp),
        "-w", "%{http_code}", shQuote(url)), stdout = TRUE, stderr = TRUE)
    code <- suppressWarnings(as.integer(tail(status, 1)))
    if (is.na(code) || code != 200L) {
        stop("fetch failed (HTTP ", paste(status, collapse = " "), "): ", url)
    }
    jsonlite::fromJSON(tmp, simplifyVector = FALSE)
}

#' Every Disease Outbreak News whose title matches, newest first. The API
#' pages, so `top` is how far back to look rather than how many to keep.
who_don_index <- function(pattern = "Bundibugyo", top = 80L) {
    url <- paste0(WHO_DON_API,
        "&%24orderby=PublicationDateAndTime%20desc&%24top=", top,
        "&%24select=Title,PublicationDateAndTime,UrlName")
    res <- fetch_json(url)$value
    dt <- rbindlist(lapply(res, function(x) data.table(
        id = x$UrlName, title = x$Title,
        published = as.Date(substr(x$PublicationDateAndTime, 1, 10)))))
    dt[grepl(pattern, title, ignore.case = TRUE)][order(published)]
}

who_don_fetch <- function(id, force = FALSE) {
    path <- external_raw_path("who_don", id)
    if (file.exists(path) && !force) return(invisible(path))
    url <- paste0(WHO_DON_API, "&%24filter=UrlName%20eq%20%27", id, "%27")
    res <- fetch_json(url)$value
    if (!length(res)) stop("no DON returned for ", id)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(jsonlite::toJSON(res[[1]], auto_unbox = TRUE, pretty = TRUE), path)
    invisible(path)
}

#' WHO writes its sections as HTML. The quote gate compares a model's quote
#' with this text, so the stripping has to be deterministic and lossless in
#' the only way that matters: no sentence may lose or gain characters between
#' one render and the next.
html_to_text <- function(x) {
    if (is.null(x) || !nzchar(x)) return("")
    #' A carriage return survives writeLines and is eaten by readLines, so a
    #' text holding one renders differently the second time it is read. Out it
    #' goes before anything else, along with the zero-width spaces WHO's
    #' editor leaves behind.
    x <- gsub("\r|\u200b|\ufeff", "", x, perl = TRUE)
    x <- gsub("<(br|/p|/h[1-6]|/li|/tr)[^>]*>", "\n", x, perl = TRUE)
    x <- gsub("<[^>]*>", "", x, perl = TRUE)
    x <- gsub("&nbsp;| | ", " ", x)
    x <- gsub("&amp;", "&", x, fixed = TRUE)
    x <- gsub("&lt;", "<", x, fixed = TRUE)
    x <- gsub("&gt;", ">", x, fixed = TRUE)
    x <- gsub("&quot;", "\"", x, fixed = TRUE)
    x <- gsub("&#39;|&rsquo;", "'", x)
    x <- gsub("[ \t]+", " ", x)
    x <- gsub(" *\n *", "\n", x)
    x <- gsub("\n{3,}", "\n\n", x)
    trimws(x)
}

#' One document, one string, front matter first. Same shape as the corpus's
#' rendered reports, so R/lib/corpus.R's quote helpers apply unchanged.
render_don <- function(id) {
    rec <- jsonlite::fromJSON(external_raw_path("who_don", id), simplifyVector = FALSE)
    body <- vapply(DON_SECTIONS, function(s) html_to_text(rec[[s]]), character(1))
    keep <- nzchar(body)
    paste0(
        "---\n",
        "id: ", id, "\n",
        "source: who_don\n",
        "publisher: World Health Organization\n",
        "title: ", rec$Title, "\n",
        "report_date: ", substr(rec$PublicationDateAndTime, 1, 10), "\n",
        "url: https://www.who.int/emergencies/disease-outbreak-news/item/", id, "\n",
        "licence: CC BY-NC-SA 3.0 IGO\n",
        "lang: en\n",
        "---\n\n",
        paste(paste0("## ", DON_SECTIONS[keep], "\n\n", body[keep]), collapse = "\n\n"))
}

#' Written to disk so that a clone with no network can rerun the extraction
#' and the quote gate against exactly the text the model was shown.
write_external_text <- function(source, id, text) {
    path <- external_text_path(source, id)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(text, path)
    invisible(path)
}

read_external_text <- function(source, id) {
    paste(readLines(external_text_path(source, id), warn = FALSE), collapse = "\n")
}

external_ids <- function(source = "who_don") {
    files <- list.files(external_dir("text"), pattern = paste0("^", source, "-.*\\.md$"))
    sort(sub(paste0("^", source, "-"), "", sub("\\.md$", "", files)))
}

#' Front matter of a rendered document, as a named list.
external_meta <- function(source, id) {
    lines <- readLines(external_text_path(source, id), warn = FALSE)
    ends <- which(lines == "---")
    if (length(ends) < 2L) return(list())
    kv <- lines[(ends[1] + 1L):(ends[2] - 1L)]
    out <- lapply(kv, function(l) sub("^[^:]+: ?", "", l))
    names(out) <- sub(":.*$", "", kv)
    out
}
