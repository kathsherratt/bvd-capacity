# Contributing

Issues and pull requests are very welcome at
[kathsherratt/bvd-capacity](https://github.com/kathsherratt/bvd-capacity).

Feedback, questions, corrections, bug reports, new steps, better prompts: all
of it is welcome, and none of it needs to be polished.

One kind of contribution needs no code at all. The pipeline deliberately
refuses to decide whether two spellings are one facility, and leaves the
question in `registry/facility_aliases.csv` for a person. If you know the
response, or the places, you can answer those directly.
`Rscript R/04_review.R` orders them by how many events depend on each.

## What this repository is for

Turning what the situation reports say about facilities into a dataset, and
being clear about what is not known. It reads the corpus published by
[bvd-sitreps](https://github.com/epiforecasts/bvd-sitreps) by path, and never
opens a PDF.

If a question cannot be answered from `data/corpus/`, the fix belongs in
bvd-sitreps.

## Layout

| path | what it is |
|---|---|
| `R/lib/corpus.R` | the shared renderer and the quote gate |
| `R/lib/places.R` | the GRID3 lookup: canonical province, health zone, reference hospitals |
| `R/00_indicators.R` | a survey of every label the report tables use; no model call |
| `R/01_facilities.R` | the extraction: one model call a report, cached in `data/cache/` |
| `R/02_resolve.R` | verifies every quote, keys the names, derives the two tables |
| `R/03_checks.R` | rebuilds the register by a second implementation and fails if they disagree |
| `R/04_review.R` | orders the open naming judgements by the events at stake |
| `R/05_places.R` | what GRID3 does and does not recognise |
| `R/06_opening.R` | opening dates as intervals |
| `R/07_organisations.R` | who the reports name alongside a facility |
| `tools/grid3-lexicon.R` | rebuilds the committed GRID3 extract; needs `sf` and a BDBV2026-Data checkout |
| `assets/prompt-facilities.md` | the extraction prompt |
| `R/08_decisions.R` | a sheet a naming decision, with the quotes that settle it |
| `R/09_apply_decisions.R` | carries `registry/decisions.csv` into the name vocabulary |
| `tools/decision-cards.R` | the open questions as JSON, for answering them away from a terminal |
| `R/21_external_extract.R` | reads WHO's documents, from the bvd-sitreps corpus, with the same schema and quote gate as the reports |
| `R/22_external_match.R` | says what each external mention corroborates, and what it names that the register lacks |
| `R/23_registers_suggest.R` | asks GRID3 and OpenStreetMap about each open naming decision |
| `tools/osm-places.R` | rebuilds the OpenStreetMap extract through Overpass |
| `registry/facility_aliases.csv` | the name vocabulary, the only file meant to be edited by hand |

`checks/` is committed, because each file is a decision waiting for a person.
`data/cache/`, one model reply a report, is not: it is machine output, and the
datasets derived from it are committed instead. Nor is `runs/`, which holds
logs, raw model output and the spend ledger.

## Running it

```sh
Rscript R/01_facilities.R          # model calls; --only=, --force, --cache=
Rscript R/02_resolve.R             # no model calls
Rscript R/03_checks.R              # exit 1 on any failure
```

Steps 2 onwards need no model access, but they read `data/cache/`, which is
not committed. A clone can therefore check, query and correct the datasets as
they stand, and rebuilding them from the reports means rerunning step 1: about
three hours over 116 reports, run detached. A correction to the register or a
decision needs no model at all.

`BVD_SITREPS` points at a bvd-sitreps checkout; the default is a sibling
clone.

## Five rules to know before changing anything

These are the load-bearing decisions. Everything else is open to argument.

The quote gate has no exemption. A row is kept only if its sentence is a span
of the rendered report, with no allow-list and no confidence threshold. A
model that paraphrases when it is right will paraphrase when it is wrong, and
the row gives no way to tell which. When the gate rejects something genuine,
the fix is in the renderer, the normaliser or the prompt, all of which are
testable; if none of those is at fault, the row stays out. Over the full
corpus the gate rejected 100 events, 92 of which turned out to be bugs here.

Extraction records, resolution decides. A facility the report does not name is
recorded with `name_status = unnamed`, not dropped at the point of reading, so
what counts is decided in code that can be read and rerun.

Judgement is flagged, never applied. Where two names might be one facility,
both stay and the pair is flagged. Merging them is a person's decision,
recorded with `reviewed = TRUE` and never recomputed after that.

A kind of site is a structure, not a spelling. A treatment centre, a transit
centre and an isolation centre at one hospital are three facilities, and no
decision merges across `site_kind`. The reports name all three by their host
(`CTE de l'HGR Bunia`, `CT HGR Bunia`, `CI HGR Bunia`), so the
`possible_same_host` and `possible_host_variant` flags group them together;
that grouping says they share a building, which is not the same claim. Merging
across kinds drags a centre's opening earlier, because the hospital was
isolating patients months before the centre was built beside it. A merge
decision compares names within one `site_kind`.

GRID3 constrains, it never overrides. What a report says about a province or
health zone is kept; the lookup only fills gaps and raises flags. Built the
other way round it moves facilities between provinces, which it did twenty
times in testing.

## Making a naming decision

The reports spell one facility several ways and spell several facilities one
way, so some names cannot be resolved by code. Those questions are collected,
ranked by the events that depend on them, and answered by a person.

1. Read the sheet in `checks/decisions/`, one per question. It holds the
   candidate names, what GRID3 recognises, whether any report names more than
   one of them, what merging would do to the opening interval, and the quotes
   the bounds come from.
2. Add a row to `registry/decisions.csv` with the verdict, your name, the
   date, and a reason. `same` needs a `merged_into` id: the id the other names
   fold into, conventionally the one already carrying the most events.
3. Run `Rscript R/09_apply_decisions.R`, then `R/02_resolve.R`, which is
   what carries the decision into the data, then `R/03_checks.R` and
   `R/06_opening.R`. Applying a decision without resolving again leaves the
   events pointing at ids the registry no longer has, and `R/03_checks.R`
   says so.

Disagreeing with a recorded decision is an ordinary pull request: change the
verdict and the reason, rerun, and say in the description what the quotes show.
The decision belongs to whoever can read the evidence, not to whoever ran the
pipeline first.

## Conventions

R with data.table and `here::here()` for paths. CSV for data, one script a
step, each runnable on its own with `Rscript`.

Cache keys carry every input: the corpus build key, the prompt hash, the
schema hash and the model. If you change what a step depends on, put it in the
key.

Every file carries an authorship tag, `#ai-written` or `#ai-input`.

British English in prose, sentence case headings, no bold or italics in
documentation, and tables in preference to prose where a claim can be one.

## Pull requests

Please say what you ran and what the counts were before and after.
`R/03_checks.R` prints them, and a facility count that moves without
explanation is the thing worth catching.

A change to `assets/prompt-facilities.md` or the model pin invalidates the
whole cache and costs a full re-run, so it helps to say why.

## Use of AI

The pipeline code was drafted by a language model under human direction, and
commits carry a `Commit-Via` trailer recording that. The extraction is model
output by design, which is why the quote gate exists. The named author is
responsible for the oversight.
