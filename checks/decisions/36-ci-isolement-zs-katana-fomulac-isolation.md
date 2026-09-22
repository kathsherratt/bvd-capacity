`#ai-written`

# Isolation centres at Katana

Cluster `ci-isolement-zs-katana-fomulac`, rank 36 of the review queue, 3 events in the cluster.
2 isolation centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `ci-isolement-zs-katana-fomulac` | isolement de la ZS de Katana (FOMULAC) | isolement de la ZS de Katana (FOMULAC) | 2 | 2 | place known, name not | [none .. 2026-08-14] |
| `ci-isolement-zs-katana` | isolement de la ZS de Katana | isolement de la ZS de Katana | 1 | 1 | place known, name not | [none .. 2026-08-13] |

No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [none .. 2026-08-13].

- `ci-isolement-zs-katana-fomulac`: [none .. 2026-08-14] becomes [none .. 2026-08-13].
- `ci-isolement-zs-katana`: [none .. 2026-08-13] becomes [none .. 2026-08-13].

## The quotes

### `ci-isolement-zs-katana-fomulac`

- SitRep 092, 2026-08-14, `operating`: 6 cas suspects sont suivis à l’isolement de la ZS de Katana (FOMULAC) ;
- SitRep 093, 2026-08-15, `operating`: 7 cas suspects sont suivis à l’isolement de la ZS de Katana (FOMULAC)

### `ci-isolement-zs-katana`

- SitRep 091, 2026-08-13, `operating`: 6 cas suspects sont suivis à l’isolement de la ZS de Katana.

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

