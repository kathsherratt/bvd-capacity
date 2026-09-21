`#ai-written`

You are reading one French-language situation report (SitRep) of the Institut National de Santé Publique (INSP), Democratic Republic of the Congo, on the 2026 Bundibugyo virus disease outbreak.

Record every named facility where people with Ebola are treated, isolated or held, and what this report says about each one's state. Record nothing else.

## Input

The whole report as transcribed from the published PDF: the body text, one sentence a line, with each table rendered in place. A table appears as a `[TABLE_n]` marker and its caption, then a header row, then one line a row, in pipes:

```
[TABLE_7] Tableau VI. Mouvement des malades dans les établissements de soins
| Indicateurs | BUNIA HGR | BUNIA SOFEPADI | BUNIA TOTAL |
| Patients au lit (J-1) | 6 | 4 | 10 |
```

`[PHOTO]` and `[FIGURE: caption]` mark images. The text is French and stays French; do not translate anything you copy.

## Which facilities count

Include, whatever the report calls them:

- treatment centres: CTE, CTC, CT Ebola
- transit centres: CT, CTr
- isolation centres: CI
- hospitals, clinics and health centres where this report shows Ebola patients isolated, treated, admitted, discharged, transferred or dying. Early reports carry the outbreak in `HGR Bunia`, `SOFEPADI`, `CH ELIKYA` and `CME Rwampara` before any CTE exists, and those are facilities for this purpose.

Leave out:

- any facility the report does not name: `le CTE`, `un CTE de 100 lits`, `les trois centres de transit`
- a name that could be two different sites in the same report (`Rwampara` where both `HGR Rwampara` and `CME Rwampara` appear)
- totals and roll-ups that sit in a table where facilities sit: `BUNIA TOTAL`, `RWAMPARA TOTAL`, `TOTAL GENERAL`, `TOTAL` are arithmetic, not places
- laboratories, points of entry (PoE, PoC), vaccination sites, burial teams and health zones as such. A health zone is a place, not a facility.

## Output

One object with an `events` array. One entry a facility a state, in the order you meet them.

| field | content |
|---|---|
| `facility_raw` | the name exactly as this report writes it, including its type prefix and any misspelling: `CTE de Nizi`, `HGR Bunia`, `BUNIA SOFEPADI`, `Clibnique Bénedicte` |
| `facility_type_raw` | the type prefix as written (`CTE`, `CT`, `CTC`, `CI`, `HGR`, `CH`, `CME`, `CS`), or `""` if the name carries none |
| `site_kind` | `treatment_centre`, `transit_centre`, `isolation_centre`, `hospital_isolation` or `other`. Use `hospital_isolation` for a hospital, clinic or health centre holding Ebola patients |
| `health_zone` | the health zone as written, `""` if this report does not give one for this facility |
| `province` | the province as written, `""` if not given |
| `event` | one value from the table below |
| `event_date` | `YYYY-MM-DD`, only when the report states the date of this event (`ouvert le 22 mai`). The report's own date is not an event date. `""` otherwise |
| `beds` | the bed capacity stated for this facility, digits only. Patients, admissions and occupancy are not beds. `""` if no bed count is given for it |
| `status_note` | one short English sentence saying what the report says. Translate; do not interpret, infer or explain |
| `evidence_quote` | 20 to 200 characters copied character for character from the input, containing the facility name. French, accents, spacing and misspellings all as they are |
| `confidence` | `high` when the wording is unambiguous, `low` when it is not |

## Event values

| event | use when the report says |
|---|---|
| `planned` | a site is chosen or prospected, construction is decided (`prospection du lieu d'installation`, `plan de construction`) |
| `under_construction` | building, fitting out, tents going up (`démarrage des travaux`, `aménagement`, `installation de tentes`) |
| `opened` | the facility opened, was inaugurated, was put into service or made operational (`ouverture`, `inauguration`, `mise en service`, `rendu opérationnel`). This is the announcement of opening, not the arrival of the first patient |
| `operating` | patients admitted, isolated, treated, discharged, dying or escaping there; a patient referred there; staff briefed there; supplies delivered for its patients |
| `expanded` | beds or capacity added to a facility already running |
| `strained` | saturation, overcrowding, shortage or a refused transfer attributed to it |
| `incident` | fire, attack, riot or other security incident at the facility, with no closure stated |
| `closed` | closure, suspension, destruction or relocation |
| `mention_only` | named with nothing said about its state: a list, a heading, a table column |

## Rules

1. At most one entry a facility an `event` value in this report. Reports repeat their summary in the body, so when several statements show the same state, keep the most informative quote. Different states for one facility (`operating` and `expanded`) are separate entries.
2. `mention_only` is common and correct. Do not promote a bare mention to `operating` or `opened`.
3. A referral (`référée au CTE de Bunia`) shows the facility takes patients: `operating`.
4. A facility that appears only as a table column header or row label is `mention_only`, unless the table's own caption says what is happening there. A bed table showing its beds is `operating` with `beds` filled in.
5. Use nothing from outside this report: not your own knowledge of the outbreak, not other reports, not what another facility in this report is doing.
6. Every `evidence_quote` is checked by exact substring match against the input text after whitespace is collapsed. A quote that does not match is thrown away with its entry. Copy, never retype from memory, and never join two separate spans.
7. When the facility is named in a table header or row, quote the shortest run of that rendered line that still contains the name. `| BUNIA HGR | BUNIA SOFEPADI |` is a valid quote; a header row longer than 200 characters should be cut down, not rewritten.
8. Return `{"events": []}` when the report names no facility. That is a real answer, not a failure.
