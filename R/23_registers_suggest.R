#!/usr/bin/env Rscript
# ai-written
#'
#' Ask the other registers what they know about each open naming question.
#'
#' GRID3's health facility list is a national register: it knows which
#' hospital is a health zone's reference hospital, which health areas sit
#' inside which zone, and which names exist as facilities in their own right.
#' Three of those facts bear directly on whether two names in the INSP reports
#' are one site:
#'
#'   `reference_hospital`  one name is the reference hospital of the health
#'                         zone the other names, so the pair is probably one
#'                         site under two names (Butembo and Kitatumba)
#'   `area_in_zone`        one name is a health area inside the other's zone,
#'                         which places the two together without making them
#'                         one facility
#'   `both_registered`     both names exist as separate GRID3 facilities in
#'                         one zone, which is evidence for keeping them apart
#'
#' OpenStreetMap answers a fourth question, `named_in_osm`: does a facility of
#' this name exist on the map, and where. OSM and GRID3 are built by different
#' people with different habits, so the two disagree usefully. GRID3 holds no
#' CME at Bunia; OSM maps one. That widens the question rather than settling
#' it, which is the right outcome for a name the reports leave ambiguous.
#'
#' A suggestion is not a decision and this script writes none. It writes
#' `checks/register_suggestions.csv`, which `R/08_decisions.R` prints on the
#' sheet, so the person answering sees what the national register says next to
#' what the reports say. GRID3 constrains, it never overrides: where the two
#' disagree, the reports are what the dataset records.
#'
#' Usage:
#'     Rscript R/23_registers_suggest.R

suppressMessages({
    library(data.table)
})
source(here::here("R", "lib", "paths.R"))
source(here::here("R", "lib", "places.R"))

`%||%` <- function(a, b) if (is.null(a)) b else a

KINDS <- c("treatment_centre", "transit_centre", "isolation_centre")

grid3 <- fread(grid3_path())
osm_path <- here::here("data", "reference", "osm_places.csv")
osm <- if (file.exists(osm_path)) fread(osm_path) else NULL
queue <- fread(review_queue_path())
facilities <- fread(facilities_path())
flag_long <- fread(flags_path())

#' The same folding R/lib/places.R uses, so a GRID3 name and a register name
#' meet on the same footing.
fold <- function(x) {
    x <- iconv(x, "UTF-8", "ASCII//TRANSLIT")
    x <- gsub("['`^~\"]", "", x)
    x <- tolower(trimws(gsub("[^A-Za-z0-9]+", " ", x)))
    trimws(gsub(" +", " ", x))
}

grid3[, `:=`(zone_key = fold(health_zone), area_key = fold(health_area),
    name_key3 = fold(facility_name))]

REFERENCE <- grid3[grepl("Référence|Reference|Général|General", facility_type),
    .(zone_key, name_key3, facility_type, grid3id)]

#' A health zone's administrative office carries the zone's name and is not a
#' place anyone is treated. Left in, it pairs every centre named after its
#' town with every other, which is how `cte-bunia` and `cte-elikya` arrived as
#' one question.
ADMIN <- "Bureau Central|Bureau de la Zone|Inspection"
treats <- grid3[!grepl(ADMIN, facility_type)]

#' What a host abbreviation is written out as in a national register. INSP
#' writes `CME`; GRID3 writes `Evangelique` under the type `Centre Médical`.
#' Without this the abbreviation matches nothing, or matches `Cmel` in Basoko.
HOST_SPELLINGS <- list(
    cme = c("cme", "evangelique", "centre medical evangelique"),
    istm = c("istm", "institut superieur des techniques medicales"),
    ist = c("ist", "istm"),
    fomulac = c("fomulac"))

#' The register's own keys, minus type words, so `cte-butembo` meets GRID3's
#' `Butembo` and `cte-kitatumba` meets its `Kitatumba`.
bare <- function(id, name) {
    x <- fold(name)
    x <- gsub("^(cte|ctc|ct|ci|hgr|ch|cs|cme|istm|hosp|hopital|clinique)\\b", "", x)
    x <- gsub("\\b(centre|traitement|ebola|transit|isolement|isolation|de|du|des|la|le|les|a|au|aux|zs|zone|sante)\\b", " ", x)
    trimws(gsub(" +", " ", x))
}

facilities[, key3 := bare(facility_id, facility_name)]

if (!"settled" %in% names(queue)) queue[, settled := ""]
queue[, etc_cluster := any(site_kind %in% KINDS), by = cluster]
open_groups <- queue[etc_cluster == TRUE & site_kind %in% KINDS & settled == "",
    .(n = .N), by = .(cluster, site_kind)][n > 1]

suggest <- list()
note <- function(...) suggest[[length(suggest) + 1L]] <<- data.table(...)

