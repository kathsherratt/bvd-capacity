#!/usr/bin/env Rscript
# ai-written
#'
#' Put the registry's open judgements in the order they are worth making.
#'
#' 795 spellings is not a review, it is a refusal to prioritise. Most are
#' singletons from one sitrep whose resolution changes nothing; a handful
#' decide whether a treatment centre with forty events is one facility or two.
#' This script groups the flagged facilities into the decisions that produced
#' them and sorts by the number of events that hang on each.
#'
#' Nothing here changes any data. It writes a worksheet; the decision is made
#' by setting `reviewed = TRUE` in registry/facility_aliases.csv, which
#' R/02_resolve.R then treats as final.
#'
#' Usage:
#'     Rscript R/04_review.R [--top=N]

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))

args <- commandArgs(trailingOnly = TRUE)
top <- as.integer(sub("^--top=", "",
    grep("^--top=", args, value = TRUE)[1]))
if (is.na(top)) top <- 25L

facilities <- fread(facilities_path())
flag_long <- fread(flags_path())
registry <- fread(registry_path())

#' A facility can be flagged against several others for several reasons, and
#' the reasons overlap: `cte-hgr-bunia` meets `cte-bunia` as a host variant
#' and `cte-cme-bunia` as the same site. Reviewing those as three separate
#' questions asks the same question three times, so the groups are merged
#' into connected components and each component is one decision.
parent <- setNames(seq_along(facilities$facility_id), facilities$facility_id)
root <- function(x) {
    while (parent[[x]] != match(x, names(parent))) {
        x <- names(parent)[parent[[x]]]
    }
    x
}
unite <- function(a, b) {
    ra <- root(a); rb <- root(b)
    if (ra != rb) parent[[ra]] <<- match(rb, names(parent))
}
for (g in split(flag_long$facility_id, flag_long$group)) {
    g <- intersect(unique(g), names(parent))
    for (i in seq_len(length(g) - 1L)) unite(g[i], g[i + 1L])
}

comp <- data.table(facility_id = names(parent),
    cluster = vapply(names(parent), root, character(1)))
comp <- comp[facility_id %in% flag_long$facility_id]

q <- merge(facilities[, .(facility_id, facility_name, site_kind, place_key,
    province, n_sitreps, n_events, date_first_in_service, status_latest,
    beds_latest, flags, aliases)], comp, by = "facility_id")

#' Where GRID3 says several members name one health zone's reference
#' hospital, that part of the decision is already answered and the count is
#' worth seeing next to the question rather than buried in a flag column.
host <- flag_long[flag == "possible_same_host",
    .(facility_id, host_zone = sub("^possible_same_host:", "", group))]
q <- merge(q, host, by = "facility_id", all.x = TRUE)

decisions <- q[, .(
    members = uniqueN(facility_id),
    kinds = uniqueN(site_kind),
    events = sum(n_events),
    same_host = uniqueN(facility_id[!is.na(host_zone)]),
    host_zone = paste(sort(unique(na.omit(host_zone))), collapse = "; "),
    max_sitreps = max(n_sitreps),
    in_service = sum(!is.na(date_first_in_service)),
    ids = paste(facility_id, collapse = " | "),
    reasons = paste(sort(unique(unlist(strsplit(flags, ";")))), collapse = ",")
), by = cluster][order(-events, -max_sitreps)]
decisions[, rank := .I]

setorder(q, -n_events)
sheet <- merge(q, decisions[, .(cluster, rank, events_in_cluster = events)],
    by = "cluster")
setorder(sheet, rank, -n_events)
setcolorder(sheet, c("rank", "cluster", "facility_id", "facility_name",
    "site_kind", "n_sitreps", "n_events"))

#' A question answered is not a question. A decision in
#' registry/decisions.csv settles the facilities it names, so those rows are
#' marked rather than asked again; `unsure` settles nothing. The decision
#' holds only while the group is unchanged, so a facility added to the cluster
#' by a later extraction reopens it, which is the same rule
#' R/09_apply_decisions.R applies.
sheet[, settled := ""]
if (file.exists(decisions_path())) {
    decided <- fread(decisions_path(), colClasses = "character")
    for (i in seq_len(nrow(decided))) {
        d <- decided[i]
        if (d$verdict == "unsure") next
        ids <- sort(trimws(strsplit(d$facility_ids, ";")[[1]]))
        rows <- sheet$cluster == d$cluster & sheet$site_kind == d$site_kind
        if (!any(rows)) next
        if (!identical(sort(sheet$facility_id[rows]), ids)) next
        sheet[rows, settled := d$verdict]
    }
}

out <- review_queue_path()
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
fwrite(sheet, out)

# ----------------------------------------------------------------- report

message(sheet[settled == "", uniqueN(cluster)], " open decisions, ",
    sheet[settled != "", uniqueN(paste(cluster, site_kind))],
    " already settled in ", basename(decisions_path()), ".\n")
message(nrow(decisions), " decisions over ", nrow(q), " facilities and ",
    sum(q$n_events), " events.")
message(nrow(facilities) - nrow(q), " facilities are flagged against nothing ",
    "and need no decision.\n")

cum <- decisions[, cumsum(events) / sum(events)]
message("The first 10 decisions cover ", round(100 * cum[min(10, length(cum))]),
    "% of the flagged events, the first 25 ",
    round(100 * cum[min(25, length(cum))]), "%.\n")

print(decisions[seq_len(min(top, .N)),
    .(rank, events, members, same_host, host_zone, ids)])

message("\nWritten: ", out)
message("Decide by setting reviewed = TRUE in ", registry_path(), ",")
message("editing facility_id on the rows that should share one.")
