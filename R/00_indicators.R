#!/usr/bin/env Rscript
# ai-written
#'
#' What do the situation reports actually measure?
#'
#' A survey, not a step of the facility pipeline. Every table in the corpus
#' carries its indicator names as text already, either as column headers or,
#' where the table is transposed and provinces are the columns, as the label
#' in the first cell of each row. Collecting them says which questions the
#' corpus can answer, and for which stretch of the outbreak: the treatment
#' table stops after SitRep 090, and a survey like this is how such a gap
#' becomes visible before a pass is designed around it.
#'
#' No model call, so it costs nothing to rerun whenever the corpus changes.
#'
#' Writes:
#'   data/indicator_appearances.csv  one row per label per table it appears in
#'   data/indicators.csv             one row per distinct label, with a topic
#'                                   guess to be corrected by hand
#'
#' Usage:
#'     Rscript R/00_indicators.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "corpus.R"))

#' Strip what changes between reports so the same indicator keys the same way.
#'
#' Dates move every day and are not part of the name. Accents stay: they
#' distinguish words, and folding them is left to the clustering below, where
#' being wrong is visible rather than silent.
norm_label <- function(x) {
    x <- tolower(trimws(gsub("\\s+", " ", x)))
    x <- gsub("\\(?\\b\\d{1,2}\\s*[/-]\\s*\\d{1,2}(\\s*[/-]\\s*\\d{2,4})?\\)?", "", x, perl = TRUE)
    x <- gsub("\\b(19|20)\\d{2}\\b", "", x, perl = TRUE)
    x <- gsub("\\b(au|du|le|en date)\\s*$", "", x, perl = TRUE)
    x <- gsub("[[:space:].,;:]+$", "", x, perl = TRUE)
    # "Report (J-1" keeps its bracket open once a date is cut out of it.
    x <- gsub("\\([^()]*$", "", x, perl = TRUE)
    trimws(gsub("\\s+", " ", x))
}

fold <- function(x) {
    x <- iconv(x, "UTF-8", "ASCII//TRANSLIT")
    x <- gsub("[`'^~\"]", "", x, perl = TRUE)
    gsub("[^a-z0-9 ]", " ", tolower(x), perl = TRUE) |> trimws()
}

#' A transposed table puts provinces in the columns and the measure in the row
#' label. These are the first-column headers that say so.
TRANSPOSED_HEAD <- "indicateur|suivi des alertes|rubrique|activit|param"

#' Not everything in a header row is a measurement. A province name is the
#' dimension a measurement is cut by, and counting it as an indicator would
#' put `ituri` at the top of the list with 242 appearances.
DIMENSIONS <- paste0(
    "^(province|provinces( touch[ée]es)?|dps|zones? de sant[ée]( touch[ée]es)?",
    "|province ?/ ?zone de sant[ée]|aire de sant[ée]|indicateurs?( cles| cl[ée]s)?",
    "|rubrique|n[°o]|date|jour|semaine|total|global|ensemble|",
    "ituri|nord-?kivu|sud-?kivu|tshopo|haut-?u[ée]l[ée]|",
    "bas-?u[ée]l[ée]|kinshasa|mai-?ndombe|[ée]quateur|poe ?/ ?poc)$")

#' Columns holding sentences, not counts. They carry real content but no
#' series, so they are kept and marked rather than mixed in with measurements.
NARRATIVE <- paste0(
    "^(commentaires?|observations?|source|d[ée]fis|impact|actions?( requises| ",
    "men[ée]es)?|recommandations?|responsables?|priorit[ée]s?|",
    "difficult[ée]s|perspectives?|activit[ée]s r[ée]alis[ée]es|",
    "points? (d'attention|saillants)|suivi des recommandations)")

TOPICS <- list(
    points_of_entry = "poe|poc|voyageur|point d'entr",
    alerts          = "alerte",
    cases           = paste0("cas confirm|cas suspect|cas probable|l[ée]talit|",
                             "nouveaux cas|incidence|\\bcas\\b|d[ée]c[èe]s|",
                             "gu[ée]rison|cumulatif|cumul[ée]s"),
    contacts        = "contact|taux de suivi|suivi journalier|perdus de vue",
    surveillance    = paste0("investigu|investigation|compl[ée]tude|promptitude|",
                             "notifi|rapportage|rapports|d[ée]tection"),
    treatment       = "\\bcte\\b|\\bct\\b|\\blit\\b|lits|patient|admission|isolement|hospitalis|gu[ée]ri|sorti|occupation|accompagnant",
    laboratory      = "laboratoire|pr[ée]l[èe]v|[ée]chantillon|r[ée]sultat|positif|genexpert|inrb|test",
    death_surveil   = "corps sans vie|swab|enterrement|inhumation|\\beds\\b|d[ée]c[èe]s communautaire",
    vaccination     = "vaccin|anneau|\\bring\\b",
    psychosocial    = "smsps|psychosocial|sant[ée] mentale|cr[èe]che|enfants s[ée]par",
    ipc_wash        = "\\bipc\\b|hygi[èe]ne|lavage|d[ée]sinfect|eau",
    community       = "sensibilis|reco\\b|communautaire|engagement",
    logistics       = "ambulance|intrant|stock|rupture|kit|carburant",
    workforce       = "\\bppl\\b|personnel|agents? de sant[ée]|prestataire|formation"
)

