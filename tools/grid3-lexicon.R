#!/usr/bin/env Rscript
# ai-written
#'
#' Build data/reference/grid3_places.csv from GRID3 COD Health Facilities v8.0.
#'
#' Run once, by hand, when the GRID3 release changes. The output is committed
#' so nothing in the pipeline needs `sf`, a path into BDBV2026-Data, or a
#' 66MB shapefile, and so the reference a row was checked against is in the
#' history beside the row.
#'
#' Source: GRID3 COD Health Facilities v8.0, CIESIN Columbia University and
#' the DRC Ministere de la Sante Publique, Hygiene et Prevention, 2025.
#' https://doi.org/10.7916/f1ft-y872. CC BY 4.0.
#'
#' Trimmed to the six provinces the outbreak reaches and to the columns a
#' name lookup needs. Geometry is dropped.
#'
#' Usage:
#'     Rscript tools/grid3-lexicon.R [--bdbv=DIR]

suppressMessages({
    library(sf)
    library(data.table)
})

args <- commandArgs(trailingOnly = TRUE)
bdbv <- sub("^--bdbv=", "", grep("^--bdbv=", args, value = TRUE)[1])
if (is.na(bdbv)) {
    bdbv <- file.path(dirname(here::here()), "BDBV2026-Data")
}
zip <- Sys.glob(file.path(bdbv, "data", "grid3_healthsites", "raw",
    "COD_GRID3_health_facilities_v8_0_*.zip"))
if (!length(zip)) stop("GRID3 zip not found under ", bdbv)

PROVINCES <- c("Ituri", "Nord-Kivu", "Sud-Kivu", "Haut-Uele", "Bas-Uele",
    "Tshopo")

tmp <- file.path(tempdir(), "grid3")
dir.create(tmp, showWarnings = FALSE)
unzip(zip[1], exdir = tmp)
shp <- Sys.glob(file.path(tmp, "*.shp"))[1]
d <- as.data.table(st_drop_geometry(st_read(shp, quiet = TRUE)))

d <- d[province %in% PROVINCES]
out <- d[, .(province, health_zone = zonesante, health_area = airesante,
    locality = localite, facility_type = esstype, facility_name = essnom2,
    grid3id)]
out <- unique(out[!is.na(facility_name) & nzchar(facility_name)])
setorder(out, province, health_zone, health_area, facility_name)
fwrite(out, here::here("data", "reference", "grid3_places.csv"))

message("Wrote ", nrow(out), " facilities in ", uniqueN(out$health_zone),
    " health zones across ", uniqueN(out$province), " provinces.")
print(out[, .N, by = province][order(-N)])
