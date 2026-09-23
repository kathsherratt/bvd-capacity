`#ai-written`

# Treatment centres at Nyankunde

Cluster `site-hgr-nyankunde`, rank 3 of the review queue, 85 events in the cluster.
5 treatment centres to decide between.

## The question

Are these 5 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-istm` | CTE ISTM | CTE de ISTM; CTE ISTM; ISTM | 28 | 28 | place known, name not | [none .. 2026-06-29] |
| `cte-nyankunde` | CTE Nyankunde | CTE de Nyankunde; CTE Nyakunde; CTE Nyankunde; Nyankunde | 16 | 16 | place known, name not | [2026-05-25 .. 2026-06-05] |
| `cte-istm-nyankunde` | ISTM Nyankunde | CTE IST Nyankunde; CTE ISTM Nyankunde; CTE ISTM/Nyankunde; ISTM Nyankunde; ISTM/Nyakunde; ISTM/Nyankunde | 7 | 7 | place known, name not | [2026-06-13 .. 2026-06-16] |
| `cte-hgr-nyankunde` | CTE HGR Nyankunde | CTE HGR Nyankunde; CTE HGR/Nyankunde | 3 | 3 | place known, name not | [2026-06-15 .. 2026-06-18] |
| `cte-cme-nyankunde` | CTE CME Nyankunde | CTE CME Nyankunde; CTE/CME Nyankunde | 2 | 2 | place known, name not | [none .. 2026-06-14] |

## Already decided, in part

`site-hgr-nyankunde__treatment__spelling-istm` was decided **same** by claude-code on 2026-09-22, over `cte-ist-nyankunde`, `cte-istm-nyakunde`, `cte-istm-nyankunde`.
Since then `cte-istm`, `cte-nyankunde`, `cte-hgr-nyankunde`, `cte-cme-nyankunde` joined the group, which is why it is asked again.
Reason given: One host, the ISTM at Nyankunde, written CTE IST Nyankunde, ISTM/Nyakunde and CTE ISTM Nyankunde.

`site-hgr-nyankunde__treatment__spelling-place` was decided **same** by claude-code on 2026-09-22, over `cte-nyakunde`, `cte-nyankunde`.
Since then `cte-istm`, `cte-istm-nyankunde`, `cte-hgr-nyankunde`, `cte-cme-nyankunde` joined the group, which is why it is asked again.
Reason given: One letter apart, and GRID3 spells the health zone Nyankunde.

`site-hgr-nyankunde__treatment` was decided **apart** by kathsherratt on 2026-09-22, over `cte-cme-nyankunde`, `cte-hgr-nyankunde`, `cte-istm-nyankunde`, `cte-nyankunde`.
Since then `cte-istm` joined the group, which is why it is asked again.
Reason given: Four hosts at Nyankunde: the town centre, the HGR, the CME and the ISTM. Reports name more than one in a sentence.


8 reports name more than one of them. A report naming both is a report telling them apart, so a merge needs a reason.

## What merging would do

Merged, the opening interval becomes [2026-05-25 .. 2026-06-05].

- `cte-istm`: [none .. 2026-06-29] becomes [2026-05-25 .. 2026-06-05].
- `cte-nyankunde`: [2026-05-25 .. 2026-06-05] becomes [2026-05-25 .. 2026-06-05].
- `cte-istm-nyankunde`: [2026-06-13 .. 2026-06-16] becomes [2026-05-25 .. 2026-06-05].
- `cte-hgr-nyankunde`: [2026-06-15 .. 2026-06-18] becomes [2026-05-25 .. 2026-06-05].
- `cte-cme-nyankunde`: [none .. 2026-06-14] becomes [2026-05-25 .. 2026-06-05].

## What the other registers say

- GRID3 on `cte-istm-nyankunde` against `cte-nyankunde`: GRID3 names nyankunde the Hôpital Général de Référence of nyankunde health zone (leans same)


## The quotes

### `cte-istm`

- SitRep 094, 2026-08-16, `under_construction`: achèvement des extensions des CTE de Nizi, ISTM et Bambu
- SitRep 095, 2026-08-17, `under_construction`: achèvement des extensions des CTE de Nizi, ISTM et Bambu en Ituri
- SitRep 098, 2026-08-20, `under_construction`: ralentissement des travaux d’extension des CTE de Nizi, ISTM et Bambu
- SitRep 046, 2026-06-29, `operating`: dans les CTE de la province de l’Ituri (4 au CTE Elikya, 4 au CTE CME, 2 au CTE Mongbwalu, 2 au CTE Nyankunde et 1 au CTE ISTM).

### `cte-nyankunde`

- SitRep 011, 2026-05-25, `under_construction`: Retard dans la construction des CTE dans tous les sites (Nyankunde, CME, HGR Rwampara) ;
- SitRep 022, 2026-06-05, `operating`: début de la sensibilisation en appui à l’accueil et isolement des malades au CTE Nyankunde
- SitRep 025, 2026-06-08, `operating`: et 4 suspects incluant 2 PPL (1 à CME, 1 Bambu, 1 Nyankunde et 1 Elikya).
- SitRep 044, 2026-06-27, `operating`: 2 au CTE Elikya/ZS Bunia, 1 au CTE Nyankunde, 1 au CTE Komanda et 1 au CTE ISTM/ZS Rwampara).

### `cte-istm-nyankunde`

- SitRep 028, 2026-06-11, `under_construction`: Suivi des travaux de construction des crèches et CTE (CME, ISTM Nyankunde, HGR Rwampara et Elykia).
- SitRep 030, 2026-06-13, `under_construction`: Suivi des travaux de construction des crèches et CTE (CME, ISTM Nyankunde, HGR Nyankunde, HGR Rwampara et Elykia).
- SitRep 033, 2026-06-16, `opened`: Opérationnalisation du CTE IST Nyankunde.
- SitRep 042, 2026-06-25, `opened`: Opérationnalité des CTE HGR/Bunia, HGR/Nyankunde, ISTM/Nyankunde,

### `cte-hgr-nyankunde`

- SitRep 032, 2026-06-15, `under_construction`: Poursuite du suivi des travaux d’aménagements dans le CTE HGR Nyankunde.
- SitRep 042, 2026-06-25, `opened`: Opérationnalité des CTE HGR/Bunia, HGR/Nyankunde,
- SitRep 035, 2026-06-18, `operating`: des kits dignités et intrants PCI au CTE CME Bunia, CTE HGR Nyankunde, CSR Shari

### `cte-cme-nyankunde`

- SitRep 031, 2026-06-14, `operating`: 43 membres de famille de 9 nouvelles admissions au CTE/CME Nyankunde ;
- SitRep 039, 2026-06-22, `operating`: 56 personnels soignants du CTE CME Nyankunde dans la ZS de Rwampara

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

