# Plan: Ebola treatment centre opening dates from the INSP sitrep corpus

Handover for a fresh session. Written 2026-09-17 03:10, updated 2026-09-21. Delete this file once the work is merged.

## Goal

A dataset of Ebola treatment facilities (CTE, CT, CI, and hospital isolation sites) named in the INSP situation reports for the 2026 DRC Bundibugyo outbreak: one row per facility with location, first mention, announced opening, first evidence of being in service, latest status. Every value traces to a verbatim French quote in a named report. Requested by the Oxford team; public data only.

Later consumers of the same corpus (treatment capacity, care-seeking) will sit beside this in bvd-capacity. Build for ETC dates only now.

## The two repositories

| | role | state |
|---|---|---|
| `~/Documents/Github/bvd-sitreps` (epiforecasts/bvd-sitreps) | fetches PDFs, publishes the corpus. Knows nothing about facilities | branch `rebuild-corpus` pushed, 5 commits ahead of `main`, no PR opened. Corpus and English pages complete |
| `~/Documents/Github/bvd-capacity` (kathsherratt/bvd-capacity, private) | reads the corpus by path, extracts facilities | branch `etc-dates` pushed. Steps 1 and 2 written, no model call made yet |

Rule: bvd-capacity never opens a PDF and never sources code from bvd-sitreps. It depends on bvd-sitreps' data only. If something cannot be answered from the corpus, fix it in bvd-sitreps.

## State of the corpus (updated 2026-09-21)

Complete and passing. 116 of 116 reports built; `Rscript R/05-check-corpus.R` prints PASS (lowest numeric recall 0.9655, 748 tables). Table CSVs written (`R/03-tables-to-csv.R`). All 116 English pages translated through agy and rendered (`173c563`); 113 needed a reviewed row in `assets/translate-exemptions.csv` for `fonctionnel 24h/24` against `operational 24/7`.

- 114 reports on `gemini-3.1-pro-preview`; 008 and 016 on `gemini-3.8-flash`, recorded with reasons in `bvd-sitreps/assets/model-overrides.csv` (pro looped on 008 and dropped page-1 headline figures on 016).
- 12 chart axis ticks in 031 are exempted after review in `bvd-sitreps/data/corpus-qa-exemptions.csv`.
- Spend on the key so far: $42.76 logged in `bvd-sitreps/outputs/gemini-ledger.csv`, plus ~$1.50 unlogged.
- At 10:40 the API key (`...1ZEQ`) ran out of prepaid credit. The user will not spend more. Everything after that runs through the Antigravity CLI on the user's Ultra plan instead, at no per-call cost (see "The agy route" below).
- All of it is committed and pushed on `rebuild-corpus`, through `173c563`.
- Translation ran at 30-70 s a report on `agy:gemini-3.8-flash-low`. Ledger at 266 calls.
- `data/corpus/fr/109_files/mediabag` is an empty Quarto render artefact left in the corpus directory, untracked. Worth deleting in bvd-sitreps.

Exit status 3 from `02` or `04` means a clean stop on quota or budget; rerun to resume, finished reports are cached.

## Corpus format (what bvd-capacity reads)

Root: `$BVD_SITREPS/data/corpus/` (default sibling `../bvd-sitreps`). Ids are three-digit sitrep numbers, `_v2` for a reissue (only `006_v2`). 115 report numbers exist; 003, 029, 043, 045, 063, 075, 076 were never published.

`fr/<id>.md`: French transcription, not translated. YAML-ish front matter, one `key: value` per line between `---` lines:

```
id, sitrep, sitrep_indexed, report_date (YYYY-MM-DD, from "Date de rapportage"),
publication_date, pdf_md5, pdf_url, model, build_key, built, lang
```

Body: one sentence per line; `[PHOTO]`, `[FIGURE: caption]` and `[TABLE_n]` markers on their own lines. Tables are not in the body.

`tables/<id>.json`:

```json
{"id": "040", "sitrep": "040", "report_date": "2026-06-23", "pdf_md5": "...",
 "tables": [{"n": 1, "caption": "Tableau 1. ...", "columns": ["..."],
             "rows": [{"cells": ["Ituri", "1020", "238", "23,3%"]}]}]}
```

