#!/usr/bin/env Rscript
# ai-written
#'
#' Named health facilities in the six outbreak provinces, from OpenStreetMap.
#'
#' A third register, after INSP's own reports and GRID3's national list. It
#' matters here because it is built by different people with different habits:
#' GRID3 records a facility under the name a ministry holds, OSM under the
#' name written on the building. `Centre Médical Évangélique` at Bunia appears
#' in OSM and not in GRID3, which is exactly the kind of gap that decides
#' whether `CTE CME` means Bunia or Rwampara.
#'
#' OpenStreetMap data is © OpenStreetMap contributors, ODbL 1.0. The extract
#' written here is a derived database under that licence, not under this
#' repository's MIT licence; `data/reference/LICENCE.md` says so.
#'
#' Rerun when the question needs it, not on a schedule: Overpass is a shared
#' public service and this asks it six large questions.
#'
#' Usage:
#'     Rscript tools/osm-places.R

suppressMessages({
    library(data.table)
    library(jsonlite)
})
source(here::here("R", "lib", "paths.R"))

PROVINCES <- c("Ituri", "Nord-Kivu", "Sud-Kivu", "Tshopo", "Haut-Uele", "Bas-Uele")

#' Overpass refuses a request with no user agent, and asks that one name the
#' caller. Kept polite and identifiable.
UA <- "bvd-capacity/0.1 (research; github.com/epiforecasts/bvd-capacity)"

#' Overpass answers a big province with 429 (slow down) or 504 (gateway
#' timeout) often enough that one attempt each leaves holes: Nord-Kivu and
#' Tshopo, the two provinces this outbreak is largest in, both failed on the
#' first run. Backing off and asking again is the whole fix.
overpass <- function(query, timeout = 180L, attempts = 4L) {
    for (attempt in seq_len(attempts)) {
        tmp <- tempfile(fileext = ".json")
        code <- system2("curl", c("-s", "--max-time", timeout,
            "-A", shQuote(UA), "-o", shQuote(tmp), "-w", "%{http_code}",
            "-X", "POST", "https://overpass-api.de/api/interpreter",
            "--data", shQuote(paste0("data=", query))), stdout = TRUE)
        if (identical(tail(code, 1), "200")) {
            on.exit(unlink(tmp), add = TRUE)
            return(fromJSON(tmp, simplifyVector = FALSE)$elements)
        }
        unlink(tmp)
        if (attempt < attempts) {
            wait <- 30L * attempt
            message("    HTTP ", tail(code, 1), ", retrying in ", wait, "s")
            Sys.sleep(wait)
        } else {
            stop("Overpass returned ", paste(code, collapse = " "),
                " after ", attempts, " attempts")
        }
    }
}

#' Province boundaries are admin_level 4 in the Democratic Republic of the
#' Congo. A facility with no name cannot be matched to a report and is left
#' out; the point here is the vocabulary, not the map.
province_query <- function(name) {
    sprintf(paste0('[out:json][timeout:120];',
        'area["name"="%s"]["admin_level"="4"]->.a;',
        '(node["amenity"~"^(hospital|clinic|doctors)$"]["name"](area.a);',
        'way["amenity"~"^(hospital|clinic|doctors)$"]["name"](area.a););',
        'out center;'), name)
}

#' A province already in the file is not asked for again, so a rerun after a
#' failure costs only the provinces that failed. Pass --force to refetch all.
path <- here::here("data", "reference", "osm_places.csv")
FORCE <- "--force" %in% commandArgs(trailingOnly = TRUE)
have <- if (file.exists(path) && !FORCE) fread(path) else NULL
rows <- if (!is.null(have)) list(have) else list()
todo <- if (is.null(have)) PROVINCES else setdiff(PROVINCES, unique(have$province))
if (!length(todo)) message("All six provinces already held; --force to refetch.")
for (p in todo) {
    els <- tryCatch(overpass(province_query(p)), error = function(e) {
        message("  ", p, ": ", conditionMessage(e)); NULL
    })
    if (is.null(els)) next
    dt <- rbindlist(lapply(els, function(e) {
        tags <- e$tags %||% list()
        centre <- e$center %||% list(lat = e$lat, lon = e$lon)
        data.table(
            province = p,
            osm_type = e$type,
            osm_id = as.character(e$id),
            name = tags$name %||% "",
            amenity = tags$amenity %||% "",
            healthcare = tags$healthcare %||% "",
            operator = tags$operator %||% "",
            lat = as.numeric(centre$lat %||% NA),
            lon = as.numeric(centre$lon %||% NA))
    }), fill = TRUE)
    message(sprintf("  %-10s %4d named health facilities", p, nrow(dt)))
    rows[[length(rows) + 1L]] <- dt
    Sys.sleep(2)
}

out <- rbindlist(rows, fill = TRUE)
out <- unique(out[nzchar(name)])
setorder(out, province, name)
fwrite(out, path)

licence <- here::here("data", "reference", "LICENCE.md")
if (!file.exists(licence)) {
    writeLines(c(
        "`#ai-written`",
        "",
        "# Reference vocabularies in this directory",
        "",
        "Neither file is the work of this repository's authors, and the MIT",
        "licence at the root does not cover them.",
        "",
        "## grid3_places.csv",
        "",
        "GRID3 COD Health Facilities v8.0. CIESIN, Columbia University;",
        "Ministère de la Santé Publique, Hygiène et Prévention, DRC; GRID3.",
        "CC BY 4.0. DOI 10.7916/f1ft-y872.",
        "",
        "## osm_places.csv",
        "",
        "© OpenStreetMap contributors, ODbL 1.0. A derived database extracted",
        "through the Overpass API: named facilities tagged hospital, clinic or",
        "doctors in the six outbreak provinces. Share alike.",
        "<https://www.openstreetmap.org/copyright>"), licence)
}

message("\n", nrow(out), " facilities written to ", path)
print(out[, .N, keyby = .(province, amenity)][order(province, -N)])
