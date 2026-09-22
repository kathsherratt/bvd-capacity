#!/usr/bin/env Rscript
# ai-written
#'
#' One sheet per naming decision, with the evidence that settles it.
#'
#' `R/04_review.R` says which facilities might be one another and orders the
#' clusters by what hangs on them. A cluster is not a question, though: it
#' groups everything sharing a host, and a treatment centre, a transit centre
#' and an isolation centre at one hospital are three facilities however they
#' are spelled. So the question is asked within one `site_kind`, and a cluster
#' holding a CTE, a CT and a CI produces three sheets or none.
#'
#' Each sheet carries what a person needs and nothing else: the rival names,
#' what GRID3 recognises, whether the two ever appear in one report, what
#' merging would do to the opening interval, and the quotes that carry the
#' bounds. A decision is then read and answered rather than investigated.
#'
#' Only treatment, transit and isolation centres get a sheet. The `other`
#' sites are health facilities the response touched, no opening date depends
#' on them, and deciding them is a later pass's problem.
#'
#' Usage:
#'     Rscript R/08_decisions.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))

KINDS <- c("treatment_centre", "transit_centre", "isolation_centre")
NOT_YET_OPEN <- c("planned", "under_construction")
IN_SERVICE <- c("operating", "expanded", "strained", "incident")
MAX_QUOTES <- 4

events <- fread(events_path())[nzchar(facility_id)]
queue <- fread(review_queue_path())
opening <- fread(opening_path())
places <- if (file.exists(place_check_path())) fread(place_check_path()) else NULL

#' The same rule as R/06_opening.R, applied to a hypothetical merge.
bounds_of <- function(d) {
    by <- suppressWarnings(min(c(
        d$report_date[d$event %in% IN_SERVICE],
        d$report_date[d$event == "opened"]), na.rm = TRUE))
    if (!is.finite(by)) by <- NA
    prior <- d$report_date[d$event %in% NOT_YET_OPEN &
        (is.na(by) | d$report_date < by)]
    after <- suppressWarnings(max(prior, na.rm = TRUE))
    if (!is.finite(after)) after <- NA
    list(after = as.Date(after), by = as.Date(by))
}

show_date <- function(x) if (is.na(x)) "none" else as.character(x)

interval_of <- function(after, by) {
    if (is.na(after) && is.na(by)) return("no bound")
    paste0("[", show_date(after), " .. ", show_date(by), "]")
}

#' A quote earns its place by carrying a bound or by naming the host. The
#' events that set the interval come first, then the earliest of the rest.
pick_quotes <- function(d) {
    d <- copy(d)
    d[, priority := fcase(
        event %in% NOT_YET_OPEN, 1L,
        event %in% IN_SERVICE, 2L,
        event == "opened", 1L,
        default = 3L)]
    setorder(d, priority, report_date)
    d <- d[!duplicated(evidence_quote)]
    head(d, MAX_QUOTES)
}

grid3_note <- function(fid) {
    if (is.null(places)) return("not checked")
    row <- places[facility_id == fid]
    if (!nrow(row)) return("not checked")
    if (isTRUE(row$confirmed_in_zone[1])) {
        return(paste0("confirmed in zone", if (nzchar(row$grid3_type[1]))
            paste0(" (", row$grid3_type[1], ")") else ""))
    }
    if (isTRUE(row$name_known[1])) return("name known elsewhere in the six provinces")
    if (isTRUE(row$place_known[1])) return("place known, name not")
    "unknown to GRID3"
}

# ----------------------------------------------------- the questions to ask

#' A sheet is a question waiting for an answer, so a subgroup already
#' settled in registry/decisions.csv gets none. R/04_review.R marks those.
if (!"settled" %in% names(queue)) queue[, settled := ""]
queue[, etc_cluster := any(site_kind %in% KINDS), by = cluster]
subgroups <- queue[etc_cluster == TRUE & site_kind %in% KINDS & settled == "",
    .(n = .N), by = .(cluster, rank, site_kind, events_in_cluster)][n > 1]
setorder(subgroups, rank, site_kind)

dir.create(checks_dir("decisions"), recursive = TRUE, showWarnings = FALSE)
for (f in list.files(checks_dir("decisions"), pattern = "\\.md$", full.names = TRUE)) {
    file.remove(f)
}

index <- vector("list", nrow(subgroups))

