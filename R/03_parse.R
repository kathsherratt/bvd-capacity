#!/usr/bin/env Rscript
#'
#' Read bed capacity, patient load and occupancy out of the INSP situation
#' report text, deterministically.
#'
#' The reports carry these quantities two ways, and the way changes with the
#' template. From SitRep 019 to 080 there is a province-by-province table
#' ("Indicateur | Ituri | Nord-Kivu | ..."), whose rows are read here by
#' aligning each number against the column header above it. From SitRep 085
#' the table is gone and the same figures appear in one prose bullet per
#' province ("En Ituri, ... 552 patients sont hospitalises pour 978 lits, soit
#' un taux d'occupation de 56,4 %"), read here by sentence pattern. Before 019
#' neither exists, and the reports are silent on capacity.
#'
#' Every value carries the line it was read from, so `06_checks.R` can assert
#' the quote occurs verbatim in that report's text. Nothing is inferred: a
#' province printed as "ND" becomes a row with no value and the flag
#' `not_reported`, and a province absent from the template produces no row at
#' all, which `coverage.csv` records separately.
#'
#' Usage:
#'     Rscript R/03_parse.R [--text-dir=data/text] [--out=data/observations]
#'
#' Reads:  data/text/*.txt, data/registry/reports.csv
#' Writes: data/observations/capacity.csv, data/observations/occupancy.csv
#'
#' Source: INSP situation reports, public, as mirrored by INRB-UMIE/BDBV2026-Data.

suppressPackageStartupMessages(library(data.table))

# ---- arguments ------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit) == 0) return(default)
    sub(paste0("^--", name, "="), "", hit[1])
}

TEXT_DIR <- arg_value("text-dir", "data/text")
OUT_DIR <- arg_value("out", "data/observations")
REPORTS <- arg_value("reports", "data/registry/reports.csv")

# ---- province vocabulary --------------------------------------------------

#' Canonical province slugs. `ensemble` is the national total the reports
#' print as the last column, kept as a place in its own right so a total is
#' never confused with a province.
PROVINCES <- data.table(
    place_id = c("ituri", "nord-kivu", "sud-kivu", "haut-uele",
                 "bas-uele", "tshopo", "ensemble"),
    place_name = c("Ituri", "Nord-Kivu", "Sud-Kivu", "Haut-Uélé",
                   "Bas-Uélé", "Tshopo", "Ensemble"),
    level = c(rep("province", 6), "national"),
    pattern = c(
        "Ituri",
        "N(?:ord)?[ -]?Kivu",
        "Sud[ -]?Kivu",
        "Haut[ -]?U[ée]l[ée]?",
        "Bas[ -]?U[ée]l[ée]?",
        "Tshopo",
        "Ensemble|Total g[ée]n[ée]ral"
    )
)

#' Header cells carry footnote markers (`Nord-Kivu*`, `Ituri1`) and the
#' accents move about, so match on the pattern rather than on equality.
province_of <- function(x) {
    x <- trimws(x)
    for (i in seq_len(nrow(PROVINCES))) {
        if (grepl(paste0("^", PROVINCES$pattern[i]), x, perl = TRUE,
                  ignore.case = TRUE)) {
            return(PROVINCES$place_id[i])
        }
    }
    NA_character_
}

# ---- small helpers --------------------------------------------------------

#' The PDF text carries non-breaking and thin spaces, which R's `\\s` does not
#' match. Replacing them one for one with an ordinary space leaves every
#' character position intact, so column alignment still works, and it is what
#' makes a quote comparable between the parse and the check.
unspace <- function(x) {
    gsub("[\u00a0\u202f\u2007\u2009\u2002-\u200a\u2060\ufeff]", " ", x,
         perl = TRUE)
}

squash <- function(x) trimws(gsub("\\s+", " ", unspace(x)))

#' French numbers: space or non-breaking space as thousands separator, comma
#' as decimal mark. Returns NA for "ND" and for anything not numeric.
parse_num <- function(x) {
    x <- gsub("[    ]", "", x)
    x <- sub(",", ".", x, fixed = TRUE)
    suppressWarnings(as.numeric(x))
}

is_nd <- function(x) grepl("^\\s*(ND|N/?A|-{1,2})\\s*$", x)

