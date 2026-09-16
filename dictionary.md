# Data dictionary

Dates are report dates (`Date de rapportage`) throughout. A report describes
the day before it, so a value dated 18 July is the situation at the end of
17 July where the report says so.

## data/observations/*.csv

One row per indicator per place per report. `capacity.csv` holds beds,
`occupancy.csv` patients and rates, `strain.csv` facility-level statements.
Same columns in all three, so they concatenate.

| column | definition |
|---|---|
| `indicator_id` | From `data/registry/indicators.csv` |
| `level` | `national`, `province` or `facility` |
| `place_id` | Province slug (`ituri`, `nord-kivu`, `sud-kivu`, `haut-uele`, `bas-uele`, `tshopo`), `ensemble` for the reports' own national total, or a `facility_id` from `data/registry/facilities.csv` |
| `place_name` | Readable name for that place |
| `report_date` | Date of the report |
| `sitrep`, `version` | Report number; version 2 for the reissued SitRep 012 |
| `value` | The number. Empty where the report named the place and printed `ND` |
| `unit` | `beds`, `patients`, `percent` or `flag`. `flag` is a statement rather than a count, and its value is 1 |
| `basis` | `table` read from a column-aligned table, `prose` from a sentence, `read` from the facility register's model reading, `derived` computed here |
| `derivation` | Formula where `basis` is `derived` |
| `evidence_quote` | The line or sentence as the report printed it, checked to occur verbatim in that report's text once whitespace is collapsed |
| `page` | Page of the PDF the quote sits on. Empty for register rows |
| `text_source` | `pdf_text`, or `ocr_mupdf` / `ocr_poppler` for the scanned reports |
| `confidence` | `low` where a table row had fewer cells than columns and was aligned by position, or where the register marked the reading doubtful |
| `flags` | Semicolon-separated. `not_reported` the place was named and left blank; `rate_disagrees`; `carry_forward` |
| `places_included` | For a national total, the provinces that filled in that same row. Empty otherwise |
| `note` | One sentence, English. Empty for parsed rows |

### Indicators

Defined with their search cues in `data/registry/indicators.csv`.

| indicator | unit | meaning |
|---|---|---|
| `beds_total` | beds | Installed beds in treatment and transit structures |
| `patients_start_day` | patients | In isolation at the start of the reporting day |
| `admissions_24h` | patients | Admitted in the previous 24 hours |
| `exits_24h` | patients | Left in the previous 24 hours: recovered, died, non-case, escaped, transferred |
| `admissions_cumulative` | patients | Admitted since the start of the outbreak |
| `patients_isolated` | patients | In isolation at the end of the reporting day |
| `patients_confirmed` | patients | Of those, confirmed cases |
| `patients_suspect` | patients | Of those, suspected cases |
| `occupancy_rate` | percent | Patients in isolation over installed beds, as the report printed it |
| `facility_saturated` | flag | A named centre reported saturated or over capacity |
| `facility_expanded` | flag | Capacity added at a centre already in service |
| `facility_closed` | flag | Closure, suspension, destruction or relocation |
| `facility_incident` | flag | Fire, arson or other security incident, no stated closure |

## data/derived/occupancy_daily.csv

One row per place per report, the observations pivoted wide.

| column | definition |
|---|---|
| `report_date`, `sitrep`, `version`, `level`, `place_id`, `place_name` | As above |
| `basis` | `table` or `prose`, from the rows behind this one |
| `beds_total` … `patients_suspect` | The values, empty where not reported |
| `occupancy_rate` | As the report printed it |
| `occupancy_rate_derived` | `100 * patients_isolated / beds_total`, computed here where both parts exist |
| `rate_gap` | Absolute difference between the two rates |
| `flags` | `rate_disagrees` where `rate_gap` exceeds one point; `carry_forward` where beds and patients both repeat the previous report for that place |

Nothing here is interpolated. A place with no row for a date was not reported
for that date.

## data/derived/coverage.csv

One row per report per indicator. The record of what the template carried.

| column | definition |
|---|---|
| `sitrep`, `version`, `report_date` | The report |
| `era` | From `data/registry/eras.csv` |
| `indicator_id` | The indicator |
| `status` | `reported` at least one place gave a value; `not_reported` every place named printed `ND`; `absent` the template did not carry it |
| `n_values`, `n_nd` | Places with a value, and places printed as `ND` |
| `places` | Which places gave a value |

## data/registry/

| file | contents |
|---|---|
| `reports.csv` | One row per PDF: number, version, filename, report date and how it was read, page count, text source, and the text file in `data/text/` |
| `indicators.csv` | One row per indicator: family, unit, levels, route, definition, the French cue it is found by, first report carrying it, notes |
| `eras.csv` | Report-number ranges and the template each carries, with the route used to read it |
| `facilities.csv` | The treatment and transit centre register: one row per facility with location, first report in service, latest reported state |
| `facility_events.csv` | Every statement behind that register, with its French quote |

`facilities.csv` and `facility_events.csv` are produced by the `etc-facilities`
skill and copied here. `strain.csv` is derived from `facility_events.csv` and
should not be edited directly.
