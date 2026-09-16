#!/usr/bin/env Rscript
#'
#' Extract the text of every situation report PDF, and record what each
#' report is.
#'
#' Seven of the early reports (007-011, 012 first issue, 014) are image-only
#' scans, and they cover the week the first treatment centres were built, so
#' they are read with French Tesseract rather than skipped. Poppler draws two
#' of them as blank pages and crashes on a third, so PyMuPDF renders first
#' and poppler runs in a child process where a crash cannot take this one
#' with it.
#'
#' Text is cached under a name carrying the PDF's hash, so a reissued report
#' is read again and an unchanged one is never OCR'd twice. The cache is
#' committed: it is what every later script reads, what every quote is
#' checked against, and it saves anyone rebuilding this repository from
#' needing poppler, PyMuPDF or Tesseract at all.
#'
#' Usage:
#'     Rscript R/02_text.R [--pdf-dir=DIR] [--text-dir=data/text]
#'
#' Default --pdf-dir is a BDBV2026-Data clone beside this repository.
#'
#' Reads:  <pdf-dir>/SitRep_MVE_*.pdf
#' Writes: data/text/<sitrep>_v<version>__<md5>.txt, data/registry/reports.csv
#'
#' Data: public PDFs from https://github.com/INRB-UMIE/BDBV2026-Data.
#' No person-level information is read or written.

suppressMessages({
    library(data.table)
    library(pdftools)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit) == 0) return(default)
    sub(paste0("^--", name, "="), "", hit[1])
}

PDF_DIR <- arg_value("pdf-dir",
                     path.expand("~/Documents/Github/BDBV2026-Data/data/insp_sitrep/raw"))
TEXT_DIR <- arg_value("text-dir", "data/text")
REG_DIR <- arg_value("registry", "data/registry")

# Below this many non-space characters a PDF is treated as a scan.
MIN_TEXT_CHARS <- 200L

FRENCH_MONTHS <- c(
    janvier = 1, fevrier = 2, mars = 3, avril = 4, mai = 5, juin = 6,
    juillet = 7, aout = 8, septembre = 9, octobre = 10, novembre = 11,
    decembre = 12
)

