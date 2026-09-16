# bvd-capacity

Health-care capacity and strain read from the INSP situation reports for the
2026 Bundibugyo virus disease outbreak in the Democratic Republic of the
Congo. Sub-national by design, public data only.

Beds, patients in isolation, admissions, exits and occupancy by province and
day; saturation by named treatment or transit centre. Every value carries the
French sentence it came from, the report number and the page.

- `data/observations/` — one row per indicator per place per report
- `data/derived/occupancy_daily.csv` — one row per place per report
- `data/derived/coverage.csv` — which indicators each report carried
- `data/registry/` — reports, indicators, eras, facilities
- `dictionary.md` — column definitions

Phase 1 of [DESIGN.md](DESIGN.md), which sets out the full scope: workforce,
supplies, transport, laboratory throughput, a Quarto site and exports to
BDBV2026-Data and BVDOutbreakSize are not built yet.

## What is here

| | |
|---|---|
| Source | INSP SitRep PDFs mirrored at https://github.com/INRB-UMIE/BDBV2026-Data, `data/insp_sitrep/raw/` |
| Reports | 96 PDFs: SitReps 001-122, 14 May to 13 September 2026, plus a reissued 012 |
| Missing from the mirror | 003, 029, 043, 045, 059, 061, 063, 068, 071, 075, 076, 083, 084, 086-088, 090-092, 095, 098, 100, 103, 105, 107, 120, 121 |
| Scanned reports, read by OCR | 007-011, 012 (first issue), 014 |
| Observations | 1,975: 1,845 values and 130 places a report named but did not fill in |
| Reports with a capacity value | 73, 1 June to 13 September |
| Places | 6 provinces, a national total, and 29 named facilities |

Counts by indicator, where a value is a number the report printed and `ND` is
a place the report listed and left blank:

| indicator | rows | values | ND |
|---|---|---|---|
| `patients_isolated` | 278 | 262 | 16 |
| `admissions_24h` | 277 | 258 | 19 |
| `exits_24h` | 269 | 251 | 18 |
| `occupancy_rate` | 234 | 219 | 15 |
| `patients_start_day` | 206 | 189 | 17 |
| `patients_confirmed` | 201 | 186 | 15 |
| `patients_suspect` | 196 | 182 | 14 |
| `beds_total` | 160 | 144 | 16 |
| `facility_saturated` | 125 | 125 | — |
| `facility_expanded` | 24 | 24 | — |
| `facility_incident` | 5 | 5 | — |

`beds_total` is the one indicator read at all three levels: 152 rows by
province or nationally, 8 for a named facility.

## How a value gets here

The reports changed template three times, and the template decides how a
number can be read.

| era | reports | how capacity appears | route |
|---|---|---|---|
| narrative | 001-018 | not reported at province level | none |
| table | 019-080 | `Indicateur` table with a column per province | parsed by column |
| dashboard | 081-082 | two-column layout; the columns interleave when the PDF text is extracted | not parsed |
| prose | 083-122 | one bullet per province, as sentences | parsed by sentence |

Reading the table means aligning each number against its column. The header
is not enough: in some templates the numbers sit twenty characters to the
right of the word above them, and a province the row leaves blank would shift
every value after it. So the column positions are measured from the rows that
carry one cell per column, and a short row is then aligned against those
positions, skipping whichever column makes the total distance smallest. Rows
aligned that way are marked `confidence = low`: there are 8, all checked by
hand.

Facility saturation is not parsed here. It comes from the treatment facility
register, where each statement was read against a fixed passage and its quote
checked verbatim, and is reshaped into the same long schema.

## Checks

`Rscript R/06_checks.R`. All 1,975 quotes occur verbatim in their report.

The rest report and continue, because the reports contradict themselves and
the disagreement is the finding:

| check | failures |
|---|---|
| start + admissions − exits = end of day | 17 of 171 place-days |
| confirmed + suspect = patients in isolation | 6 of 166 |
| printed occupancy rate against patients ÷ beds | 6 of 108 |
| national total against the provinces it names | 0 of 290 |

SitRep 046 is the pattern: Ituri opens with 449 patients, admits 68 and
discharges 50, which leaves 467, and the table prints 451. SitRep 065 gives
Nord-Kivu 181 patients in 141 beds and calls it 123.1 per cent. Both numbers
are kept and flagged; neither is corrected.

## Rerunning

Requirements: R with `data.table` and `pdftools`. Rebuilding the text from
the PDFs as well needs `tesseract` with French, Python 3 with `pymupdf`, and
a BDBV2026-Data clone.

```bash
Rscript R/02_text.R --pdf-dir=/path/to/BDBV2026-Data/data/insp_sitrep/raw
Rscript R/03_parse.R
Rscript R/05_build.R
Rscript R/06_checks.R
```

`data/text/` is committed, so steps 3 to 5 run on a fresh clone with nothing
but R and `data.table`, and step 2 is only needed for new reports. Step 2 on
the committed cache reproduces `data/registry/reports.csv` unchanged.

`01_fetch.R` (ask INSP for reports the mirror does not have yet) and
`04_passages.R` (passages for a reading pass) are in the design and not yet
written.

## Limits

- 27 report numbers between 001 and 122 are absent from the mirror, so a
  series can have a gap that is not a reporting gap.
- Which provinces print which quantity changes from report to report. A total
  carries `places_included` naming the places behind it, so a step in a
  national series is not read as a change on the ground.
- Indicators appear and vanish with the template. The confirmed/suspect
  split and patients at the start of the day stop dead at SitRep 080 with the
  table; bed capacity is reported in only 40 of 96 reports, first at 051.
  `data/derived/coverage.csv` is the record of this and should be read beside
  any series.

| indicator | first report | last | reports carrying it |
|---|---|---|---|
| `exits_24h` | 018 | 122 | 72 |
| `admissions_24h` | 019 | 122 | 70 |
| `patients_isolated` | 018 | 122 | 68 |
| `occupancy_rate` | 028 | 122 | 58 |
| `patients_start_day` | 019 | 080 | 48 |
| `patients_confirmed` | 019 | 080 | 47 |
| `patients_suspect` | 019 | 080 | 46 |
| `beds_total` | 051 | 122 | 40 |
| `facility_saturated` | 062 | 119 | 24 |
| `facility_expanded` | 027 | 118 | 16 |
| `facility_incident` | 010 | 108 | 5 |
- A quantity a report does not print is never zero. It is `ND` where the
  report named the place and left it blank, and absent otherwise.
- SitReps 081 and 082 hold province figures this repository does not extract.
  Their two-column layout interleaves on extraction, so a parsed quote would
  not be a sentence the report printed.
- Spelled-out numbers are not parsed. "Une nouvelle admission a été
  enregistrée" reads as absent, not as 1.
- Facility-level rows cover the 29 centres a report described as saturated,
  expanded or damaged. Absence of a facility is not evidence it was fine.
- `carry_forward` flags a report repeating the previous report's beds and
  patients unchanged. It is flagged, not dropped: 9 rows.

Public data. Facility and province level only, no person-level information.
The mirror's own metadata asks that distribution terms be confirmed with INSP
before external republication; attribution to INSP with report number and
date belongs on anything derived from this.
