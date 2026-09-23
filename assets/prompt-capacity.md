`#ai-written`

You are reading one public situation report on the 2026 Bundibugyo virus disease outbreak in the Democratic Republic of the Congo.

Record every figure the document gives about the capacity of the response to hold and treat patients: beds, occupancy, patients in isolation, movements in and out of treatment facilities, and the number of facilities or laboratories in service. Record nothing else.

## Input

One document as plain text, with front matter naming its publisher and date, then `[PAGE n]` markers and the page text as the PDF lays it out. Tables and figure blocks keep their layout, so a label and its number may sit on different lines, and a row of numbers may sit above the row of labels that names them:

```
7 Provinces      6 Provinces           1 902      59.1%      33 520
63 Health Zones  49 Health Zones       Cases      Bed        Contacts
Affected         Active Transmission*  Recovered  Occupancy  under follow up
```

Read those blocks by column: the fourth column above says bed occupancy is 59.1%.

## Which figures count

| `indicator` | what it counts |
|---|---|
| `beds_capacity` | beds available to hold patients, whatever the document calls it: bed capacity, capacité en lits, installed beds |
| `beds_occupied` | beds in use, or patients at a bed |
| `bed_occupancy_pct` | occupancy as a percentage or rate |
| `patients_in_isolation` | people held in isolation, suspected and confirmed together unless the document separates them |
| `admissions` | new admissions to treatment or isolation over a stated period |
| `discharges_recovered` | people discharged recovered, cured, guéris |
| `deaths_in_facility` | deaths that happened inside a treatment or isolation facility, as against community deaths |
| `escapes` | patients who left without discharge, évadés |
| `facilities_operational` | the count of treatment, transit or isolation facilities in service |
| `laboratories_testing` | the count of laboratories testing for this outbreak |

Leave out: case counts, deaths in the community, contacts, vaccinations, funerals, staffing, and anything about money. Epidemiological totals are not capacity. A death is recorded only where the document places it inside a facility.

## Where the figure applies

| `level` | when |
|---|---|
| `national` | the figure covers a whole country: `Democratic Republic of the Congo`, or an unqualified headline figure in a report about one country |
| `province` | a province is named |
| `health_zone` | a health zone is named |
| `facility` | one named facility |

Give `place_raw` as the document writes the place, `""` for a national figure. Give `country` where the document makes it clear, `""` otherwise. A report covering two countries gives national figures for each: record both, and never add them together.

## Output

One object with an `indicators` array. One entry per figure per place per date.

| field | content |
|---|---|
| `indicator` | one value from the table above |
| `level` | `national`, `province`, `health_zone` or `facility` |
| `country` | as written, `""` if not clear |
| `place_raw` | province, zone or facility as written, `""` for a national figure |
| `value` | digits only, with a decimal point if the document gives one. No thousands separators, no percent sign, no words |
| `unit` | `beds`, `patients`, `percent`, `facilities`, `laboratories` |
| `period` | `point` for a stock at a moment, `24h`, `7d` or `cumulative` for a flow, as the document says |
| `as_of_date` | `YYYY-MM-DD` if the document dates this figure; `""` if it gives only the report's own date |
| `evidence_quote` | 20 to 200 characters copied character for character from the input, containing the figure. Keep the line breaks and spacing exactly as they are |
| `confidence` | `high` when label and number are unambiguous, `low` when the layout leaves any doubt |

## Rules

1. Copy the number as printed, minus the thousands separator: `1 535` becomes `1535`, `59.1%` becomes `59.1` with `unit` `percent`.
2. A figure in a chart axis, a legend, or a figure caption is not a figure the document states. Skip it.
3. Where the same figure appears twice, once in the headline block and once in the text, record it once.
4. Use no outside knowledge, and never compute a figure the document does not print. Do not divide occupied beds by capacity to get a rate; if the rate is not printed, it is not there.
5. Every `evidence_quote` is a contiguous span of the input, copied exactly. A quote that is reworded, joined from two places or tidied up will be rejected and the entry with it. A quote may span lines, and for a column block it usually must.
6. Return an empty `indicators` array if the document gives no capacity figure. That is a real answer.
