`#ai-written`

# Treatment centres at Mongbwalu

Cluster `site-hgr-mongwalu`, rank 5 of the review queue, 53 events in the cluster.
2 treatment centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-mongbwalu` | CTE de Mongbwalu | CTE à Mongbwalu; CTE de Mongbwalu; CTE Mongbwalu; CTE Mongwalu; Mongbwalu | 24 | 25 | place known, name not | [none .. 2026-05-19] |
| `cte-hgr-mongbwalu` | CTE de l’HGR Mongbwalu | CTE de l’HGR Mongbwalu | 2 | 2 | place known, name not | [none .. 2026-06-19] |

No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [none .. 2026-05-19].

- `cte-mongbwalu`: [none .. 2026-05-19] becomes [none .. 2026-05-19].
- `cte-hgr-mongbwalu`: [none .. 2026-06-19] becomes [none .. 2026-05-19].

## The quotes

### `cte-mongbwalu`

- SitRep 008, 2026-05-22, `under_construction`: ❖ Suivi des travaux d’installation de tentes de prise en charge à l’HGR Bunia (ALIMA et OMS) et d’installation du CTE à Mongbwalu par MSF
- SitRep 092, 2026-08-14, `opened`: Le nouveau CTE de Mongbwalu a été inauguré
- SitRep 095, 2026-08-17, `opened`: le nouveau bâtiment du CTE de Mongbwalu est opérationnel avec 60 lits.
- SitRep 005, 2026-05-19, `operating`: Briefing de 3 prestataires de CTE Mongwalu sur les précautions standard,

### `cte-hgr-mongbwalu`

- SitRep 036, 2026-06-19, `operating`: 1 alerte vivante évadée du CTE de l’HGR Mongbwalu, interceptée, au PoC PLUTO
- SitRep 041, 2026-06-24, `operating`: retour de 5 évadés suspects de l’AS Saio vers le CTE de l’HGR Mongbwalu

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

