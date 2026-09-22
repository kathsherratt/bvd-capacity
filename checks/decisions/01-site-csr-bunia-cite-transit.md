`#ai-written`

# Transit centres at Bunia

Cluster `site-csr-bunia-cite`, rank 1 of the review queue, 170 events in the cluster.
2 transit centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `ct-bunia` | CT Bunia | CT Bunia | 2 | 2 | place known, name not | [none .. 2026-05-23] |
| `ct-hgr-bunia` | CT HGR Bunia | CT HGR Bunia | 1 | 1 | place known, name not | [none .. 2026-07-14] |

No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [none .. 2026-05-23].

- `ct-bunia`: [none .. 2026-05-23] becomes [none .. 2026-05-23].
- `ct-hgr-bunia`: [none .. 2026-07-14] becomes [none .. 2026-05-23].

## The quotes

### `ct-bunia`

- SitRep 009, 2026-05-23, `operating`: Supervision conjointe PCI- PEC du CT Bunia pour la définition du circuit;
- SitRep 104, 2026-08-26, `operating`: toutes validées, isolées et référées au CT Bunia et au CT Elikia ;

### `ct-hgr-bunia`

- SitRep 061, 2026-07-14, `operating`: 1 au CT HGR Bunia,

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

