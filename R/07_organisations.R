#!/usr/bin/env Rscript
# ai-written
#'
#' Who the reports name alongside a facility.
#'
#' A keyword scan, not a model pass. Every row carries the sentence it came
#' from, and that sentence is a literal slice of the corpus, so it needs no
#' quote gate: it is verbatim by construction.
#'
#' What this does and does not claim. A row says an organisation was named in
#' a sentence that also mentions a facility. That catches building a treatment
#' centre, and it equally catches delivering soap to one, so the counts are an
#' upper bound on "provided a facility". Read `example_quote` before citing a
#' row. The organisations that built or ran something say so plainly:
#' `construction du CTE a l'HGR Bunia par le partenaire IMC`.
#'
#' Word boundaries are not optional. Matching `PUI` without them finds it
#' inside `appui` and turns Premiere Urgence into the most active partner of
#' the response, with 107 sentences it has nothing to do with. Acronyms are
#' matched case sensitively for the same reason.
#'
#' Two kinds of organisation are in here and the `type` column separates them.
#' An international NGO or UN agency is a partner to approach for its own
#' records. A Congolese hospital or institute, the CME at Nyankunde, ISTM,
#' FOMULAC at Katana, is the building itself, and appears because the reports
#' name a facility by its host.
#'
#' Usage:
#'     Rscript R/07_organisations.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "corpus.R"))

#' A sentence counts as being about a facility if it names one of these.
FACILITY <- paste0("\\bCTE\\b|\\bCT\\b|\\bCI\\b|\\bHGR\\b|isolement|",
    "centre de traitement|centre de transit|triage|\\bPoC\\b|\\bPoE\\b")

#' name, kind, what the reports attribute, pattern. Patterns are anchored on
#' both sides and acronyms keep their case.
ORGANISATIONS <- list(
    list("MSF", "international NGO",
        "built and ran facilities; appears as MSF France and MSF Hollande",
        "\\b(MSF|M\u00e9decins Sans Fronti\u00e8res|Medecins Sans Frontieres)\\b"),
    list("ALIMA", "international NGO", "ran the CTE at HGR Rwampara",
        "\\b(ALIMA|Alima)\\b"),
    list("IMC", "international NGO",
        "built and ran the CTE at HGR Bunia; built CTE Matanda", "\\bIMC\\b"),
    list("ULB Cooperation", "university cooperation",
        "isolation unit and triage at HGR Vuhovi", "\\bULB\\b"),
    list("MEDAIR", "international NGO",
        "triage at HGR Katwa and CS Bahwere", "\\b(MEDAIR|Medair)\\b"),
    list("IMA World Health", "international NGO",
        "IPC support; siting the large-capacity CTE in Tshopo", "\\bIMA\\b"),
    list("Samaritan's Purse", "international NGO",
        "water tanks at points of control", "Samaritan"),
    list("UNICEF", "UN agency", "funded water and triage works",
        "\\b(UNICEF|Unicef)\\b"),
    list("OMS", "UN agency", "co-ordination and joint missions", "\\bOMS\\b"),
    list("PAM", "UN agency", "joint visits, food to facilities", "\\bPAM\\b"),
    list("OIM", "UN agency", "activated points of entry and control", "\\bOIM\\b"),
    list("CAUB", "local contractor",
        "water to CTE Katwa, implementing for UNICEF", "\\bCAUB\\b"),
    list("INSP", "DRC government",
        "runs the response and publishes these reports", "\\bINSP\\b"),
    list("INRB", "DRC government", "laboratories", "\\bINRB\\b"),
    list("COUSP", "DRC government", "emergency operations centre", "\\bCOUSP\\b"),
    list("CME", "Congolese hospital", "hosted CTEs at Nyankunde and Bunia",
        "\\bCME\\b"),
    list("ISTM", "Congolese medical institute", "hosted a CTE at Nyankunde",
        "\\bISTM\\b"),
    list("FOMULAC", "Congolese hospital",
        "reference hospital of Katana; hosted isolation", "\\bFOMULAC\\b"),
    list("SOFEPADI", "Congolese NGO clinic", "Bunia", "\\bSOFEPADI\\b"),
    list("HEAL Africa", "Congolese hospital", "Goma", "\\b(HEAL|Heal) Africa\\b"),
    list("CBCA", "Congolese church health network", "hospitals used", "\\bCBCA\\b"),
    list("UCBC", "Congolese university", "site named", "\\bUCBC\\b"))

#' Front matter and tables are dropped: a sentence split over YAML turns the
#' report id block into a sentence about whatever the header mentions.
sentences <- rbindlist(lapply(corpus_ids(), function(id) {
    body <- read_report(id)$body
    s <- unlist(strsplit(paste(body, collapse = " "), "(?<=[.;])\\s+", perl = TRUE))
    s <- trimws(gsub("\\s+", " ", s))
    data.table(sitrep = id, sentence = s[nzchar(s)])
}))
fac <- sentences[grepl(FACILITY, sentence, perl = TRUE)]

out <- rbindlist(lapply(ORGANISATIONS, function(o) {
    hits <- unique(fac[grepl(o[[4]], sentence, perl = TRUE)])
    if (!nrow(hits)) return(NULL)
    setorder(hits, sitrep)
    data.table(
        organisation = o[[1]], type = o[[2]], role_in_reports = o[[3]],
        facility_sentences = nrow(hits), reports = uniqueN(hits$sitrep),
        first_sitrep = hits$sitrep[1], last_sitrep = hits$sitrep[nrow(hits)],
        example_sitrep = hits$sitrep[1],
        example_quote = substr(hits$sentence[1], 1, 300),
        corpus_md = file.path("data", "corpus", "fr",
            paste0(hits$sitrep[1], ".md")),
        source_pdf = file.path("data", "pdf", paste0(hits$sitrep[1], ".pdf")))
}))
setorder(out, -facility_sentences)
fwrite(out, organisations_path())

message("Scanned ", nrow(sentences), " sentences over ", uniqueN(sentences$sitrep),
    " reports; ", nrow(fac), " mention a facility.\n")
print(out[, .(organisation, type, facility_sentences, reports)])
message("\nWritten: ", organisations_path())
