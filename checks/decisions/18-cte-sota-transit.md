`#ai-written`

# Transit centres at Sota

Cluster `cte-sota`, rank 18 of the review queue, 10 events in the cluster.
2 transit centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `ct-sota` | CT Sota | CT Sota; CT SOTA | 7 | 7 | place known, name not | [none .. 2026-07-05] |
| `ct-1ct-sota` | 1CT SOTA | 1CT SOTA | 1 | 1 | place known, name not | [none .. 2026-07-03] |

No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [none .. 2026-07-03].

- `ct-sota`: [none .. 2026-07-05] becomes [none .. 2026-07-03].
- `ct-1ct-sota`: [none .. 2026-07-03] becomes [none .. 2026-07-03].

## The quotes

### `ct-sota`

- SitRep 052, 2026-07-05, `operating`: 4 au CTE Elikya, 3 au CTE Mongbwalu, 3 au CTE Nyankunde, 3 au CT Sota, 2 au CTE Rwampara et 1 au CT Bambu) ont été déclarés guéris
- SitRep 053, 2026-07-06, `operating`: Neuf (9) décès ont été enregistrés parmi les patients atteints de MVE dans les CTE dans les provinces de l’Ituri (2 au CTE ISTM, 1 au CTE de Mongbwalu, 1 au CTE Bunia et 1 au CT Sota)
- SitRep 054, 2026-07-07, `operating`: Cinq (5) patients atteints de la maladie à virus Ebola dans la province de l’Ituri (2 au CT SOTA, 1 au CTE Rwampara
- SitRep 055, 2026-07-08, `operating`: (3 au CTE Bunia, 3 au CTE Rwampara, 3 au CT Nizi, 2 au CTE Mongbwalu, 1 au CTE Nyakunde, 1 au CTE CME, et 1 au CT Sota)

### `ct-1ct-sota`

- SitRep 050, 2026-07-03, `operating`: 1 au CTE de Bunia, 1 au CTE Elikya et 1 au 1CT SOTA) et du Nord-Kivu (2 au CTE Katwa).

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

