`#ai-written`

# Treatment centres at Katwa

Cluster `cte-katwa`, rank 6 of the review queue, 42 events in the cluster.
2 treatment centres to decide between.

## The question

Are these 2 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-katwa` | CTE de Katwa | CTE à Katwa; CTE de Katwa; CTE en construction à Katwa; CTE Katwa; Katwa | 32 | 35 | place known, name not | [2026-06-03 .. 2026-06-07] |
| `cte-hgr-katwa` | HGR Katwa | CTE à l’HGR Katwa; HGR de Katwa; HGR Katwa | 6 | 7 | place known, name not | [2026-06-07 .. none] |

3 reports name more than one of them. A report naming both is a report telling them apart, so a merge needs a reason.

## What merging would do

Merged, the opening interval becomes [2026-06-06 .. 2026-06-07].

- `cte-katwa`: [2026-06-03 .. 2026-06-07] becomes [2026-06-06 .. 2026-06-07].
- `cte-hgr-katwa`: [2026-06-07 .. none] becomes [2026-06-06 .. 2026-06-07].

## The quotes

### `cte-katwa`

- SitRep 020, 2026-06-03, `under_construction`: | 9 | Nord-Kivu : Poursuite réhabilitation CTE Katwa, réponse aux incidents sécuritaires (ADF), formation PCI HGR Virunga, extension CREC à 15 000 ménages | Multi-pilier | J+3 |
- SitRep 113, 2026-09-04, `under_construction`: menace de la population de brûler le CTE en construction à Katwa
- SitRep 024, 2026-06-07, `operating`: clôture de la formation de 45 prestataires de santé du CTE de Katwa
- SitRep 038, 2026-06-21, `operating`: décontamination de 2 ESS (CH JERUSALEM & CH MUTIRI) à la suite du transfert d’un cas confirmé positif au CTE à Katwa

### `cte-hgr-katwa`

- SitRep 023, 2026-06-06, `under_construction`: Suivi des travaux de réhabilitation du CTE à l’HGR Katwa.
- SitRep 023, 2026-06-06, `mention_only`: 4 thermo flash pour l’HGR Katwa via la ZS Katwa.
- SitRep 028, 2026-06-11, `mention_only`: 2/2 ESS décontaminés (HGR Katwa et CH FEPSI)
- SitRep 031, 2026-06-14, `mention_only`: la nécessite d’améliorer le circuit du triage de l’HGR Katwa, le respect des SOPs de décontamination

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