Every row has as many cells as `columns`. Spanning cells are repeated on each row; group-heading rows are folded into row labels. Tables matter here: early reports list facilities as table columns (e.g. SitRep 006 bed table headed `Bunia HGR`, `Bunia SOFEPADI`, `Rwampara CME`...).

## Done so far in bvd-capacity (branch `etc-dates`)

- `git rm` of the prototype: `R/02_text.R`, `R/03_parse.R`, `R/05_build.R`, `R/06_checks.R`, `data/text/`, `data/registry/`, `data/observations/`, `data/derived/`. Kept `LICENSE`, `README.md`, `DESIGN.md`, `dictionary.md` (all three describe the prototype and need rewriting). `runs/` is gitignored.
- `R/lib/paths.R`: `sitreps_root()`, `corpus_dir(...)`, `sitreps_manifest_path()`, `cache_dir(...)` (`data/cache/`, committed), `registry_path()` (`registry/facility_aliases.csv`), `events_path()` (`data/facility_events.csv`), `facilities_path()` (`data/facilities.csv`), `rejected_path()` (`checks/rejected_events.csv`), `ensure_dirs()`.
- `R/lib/corpus.R`: `corpus_ids()`, `read_report()`, `render_report()`, `normalise_for_match()`, `quote_matches()`. Step 1 as specified below. Verified: renders byte-identically across calls, all 116 ids resolve, SitRep 006 Tableau VI keeps its facility column headers, a header slice passes the gate and a paraphrase fails it.
- `assets/prompt-facilities.md` and `R/01_facilities.R`: step 2 as specified below, with `--only`, `--force` and `--cache=DIR`. Payload is 23.5k characters median and 38.5k worst case, so roughly 33k input tokens a call on the agy route. Nothing has been through a live model.
- `R/lib/gemini.R`: copy of bvd-sitreps' client, including the later fixes (retries dropped connections, logs usage before raising on a bad finish, optional `thinking_level`). `gemini(parts, schema, model = GEMINI_MODEL_EXTRACT, temperature = 0, label)` returns parsed JSON from a `responseSchema` call. Pin `GEMINI_MODEL_EXTRACT` defaults to `gemini-3.1-pro-preview` (unvalidated for extraction; see step 2). Handles: per-minute 429 retries honouring `retryDelay`; daily-quota, billing and budget stops raised as class `gemini_quota_stop`; `GEMINI_BUDGET_USD` checked before each call against a ledger; `GEMINI_LEDGER` env var to share one ledger across repos; `GEMINI_PRICES` table (add any new model before budgeting it); `gemini_pdf_part()`, `gemini_text_part()`, `gemini_models()`, `gemini_spent()`.
- Empty `registry/`, `data/cache/`.

Still to do, in order: the model comparison in step 2, the full extraction run, then steps 3 to 5.

## Remaining steps

### 1. `R/lib/corpus.R`: read and render a report

Shared by extraction and verification, so the quote check runs on exactly the text the model was shown.

- `corpus_ids()`: ids with both `fr/<id>.md` and `tables/<id>.json`.
- `read_report(id)`: list with `meta` (front matter as named list), `body`, `tables`.
- `render_report(id)`: body with each `[TABLE_n]` replaced by the table rendered as pipe rows (`caption` line, then `| col | col |`, then one line per row). Append any table whose marker is missing. Deterministic: same corpus file, same string.
- `normalise_for_match(x)`: collapse whitespace, map `’ ‘` to `'`, `“ ” « »` spacing left alone but NBSP and narrow NBSP to space. Applied to both quote and text. Nothing else; do not strip accents or case.

### 2. `assets/prompt-facilities.md` and `R/01_facilities.R`: one call per report

Input to the model: the prompt, then `render_report(id)` as text. Output schema, one object:

```
events: [{
  facility_raw      as written ("CTE de Nizi", "HGR Bunia", "un CTE de 100 lits")
  facility_type_raw type prefix as written, "" if none (CTE, CT, CTC, CI, HGR, CH, CS, ...)
  site_kind         treatment_centre | transit_centre | isolation_centre | hospital_isolation | other
  name_status       named | unnamed | ambiguous
  place_raw         town, site or locality as written, "" if not given
  health_zone       as written, "" if not given
  province          as written, "" if not given
  event             planned | under_construction | opened | operating | expanded | strained | incident | closed | mention_only
  event_date        YYYY-MM-DD only if the text states the date of this event; else ""
  beds              bed capacity stated for this facility, digits as a string; else "". Patients are not beds
  status_note       one short English sentence, translating not interpreting
  evidence_quote    contiguous span copied character for character, 20-200 chars, containing the facility name
  confidence        high | low
}]
```