suggest_topic <- function(key) {
    out <- rep("", length(key))
    for (nm in names(TOPICS)) {
        hit <- out == "" & grepl(TOPICS[[nm]], key, perl = TRUE)
        out[hit] <- nm
    }
    out
}

ids <- corpus_ids()
message("Reading ", length(ids), " reports.")

rows <- list()
for (id in ids) {
    rep <- read_report(id)
    for (tb in rep$tables) {
        cols <- unlist(tb$columns)
        caption <- tb$caption %||% ""
        transposed <- grepl(TRANSPOSED_HEAD, norm_label(cols[1]), perl = TRUE)
        labels <- cols
        kind <- rep("column", length(cols))
        if (transposed) {
            first <- vapply(tb$rows, function(r) unlist(r$cells)[1], character(1))
            labels <- c(cols, first)
            kind <- c(kind, rep("row_label", length(first)))
        }
        rows[[length(rows) + 1]] <- data.table(
            sitrep = id,
            sitrep_num = as.integer(sub("_v.*", "", id)),
            report_date = rep$meta$report_date,
            table_n = tb$n,
            caption = caption,
            label_raw = labels,
            kind = kind
        )
    }
}
app <- rbindlist(rows)
app <- app[nzchar(trimws(label_raw))]
app[, label_key := norm_label(label_raw)]
app <- app[nzchar(label_key)]
app[, role := fcase(
    grepl(DIMENSIONS, label_key, perl = TRUE), "dimension",
    grepl(NARRATIVE, label_key, perl = TRUE), "narrative",
    default = "indicator")]

setorder(app, sitrep_num, table_n)
fwrite(app, indicator_appearances_path())

ind <- app[, .(
    role = role[1],
    kind = paste(sort(unique(kind)), collapse = "+"),
    n_appearances = .N,
    n_reports = uniqueN(sitrep),
    first_sitrep = min(sitrep_num),
    last_sitrep = max(sitrep_num),
    first_date = min(report_date),
    last_date = max(report_date),
    example_caption = caption[which.max(nchar(caption))],
    example_raw = label_raw[1]
), by = label_key]

# A label that stops appearing is the thing this survey is for: it marks the
# end of a series, not a spelling change. Flagged rather than dropped.
last_report <- max(app$sitrep_num)
ind[, has_series := n_reports >= 5L]
ind[, still_reported := last_sitrep >= last_report - 5L]
ind[, topic_suggested := suggest_topic(label_key)]
ind[role == "dimension", topic_suggested := ""]
ind[, topic := ""]

# Near-duplicates: the same measure spelled two ways. Clustered on the
# accent-folded key so that a review sees them side by side, in the same way
# the facility registry will treat Mongbwalu and Mungbwalu.
ind[, folded := fold(label_key)]
ind[, cluster := folded]
long <- ind[nchar(folded) >= 8L]
if (nrow(long) > 1L) {
    d <- adist(long$folded, long$folded, costs = c(1, 1, 1))
    for (i in seq_len(nrow(long))) {
        near <- which(d[i, ] <= 2L)
        if (length(near) > 1L) {
            rep_key <- long$folded[near][which.max(long$n_appearances[near])]
            ind[folded %in% long$folded[near], cluster := rep_key]
        }
    }
}
ind[, n_in_cluster := .N, by = cluster]

setorder(ind, role, -n_appearances)
setcolorder(ind, c("label_key", "role", "topic", "topic_suggested", "kind",
    "n_appearances", "n_reports", "first_sitrep", "last_sitrep",
    "has_series", "still_reported", "cluster", "n_in_cluster"))
fwrite(ind[, -c("folded")], indicators_path())

message("\nLabels: ", nrow(ind), " distinct (",
    sum(ind$role == "indicator"), " indicators, ",
    sum(ind$role == "dimension"), " dimensions)")
message("Appearances: ", nrow(app))
message("Indicators with a series (5+ reports): ",
    nrow(ind[role == "indicator" & has_series]),
    ", of which stopped before the last 5 sitreps: ",
    nrow(ind[role == "indicator" & has_series & !still_reported]))
message("\nIndicators by suggested topic:")
print(ind[role == "indicator", .(labels = .N, appearances = sum(n_appearances)),
    by = topic_suggested][order(-appearances)])
message("\nWritten: ", indicators_path())
message("Written: ", indicator_appearances_path())
