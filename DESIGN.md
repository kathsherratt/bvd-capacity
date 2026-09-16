# Design

What this repository is for, what shape it takes, and what is not built yet.
[README.md](README.md) describes what exists today; this is the target.

## Why it is separate

Two repositories already read the INSP situation reports and neither holds
capacity at the level where saturation happens.

| repository | holds | stops |
|---|---|---|
| INRB-UMIE/BDBV2026-Data | the PDFs, zone-level digitised counts, French and English pillar narratives | bed and hospitalisation fields end 30 May |
| epiforecasts/BVDOutbreakSize | national fitted streams, a national bed-capacity series, a register of signals seen but not fitted | scanning ends at SitRep 089, 11 August |
| bvd-capacity | beds, occupancy, saturation, workforce, supplies and laboratory throughput by province, zone and facility | — |

BVDOutbreakSize names the gap itself, listing under signals it does not
track: per-province occupancy against beds, local saturation that a single
national bed-capacity series cannot represent. That is the remit.

## Principles

Place first. Every row carries province, health zone and facility where the
text gives them. A signals table with no place column sums over whichever
places reported that day, and consecutive rows are then not comparable.

Provenance per row. Source quote, report number, page and basis travel with
the value, in columns. A prose `source =` field describing a whole stream
cannot be diffed or checked.

Absence is data. A quantity a report does not print is recorded as not
reported, never as zero, and the difference between a place printing `ND` and
a template not carrying the indicator is kept.

Freeze, don't bridge. When a template change ends a series, it stops with a
reason rather than being interpolated across the break.

Two routes. Numeric, formulaic text is parsed deterministically. Prose is
read by a model against fixed passages, with every claim carrying a quote
checked verbatim against the source.

Vintages kept. Rows are keyed by report, not only by date, so revisions stay
visible.

## Layout

```
bvd-capacity/
├── README.md                  what it is, coverage, limits
├── DESIGN.md                  this document
├── dictionary.md              column definitions
├── data/
│   ├── text/                  extracted report text, one file per report
│   │                          (committed: carries the OCR of the scans)
│   ├── registry/
│   │   ├── reports.csv        one row per PDF
│   │   ├── indicators.csv     indicator definitions and search cues
│   │   ├── eras.csv           report templates and what each carries
│   │   ├── facilities.csv     the treatment and transit centre register
│   │   └── facility_events.csv  every statement behind it
│   ├── observations/
│   │   ├── capacity.csv       beds and installed capacity
│   │   ├── occupancy.csv      patients, occupancy rates, flows
│   │   ├── strain.csv         saturation, shortages, incidents, workforce
│   │   └── laboratory.csv     samples, positivity, sites, blood      [phase 3]
│   └── derived/
│       ├── occupancy_daily.csv  one row per place per report
│       └── coverage.csv         what each report reported
├── R/
│   ├── 01_fetch.R             INSP WordPress API, mirror as fallback  [phase 5]
│   ├── 02_text.R              pdftools, MuPDF render, French OCR
│   ├── 03_parse.R             deterministic numeric patterns
│   ├── 04_passages.R          passages for reading, tracked per passage [phase 4]
│   ├── 05_build.R             assemble, validate, write observations
│   └── 06_checks.R            invariants, coverage, regression
├── prompts/                   prose reading, one report at a time     [phase 4]
├── report/                    Quarto site, four pages                 [phase 2]
└── exports/                   shaped for other repositories           [phase 5]
```

## Indicator catalogue

Chosen by measuring the corpus, not by guessing. Yield is matches, then
reports carrying the indicator, out of the 96 held.

| indicator | cue | route | yield | phase |
|---|---|---|---|---|
| `beds_total` | `Nombre de lits` row; `capacité installée atteint 840 lits` | parse | 204 / 47 | 1 |
| `patients_isolated`, `occupancy_rate` | `548 patients pour 991 lits`; `taux d'occupation` | parse | 155 / 48 | 1 |
| `facility_occupancy_pct` | `CTE Nizi (322 %)` | parse | 16 / 6 | 2 |
| `facility_saturated` | `saturé`, `sursaturation`, `dépasse sa capacité` | read | 93 / 54 | 1 |
| `patients_outside_standard` | `101 des 254 patients … ne sont pas des CTE` | read | 27 / 17 | 4 |
| `admissions_24h`, `exits_24h` | occupation table rows; PECH prose after SitRep 081 | parse | table era | 1 |
| `patients_critical` | `31 malades en état critique` | parse | 3 / 3 | 4 |
| `transfer_delay_or_refusal` | `retards d'admission`, `refus de transfert` | read | 59 / 40 | 4 |
| `escapes` | `évadés`, `évasion` | read | 73 / 51 | 4 |
| `ambulances_available` | `ambulances disponibles`, `courses réalisées` | parse | 25 / 14 | 4 |
| `community_death_share` | `décès communautaires`, `mortalité intra-CTE` | parse | 158 / 60 | 4 |
| `staff_strike`, `staff_shortage` | `grève`, `non-paiement`, `insuffisance de personnel` | read | 58 / 40 | 4 |
| `hcw_infections_cum` | PPL tables and narrative totals | parse | 35 / 19 | 4 |
| `supply_stockout`, `ppe_insufficient` | `rupture de stock`, `EPI insuffisants` | read | 16 / 15 | 4 |
| `samples_received`, `samples_analysed` | `99 échantillons reçus`, per province | parse | 204 / 75 | 3 |
| `lab_site_status` | `laboratoire de proximité`, `GeneXpert`, launches | read | 18 / 13 | 3 |
| `positivity_rate`, `result_delay` | `taux de positivité`, `résultats en attente` | parse | 14 / 14 | 3 |
| `blood_available` | `absence de sang sécurisé` | read | 22 / 13 | 4 |