Prompt content: carry over the event table and rules 1, 2, 3, 6, 7 from `~/Documents/Github/bvd-internal-cmmid/skills/etc-facilities/prompts/facility-events.md` (one event per facility per event value per report; `mention_only` is normal; a referral means `operating`; no outside knowledge; quotes checked verbatim). Drop everything about batches, passages, registries, OCR and column interleaving; none applies to the corpus. Add: include hospital isolation sites where the text shows Ebola patients isolated or treated there (early reports use `HGR Bunia`, `CH Elikya`, `SOFEPADI` before CTEs exist; the old register missed these); a facility named in a table header or row label is a mention, and the quote is that header or row as rendered; `opened` is an announcement of opening, inauguration, mise en service or rendu opérationnel, not the first patient.

Nothing is dropped for being unnamed. A facility the report describes but does not name (`un CTE de 100 lits`, `le CTE de fortune`), or names ambiguously (`Rwampara` where both HGR and CME Rwampara exist), is recorded with `name_status` and resolved, or not, in step 3. Asking the model to suppress these makes the loss invisible; a flag is recoverable. Measured on the corpus: about 15 to 20 such mentions carry a bed count, opening wording or a bracketed list of names, so the volume is small.

What must stay out is the other thing an unnamed `CTE` usually means: a count over all of them ("12 décès dans les CTE ont été enregistrés", "les CTE/CT ont enregistré 127 nouvelles admissions"). That is roughly 398 of the 1210 prose mentions, it is province-level throughput rather than a facility event, and letting it in would swamp the register. It deserves a pass of its own later; see "Later passes".

Cache: `data/cache/<id>.json` holding `id`, `report_date`, `extract_key`, `model`, `events`. `extract_key` = the corpus file's `build_key` + md5 of the prompt + md5 of the schema + model. Skip when the key matches. Keying on anything less means a prompt fix silently misses reports already read (this bit bvd-sitreps once).

Loop pattern (copy from `bvd-sitreps/R/02-build-corpus.R`): `for` loop with `tryCatch(..., gemini_quota_stop = function(e) { quota <<- e; "stopped" }, error = ...)`, `break` on quota, exit 3 on quota stop, exit 1 on failures. Flags `--only=001,040` and `--force`.

Model choice, before the full run: extract 005, 006, 040 and one late report with each candidate and compare facility sets, events and quote rejects. Write the reason in the header comment of `01_facilities.R`. No API credit is left, so run the comparison and extraction with `GEMINI_BACKEND=agy` (see "The agy route"). Compare `gemini-3.1-pro-low`, `gemini-3.1-pro-high` and `gemini-3.8-flash-low` via `AGY_MODEL`, and watch `thinking_tokens` in the ledger: a high-thinking run that climbs past ~50k thinking tokens is looping, not reasoning. Quota, not money, is the constraint.

Run with one budget across both repos:

```bash
export GEMINI_LEDGER=~/Documents/Github/bvd-sitreps/outputs/gemini-ledger.csv
export GEMINI_BACKEND=agy          # plan quota, no per-call cost
export AGY_MODEL=gemini-3.1-pro-low   # or whatever the comparison chose
nohup caffeinate -is Rscript R/01_facilities.R > runs/logs/facilities_$(date +%F-%H%M).log 2>&1 &
```


### 3. `R/02_resolve.R`: verify, register, derive

In order:

