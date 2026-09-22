`#ai-written`

# Treatment centres at Isiro

Cluster `site-hgr-isiro`, rank 8 of the review queue, 36 events in the cluster.
2 treatment centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-isiro` | CTE d'Isiro | celui d’Isiro; CT/CTE d'Isiro; CTE d'Isiro; CTE d’Isiro; CTE de l’HGR d’Isiro; Isiro | 19 | 25 | place known, name not | [none .. 2026-07-30] |
| `cte-cth-isiro` | CTH d’Isiro | CTH d’Isiro | 1 | 1 | place known, name not | [none .. 2026-08-12] |

## Already decided, in part

`cte-isiro__treatment__pronoun` was decided **same** by claude-code on 2026-09-23, over `cte-celui-isiro`, `cte-isiro`.
Since then `cte-cth-isiro` joined the group, which is why it is asked again.
Reason given: celui d Isiro is a pronoun standing for the CTE named earlier in the sentence: le CTE de Pawa manque d installations hygieniques et celui d Isiro d espace. Not a second centre.

`site-hgr-isiro__treatment` was decided **same** by kathsherratt on 2026-09-22, over `cte-hgr-isiro`, `cte-isiro`.
Since then `cte-cth-isiro` joined the group, which is why it is asked again.


No report names two of them, which is what a spelling variant looks like.

## What merging would do

Merged, the opening interval becomes [none .. 2026-07-30].

- `cte-isiro`: [none .. 2026-07-30] becomes [none .. 2026-07-30].
- `cte-cth-isiro`: [none .. 2026-08-12] becomes [none .. 2026-07-30].

## The quotes

### `cte-isiro`

- SitRep 080, 2026-08-02, `opened`: démarrage du service au CTE d'Isiro
- SitRep 080, 2026-08-02, `under_construction`: démarrage du service au CTE d'Isiro et travaux d'aménagement.
- SitRep 107, 2026-08-29, `under_construction`: reprise des travaux d’installation du CTE d’Isiro
- SitRep 118, 2026-09-09, `under_construction`: livraison d’une table et de 4 chaises au pilier surveillance pour l’installation d’un bureau au CTE d’Isiro et suivi des travaux d’installation de ce CTE

### `cte-cth-isiro`

- SitRep 090, 2026-08-12, `operating`: et 4 guéris ont été déchargés au CTH d’Isiro

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

