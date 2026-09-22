`#ai-input`

# Contributing

Issues and pull requests are welcome.

The most useful contribution is a judgement. The pipeline deliberately refuses
to decide whether two spellings are one facility, and leaves the question in
`registry/facility_aliases.csv` for a person. If you know the outbreak
response, resolving those is worth more than any code change. Run
`Rscript R/04_review.R` to see which decisions carry the most events.

## What this repository is for

Turning what the situation reports say about facilities into a dataset, and
being honest about what is not known. It reads the corpus published by
[bvd-sitreps](https://github.com/epiforecasts/bvd-sitreps) by path, never
opens a PDF, and never sources code from that repository. A change there
reaches here as changed files, which the cache keys notice, not as changed
behaviour.

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
| `registry/facility_aliases.csv` | the name vocabulary, the only file meant to be edited by hand |

`data/cache/` is committed, because each entry costs a model call to remake.
`outputs/` is not.

## Running it

```sh
Rscript R/01_facilities.R          # model calls; --only=, --force, --cache=
Rscript R/02_resolve.R             # no model calls
Rscript R/03_checks.R              # exit 1 on any failure
```

Steps 2 onwards need no model access, so anyone with a clone can reproduce the
dataset from the committed cache. Only step 1 needs a model, and it takes
about three hours over 116 reports; run it detached.

`BVD_SITREPS` points at a bvd-sitreps checkout; the default is a sibling
clone.

## The rules that are not negotiable

**The quote gate has no exemption.** Every row carries the sentence it came
from, and the row is kept only if that sentence is a span of the rendered
report after normalising whitespace and apostrophes. There is no allow-list
and no confidence threshold that lets a row through.

The argument for an exemption is always that this particular quote is
obviously right and the model only tidied the punctuation. The argument
against is that a model which paraphrases when it is right will paraphrase
when it is wrong, and the row gives no way to tell the two apart. When the
gate rejects something genuine, fix the renderer, the normaliser or the
prompt, all of which are testable. If none of those is at fault, the row stays
out. Running the gate over the full corpus rejected 100 events, of which 92
were bugs in this repository's own code, found because the gate had no way to
hide them.

**Extraction records, resolution decides.** A facility the report does not
name is recorded with `name_status = unnamed`, not dropped at the point of
reading. What counts is decided in code that can be read and rerun, not
inside a model call that cannot.

**Judgement is flagged, never applied.** Where two names might be one
facility, both stay and the pair is flagged. Merging them is a person's
decision, recorded in the registry with `reviewed = TRUE`, and from then on
never recomputed.

**GRID3 constrains, it never overrides.** What a report says about a province
or health zone is kept. The lookup fills gaps and raises flags. Built the
other way round it silently moves facilities between provinces, which it did
twenty times in testing.

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

Say what you ran and what the counts were before and after. `R/03_checks.R`
prints them, and a change that moves a facility count without explanation is
the thing reviewers should catch.

A change to `assets/prompt-facilities.md` or the model pin invalidates the
whole cache and costs a full re-run, so it needs a reason in the commit.

## Use of AI

The pipeline code was drafted by a language model under human direction, and
commits carry a `Commit-Via` trailer recording that. The extraction is model
output by design, which is why the quote gate exists. The named author is
responsible for the oversight.
