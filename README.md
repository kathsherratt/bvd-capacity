`#ai-input`

# bvd-capacity

When each Ebola treatment, transit and isolation facility appeared, opened and
came under strain during the 2026 Bundibugyo virus disease outbreak in the
Democratic Republic of the Congo, read from the INSP situation reports.

Every row carries the French sentence it came from, and that sentence is
checked against the report character for character before the row is kept.

| | |
|---|---|
| Source | INSP situation reports, via the verified corpus published by [bvd-sitreps](https://github.com/epiforecasts/bvd-sitreps) |
| Reports | 116, SitReps 001 to 122, 14 May to 13 September 2026 |
| Events | 1,885 |
| Facilities | 620 |
| Read by | `gemini-3.1-pro` at low thinking, one call a report |

## The three outputs

`data/facility_events.csv` is the observations: one row for each thing a
report says about a facility. A facility mentioned in forty reports has forty
or more rows, each with its own quote. This is the table to use for anything
that should respect what was known when.

`data/facilities.csv` is the register: one row a facility, with the dates
derived from its events. First mentioned, first planned, opening announced,
opening date as stated, first seen in service, latest status, latest bed
count.

`registry/facility_aliases.csv` is the name vocabulary: one row a spelling,
mapping it to a `facility_id`. It is the only file meant to be edited by hand.

Supporting: `data/facility_flags.csv` says which facilities each flag grouped
together. `data/reference/grid3_places.csv` is the canonical place vocabulary,
described below. `data/indicators.csv` and `data/indicator_appearances.csv` are a
separate survey of every label the situation report tables use, built without
a model call.

## Coverage

| kind of site | facilities | in 3+ reports | with an in-service date |
|---|---|---|---|
| treatment centre | 81 | 52 | 68 |
| hospital isolation | 83 | 22 | 81 |
| transit centre | 40 | 12 | 35 |
| isolation centre | 27 | 5 | 10 |
| other | 389 | 40 | 13 |

`other` is a health facility the response touched without the report saying it
held Ebola patients: a decontamination, a supply delivery, a supervision
visit. Most appear once. They are kept because a later pass over the same
corpus will want them, and because deciding they are irrelevant is not the
extraction step's job.

Of 1,885 events, 1,595 resolve to a named facility. The remaining 290 are
places the report described without naming, kept with their place and their
quote so a person can attach them later, and absent from `facilities.csv`.

## The canonical place vocabulary

`data/reference/grid3_places.csv` holds GRID3 COD Health Facilities v8.0 for
the six provinces the outbreak reaches: 8,667 facilities with province, health
zone, health area, locality, name and type. Rebuild it with
`tools/grid3-lexicon.R`, which needs a BDBV2026-Data checkout and `sf`;
nothing else in the pipeline needs either.

It does three things.

It respells `province` to one of six canonical values, which removes the
`Bas Uele` and `Nord-kivu` variants the reports contain.

It fills a health zone or province the report left out, 901 zones and 332
provinces, and only where the place names exactly one zone inside the province
the report already gave. Where the report gave a province or zone, GRID3 never
overrides it. That direction is not cosmetic: names like Amani and Gloria
belong to facilities in several provinces, so an unconstrained lookup silently
moves facilities between them.

It says which health zone's reference hospital carries which name. A zone has
one, so `CTE de l'HGR Bunia` and `CTE de Bunia` are the same centre while
`CTE de l'HGR Rwampara` and `CTE du CME Rwampara` are not. It also finds
merges no comparison of strings could: the reference hospital of Butembo is
named Kitatumba, and Katana's is named FOMULAC.

Citation: Center for Integrated Earth System Information (CIESIN), Columbia
University; Ministere de la Sante Publique, Hygiene et Prevention, Democratic
Republic of the Congo; GRID3 (2025). GRID3 COD Health Facilities v8.0.
https://doi.org/10.7916/f1ft-y872. CC BY 4.0.

## Method

1. `R/lib/corpus.R` renders a report to one deterministic text, body and
   tables together. Extraction and verification use the same renderer, so a
   quote that matched at extraction still matches at verification.
2. `R/01_facilities.R` sends that text to the model with
   `assets/prompt-facilities.md` and a fixed schema, and caches the reply in
   `data/cache/` under a key made from the corpus build key, the prompt, the
   schema and the model. Any change to any of those invalidates the cache.
3. `R/02_resolve.R` verifies every quote, keys the names, assigns facility
   ids from the registry, and derives the two tables.
4. `R/03_checks.R` rebuilds the register from the events by a second
   implementation and fails if the two disagree.
5. `R/04_review.R` orders the open naming judgements by how many events
   depend on each, and `R/05_places.R` checks the register's places against
   GRID3.

The quote gate in step 3 has no exemption route. A quote that is not a span of
the report is dropped, whatever it says, because a model that paraphrases once
will paraphrase again and there is no way to tell from the row which it did.
Rejections are written to `outputs/rejected_events.csv` and `R/03_checks.R`
fails while any remain.

## Running it

```sh
Rscript R/01_facilities.R          # model calls; --only=, --force, --cache=
Rscript R/02_resolve.R             # no model calls
Rscript R/03_checks.R              # exit 1 on any failure
Rscript R/04_review.R              # worksheet for the naming decisions
Rscript R/05_places.R              # what GRID3 does and does not recognise
```

`R/01_facilities.R` expects a bvd-sitreps checkout beside this one, or
`BVD_SITREPS` pointing at one. It reads that corpus by path and never opens a
PDF. Extraction takes about three hours over 116 reports and should be run
detached:

```sh
mkdir -p outputs/logs
nohup caffeinate -is Rscript R/01_facilities.R \
  > outputs/logs/facilities_$(date +%F-%H%M).log 2>&1 &
```

Exit 3 means the model quota stopped the run; rerunning resumes from the
cache. `data/cache/` is committed, so steps 2 to 4 run without any model
access.

## Limitations

The register counts spellings, not buildings. `CTE de l'HGR Bunia` and `CTE de
Bunia` are probably one centre and are two rows until someone says otherwise;
`CTE de l'HGR Rwampara` and `CTE du CME Rwampara` are two centres in one town
and must stay apart. 65 such decisions are open, and the first ten carry 66%
of the events involved. Until they are made, treat the facility counts above
as an upper bound and the event table as the reliable layer.

A date here is the date a report said something, not the date it happened.
`date_first_in_service` is the first report showing patients at the facility,
which is at or after the true opening.

`date_opening_stated` is empty for every facility. It exists to hold a date
the report itself gives, and across 116 reports the INSP never gives one: an
opening is announced on the day it is reported (`Inauguration officielle du
CTE normé de CME Rwampara`) and the date is the report's. Three events
anywhere in the corpus carry a date of their own. Treat
`date_opening_announced`, which 20 facilities have, as the earliest date an
opening is known by, not as the opening.

Seven SitRep numbers were never published (003, 029, 043, 045, 063, 075,
076), so a facility's first mention may sit in a report that does not exist.
`first_mention_after_gap` marks the 50 facilities where this is possible.

Fourteen events were rejected by the quote gate and are not in the data. Eight
are quotes that are not spans of the report; six are quotes too short to name
what they evidence.

Beds are sparse. Only 25 facilities have a bed count, because the bed table
stops appearing after SitRep 090.

## Licence

Code under the licence in `LICENSE`. The situation reports are the INSP's.
