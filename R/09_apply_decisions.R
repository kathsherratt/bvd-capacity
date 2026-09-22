#!/usr/bin/env Rscript
# ai-written
#'
#' Apply the naming decisions a person made to the name vocabulary.
#'
#' `registry/decisions.csv` is the record of who decided what and when.
#' `registry/facility_aliases.csv` is what the pipeline reads. This script
#' carries one into the other, so a decision is written down once, in the
#' file that says who made it, rather than edited into a vocabulary of 800
#' rows where the reasoning is lost.
#'
#' `same` gives every name in the group the `merged_into` id and marks the
#' rows reviewed. `apart` leaves the ids alone and marks them reviewed, which
#' is a decision too: it stops the flag being raised again. `unsure` touches
#' nothing, so the facilities stay separate and stay flagged.
#'
#' Rerunning is safe, and rerunning after `R/02_resolve.R` has appended new
#' spellings is the point: a spelling the corpus grows later lands in the
#' group its name key belongs to and is marked reviewed with the rest.
#'
#' Decisions are applied in file order, so a decision that assumes an earlier
#' one is written after it: the spelling merges at Nyankunde and Mongbwalu
#' collapse the variants, and the `apart` row that follows ranges over what is
#' left. Rerunning is then a no-op rather than a contradiction, because an id
#' already folded into another reads as absent, not as a changed question.
#'
#' A decision does not silently outlive its evidence. `same` needs its
#' `merged_into` id to exist; `apart` needs at least two of its ids to exist,
#' since a decision to keep one facility apart from nothing is not a decision.
#' A row that fails either test is reported and skipped.
#'
#' Usage:
#'     Rscript R/09_apply_decisions.R [--dry-run]

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))

DRY <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)

decisions <- fread(decisions_path(), colClasses = "character")
registry <- fread(registry_path(), colClasses = "character")

stopifnot(all(c("decision_id", "verdict", "facility_ids", "merged_into") %in%
    names(decisions)))
bad <- decisions[!verdict %in% c("same", "apart", "unsure")]
if (nrow(bad)) {
    stop("verdict must be same, apart or unsure: ", paste(bad$decision_id, collapse = ", "))
}

applied <- 0L
skipped <- character()
touched <- 0L

for (i in seq_len(nrow(decisions))) {
    d <- decisions[i]
    ids <- sort(trimws(strsplit(d$facility_ids, ";")[[1]]))
    if (d$verdict == "unsure") next

    held <- sort(unique(registry[facility_id %in% ids, facility_id]))

    if (d$verdict == "same") {
        if (!nzchar(d$merged_into)) {
            skipped <- c(skipped, paste0(d$decision_id, " (same, but no merged_into)"))
            next
        }
        if (!d$merged_into %in% held) {
            skipped <- c(skipped, sprintf("%s (same, but %s is not in the register)",
                d$decision_id, d$merged_into))
            next
        }
    } else if (length(held) < 2L) {
        skipped <- c(skipped, sprintf("%s (apart, but the register holds %s of %s)",
            d$decision_id, if (length(held)) paste(held, collapse = ";") else "none",
            paste(ids, collapse = ";")))
        next
    }

    rows <- registry$facility_id %in% held
    if (d$verdict == "same") registry[rows, facility_id := d$merged_into]
    registry[rows, reviewed := "TRUE"]
    registry[rows, note := sprintf("decision %s: %s%s", d$decision_id, d$verdict,
        if (nzchar(d$note)) paste0(", ", d$note) else "")]
    applied <- applied + 1L
    touched <- touched + sum(rows)
}

if (!DRY) fwrite(registry, registry_path())

# ----------------------------------------------------------------- report

message(applied, " decisions applied over ", touched, " registry rows",
    if (DRY) " (dry run, nothing written)" else "", ".")
message(decisions[verdict == "unsure", .N], " left unsure, still flagged.")
if (length(skipped)) {
    message("\nSkipped, because the register no longer holds that group:")
    for (s in skipped) message("  - ", s)
}
open_q <- decisions[nzchar(open_question)]
if (nrow(open_q)) {
    message("\nStill open inside a group decided apart, one name per pair:")
    for (i in seq_len(nrow(open_q))) {
        message("  - ", open_q$decision_id[i], ": ", open_q$open_question[i])
    }
}
message("\nReviewed rows in the registry: ",
    registry[reviewed == "TRUE", .N], " of ", nrow(registry))