#' Strip accents and lower-case, so "Août" and "aout" compare equal
fold <- function(x) {
    tolower(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
}

#' Sitrep number and version from a PDF filename
#'
#' Handles SitRep_MVE_060-2026.pdf, SitRep_MVE_060_2026.pdf,
#' SitRep_MVE_28_2026.pdf and SitRep_MVE_012-2026_v2.pdf.
parse_filename <- function(f) {
    m <- regmatches(f, regexec("SitRep_MVE_([0-9]+)[-_]2026(_v([0-9]+))?", f))
    data.table(
        sitrep = as.integer(vapply(m, `[`, "", 2)),
        version = fifelse(
            vapply(m, `[`, "", 4) == "", 1L,
            suppressWarnings(as.integer(vapply(m, `[`, "", 4)))
        )
    )
}

#' Report date from the full text of one sitrep
#'
#' Searched over the whole document, because some reports have a near-empty
#' first page. Early reports write it as "14 Mai 2026"; later ones also carry
#' "SitRep N°060/MVB_13/07/2026", used as a fallback. A date that cannot be
#' read is NA with a warning, never a guess.
parse_report_date <- function(text) {
    doc <- paste(text, collapse = "\n")
    long <- regmatches(doc, regexec(
        paste0("Date de rapportage[^0-9]{0,80}?([0-9]{1,2})\\s*",
               "([[:alpha:]éû]+)\\s*(20[0-9]{2})"),
        doc, perl = TRUE
    ))[[1]]
    if (length(long) == 4) {
        month <- FRENCH_MONTHS[fold(long[3])]
        if (!is.na(month)) {
            d <- as.Date(sprintf("%s-%02d-%02d", long[4], month,
                                 as.integer(long[2])))
            return(list(date = d, source = "date_de_rapportage"))
        }
    }
    short <- regmatches(doc, regexec(
        "Date de rapportage[^0-9]{0,80}?([0-9]{2})/([0-9]{2})/(20[0-9]{2})",
        doc, perl = TRUE
    ))[[1]]
    if (length(short) == 4) {
        return(list(date = as.Date(sprintf("%s-%s-%s", short[4], short[3],
                                           short[2])),
                    source = "date_de_rapportage_numeric"))
    }
    header <- regmatches(doc, regexec(
        "SitRep\\s*N\\S*\\s*[0-9]{2,3}\\S*?([0-9]{2})/([0-9]{2})/(20[0-9]{2})",
        doc, perl = TRUE
    ))[[1]]
    if (length(header) == 4) {
        return(list(date = as.Date(sprintf("%s-%s-%s", header[4], header[3],
                                           header[2])),
                    source = "sitrep_header"))
    }
    list(date = as.Date(NA), source = NA_character_)
}

#' Render every page of a PDF to PNG with PyMuPDF, if Python has it
render_mupdf <- function(path, pngs, dpi) {
    python <- Sys.which("python3")
    if (!nzchar(python)) return(FALSE)
    script <- tempfile(fileext = ".py")
    on.exit(unlink(script))
    writeLines(c(
        "import sys, pymupdf",
        "doc = pymupdf.open(sys.argv[1])",
        "for page, out in zip(doc, sys.argv[3:]):",
        "    page.get_pixmap(dpi=int(sys.argv[2])).save(out)"
    ), script)
    status <- suppressWarnings(system2(
        python, c(script, shQuote(path), dpi, shQuote(pngs)),
        stdout = FALSE, stderr = FALSE
    ))
    identical(status, 0L) && all(file.exists(pngs))
}

#' Render every page of a PDF to PNG with poppler, in a child R process
render_poppler <- function(path, pngs, dpi) {
    code <- sprintf(
        paste0("pdftools::pdf_convert(%s, pages = seq_len(%d), dpi = %d, ",
               "filenames = c(%s), verbose = FALSE)"),
        deparse(path), length(pngs), as.integer(dpi),
        paste(vapply(pngs, deparse, ""), collapse = ", ")
    )
    status <- suppressWarnings(system2(
        file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
        stdout = FALSE, stderr = FALSE
    ))
    identical(status, 0L) && all(file.exists(pngs))
}

text_cache_path <- function(path, text_dir) {
    info <- parse_filename(basename(path))
    file.path(text_dir, sprintf("%03d_v%d__%s.txt", info$sitrep,
                                info$version, tools::md5sum(path)))
}

# Pages are separated by a form feed; the first line records how the text was
# obtained, so a value read out of an OCR'd report can be told apart from one
# read out of a text layer.
write_text_cache <- function(file, text, source) {
    writeLines(c(paste0("#text_source: ", source),
                 paste(text, collapse = "\f")), file, useBytes = TRUE)
    list(text = text, source = source)
}

read_text_cache <- function(file) {
    lines <- readLines(file, encoding = "UTF-8", warn = FALSE)
    list(text = strsplit(paste(lines[-1], collapse = "\n"), "\f",
                         fixed = TRUE)[[1]],
         source = sub("^#text_source: ", "", lines[1]))
}

read_pdf_text <- function(path, text_dir, dpi = 250L) {
    cached <- text_cache_path(path, text_dir)
    if (file.exists(cached)) return(read_text_cache(cached))
    text <- tryCatch(pdf_text(path), error = function(e) {
        warning("Cannot read ", basename(path), ": ", conditionMessage(e))
        character()
    })
    if (sum(nchar(gsub("\\s", "", text))) >= MIN_TEXT_CHARS) {
        return(write_text_cache(cached, text, "pdf_text"))
    }
    if (!requireNamespace("tesseract", quietly = TRUE) ||
        !"fra" %in% tesseract::tesseract_info()$available) {
        warning(basename(path), " has no text layer and French Tesseract ",
                "is not installed; skipped")
        return(list(text = text, source = "none"))
    }
    message("  OCR: ", basename(path))
    engine <- tesseract::tesseract("fra")
    pngs <- file.path(tempdir(), sprintf("ocr_%s_%02d.png",
                                         tools::md5sum(path),
                                         seq_along(text)))
    on.exit(unlink(pngs))
    for (renderer in c("mupdf", "poppler")) {
        unlink(pngs)
        ok <- switch(renderer,
            mupdf = render_mupdf(path, pngs, dpi),
            poppler = render_poppler(path, pngs, dpi)
        )
        if (!ok) next
        ocr_text <- unname(vapply(pngs, tesseract::ocr, character(1),
                                  engine = engine))
        if (sum(nchar(gsub("\\s", "", ocr_text))) >= MIN_TEXT_CHARS) {
            return(write_text_cache(cached, ocr_text,
                                    paste0("ocr_", renderer)))
        }
    }
    warning(basename(path), " could not be OCR'd; install PyMuPDF ",
            "(pip install pymupdf) or transcribe it by hand")
    list(text = text, source = "none")
}

# ---- main -----------------------------------------------------------------

if (!dir.exists(PDF_DIR)) {
    stop("No PDF directory at ", PDF_DIR,
         ". Clone https://github.com/INRB-UMIE/BDBV2026-Data, or pass ",
         "--pdf-dir=")
}
dir.create(TEXT_DIR, showWarnings = FALSE, recursive = TRUE)

pdfs <- sort(list.files(PDF_DIR, pattern = "^SitRep_MVE_.*\\.pdf$",
                        full.names = TRUE))
message("PDFs: ", length(pdfs))

rows <- vector("list", length(pdfs))
for (i in seq_along(pdfs)) {
    path <- pdfs[i]
    read <- read_pdf_text(path, TEXT_DIR)
    info <- parse_filename(basename(path))
    rd <- parse_report_date(read$text)
    if (is.na(rd$date)) warning("No report date in ", basename(path))
    rows[[i]] <- data.table(
        sitrep = info$sitrep,
        version = info$version,
        pdf_file = basename(path),
        report_date = rd$date,
        report_date_source = rd$source,
        text_source = read$source,
        n_pages = length(read$text),
        text_file = basename(text_cache_path(path, TEXT_DIR))
    )
}

reports <- rbindlist(rows)
setorder(reports, sitrep, version)
print(as.data.frame(head(reports, 3)))
message("scanned reports read by OCR: ",
        reports[grepl("^ocr", text_source), .N])
message("reports with no date: ", reports[is.na(report_date), .N])

dir.create(REG_DIR, showWarnings = FALSE, recursive = TRUE)
fwrite(reports, file.path(REG_DIR, "reports.csv"))
message("wrote ", file.path(REG_DIR, "reports.csv"), ": ", nrow(reports))