for (i in seq_len(nrow(subgroups))) {
    sg <- subgroups[i]
    members <- queue[cluster == sg$cluster & site_kind == sg$site_kind &
        settled == ""]
    ids <- members$facility_id
    ev <- events[facility_id %in% ids]
    now <- opening[facility_id %in% ids]
    merged <- bounds_of(ev)

    kind_label <- sub("_centre", " centre", sg$site_kind)
    place <- paste(unique(members$place_key), collapse = ", ")
    slug <- sprintf("%02d-%s-%s", sg$rank, sg$cluster, sub("_centre", "", sg$site_kind))
    path <- checks_dir("decisions", paste0(slug, ".md"))

    #' Two names in one report are usually two facilities: a report listing
    #' both is a report distinguishing them.
    shared <- ev[, .(ids = uniqueN(facility_id)), by = sitrep][ids > 1, .N]

    l <- c(
        "`#ai-written`",
        "",
        sprintf("# %ss at %s", sub("^(.)", "\\U\\1", kind_label, perl = TRUE),
            gsub("\\b(.)", "\\U\\1", place, perl = TRUE)),
        "",
        sprintf("Cluster `%s`, rank %d of the review queue, %d events in the cluster.",
            sg$cluster, sg$rank, sg$events_in_cluster),
        sprintf("%d %ss to decide between.", nrow(members), kind_label),
        "",
        "## The question",
        "",
        sprintf("Are these %d one facility, or more than one?", nrow(members)),
        "",
        "| facility_id | name | aliases | reports | events | GRID3 | opening interval now |",
        "|---|---|---|---|---|---|---|")

    for (j in seq_len(nrow(members))) {
        m <- members[j]
        o <- now[facility_id == m$facility_id]
        l <- c(l, sprintf("| `%s` | %s | %s | %d | %d | %s | %s |",
            m$facility_id, m$facility_name,
            gsub("\\|", "/", m$aliases), m$n_sitreps, m$n_events,
            grid3_note(m$facility_id),
            if (nrow(o)) interval_of(o$opened_after[1], o$opened_by[1]) else "not in the opening table"))
    }

    l <- c(l, "",
        if (shared > 0) {
            sprintf(paste("%d report%s name more than one of them. A report",
                "naming both is a report telling them apart, so a merge needs",
                "a reason."), shared, if (shared == 1) "" else "s")
        } else {
            "No report names two of them, which is what a spelling variant looks like."
        },
        "",
        "## What merging would do",
        "",
        sprintf("Merged, the opening interval becomes %s.",
            interval_of(merged$after, merged$by)),
        "")

    for (j in seq_len(nrow(members))) {
        o <- now[facility_id == members$facility_id[j]]
        if (!nrow(o)) next
        l <- c(l, sprintf("- `%s`: %s becomes %s.", members$facility_id[j],
            interval_of(o$opened_after[1], o$opened_by[1]),
            interval_of(merged$after, merged$by)))
    }

    l <- c(l, "", "## The quotes", "")
    for (j in seq_len(nrow(members))) {
        m <- members[j]
        q <- pick_quotes(ev[facility_id == m$facility_id])
        l <- c(l, sprintf("### `%s`", m$facility_id), "")
        for (k in seq_len(nrow(q))) {
            l <- c(l, sprintf("- SitRep %s, %s, `%s`: %s", q$sitrep[k],
                q$report_date[k], q$event[k], q$evidence_quote[k]))
        }
        l <- c(l, "")
    }

    l <- c(l,
        "## Deciding",
        "",
        "One facility: give every row of these names one `facility_id` in",
        "`registry/facility_aliases.csv`, keeping the id already carrying the most",
        "events, and set `reviewed = TRUE` on each. More than one: leave the ids",
        "apart and set `reviewed = TRUE` anyway, so the flag stops being raised.",
        "Put the reason in `note` either way.",
        "",
        "Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.",
        "",
        "Decision:",
        "",
        "Reason:",
        "")

    writeLines(l, path)
    index[[i]] <- data.table(rank = sg$rank, cluster = sg$cluster,
        site_kind = sg$site_kind, facilities = nrow(members),
        events = sum(members$n_events), same_report = shared,
        now = paste(unique(vapply(seq_len(nrow(now)), function(z)
            interval_of(now$opened_after[z], now$opened_by[z]), character(1))),
            collapse = " / "),
        if_merged = interval_of(merged$after, merged$by),
        sheet = basename(path))
}

idx <- rbindlist(index)
setorder(idx, rank)
fwrite(idx, checks_dir("decisions", "index.csv"))

# ----------------------------------------------------------------- report

message(nrow(idx), " decision sheets in ", checks_dir("decisions"), ".\n")
print(idx[, .(rank, cluster, kind = sub("_centre", "", site_kind),
    facilities, events, same_report)])
message("\nDecisions where no report names two of them (spelling, quickest): ",
    idx[same_report == 0, .N])
message("Decisions where a report names two (a reason is needed to merge): ",
    idx[same_report > 0, .N])