#' Page number for a character offset, counting the form feeds that
#' `02_text.R` writes between pages.
page_of <- function(text, pos) {
    if (is.na(pos) || pos < 1) return(NA_integer_)
    1L + lengths(gregexpr("\f", substr(text, 1, pos), fixed = TRUE))[1] -
        as.integer(!grepl("\f", substr(text, 1, pos), fixed = TRUE))
}

# ---- observation rows -----------------------------------------------------

OBS_COLS <- c("indicator_id", "level", "place_id", "place_name",
              "report_date", "sitrep", "version", "value", "unit",
              "basis", "derivation", "evidence_quote", "page",
              "text_source", "confidence", "flags", "places_included",
              "note")

obs <- function(meta, indicator_id, place_id, value, unit, basis,
                evidence_quote, page, flags = "", places_included = "",
                confidence = "high", derivation = "", note = "") {
    i <- match(place_id, PROVINCES$place_id)
    data.table(
        indicator_id = indicator_id,
        level = PROVINCES$level[i],
        place_id = place_id,
        place_name = PROVINCES$place_name[i],
        report_date = meta$report_date,
        sitrep = meta$sitrep,
        version = meta$version,
        value = value,
        unit = unit,
        basis = basis,
        derivation = derivation,
        evidence_quote = evidence_quote,
        page = page,
        text_source = meta$text_source,
        confidence = confidence,
        flags = flags,
        places_included = places_included,
        note = note
    )
}

# ---- the table era, SitRep 019 to 080 -------------------------------------

#' Row labels that matter for capacity and occupancy. Order is significant:
#' "Total admissions (24 h)" must be tested before the cumulative
#' "Total admissions", which the same table also carries.
TABLE_ROWS <- list(
    list(id = "beds_total", unit = "beds",
         pattern = "^\\s*Nombre de lits"),
    list(id = "patients_start_day", unit = "patients",
         pattern = "^\\s*Patients? au lit"),
    list(id = "admissions_24h", unit = "patients",
         pattern = "^\\s*Total admissions?\\s*\\(\\s*24"),
    list(id = "admissions_cumulative", unit = "patients",
         pattern = "^\\s*Total admissions?\\s*$"),
    list(id = "exits_24h", unit = "patients",
         pattern = "^\\s*Total sorties"),
    list(id = "patients_isolated", unit = "patients",
         pattern = "^\\s*Patients? en isolement"),
    list(id = "patients_confirmed", unit = "patients",
         pattern = "^\\s*dont confirm"),
    list(id = "patients_suspect", unit = "patients",
         pattern = "^\\s*dont suspect"),
    list(id = "occupancy_rate", unit = "percent",
         pattern = "^\\s*Taux d.{1,2}occupation")
)

#' Column spans from a header line: for each province name found, the
#' character range it occupies.
header_columns <- function(line) {
    cols <- list()
    for (i in seq_len(nrow(PROVINCES))) {
        m <- gregexpr(PROVINCES$pattern[i], line, perl = TRUE,
                      ignore.case = TRUE)[[1]]
        if (m[1] == -1) next
        for (k in seq_along(m)) {
            cols[[length(cols) + 1]] <- list(
                place_id = PROVINCES$place_id[i],
                start = m[k],
                end = m[k] + attr(m, "match.length")[k] - 1L
            )
        }
    }
    if (length(cols) == 0) return(NULL)
    dt <- rbindlist(lapply(cols, as.data.table))
    dt <- dt[order(start)]
    dt <- dt[!duplicated(place_id)]
    dt[, centre := (start + end) / 2]
    dt[]
}

#' A field is a run of non-space text between column gaps. The optional group
#' is made lazy (`??`) so a field ends at the first two-space gap rather than
#' running on to the last non-space character of the line.
FIELD <- "\\S(?:.*?\\S)??(?=\\s{2,}|\\s*$)"

#' A number as the reports print it: digits, optionally grouped in threes by a
#' space or non-breaking space, optionally with a decimal comma.
NUM <- "\\d+(?:[\u00a0\u202f ]\\d{3})*(?:[.,]\\d+)?"