for (i in seq_len(nrow(open_groups))) {
    g <- open_groups[i]
    mem <- merge(queue[cluster == g$cluster & site_kind == g$site_kind,
        .(facility_id)], facilities[, .(facility_id, facility_name, key3,
        health_zone, place_key)], by = "facility_id")
    if (nrow(mem) < 2L) next

    for (a in seq_len(nrow(mem))) for (b in seq_len(nrow(mem))) {
        if (a >= b) next
        ka <- mem$key3[a]; kb <- mem$key3[b]
        if (!nzchar(ka) || !nzchar(kb)) next

        #' Is one the reference hospital of the zone the other names?
        hit <- REFERENCE[(zone_key == ka & name_key3 == kb) |
            (zone_key == kb & name_key3 == ka)]
        if (nrow(hit)) {
            note(cluster = g$cluster, site_kind = g$site_kind,
                facility_a = mem$facility_id[a], facility_b = mem$facility_id[b],
                source = "grid3", finding = "reference_hospital", leans = "same",
                detail = sprintf("GRID3 names %s the %s of %s health zone",
                    hit$name_key3[1], hit$facility_type[1], hit$zone_key[1]),
                grid3id = hit$grid3id[1])
            next
        }

        #' Is one a health area inside the other's zone?
        area <- unique(grid3[(zone_key == ka & area_key == kb) |
            (zone_key == kb & area_key == ka), .(zone_key, area_key)])
        if (nrow(area)) {
            note(cluster = g$cluster, site_kind = g$site_kind,
                facility_a = mem$facility_id[a], facility_b = mem$facility_id[b],
                source = "grid3", finding = "area_in_zone", leans = "same place",
                detail = sprintf("GRID3 puts health area %s inside %s health zone",
                    area$area_key[1], area$zone_key[1]),
                grid3id = "")
            next
        }

        #' Do both exist as facilities of their own in one zone? Only when
        #' the two keys differ: a pair that folds to one key is a spelling or
        #' a host variant, and matching it against itself reports whichever
        #' zone happens to hold two facilities of that name.
        both <- if (identical(ka, kb)) data.table() else merge(
            treats[name_key3 == ka, .(zone_key, a_type = facility_type, a_id = grid3id)],
            treats[name_key3 == kb, .(zone_key, b_type = facility_type, b_id = grid3id)],
            by = "zone_key")[a_id != b_id]
        if (nrow(both)) {
            note(cluster = g$cluster, site_kind = g$site_kind,
                facility_a = mem$facility_id[a], facility_b = mem$facility_id[b],
                source = "grid3", finding = "both_registered", leans = "apart",
                detail = sprintf("GRID3 lists both in %s zone: %s and %s",
                    both$zone_key[1], both$a_type[1], both$b_type[1]),
                grid3id = "")
        }
    }
}

#' The names carrying no town get the same treatment, one to many: where does
#' GRID3 say a facility of that name exists at all?
mp <- flag_long[flag == "possible_missing_place"]
for (g in unique(mp$group)) {
    ids <- mp[group == g, unique(facility_id)]
    fac <- facilities[facility_id %in% ids][order(nchar(facility_name))]
    host <- bare(fac$facility_id[1], fac$facility_name[1])
    if (!nzchar(host)) host <- fold(fac$facility_name[1])
    spellings <- HOST_SPELLINGS[[host]] %||% host
    pattern <- paste0("\\b(", paste(spellings, collapse = "|"), ")\\b")
    where <- unique(treats[grepl(pattern, name_key3, perl = TRUE),
        .(province, health_zone, facility_name, facility_type)])
    if (!nrow(where)) next
    note(cluster = fac$facility_id[1], site_kind = fac$site_kind[1],
        facility_a = fac$facility_id[1], facility_b = "",
        source = "grid3", finding = "host_registered_at", leans = "narrows the candidates",
        detail = paste(sprintf("%s (%s, %s)", where$facility_name,
            where$health_zone, where$facility_type), collapse = "; "),
        grid3id = "")
}

#' The same question put to OpenStreetMap, which names buildings rather than
#' registrations, and so holds facilities a ministry list does not.
if (!is.null(osm)) {
    osm[, osm_key := fold(name)]
    for (g in unique(mp$group)) {
        ids <- mp[group == g, unique(facility_id)]
        fac <- facilities[facility_id %in% ids][order(nchar(facility_name))]
        host <- bare(fac$facility_id[1], fac$facility_name[1])
        if (!nzchar(host)) host <- fold(fac$facility_name[1])
        spellings <- HOST_SPELLINGS[[host]] %||% host
        pattern <- paste0("\\b(", paste(spellings, collapse = "|"), ")\\b")
        hit <- unique(osm[grepl(pattern, osm_key, perl = TRUE),
            .(province, name, amenity)])
        if (!nrow(hit)) next
        note(cluster = fac$facility_id[1], site_kind = fac$site_kind[1],
            facility_a = fac$facility_id[1], facility_b = "",
            source = "osm", finding = "named_in_osm",
            leans = "narrows the candidates",
            detail = paste(sprintf("%s (%s, %s)", hit$name, hit$province,
                hit$amenity), collapse = "; "),
            grid3id = "")
    }
}

out <- if (length(suggest)) rbindlist(suggest) else data.table(
    cluster = character(), site_kind = character(), facility_a = character(),
    facility_b = character(), source = character(),
    finding = character(), leans = character(),
    detail = character(), grid3id = character())
fwrite(out, checks_dir("register_suggestions.csv"))

# ----------------------------------------------------------------- report

message(nrow(out), " suggestions over ", uniqueN(out$cluster), " questions.\n")
if (nrow(out)) print(out[, .N, keyby = .(source, finding, leans)])
for (i in seq_len(nrow(out))) {
    message(sprintf("  %-22s %s %s %s: %s", out$cluster[i], out$facility_a[i],
        if (nzchar(out$facility_b[i])) "vs" else "", out$facility_b[i],
        out$detail[i]))
}
message("\nWritten: ", checks_dir("register_suggestions.csv"))
