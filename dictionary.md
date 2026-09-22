`#ai-written`

# Column definitions

Four tables. `facility_events.csv` is what the reports say,
`facilities.csv` is what follows from it, `facility_aliases.csv` is the name
vocabulary that joins them, and `facility_flags.csv` records which facilities
a flag put together.

An empty string and `NA` both mean the report did not say. Neither means zero.

## data/facility_events.csv

One row for each thing one report says about one facility. 1,885 rows.

| column | meaning |
|---|---|
| `sitrep` | report id, as the corpus names it (`006_v2` is the reissue of 006) |
| `report_date` | the report's own date, from the corpus, never from the model |
| `facility_id` | the facility this resolved to, empty where it did not resolve |
| `facility_raw` | the facility as the report writes it, unaltered |
| `name_status` | `named`, `unnamed` or `ambiguous`; only `named` rows resolve |
| `site_kind` | `treatment_centre`, `transit_centre`, `isolation_centre`, `hospital_isolation` or `other` |
| `place_key` | the locality, with every word naming a kind of building removed |
| `place_raw` | the place as the report writes it |
| `event` | one of the nine values below |
| `event_date` | a date the report itself gives for the event; empty in all but three rows |
| `beds` | bed count as an integer, where the report gives one |
| `health_zone` | health zone, where the report gives one |
| `province` | province, where the report gives one; spellings are not yet normalised |
| `status_note` | a short note the model took from the text |
| `evidence_quote` | the French sentence this row came from, verified character for character against the report |
| `confidence` | `high` or `low`, the model's own |
| `model` | which model read the report |

### event

The vocabulary is closed. `R/03_checks.R` fails on any other value.

| value | what the report has to say |
|---|---|
| `planned` | a facility is intended |
| `under_construction` | building or fitting out is under way |
| `opened` | an opening is announced or has just happened |
| `operating` | Ebola patients are at the facility |
| `expanded` | capacity was added |
| `strained` | saturated, over capacity, or short of something needed to run |
| `incident` | an attack, a closure threat, a breakdown, a stock-out |
| `closed` | the facility stopped taking patients |
| `mention_only` | the report names the place without saying patients were there: a decontamination, a supply delivery, a supervision visit |

`operating`, `expanded`, `strained` and `incident` are the four that show a
facility in service. `date_first_in_service` is the first report date carrying
any of them.

The distinction that does most work here is between `operating` and
`mention_only`. Work done at a building is not the same as patients being in
it, and the reports describe far more of the first than the second.

## data/facilities.csv

One row a facility. 620 rows. Every column is derived from that facility's
events and nothing else, and `R/03_checks.R` recomputes all of them by a
second implementation.

| column | meaning |
|---|---|
| `facility_id` | `<kind prefix>-<name key>`: `cte`, `ct`, `ci`, `hosp` or `site` |
| `facility_name` | the commonest spelling among its events |
| `site_kind` | the kind the id asserts, taken from the registry |
| `place_key` | the locality |
| `health_zone`, `province` | the commonest value among its events |
| `date_first_mentioned` | earliest report date of any event |
| `sitrep_first_mentioned` | the report that date came from |
| `first_mention_after_gap` | TRUE where the SitRep before the first mention was never published, so the true first mention may be unrecoverable |
| `date_first_planned` | first report date of a `planned` or `under_construction` event |
| `date_opening_announced` | first report date of an `opened` event |
| `sitrep_opening_announced` | the report that date came from |
| `date_opening_stated` | a date the report gives for the opening; empty for every facility, see README |
| `date_first_in_service` | first report date of an `operating`, `expanded`, `strained` or `incident` event |
| `status_latest` | the event of the latest report that said anything other than `mention_only` |
| `status_latest_date` | that report's date |
| `beds_latest` | the bed count from the latest report giving one |
| `beds_latest_date` | that report's date |
| `date_last_mentioned` | latest report date of any event |
| `n_sitreps` | reports mentioning it |
| `n_events` | rows in `facility_events.csv` |
| `aliases` | every spelling seen, semicolon separated |
| `flags` | open judgements, semicolon separated, see below |

## registry/facility_aliases.csv

One row a spelling. 795 rows. The only file meant to be edited by hand.