#' Numeric cells on a row, with the character span of each. Fields are split
#' on runs of two or more spaces, which is what separates the columns; a
#' single space inside a field is a thousands separator ("1 050"), so
#' splitting this way rather than matching digit runs is what keeps a row of
#' column-aligned numbers from reading as one number. "ND" is kept as a cell
#' with no value, since a province saying it did not report is not the same
#' as a province being absent from the table.
row_cells <- function(line) {
    m <- gregexpr(FIELD, line, perl = TRUE)[[1]]
    if (m[1] == -1) return(NULL)
    fields <- regmatches(line, gregexpr(FIELD,
                                        line, perl = TRUE))[[1]]
    dt <- data.table(
        raw = fields,
        start = as.integer(m),
        end = as.integer(m) + attr(m, "match.length") - 1L
    )
    keep <- grepl(paste0("^(?:", NUM, "\\s*%?|ND|N/?A)$"), dt$raw,
                  perl = TRUE)
    dt <- dt[keep]
    if (nrow(dt) == 0) return(NULL)
    dt[, centre := (start + end) / 2]
    dt[]
}

#' Where the columns actually sit, which is not where the header sits: the
#' numbers are right-aligned and in some templates run 15 to 20 characters to
#' the right of the word above them. Taken from the rows that carry one cell
#' per column, whose k-th cell is by construction the k-th column, and which
#' are therefore a direct measurement. Falls back to the header when the
#' table has no such row.
column_anchors <- function(lines, cols) {
    full <- list()
    for (line in lines) {
        cl <- row_cells(line)
        if (is.null(cl) || nrow(cl) != nrow(cols)) next
        full[[length(full) + 1]] <- cl$centre
    }
    if (length(full) < 2) return(cols$centre)
    apply(do.call(rbind, full), 2, median)
}

#' Assign cells to columns. Where the row has exactly one cell per column the
#' assignment is positional. Where it has fewer -- a province the row simply
#' leaves blank -- the cells are aligned to the column anchors in order,
#' skipping whichever columns make the total distance smallest, so a blank
#' column shifts nothing to its left or right. That row is marked low
#' confidence.
assign_cells <- function(cells, cols) {
    n <- nrow(cells)
    m <- nrow(cols)
    if (n == m) {
        cells[, place_id := cols$place_id]
        cells[, confidence := "high"]
        return(cells[])
    }
    if (n > m) {
        # More numbers than columns: the row is not a clean province row.
        cells[, place_id := cols$place_id[
            vapply(centre, function(c) which.min(abs(cols$centre - c)), 1L)]]
        cells[, confidence := "low"]
        return(cells[!duplicated(place_id)])
    }
    anchors <- attr(cols, "anchors")
    if (is.null(anchors)) anchors <- cols$centre
    cost <- outer(cells$centre, anchors, function(a, b) abs(a - b))
    f <- matrix(Inf, n + 1L, m + 1L)
    f[1L, ] <- 0
    back <- matrix(0L, n + 1L, m + 1L)
    for (i in seq_len(n) + 1L) {
        for (j in seq_len(m) + 1L) {
            skip <- f[i, j - 1L]
            take <- f[i - 1L, j - 1L] + cost[i - 1L, j - 1L]
            if (take <= skip) { f[i, j] <- take; back[i, j] <- 1L }
            else { f[i, j] <- skip; back[i, j] <- 0L }
        }
    }
    pick <- integer(n)
    i <- n + 1L
    j <- m + 1L
    while (i > 1L) {
        if (back[i, j] == 1L) { pick[i - 1L] <- j - 1L; i <- i - 1L }
        j <- j - 1L
    }
    cells[, place_id := cols$place_id[pick]]
    cells[, confidence := "low"]
    cells[]
}

