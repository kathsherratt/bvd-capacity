`#ai-written`

# Treatment centres at Kitatumba, Butembo

Cluster `cte-kitatumba`, rank 13 of the review queue, 16 events in the cluster.
2 treatment centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-kitatumba` | CTE de Kitatumba | CTE de Kitatumba; CTE Kitatumba; Kitatumba | 11 | 12 | place known, name not | [none .. 2026-07-06] |
| `cte-butembo` | CTE Butembo | CTE Butembo; CTE/CT de Butembo | 4 | 4 | place known, name not | [none .. 2026-07-06] |

1 report name more than one of them. A report naming both is a report telling them apart, so a merge needs a reason.

## What merging would do

Merged, the opening interval becomes [none .. 2026-07-06].

- `cte-kitatumba`: [none .. 2026-07-06] becomes [none .. 2026-07-06].
- `cte-butembo`: [none .. 2026-07-06] becomes [none .. 2026-07-06].

## The quotes

### `cte-kitatumba`

- SitRep 053, 2026-07-06, `incident`: Incendie criminelle au CTE Kitatumba (dégâts réduits grâce à l’intervention de la police) au Nord-Kivu.
- SitRep 056, 2026-07-09, `operating`: Au CTE Kitatumba, les éléments de la PNC affectés au site ont été briefés sur le respect strict des mesures barrières.
- SitRep 085, 2026-08-07, `operating`: 1 échec au Nord-Kivu (CTE de Kitatumba, Butembo)
- SitRep 094, 2026-08-16, `operating`: 48 sorties dont 2 guéris au CTE de Kitatumba.

### `cte-butembo`

- SitRep 053, 2026-07-06, `operating`: et du Nord-Kivu (2 au CTE Beni, 1 au CTE Butembo et 1 au CTE Katwa).
- SitRep 058, 2026-07-11, `operating`: (4 au CTE Mongbwalu, 2 au CTE Elikya, 1 au CTE Rwampara, 1 au CT Sota et 1 au CT HGR Nia-Nia) et au Nord-Kivu (1 au CTE Butembo).
- SitRep 061, 2026-07-14, `operating`: 1 au CTE Butembo).
- SitRep 121, 2026-09-12, `strained`: sans aucun lit disponible dans les CTE/CT de Butembo et Katwa

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