| column | meaning |
|---|---|
| `facility_raw` | the spelling, as it appears in a report |
| `name_key` | what identifies the facility: the kind of centre stripped out, the host hospital kept in |
| `place_key` | what identifies the locality: every word naming a kind of building stripped out |
| `site_kind` | the kind of site this spelling is taken to be |
| `facility_id` | the facility it resolves to |
| `reviewed` | TRUE where a person decided this row |
| `note` | free text |

`reviewed` is the whole point of the file. A row with `reviewed = FALSE` is a
guess `R/02_resolve.R` made and will remake, so a correction to the keys takes
effect without hand editing. A row with `reviewed = TRUE` is a decision and is
never recomputed. To merge two facilities, set both rows to the same
`facility_id` and mark them reviewed.

## data/facility_flags.csv

One row a facility a flag. 369 rows. `group` names the set a flag put
together, so `R/04_review.R` can reconstruct the clusters.

| flag | what it means |
|---|---|
| `possible_same_site` | one name, two kinds of site; a transit centre and a treatment centre can share a town |
| `possible_spelling_variant` | two names within an edit distance of two, same kind of site: Mongbwalu, Mungbwalu, Mongwalu |
| `possible_host_variant` | one name carries a host hospital and another does not: `CTE de l'HGR Bunia` against `CTE de Bunia` |
| `possible_word_order` | the same words in a different order: `hosp-hgr-bunia` against `hosp-bunia-hgr` |
| `possible_same_host` | GRID3 says these name the same health zone's reference hospital, whether by the zone (`cte-butembo`) or by the hospital's own name (`cte-kitatumba`) |

Nothing flagged is ever merged automatically. A flag says a person should
look, and `R/04_review.R` says in what order.

## data/organisations.csv

Who the reports name alongside a facility, one row an organisation, written
by `R/07_organisations.R`. A keyword scan over the corpus with no model call.

| column | meaning |
|---|---|
| `organisation` | the name as this script groups it; MSF covers MSF, MSF France and MSF Hollande |
| `type` | international NGO, UN agency, DRC government, Congolese hospital or institute, local contractor |
| `role_in_reports` | what the reports attribute to it, read from the quotes |
| `facility_sentences` | sentences naming both it and a facility |
| `reports` | how many reports those fall in |
| `first_sitrep`, `last_sitrep` | the range |
| `example_quote` | a verbatim sentence, a literal slice of the corpus |
| `corpus_md`, `source_pdf` | paths to that report inside a bvd-sitreps checkout |

A row says an organisation was named in a sentence that also mentions a
facility. That covers building a treatment centre and equally covers
delivering soap to one, so `facility_sentences` is an upper bound on
providing a facility. Read the quote before citing a row.

`type` separates two different things. An international NGO or UN agency is a
partner with its own records to ask for. A Congolese hospital or institute,
CME, ISTM, FOMULAC, is the building itself, and appears because the reports
name a facility by its host.

## data/reference/grid3_places.csv

GRID3 COD Health Facilities v8.0, trimmed to the six outbreak provinces and to
the columns a name lookup needs. 8,667 rows: `province`, `health_zone`,
`health_area`, `locality`, `facility_type`, `facility_name`, `grid3id`. Built
by `tools/grid3-lexicon.R`, committed, and read only by `R/lib/places.R`.

## outputs/place-check.csv

One row a facility, written by `R/05_places.R` and not committed.
`confirmed_in_zone` is TRUE where GRID3 lists that name inside that health
zone, which is the strong form; `name_known` allows a match anywhere in the
six provinces; `place_known` says only that the locality exists. `grid3_type`
is what GRID3 calls it. A facility unknown to GRID3 is not necessarily wrong,
since the response built structures no national register lists, but the list
is mostly misspellings: `cte-elykia` is unknown where `cte-elikya` is
confirmed.

## data/indicators.csv and data/indicator_appearances.csv

A survey of every label the situation report tables use, built from the tables
alone with no model call. Separate from the facility pipeline.

`indicator_appearances.csv` is one row a label an appearance: `sitrep`,
`report_date`, `table_n`, `caption`, `label_raw`, `kind`, `label_key`, `role`.

`indicators.csv` is one row a distinct label, with `n_appearances`,
`n_reports`, `first_sitrep`, `last_sitrep`, `first_date`, `last_date`,
`has_series` (in five or more reports), `still_reported`, a `cluster` of
near-identical labels, and `example_caption` and `example_raw` showing where
it appears. `role` separates an indicator from a dimension (a province, a
health zone) and from free text. `topic_suggested` is this script's guess;
`topic` is the column for a person to fill.