parse_table_era <- function(lines, text, meta) {
    header_i <- which(grepl("^\\s*Indicateurs?\\b", lines, perl = TRUE))
    out <- list()
    for (h in header_i) {
        cols <- header_columns(lines[h])
        if (is.null(cols) || nrow(cols) < 2) next
        # Body runs to the next table title, numbered section or the second
        # blank line in a row, whichever comes first.
        stop_at <- length(lines)
        blanks <- 0L
        for (j in seq(h + 1L, length(lines))) {
            if (grepl("^\\s*$", lines[j])) {
                blanks <- blanks + 1L
                if (blanks >= 2L) { stop_at <- j - 1L; break }
                next
            }
            blanks <- 0L
            if (grepl("^\\s*(TABLEAU|Tableau|Au total|\\d+\\.\\d|Figure)",
                      lines[j], perl = TRUE)) { stop_at <- j - 1L; break }
        }
        # A report carries several "Indicateur" tables (SMSPS, laboratory,
        # vaccination) and their columns are provinces too, so a body must
        # never run past the next header.
        next_header <- header_i[header_i > h]
        if (length(next_header) > 0) {
            stop_at <- min(stop_at, next_header[1] - 1L)
        }
        body <- seq(h + 1L, max(h + 1L, stop_at))
        setattr(cols, "anchors", column_anchors(lines[body], cols))
        for (j in body) {
            line <- lines[j]
            hit <- NULL
            for (r in TABLE_ROWS) {
                if (grepl(r$pattern, line, perl = TRUE, ignore.case = TRUE)) {
                    hit <- r
                    break
                }
            }
            if (is.null(hit)) next
            cells <- row_cells(line)
            if (is.null(cells)) next
            # Drop anything left of the first column header: that is the row
            # label, and labels carry digits ("Patients au lit (J-1)").
            cells <- cells[end >= cols$start[1] - 6L]
            if (nrow(cells) == 0) next
            cells <- assign_cells(cells, cols)
            quote <- squash(line)
            page <- page_of(text, sum(nchar(lines[seq_len(j - 1L)]) + 1L))
            reported <- cells[!is_nd(raw)]$place_id
            reported <- setdiff(reported, "ensemble")
            for (k in seq_len(nrow(cells))) {
                nd <- is_nd(cells$raw[k])
                pid <- cells$place_id[k]
                out[[length(out) + 1]] <- obs(
                    meta,
                    indicator_id = hit$id,
                    place_id = pid,
                    value = if (nd) NA_real_ else parse_num(
                        sub("%", "", cells$raw[k])),
                    unit = hit$unit,
                    basis = "table",
                    evidence_quote = quote,
                    page = page,
                    flags = if (nd) "not_reported" else "",
                    places_included = if (pid == "ensemble")
                        paste(reported, collapse = ";") else "",
                    confidence = cells$confidence[k]
                )
            }
        }
    }
    if (length(out) == 0) return(NULL)
    res <- rbindlist(out)
    # A row label can recur further down the same section; the first table to
    # carry it is the occupation table itself.
    unique(res, by = c("indicator_id", "place_id"))
}

# ---- the prose era, SitRep 085 on ----------------------------------------

#' One bullet per province in the "Continuité des soins" / "Prise en charge"
#' section. A bullet is taken from its province opener to the next opener,
#' and kept only if it says something about beds or patient load, which
#' excludes the identically shaped bullets in the WASH and surveillance
#' sections.
PROSE_INDICATORS <- list(
    list(id = "patients_isolated", unit = "patients", pattern = paste0(
        "\\(?(", NUM, ")\\)?\\s+(?:patients?|malades)\\b",
        "[^.;]{0,80}?",
        "(?:sont|est|restent|reste)\\s+",
        "(?:actuellement\\s+)?",
        "(?:hospitalis|en isolement|pris\\s+en\\s+charge|en cours de soins)")),
    list(id = "beds_total", unit = "beds", pattern = paste0(
        "pour\\s+(", NUM, ")\\s+lits|",
        "(", NUM, ")\\s+lits\\s+disponibles")),
    list(id = "occupancy_rate", unit = "percent", pattern = paste0(
        "taux\\s+d.{1,2}occupation[^%\\d]{0,60}?",
        "(", NUM, ")\\s*%")),
    list(id = "admissions_24h", unit = "patients", pattern = paste0(
        "\\(?(", NUM, ")\\)?\\s+nouvelles?\\s+admissions?|",
        "\\(?(", NUM, ")\\)?\\s+admissions?\\s+",
        "(?:ont\\s+[ée]t[ée]\\s+enregistr|enregistr)")),
    list(id = "exits_24h", unit = "patients", pattern = paste0(
        "\\(?(", NUM, ")\\)?\\s+sorties"))
)

CAPACITY_CUE <- paste0(
    "\\blits\\b|hospitalis|en isolement|taux d.{1,2}occupation|",
    "pris\\s+en\\s+charge\\s+en\\s+hospitalisation"
)