1. Read every cache file. Verify each `evidence_quote`: `normalise_for_match(quote)` must be a substring of `normalise_for_match(render_report(id))` and must contain `facility_raw` (normalised). Failures go to `checks/rejected_events.csv` with the reason and are dropped.
2. Place key and name key. The place key is the locality (`bunia`, `mongbwalu`, `nizi`), from `place_raw` where the model gave one and from the facility name otherwise; it is a column of the registry in its own right, not something baked only into `facility_id`. Later passes over this corpus (laboratories, vaccination sites, burial teams, points of entry) key on the same places rather than building a second name vocabulary, and `CTE de l'HGR Bunia` and `HGR Bunia` are two facilities at one place.

   The name key identifies the facility: fold accents (`iconv` to ASCII//TRANSLIT, then drop `'`^~"` which macOS inserts), lowercase, remove type prefixes and their spelled-out forms (`centre de traitement ebola`, `centre de transit`, `centre d'isolement`, CTE, CTC, CT, CI), remove `de du d' de la l' des`, collapse punctuation to single spaces. Type class from `site_kind`.
3. Registry `registry/facility_aliases.csv`, columns `facility_raw, name_key, place_key, site_kind, facility_id, reviewed, note`. An event whose `name_status` is `unnamed` or `ambiguous` gets no `facility_id` and no registry row; it keeps its place and health zone and stays in the events table for a person to attach or leave. Nothing about it reaches `facilities.csv`. Rows with `reviewed = TRUE` are hand decisions and win. New spellings are appended with `reviewed = FALSE` and an automatic `facility_id` = `<site_kind prefix>-<name_key slug>` (`cte-bunia`, `ct-kigonze`, `hosp-hgr-bunia`). Never rename an existing `facility_id`.
4. Flags, not merges, for judgement calls: same `name_key` with different `site_kind` (`CT Bunia` vs `CTE Bunia`) gets `possible_same_site`; keys within `adist` 2 of each other, both 6+ characters, same `site_kind`, get `possible_spelling_variant` (INSP writes Mongbwalu, Mungbwalu and Mongwalu). A person resolves these by editing the registry and setting `reviewed = TRUE`.
5. Write `data/facility_events.csv`: `sitrep, report_date, facility_id, facility_raw, name_status, site_kind, place_key, place_raw, event, event_date, beds, health_zone, province, status_note, evidence_quote, confidence`. `facility_id` is empty for an unresolved row. `report_date` from corpus front matter, never from the model.
6. Write `data/facilities.csv` from the rows that carry a `facility_id`, every column derived from events:
   - `facility_id, facility_name` (most frequent raw spelling), `site_kind`, `health_zone`, `province` (most frequent non-empty)
   - `date_first_mentioned, sitrep_first_mentioned`
   - `first_mention_after_gap`: TRUE if the sitrep number before the first mention was never published, so the true first mention may be earlier
   - `date_first_planned` (earliest `planned` or `under_construction`)
   - `date_opening_announced, sitrep_opening_announced, date_opening_stated` (earliest `opened`; `date_opening_stated` is its `event_date` if given)
   - `date_first_in_service` (earliest `operating`, `expanded`, `strained` or `incident`)
   - `status_latest, status_latest_date` (latest non-`mention_only` event)
   - `beds_latest, beds_latest_date`
   - `date_last_mentioned, n_sitreps, aliases, flags`

Keep announced opening and first in service separate. The old register found nine facilities with an announced opening, and CTE Beni with patients from 29 June but an official opening on 4 July.

### 4. `R/03_checks.R`: gate

Fail (exit 1) if: `checks/rejected_events.csv` has rows; any event value outside the closed vocabulary; any non-empty `facility_id` absent from the registry; any `named` event without a `facility_id`; any `report_date` outside the corpus range; any facilities row whose dates cannot be recomputed from events; any registry `facility_id` claimed by two different `site_kind` values. Print counts: facilities by `site_kind` and province, events by type, unreviewed registry rows, flagged rows.

Do not relax the quote check to make rejects disappear. A reject is fixed by rerunning that report with a better prompt, or it stays out.

### 5. Documentation

Rewrite `README.md` (what, coverage, method, limitations, running), `dictionary.md` (columns of the three outputs), and replace `DESIGN.md` or cut it to principles that still hold. Its "Principles" section (place first, provenance per row, absence is data, vintages kept) still applies. Add a `.gitignore` line check: `data/cache/` and `checks/` are committed, `runs/` is not.

## Later passes

The same corpus, the same renderer and the same quote gate serve the other contact points with the health system, one pass a topic rather than one prompt for all of them. Each needs its own event vocabulary (a laboratory opens, has throughput and runs out of reagent; a burial team deploys and performs burials), and a single union vocabulary would be about thirty values chosen between badly. Extraction is cheap to repeat on plan quota, so the cost of adding a pass later is roughly one full re-run.

Coverage in the corpus, of 116 reports: laboratories 116, burials 116, points of entry 111, transit centres 103, vaccination 58.

Separate from those, and probably first: province-level treatment throughput from the statements this pass excludes ("les CTE/CT ont enregistré 127 nouvelles admissions"). That is the question the repository is named for and no pass currently captures it.

## Verification

1. `Rscript R/01_facilities.R --only=005,006,040` then `R/02_resolve.R` then `R/03_checks.R` passes.
2. SitRep 006: the bed table's facility columns (HGR, SOFEPADI, Clinique Bénedicte, RWAOLE, CH ELIKYA in Bunia; HGR, CME, CH SALAMA, CS HOHO in Rwampara; HGR Mongbwalu; HGR Nyankunde) appear as `hospital_isolation` or `treatment_centre` facilities with `operating` events.
3. Full run, then compare `data/facilities.csv` with `~/Documents/Github/bvd-internal-cmmid/skills/etc-facilities/results/etc_facilities.csv` (55 facilities, 443 events, built from the lossy mirror). Read-only comparison. Account for every facility in one and not the other: expect gains from the 20 reports the mirror lacked (it held 95 report numbers; INSP has 115) and from hospital isolation sites; anything the old register had and the new one lacks is a regression to explain. Check the nine facilities with announced openings and CTE Beni's dates.
4. Spot-check three facilities against the source PDFs (`bvd-sitreps/data/pdf/<id>.pdf`): one with an announced opening, one known only from in-service evidence, one known only from a saturation list.

## The agy route

`R/lib/gemini.R` in both repositories has a second backend. `GEMINI_BACKEND=agy` sends each `gemini()` call through `~/.gemini/bin/agy -p ... --output-format json --json-schema <file> --model <id>`, run from an empty temp directory with an instruction not to use tools. Scripts do not change: `gemini()` returns the same parsed object.

- Models: `agy models` lists them. The client maps API ids (`gemini-3.1-pro-preview` -> `gemini-3.1-pro-high`, `thinking_level = "low"` -> `-low`); `AGY_MODEL` overrides.
- Text parts only. PDFs stay on the API.
- Quota: Ultra plan, unpublished amount, refreshes every five hours within a weekly limit. A quota message raises `gemini_quota_stop` (kind `agy_quota`), the loop stops, exit 3; rerun later. The user should set Antigravity's AI Credit Overages to Never.
- Each call carries ~20-35k tokens of agent context. Ledger rows have `key_tail = agy` and `cost_usd = 0`.
- No temperature control, so reruns vary more than on the API. The verbatim quote gate matters more, not less.
- Raw stdout and stderr of every call are saved to `runs/logs/agy/<label>_<time>_attempt<n>.*`. Read these first when a call fails.
- Measured on translation: flash-high on SitRep 005 spent 80-120k thinking tokens and 530k total over two attempts and returned nothing; flash-low did the whole report in 12 s with no thinking tokens. Start extraction tests on low.

## Traps already hit in this work

- Rscript reads its `--file` script a piece at a time. Editing a script while Rscript is running it corrupts the rest of the run. Files it has `source()`d are read whole and are safe to edit.
- `paste(a, NULL, sep = ":")` gives `"a:"`, not `"a"`. Build keys with `paste(c(...), collapse = ":")`.
- Check cache keys offline before any rerun: compute each report's key and compare with the stored one. That caught two bugs that would each have rebuilt the whole corpus.
- Pro on some reports: thinking can fill the 65k output limit, and `thinkingLevel = "low"` truncates. Switching that report to flash worked; record it rather than passing a flag once.

- data.table scoping: inside `dt[...]`, a loop variable with the same name as a column (`id`) silently resolves to the column. Use `dt[match(this_id, dt$id)]` or a differently named variable.
- Define `%||%` before first use in any script that does not source `gemini.R`.
- `tools::md5sum` and `digest::digest(x, algo = "md5", serialize = FALSE)` for text; `serialize = TRUE` (default) for R objects such as schemas.
- Long runs detached with `nohup caffeinate -is ... > runs/logs/... 2>&1 &`; poll the log. The IDE extension host crashes under memory pressure and takes attached jobs with it.
- Commit only when asked. Commit trailer: `Commit-Via: LLM from @kathsherratt`; no Co-Authored-By.
- Writing style for docs: no bold or italics, short sentences, tables over prose, no statements of the obvious.
