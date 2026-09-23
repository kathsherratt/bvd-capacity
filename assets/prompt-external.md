`#ai-written`

You are reading one public document about the 2026 Bundibugyo virus disease outbreak in the Democratic Republic of the Congo, published by an organisation other than INSP: a WHO Disease Outbreak News, a situation report, or a similar account.

Record every facility where people with Ebola are treated, isolated or held, and what this document says about each one's state. Record nothing else.

The point of this reading is corroboration. A register of facilities has already been built from the INSP situation reports; this document is a second, independent account of the same outbreak. So record what this document says on its own terms, without reference to any other source, and never smooth a name towards one you think is intended.

## Input

One document as plain text, with front matter naming its publisher, date and licence, then sections under `##` headings. English unless the front matter says otherwise. No tables.

## Which facilities count

Include, whatever the document calls them:

- Ebola treatment centres, treatment units, treatment facilities
- transit centres, triage or holding units
- isolation centres, isolation units, isolation wards
- hospitals, clinics and health centres this document shows holding, treating, admitting, discharging, transferring or losing Ebola patients

Include a facility outside the Democratic Republic of the Congo if the document shows it holding a patient from this outbreak. Give its place as written and let `province` stay empty.

Leave out:

- statements about treatment centres as a group rather than about one site: `patients admitted to Ebola treatment centres`, `treatment centres reported 127 admissions`. These count a system, not a place. When no single facility is being described, record nothing
- laboratories, points of entry, vaccination sites and burial teams
- a health zone, a province or a country. These are places, not facilities

## Facilities the document does not name

Record these too, with `name_status` saying so, exactly as for a named one.

| `name_status` | when |
|---|---|
| `named` | the document gives the facility's own name, or the place or host hospital it sits at: `the Ebola treatment centre in Bunia`, `Nyankunde hospital` |
| `unnamed` | one facility is described but not named: `a treatment centre in North Kivu`, `an isolation unit` |
| `ambiguous` | a name that could be more than one site in this document |

## Output

One object with an `events` array. One entry for each facility for each thing this document says about it.

| field | content |
|---|---|
| `facility_raw` | the facility as this document writes it, including any type word and any misspelling |
| `facility_type_raw` | the type word as written (`Ebola treatment centre`, `transit centre`, `isolation unit`, `hospital`), or `""` |
| `site_kind` | `treatment_centre`, `transit_centre`, `isolation_centre`, `hospital_isolation` or `other`. Use `hospital_isolation` only for a hospital, clinic or health centre this document shows holding Ebola patients, and `other` for a health structure named in connection with the outbreak without being shown to hold any |
| `name_status` | `named`, `unnamed` or `ambiguous`, as the table above sets out |
| `place_raw` | the town, site or locality as written. `""` when the document gives none |
| `health_zone` | the health zone as written, `""` if not given |
| `province` | the province as written, `""` if not given |
| `event` | one value from the table below |
| `event_date` | `YYYY-MM-DD`, only when the document states the date of this event. The document's own date is not an event date. `""` otherwise |
| `beds` | the bed capacity stated for this facility, digits only. Patients and admissions are not beds. `""` if none is given |
| `status_note` | one short sentence saying what the document says. Do not interpret, infer or explain |
| `evidence_quote` | 20 to 200 characters copied character for character from the input, containing the facility as the document writes it. Spacing, punctuation and misspellings all as they are |
| `confidence` | `high` when the wording is unambiguous, `low` when it is not |

## Event values

| event | use when the document says |
|---|---|
| `planned` | a site is chosen or construction is decided |
| `under_construction` | building, fitting out, tents going up |
| `opened` | the facility opened, was inaugurated, was put into service or made operational. This is the announcement of opening, not the arrival of the first patient |
| `operating` | Ebola patients are at the facility: admitted, isolated, treated, discharged, transferred, dying or escaping there, or referred there for care. The evidence has to be about patients, not about work done at the building |
| `expanded` | beds or capacity added to a facility already running |
| `strained` | saturation, overcrowding, shortage or a refused transfer attributed to it |
| `incident` | fire, attack, riot or other security incident at the facility, with no closure stated |
| `closed` | closure, suspension, destruction or relocation |
| `mention_only` | named with nothing said about its state |

## Rules

1. One entry per facility per event value per document. A document saying a centre is open and overcrowded gives two entries, `operating` and `strained`.
2. `mention_only` is a normal answer. Most facilities in a document like this are named once in passing.
3. A patient referred or transferred to a facility makes that facility `operating`.
4. Use no outside knowledge. Do not add a town, a health zone or a spelling the document does not give, and do not correct one it does give.
5. Every `evidence_quote` is a contiguous span of the input, copied exactly. A quote that is reworded, joined from two places or tidied up will be rejected and the entry with it.
6. Return an empty `events` array if the document names no facility. That is a real answer about a document that discusses the outbreak nationally, and it is better than a guess.
