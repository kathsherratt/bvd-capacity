`#ai-written`

# Isolation centres at Konga Konga

Cluster `ci-konga-konga`, rank 29 of the review queue, 4 events in the cluster.
2 isolation centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `ci-konga-konga` | Konga-Konga | Konga-Konga; sites d’isolement de Kongakonga | 3 | 3 | confirmed in zone (Centre de Santé) | [2026-09-04 .. none] |
| `ci-isolements-konga-konga` | isolements (KONGA KONGA) | isolements (KONGA KONGA) | 1 | 1 | place known, name not | [2026-08-27 .. none] |

No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [2026-09-04 .. none].

- `ci-konga-konga`: [2026-09-04 .. none] becomes [2026-09-04 .. none].
- `ci-isolements-konga-konga`: [2026-08-27 .. none] becomes [2026-09-04 .. none].

## The quotes

### `ci-konga-konga`

- SitRep 107, 2026-08-29, `under_construction`: construction des sites d’isolement (Madula, Kabondo et Konga-Konga)
- SitRep 108, 2026-08-30, `under_construction`: suivi de la construction des sites d’isolement de Madula, Kabondo et Konga-Konga
- SitRep 113, 2026-09-04, `under_construction`: poursuite de la construction des sites d’isolement de Kongakonga, Madula et Kabondo

### `ci-isolements-konga-konga`

- SitRep 105, 2026-08-27, `under_construction`: Construction des isolements (KONGA KONGA)

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

