# ai-written
#' Read one report out of the bvd-sitreps corpus.
#'
#' Extraction and verification both reach a report through `render_report()`,
#' so the quote check in R/02_resolve.R runs on exactly the string the model
#' was shown. Two renderers would mean every quote failing for a reason that
#' has nothing to do with the model, so there is one.
#'
#' Nothing here opens a PDF. A question the corpus cannot answer is a
#' bvd-sitreps problem, not one to patch around here.

#' Reports with both a French transcription and a table file.
corpus_ids <- function() {
    fr <- sub("\\.md$", "", list.files(corpus_dir("fr"), pattern = "\\.md$"))
    tb <- sub("\\.json$", "", list.files(corpus_dir("tables"), pattern = "\\.json$"))
    sort(intersect(fr, tb))
}

#' Split the `---` front matter off the body.
#'
#' The front matter is one `key: value` a line, so a value containing a colon
#' (`build_key`, `pdf_url`) keeps everything after the first one.
read_front <- function(lines) {
    end <- which(lines == "---")
    if (length(end) < 2) stop("No front matter in this report.", call. = FALSE)
    kv <- lines[(end[1] + 1):(end[2] - 1)]
    kv <- kv[grepl(":", kv, fixed = TRUE)]
    list(
        meta = setNames(as.list(trimws(sub("^[^:]*:", "", kv))), sub(":.*$", "", kv)),
        body = paste(lines[-(1:end[2])], collapse = "\n")
    )
}

read_report <- function(id) {
    fr <- read_front(readLines(corpus_dir("fr", paste0(id, ".md")), warn = FALSE))
    tables <- jsonlite::fromJSON(corpus_dir("tables", paste0(id, ".json")),
        simplifyVector = FALSE)$tables
    list(id = id, meta = fr$meta, body = fr$body, tables = tables)
}

#' One table as its marker and caption, a header row, then a row a line.
#'
#' Pipes inside a cell are left alone rather than escaped. Escaping would make
#' the table better markdown and the quotes worse: a backslash the model has
#' to copy exactly is a quote rejected for nothing. Nothing reads these rows
#' as a table, so the ambiguity costs nothing.
#'
#' Early reports name facilities in column headers (SitRep 006 Tableau VI is
#' headed `BUNIA HGR`, `BUNIA SOFEPADI`, ...), which is why tables are put in
#' front of the model at all.
render_table <- function(tb) {
    row <- function(x) paste0("| ", paste(unlist(x), collapse = " | "), " |")
    c(paste0("[TABLE_", tb$n, "] ", tb$caption %||% ""),
        row(tb$columns),
        vapply(tb$rows, function(r) row(r$cells), character(1)))
}

#' Put `block` where `marker` sits, without regex replacement escaping.
#'
#' `sub()` would read a backslash in a cell as a backreference and corrupt the
#' rendering silently.
splice <- function(text, marker, block) {
    at <- regexpr(marker, text, fixed = TRUE)
    if (at == -1L) return(NULL)
    paste0(substr(text, 1L, at - 1L), block,
        substr(text, at + attr(at, "match.length"), nchar(text)))
}

#' The body with every table rendered in place.
#'
#' Deterministic: the same corpus files give the same string, byte for byte. A
#' table whose `[TABLE_n]` marker is missing from the body is appended, so no
#' table is ever dropped.
render_report <- function(id, report = read_report(id)) {
    body <- report$body
    for (tb in report$tables) {
        block <- paste(render_table(tb), collapse = "\n")
        spliced <- splice(body, paste0("[TABLE_", tb$n, "]"), block)
        body <- if (is.null(spliced)) paste0(body, "\n\n", block) else spliced
    }
    body
}

#' The only text tidying the quote check is allowed.
#'
#' Whitespace and apostrophe shape are the two things a model changes while
#' still copying honestly: a PDF's non-breaking spaces come back as plain ones
#' and its curly apostrophes as straight ones. Everything else is left alone.
#' Folding accents or case here would let a paraphrase through, which is the
#' one thing this check exists to catch.
normalise_for_match <- function(x) {
    x <- gsub("[    ]", " ", x, perl = TRUE)
    x <- gsub("[‘’ʼ`´]", "'", x, perl = TRUE)
    x <- gsub("\\s+", " ", x, perl = TRUE)
    trimws(x)
}

#' Is this quote a span of this text?
#'
#' The gate. There is no exemption route: a quote that fails is either a
#' rendering bug, a gap in `normalise_for_match()`, or a model that did not
#' copy. The first two are fixed here for every report at once; the third is
#' what the check is for.
quote_matches <- function(quote, rendered) {
    q <- normalise_for_match(quote)
    nzchar(q) && grepl(q, normalise_for_match(rendered), fixed = TRUE)
}
