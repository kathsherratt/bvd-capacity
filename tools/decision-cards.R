#!/usr/bin/env Rscript
# ai-written
#'
#' The open naming questions as one JSON file, for a page a person can answer
#' on a phone.
#'
#' Same questions as the sheets in `checks/decisions/`, same evidence, in the
#' shape a card wants rather than the shape a diff wants. Two kinds of
#' question: whether several names are one facility, and which existing centre
#' a name that carries no town belongs to.
#'
#' Nothing here decides anything or writes into the repository. The answers
#' come back through `registry/decisions.csv`.
#'
#' Usage:
#'     Rscript tools/decision-cards.R [out.json]

suppressMessages({
    library(data.table)
    library(jsonlite)
})
source(here::here("R", "lib", "paths.R"))

args <- commandArgs(trailingOnly = TRUE)
out_path <- if (length(args)) args[1] else here::here("runs", "decision-cards.json")

KINDS <- c("treatment_centre", "transit_centre", "isolation_centre")
NOT_YET_OPEN <- c("planned", "under_construction")
IN_SERVICE <- c("operating", "expanded", "strained", "incident")

events <- fread(events_path())[nzchar(facility_id)]
facilities <- fread(facilities_path())
queue <- fread(review_queue_path())
opening <- fread(opening_path())
places <- fread(place_check_path())
flag_long <- fread(flags_path())
decided <- if (file.exists(decisions_path())) {
    fread(decisions_path(), colClasses = "character")
} else NULL

bounds_of <- function(d) {
    by <- suppressWarnings(min(c(d$report_date[d$event %in% IN_SERVICE],
        d$report_date[d$event == "opened"]), na.rm = TRUE))
    if (!is.finite(by)) by <- NA
    prior <- d$report_date[d$event %in% NOT_YET_OPEN & (is.na(by) | d$report_date < by)]
    af <- suppressWarnings(max(prior, na.rm = TRUE))
    if (!is.finite(af)) af <- NA
    list(after = as.character(as.Date(af)), by = as.character(as.Date(by)))
}

grid3_note <- function(id) {
    r <- places[facility_id == id]
    if (!nrow(r)) return("not checked")
    if (isTRUE(r$confirmed_in_zone[1])) {
        return(paste0("confirmed in zone",
            if (nzchar(r$grid3_type[1])) paste0(" (", r$grid3_type[1], ")") else ""))
    }
    if (isTRUE(r$name_known[1])) return("name known elsewhere")
    if (isTRUE(r$place_known[1])) return("place known, name not")
    "unknown to GRID3"
}

quotes_for <- function(id, shared_reports, n = 5L) {
    d <- copy(events[facility_id == id])
    if (!nrow(d)) return(list())
    d[, pr := fcase(event %in% NOT_YET_OPEN, 1L, event == "opened", 1L,
        event %in% IN_SERVICE, 2L, default = 3L)]
    setorder(d, pr, report_date)
    d <- d[!duplicated(evidence_quote)]
    lapply(seq_len(min(n, nrow(d))), function(k) list(
        sitrep = d$sitrep[k], date = as.character(d$report_date[k]),
        event = d$event[k], quote = d$evidence_quote[k],
        shared = d$sitrep[k] %in% shared_reports))
}

member_of <- function(id, name, aliases, n_sitreps, n_events, shared_reports) {
    o <- opening[facility_id == id]
    list(id = id, name = name, aliases = I(aliases),
        reports = n_sitreps, events = n_events, grid3 = grid3_note(id),
        now_after = if (nrow(o)) as.character(o$opened_after[1]) else NA,
        now_by = if (nrow(o)) as.character(o$opened_by[1]) else NA,
        quotes = I(quotes_for(id, shared_reports)))
}

# ------------------------------------------------- are these one facility?

if (!"settled" %in% names(queue)) queue[, settled := ""]
queue[, etc_cluster := any(site_kind %in% KINDS), by = cluster]
subgroups <- queue[etc_cluster == TRUE & site_kind %in% KINDS & settled == "",
    .(n = .N), by = .(cluster, rank, site_kind, events_in_cluster)][n > 1]
setorder(subgroups, rank, site_kind)

cards <- lapply(seq_len(nrow(subgroups)), function(i) {
    sg <- subgroups[i]
    mem <- queue[cluster == sg$cluster & site_kind == sg$site_kind & settled == ""]
    ev <- events[facility_id %in% mem$facility_id]
    shared_reports <- ev[, .(k = uniqueN(facility_id)), by = sitrep][k > 1, sitrep]
    m <- bounds_of(ev)
    prior <- if (!is.null(decided)) {
        decided[cluster == sg$cluster & site_kind == sg$site_kind & verdict != "unsure"]
    } else NULL
    list(
        id = paste0(sg$cluster, "__", sub("_centre", "", sg$site_kind)),
        type = "same_or_not",
        rank = sg$rank, cluster = sg$cluster,
        kind = sub("_centre", "", sg$site_kind),
        place = paste(unique(mem$place_key), collapse = ", "),
        province = mem$province[1],
        cluster_events = sg$events_in_cluster,
        shared = length(shared_reports),
        merged_after = m$after, merged_by = m$by,
        prior = I(if (!is.null(prior) && nrow(prior)) lapply(seq_len(nrow(prior)), function(j) list(
            decision_id = prior$decision_id[j], verdict = prior$verdict[j],
            by = prior$decided_by[j], on = prior$decided_on[j],
            was = I(sort(trimws(strsplit(prior$facility_ids[j], ";")[[1]]))),
            joined = I(setdiff(mem$facility_id, trimws(strsplit(prior$facility_ids[j], ";")[[1]]))),
            note = prior$note[j])) else list()),
        members = I(lapply(seq_len(nrow(mem)), function(j) member_of(
            mem$facility_id[j], mem$facility_name[j],
            strsplit(mem$aliases[j], "; ")[[1]], mem$n_sitreps[j], mem$n_events[j],
            shared_reports))))
})

# ------------------------------------------------------- which one is this?

mp <- flag_long[flag == "possible_missing_place"]
place_cards <- lapply(unique(mp$group), function(g) {
    ids <- mp[group == g, unique(facility_id)]
    fac <- facilities[facility_id %in% ids]
    fac <- fac[order(nchar(facility_name))]
    bare <- fac[1]
    others <- fac[facility_id != bare$facility_id]
    list(
        id = paste0("missing-place__", bare$facility_id),
        type = "which_one",
        rank = 0L, cluster = bare$facility_id,
        kind = sub("_centre", "", bare$site_kind),
        place = "no town given", province = bare$province,
        cluster_events = sum(fac$n_events), shared = 0L,
        merged_after = NA, merged_by = NA, prior = I(list()),
        members = I(c(
            list(member_of(bare$facility_id, bare$facility_name,
                strsplit(bare$aliases, "; ")[[1]], bare$n_sitreps, bare$n_events,
                character())),
            lapply(seq_len(nrow(others)), function(j) member_of(
                others$facility_id[j], others$facility_name[j],
                strsplit(others$aliases[j], "; ")[[1]],
                others$n_sitreps[j], others$n_events[j], character())))))
})

all_cards <- c(place_cards, cards)
writeLines(toJSON(all_cards, auto_unbox = TRUE, null = "null", na = "null"), out_path)
message(length(all_cards), " questions written to ", out_path, ": ",
    length(place_cards), " about a missing town, ", length(cards),
    " about whether names are one facility.")
