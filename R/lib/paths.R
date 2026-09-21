#' Where everything lives.
#'
#' This repository reads the INSP situation reports only through the corpus
#' that bvd-sitreps publishes, and finds it by path. Nothing here opens a PDF,
#' and nothing sources code from bvd-sitreps: a change there reaches this
#' repository as changed files in the corpus, which the cache keys below see,
#' never as changed behaviour. If a question cannot be answered from
#' `data/corpus/`, the fix belongs in bvd-sitreps.
#'
#' `BVD_SITREPS` points at a bvd-sitreps checkout; the default is a sibling
#' clone.

sitreps_root <- function() {
    Sys.getenv("BVD_SITREPS",
        unset = file.path(dirname(here::here()), "bvd-sitreps"))
}

corpus_dir <- function(...) file.path(sitreps_root(), "data", "corpus", ...)

sitreps_manifest_path <- function() {
    file.path(sitreps_root(), "data", "manifest.csv")
}

#' One model reading per report. Committed, because each costs a model call
#' to remake.
cache_dir <- function(...) here::here("data", "cache", ...)

registry_path <- function() here::here("registry", "facility_aliases.csv")

events_path <- function() here::here("data", "facility_events.csv")

facilities_path <- function() here::here("data", "facilities.csv")

rejected_path <- function() here::here("outputs", "rejected_events.csv")

ensure_dirs <- function() {
    for (d in c(cache_dir(), dirname(registry_path()), here::here("outputs", "logs"))) {
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }
    invisible(NULL)
}
