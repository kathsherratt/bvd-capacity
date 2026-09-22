#!/usr/bin/env Rscript
# ai-written
#'
#' Check the register's places against GRID3, and say what GRID3 does not know.
#'
#' A facility GRID3 has never heard of is not necessarily wrong. The Ebola
#' response built structures that no national register lists, and GRID3 v8.0
#' predates the outbreak. But a name GRID3 does recognise is a name two
#' independent sources agree on, which is a check the quote gate cannot make:
#' the gate proves the model copied the report, not that the report's facility
#' is real.
#'
#' Writes checks/place_check.csv, one row a facility. Nothing is changed.
#'
#' Usage:
#'     Rscript R/05_places.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "places.R"))

fold <- function(x) {
    x <- gsub("['’‘`´]", " ", x, perl = TRUE)
    x <- iconv(x, "UTF-8", "ASCII//TRANSLIT", sub = " ")
    x[is.na(x)] <- ""
    x <- gsub("[`'^~\"]", "", x, perl = TRUE)
    x <- gsub("[^a-z0-9]+", " ", tolower(x), perl = TRUE)
    trimws(gsub("\\s+", " ", x, perl = TRUE))
}

facilities <- fread(facilities_path())
grid3 <- grid3_places(fold)

#' The name as the reports write it, and the name with the kind of centre
#' taken off, are both tried: GRID3 lists `Elikya`, the reports write
#' `CTE Elikya` and `CH ELIKYA`.
facilities[, name_fold := fold(facility_name)]
facilities[, place_fold := fold(place_key)]

names_in_zone <- unique(grid3[, .(health_zone, name_key, facility_type)])
places_known <- unique(c(grid3$zone_key, grid3$area_key, grid3$locality_key,
    grid3$name_key))
places_known <- places_known[nzchar(places_known)]

facilities[, place_known := place_fold %in% places_known]
facilities[, name_known := name_fold %in% grid3$name_key]

#' The strongest form: GRID3 lists this name inside the health zone the
#' register puts it in. A national name match can be a coincidence between
#' two provinces; a within-zone match cannot.
in_zone <- merge(facilities[, .(facility_id, health_zone, name_fold)],
    names_in_zone, by.x = c("health_zone", "name_fold"),
    by.y = c("health_zone", "name_key"))
facilities[, confirmed_in_zone := facility_id %in% in_zone$facility_id]
#' A name can match several GRID3 records in one zone, a health centre and a
#' clinic of the same name. Collapse them, or the register grows rows here.
types <- in_zone[, .(grid3_type = paste(sort(unique(facility_type)),
    collapse = "; ")), by = facility_id]
facilities <- merge(facilities, types, by = "facility_id", all.x = TRUE)

out <- facilities[, .(facility_id, facility_name, site_kind, place_key,
    health_zone, province, n_sitreps, n_events, confirmed_in_zone,
    name_known, place_known, grid3_type, flags)]
setorder(out, -confirmed_in_zone, -n_events)
dir.create(checks_dir(), showWarnings = FALSE, recursive = TRUE)
fwrite(out, place_check_path())

# ----------------------------------------------------------------- report

message("Checked ", nrow(facilities), " facilities against GRID3 COD Health ",
    "Facilities v8.0.\n")
print(facilities[, .(
    facilities = .N,
    confirmed_in_zone = sum(confirmed_in_zone),
    name_known_elsewhere = sum(name_known & !confirmed_in_zone),
    place_known_only = sum(!name_known & place_known),
    unknown = sum(!name_known & !place_known)
), by = site_kind][order(-facilities)])

message("\nUnknown to GRID3, by how much the register leans on them:")
print(facilities[!name_known & !place_known][order(-n_events)][
    seq_len(min(15, .N)), .(facility_id, site_kind, n_sitreps, n_events)])

message("\nWritten: ", place_check_path())