Denominators come from outside the reports: zone population and baseline
facility counts from BDBV2026-Data (`worldpop`, `grid3_healthsites`), and
planned PCR throughput from its `testing_capacity` dataset, which lets
laboratory volume be read against plan.

## Checks

Run on every build; see `R/06_checks.R`.

1. Evidence. Every quote occurs verbatim in that report's text once
   whitespace is collapsed. A failure stops the run.
2. Balance closure. Patients at bed (J−1) plus admissions minus exits equals
   patients at end of day, and the confirmed/suspect split sums to the total.
3. Carry-forward. A figure identical to the previous vintage with no fresh
   table behind it is flagged and excluded from derived series.
4. Two routes. Where beds appear both printed and derivable as occupancy over
   rate, both are computed and a mismatch is flagged, not resolved.
5. Headline against table. Prefer the auditable table sum; record the
   headline as a discrepancy. [phase 2]
6. Regression. A rerun must reproduce every committed value unchanged before
   new rows are accepted. [phase 2]
7. Coverage. `derived/coverage.csv` is rebuilt each run.

## The site [phase 2]

Four Quarto pages, static, rendered from the committed CSVs so it builds
without rerunning any extraction.

| page | content |
|---|---|
| `index.qmd` | Latest picture: beds and occupancy by province, facilities currently reported saturated, laboratory volume against plan. Three plots, one table, a line saying which report it is as of |
| `coverage.qmd` | Indicator against report as a tile grid: reported, not reported, template break |
| `facilities.qmd` | The register, one row per facility, with its strain history |
| `methods.qmd` | How values are read, the checks, the dictionary, download links, limits |

Plots in ggplot2, tables in `gt` or `knitr::kable`, deployed to GitHub Pages
by the same workflow that updates the data. Anything beyond this belongs in a
consumer of the CSVs.

## Exports [phase 5]

| destination | shape |
|---|---|
| BDBV2026-Data | `capacity__<indicator>__daily.csv` with `nom, date, value`, zone names canonical against the shapefile, offered as a pull request with a dataset README and `metadata.yaml` in their format |
| BVDOutbreakSize | rows in their `candidate_signals.csv` schema, plus the province split they have an open issue for |
| Oxford team | `facilities.csv` and its dictionary |
| anyone | tagged releases of `data/`, cited by report range |

## Update cycle [phase 5]

```
daily, by scheduled action
  01_fetch    ask INSP for reports not yet held; exit 0 if none
  02_text     extract text; OCR any scan; cache by file hash
  03_parse    deterministic numeric patterns -> observations
  04_passages list passages needing a read; open an issue if any
  06_checks   invariants; fail loudly

on a person or agent completing the reads
  05_build    assemble, validate, write derived/
  render      Quarto -> Pages
  exports     regenerate; pull requests on a weekly cadence
```

INSP returns 403 to default user agents and 200 to a browser one; its post
list is a WordPress REST endpoint, and each post embeds the PDF URL in a
`pdfemb-data` base64 blob. INSP is the source; the mirror is the cross-check
and lags it.

## Phasing

| phase | delivers | status |
|---|---|---|
| 1 | beds, patients, occupancy by province and day; facility saturation from the register | done |
| 2 | the site and the coverage map | |
| 3 | laboratory volume against the Africa CDC plan | |
| 4 | workforce, supplies, transport, community death share | |
| 5 | exports and the daily action | |

## Risks

Template churn. The reports changed template at least three times, and
indicators appear and vanish with it. Care outside standard structures exists
only from August; the confirmed/suspect split ends with the table at SitRep
080.

Missing reports. 27 numbers between 001 and 122 are absent from the mirror.

Uneven places. Which provinces print which quantity changes report to report.
Hence `places_included` on every total.

Internal contradiction. Reports disagree with themselves. SitRep 079 says six
structures are saturated and lists five. Both numbers are kept; neither is
reconciled silently.

Reading error. Model reading is checked by quote, which catches invention but
not misreading. An audit of a stratified sample, with an agreement rate
published on the methods page, is part of a release.

Terms of use. The mirror's own metadata asks that distribution terms be
confirmed with INSP before external republication. Attribution to INSP,
citing report number and date, on every export.
