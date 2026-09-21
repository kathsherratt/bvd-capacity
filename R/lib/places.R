# ai-written
#'
#' The canonical place vocabulary: GRID3's health zones, areas, localities and
#' facility names for the six provinces the outbreak reaches.
#'
#' The inference runs one way. What the report says constrains the lookup;
#' the lookup fills gaps and raises flags. It never overrides the report. The
#' reason is measurable: Amani, Gloria and Lobiko are facility names that
#' occur in several provinces, so an unconstrained match picks the wrong one
#' about twenty times in 345, and every one of those would have been a
#' facility silently moved to another province.
#'
#' Source: GRID3 COD Health Facilities v8.0, CIESIN Columbia University and
#' the DRC Ministere de la Sante Publique, Hygiene et Prevention, 2025.
#' https://doi.org/10.7916/f1ft-y872. CC BY 4.0. Rebuild the committed extract
#' with tools/grid3-lexicon.R.

#' Types GRID3 gives a health zone's reference hospital. A zone has one, which
#' is what makes `CTE de l'HGR Bunia` and `CTE de Bunia` the same centre.
REFERENCE_HOSPITAL <- "hopital general de reference"

#' Read once per session. `fold` has to be the same folding the keys use, so
#' it is passed in rather than defined twice.
grid3_places <- local({
    cached <- NULL
    function(fold) {
        if (!is.null(cached)) return(cached)
        d <- data.table::fread(grid3_path())
        d[, `:=`(
            zone_key = fold(health_zone),
            area_key = fold(health_area),
            locality_key = fold(locality),
            name_key = fold(facility_name),
            type_key = fold(facility_type),
            province_key = fold(province)
        )]
        cached <<- d
        d
    }
})

#' The canonical spelling of a province, or "" where the reported value
#' matches none of the six. Folding absorbs `Bas Uele` against `Bas-Uele` and
#' `Nord-kivu` against `Nord-Kivu`.
canonical_province <- function(x, fold) {
    d <- grid3_places(fold)
    lookup <- unique(d[, .(province_key, province)])
    out <- lookup$province[match(fold(x), lookup$province_key)]
    out[is.na(out)] <- ""
    out
}

#' Every way a place can be named, one row a name a zone, ranked so a coarser
#' unit wins: a zone name is shared by two zones far less often than a
#' facility name is.
place_lexicon <- local({
    cached <- NULL
    function(fold) {
        if (!is.null(cached)) return(cached)
        d <- grid3_places(fold)
        cols <- c("zone_key", "area_key", "locality_key", "name_key")
        lex <- data.table::rbindlist(lapply(seq_along(cols), function(i) {
            d[nzchar(get(cols[i])), .(key = get(cols[i]), rank = i,
                zone = health_zone, province, province_key)]
        }))
        cached <<- unique(lex)
        cached
    }
})

#' The health zone a place names, within a province, or "" where the answer is
#' not unique. An empty province searches all six and returns only an answer
#' unique across them.
resolve_zone <- function(place, province, fold) {
    lex <- place_lexicon(fold)
    q <- data.table::data.table(i = seq_along(place), key_ = fold(place),
        prov = fold(province))
    hits <- merge(q[nzchar(key_)], lex, by.x = "key_", by.y = "key",
        allow.cartesian = TRUE)
    hits <- hits[!nzchar(prov) | prov == province_key]
    #' With no province to constrain it, only a health zone's own name is
    #' trusted. Amani is a facility name in four zones and a locality in two
    #' more, and picking whichever is unique across the six provinces would
    #' put it in Karisimbi on no evidence.
    hits <- hits[nzchar(prov) | rank == 1L]
    hits <- hits[hits[, .I[rank == min(rank)], by = i]$V1]
    ans <- hits[, .(zone = if (data.table::uniqueN(zone) == 1L) zone[1] else ""),
        by = i]
    out <- rep("", length(place))
    out[ans$i] <- ans$zone

    #' A zone's name is not always the name the reports use for it. The INSP
    #' writes Kisangani; GRID3 calls the zone Makiso Kisangani. Where an exact
    #' match found nothing, the place is accepted as a whole word of exactly
    #' one zone name in the reported province. Whole word, not substring: Nia
    #' is a word of Nia Nia and should not also match Niangara.
    todo <- which(!nzchar(out) & nzchar(q$key_) & nzchar(q$prov))
    if (length(todo)) {
        zones <- unique(lex[rank == 1L, .(zone, province_key, key)])
        zones[, words := strsplit(key, " ", fixed = TRUE)]
        flat <- zones[, .(word = unlist(words)), by = .(zone, province_key)]
        for (i in todo) {
            cand <- flat[word == q$key_[i] & province_key == q$prov[i]]
            if (data.table::uniqueN(cand$zone) == 1L) out[i] <- cand$zone[1]
        }
    }
    out
}

#' The province of a health zone, or "" where two provinces share a zone name.
zone_province <- function(zone, fold) {
    d <- grid3_places(fold)
    lookup <- unique(d[, .(health_zone, province)])
    dup <- lookup[, .N, by = health_zone][N > 1L, health_zone]
    lookup <- lookup[!health_zone %in% dup]
    out <- lookup$province[match(zone, lookup$health_zone)]
    out[is.na(out)] <- ""
    out
}

#' For each health zone with exactly one reference hospital, the folded name
#' of that hospital. Butembo's is named Kitatumba, so a CTE at Kitatumba and a
#' CTE at Butembo are one centre, which no comparison of the two strings could
#' ever say.
zone_host_names <- function(fold) {
    d <- grid3_places(fold)
    hgr <- d[type_key == REFERENCE_HOSPITAL & nzchar(name_key)]
    one <- hgr[, .(n = data.table::uniqueN(name_key)), by = health_zone][n == 1L]
    unique(hgr[health_zone %in% one$health_zone,
        .(health_zone, host_key = name_key)])
}