parse_prose_era <- function(text, meta) {
    flat <- gsub("\\s+", " ", text)
    opener <- paste0(
        "(?:En|Au|Aux|[ÀA]\\s+la|Dans\\s+(?:la|le))\\s+(",
        paste(PROVINCES$pattern[PROVINCES$level == "province"],
              collapse = "|"),
        ")\\s*,")
    m <- gregexpr(opener, flat, perl = TRUE, ignore.case = FALSE)[[1]]
    if (m[1] == -1) return(NULL)
    starts <- as.integer(m)
    ends <- c(starts[-1] - 1L, nchar(flat))
    ends <- pmin(ends, starts + 900L)
    out <- list()
    for (i in seq_along(starts)) {
        chunk <- substr(flat, starts[i], ends[i])
        if (!grepl(CAPACITY_CUE, chunk, perl = TRUE, ignore.case = TRUE)) next
        pid <- province_of(sub(paste0("^", opener, ".*$"), "\\1", chunk,
                               perl = TRUE))
        if (is.na(pid)) next
        # Stop the chunk at the end of the sentence carrying the last
        # capacity cue, so a bullet never reaches into the next topic.
        sent <- unlist(strsplit(chunk, "(?<=[.;])\\s+", perl = TRUE))
        keep <- which(grepl(CAPACITY_CUE, sent, perl = TRUE,
                            ignore.case = TRUE))
        if (length(keep) == 0) next
        sent <- sent[seq_len(max(keep))]
        chunk <- paste(sent, collapse = " ")
        page <- page_of(text, regexpr(substr(squash(sent[1]), 1, 40),
                                      gsub("\\s+", " ", text), fixed = TRUE))
        for (ind in PROSE_INDICATORS) {
            mm <- regexpr(ind$pattern, chunk, perl = TRUE,
                          ignore.case = TRUE)
            if (mm == -1) next
            groups <- attr(mm, "capture.start")
            lens <- attr(mm, "capture.length")
            val <- NA_real_
            for (g in seq_along(groups)) {
                if (lens[g] > 0) {
                    val <- parse_num(substr(chunk, groups[g],
                                            groups[g] + lens[g] - 1L))
                    break
                }
            }
            if (is.na(val)) next
            quote <- squash(substr(chunk, mm,
                                   mm + attr(mm, "match.length") - 1L))
            # Give the quote its sentence, which is what a reader needs to
            # check it, and what the verbatim test runs against.
            in_sent <- sent[grepl(quote, sent, fixed = TRUE)]
            if (length(in_sent) > 0) quote <- squash(in_sent[1])
            out[[length(out) + 1]] <- obs(
                meta,
                indicator_id = ind$id,
                place_id = pid,
                value = val,
                unit = ind$unit,
                basis = "prose",
                evidence_quote = quote,
                page = page
            )
        }
    }
    if (length(out) == 0) return(NULL)
    res <- rbindlist(out)
    # One value per indicator per place per report: the reports repeat the
    # same figure in the "Défis" section, and the first statement is the one
    # in the operational section.
    unique(res, by = c("indicator_id", "place_id"))
}

# ---- main -----------------------------------------------------------------

reports <- fread(REPORTS)
stopifnot(all(c("sitrep", "version", "report_date", "text_file") %in%
              names(reports)))
message("reports: ", nrow(reports))

all_obs <- vector("list", nrow(reports))
for (i in seq_len(nrow(reports))) {
    meta <- as.list(reports[i])
    path <- file.path(TEXT_DIR, meta$text_file)
    if (!file.exists(path)) {
        warning("no text for SitRep ", meta$sitrep, ": ", path)
        next
    }
    raw <- readLines(path, warn = FALSE, encoding = "UTF-8")
    raw <- unspace(raw[-1])  # drop the "#text_source:" header line
    text <- paste(raw, collapse = "\n")
    tbl <- parse_table_era(raw, text, meta)
    pro <- if (is.null(tbl)) parse_prose_era(text, meta) else NULL
    all_obs[[i]] <- rbindlist(list(tbl, pro))
}

obs_all <- rbindlist(all_obs)
setcolorder(obs_all, OBS_COLS)
setorder(obs_all, sitrep, version, indicator_id, place_id)
message("observations: ", nrow(obs_all), " over ",
        uniqueN(obs_all[, .(sitrep, version)]), " reports")
print(obs_all[, .N, by = .(indicator_id, basis)][order(indicator_id)])

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
capacity <- obs_all[indicator_id == "beds_total"]
occupancy <- obs_all[indicator_id != "beds_total"]
fwrite(capacity, file.path(OUT_DIR, "capacity.csv"))
fwrite(occupancy, file.path(OUT_DIR, "occupancy.csv"))
message("wrote ", file.path(OUT_DIR, "capacity.csv"), ": ", nrow(capacity))
message("wrote ", file.path(OUT_DIR, "occupancy.csv"), ": ", nrow(occupancy))
