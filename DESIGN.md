`#ai-input`

# Design

Why this repository exists, the principles it holds to, and what is not built
yet. [README.md](README.md) describes what exists today.

## Why it is separate

Two repositories already read the INSP situation reports and neither holds
capacity at the level where saturation happens.

| repository | holds | stops |
|---|---|---|
| INRB-UMIE/BDBV2026-Data | the PDFs, zone-level digitised counts, French and English pillar narratives | bed and hospitalisation fields end 30 May |
| epiforecasts/BVDOutbreakSize | national fitted streams, a national bed-capacity series, a register of signals seen but not fitted | scanning ends at SitRep 089, 11 August |
| bvd-capacity | beds, occupancy and saturation by province, zone and facility | |

BVDOutbreakSize names the gap itself, listing under signals it does not track:
per-province occupancy against beds, local saturation that a single national
bed-capacity series cannot represent. That is the remit.

## Two repositories, one direction

[bvd-sitreps](https://github.com/epiforecasts/bvd-sitreps) publishes a
verified French corpus of the situation reports. This repository reads it by
path and nothing else: it never opens a PDF, and it never sources code from
bvd-sitreps. A change there arrives here as changed files under
`data/corpus/`, which the cache keys notice, never as changed behaviour. If a
question cannot be answered from the corpus, the fix belongs in bvd-sitreps.

The alternative, a package shared between the two, was rejected. It makes
every extraction depend on a version of code that is not recorded in the
output, so a row cannot be traced to the thing that produced it.

## Principles

Place first. Every row carries province, health zone and facility where the
text gives them. A signals table with no place column sums over whichever
places reported that day, and consecutive rows are then not comparable.

Provenance per row. The source quote and report number travel with the value,
in columns. A prose `source =` field describing a whole stream cannot be
diffed or checked.

Absence is data. A quantity a report does not print is recorded as not
reported, never as zero.

Vintages kept. Rows are keyed by report, not only by date, so revisions stay
visible. `006_v2` is a row of its own, not a correction applied to `006`.

Record, don't suppress. Extraction records what the text says. Deciding what
counts is resolution's job, and it happens in code that can be read and
rerun rather than inside a model call that cannot. A facility the report does
not name is recorded with `name_status = unnamed` and kept out of the
register, not dropped at the point of reading.

Judgement flagged, never applied. Where two names might be one facility, both
stay and the pair is flagged. Merging them is a person's decision, recorded in
the registry, and from then on never recomputed.

One deterministic renderer. Extraction and verification see byte-identical
text, so a quote that matched when the model wrote it still matches when the
gate checks it. Two renderers would make every gate failure ambiguous between
a bad model and a bad renderer.

## The quote gate

Every extracted row carries a quote, and the row is kept only if that quote is
a span of the rendered report after normalising whitespace and apostrophes.
There is no exemption route, no allow-list and no confidence threshold that
lets a row through.

The argument for an exemption is always the same: this particular quote is
obviously right, the model only tidied the punctuation. The argument against
is that a model which paraphrases when it is right will paraphrase when it is
wrong, and the row gives no way to tell the two apart. A gate with an
exemption tests the exemption, not the model. When it rejects something
genuine the answer is to fix the renderer, the normaliser or the prompt, all
of which are testable; if none of those is at fault, the row stays out.

Running the gate over the full corpus rejected 100 events. Ninety-two were the
gate's own fault, two bugs in code that could be found and fixed because the
gate had no way to hide them. The remaining fourteen are model errors.

## Later passes

The same corpus, the same renderer and the same gate serve the other contact
points with the health system: laboratories and their throughput, vaccination
sites, burial teams, points of entry. One pass a topic, not one prompt for all
of them. Each needs its own event vocabulary, and a single union vocabulary
would be about thirty values chosen between badly. Extraction is cheap to
repeat on plan quota, so adding a pass later costs roughly one full re-run.

`place_key` exists for this. It identifies the locality rather than the
building, so a later pass keys onto the same place vocabulary without building
a second one. `data/indicators.csv` is the survey of what those passes could
measure.

## Not built

An `aggregates` array alongside the facility events, holding the province and
system-level throughput and occupancy figures the tables carry. Agreed in
principle, deferred until the indicator survey settles which measures are
worth naming.

Province spellings are not normalised: `Bas Uele` and `Bas-Uélé`, `Nord Kivu`,
`Nord-Kivu` and `Nord-kivu` all appear.

A Quarto site, and exports to BDBV2026-Data and BVDOutbreakSize.
