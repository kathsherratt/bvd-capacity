`#ai-written`

# Treatment centres at Rwampara

Cluster `ct-rwampara`, rank 2 of the review queue, 129 events in the cluster.
5 treatment centres to decide between.

## The question

Are these 5 one facility, or more than one?

| facility_id | name | aliases | reports | events | GRID3 | opening interval now |
|---|---|---|---|---|---|---|
| `cte-rwampara` | CTE Rwampara | Centre de Traitement Ebola (CTE) de la zone de santé de Rwampara; CTE de Rwampara; CTE Rwampara; CTE RWAMPARA; Rwampara | 35 | 38 | place known, name not | [2026-05-24 .. 2026-05-27] |
| `cte-cme` | CTE CME | CME; CTC CME; CTE CME; CTE du CME; CTE-CME | 28 | 29 | place known, name not | [2026-05-25 .. 2026-05-27] |
| `cte-hgr-rwampara` | CTE HGR/Rwampara | CTE au HGR Rwampara; CTE HGR/Rwampara; HGR Rwampara (CTE) | 3 | 4 | place known, name not | [2026-06-06 .. 2026-06-25] |
| `cte-cme-rwampara` | Centre de Traitement Ebola (CTE) normé de CME Rwampara | Centre de Traitement Ebola (CTE) normé de CME Rwampara; CTE CME de Rwampara; CTE normé CME Rwampara | 3 | 3 | place known, name not | [none .. 2026-05-31] |
| `cte-istm-zs-rwampara` | CTE ISTM/ZS Rwampara | CTE ISTM/ZS Rwampara | 1 | 1 | place known, name not | [none .. 2026-06-27] |

## Already decided, in part

`ct-rwampara__treatment` was decided **apart** by kathsherratt on 2026-09-22, over `cte-cme-rwampara`, `cte-hgr-rwampara`, `cte-rwampara`.
Since then `cte-cme`, `cte-istm-zs-rwampara` joined the group, which is why it is asked again.


16 reports name more than one of them. A report naming both is a report telling them apart, so a merge needs a reason.

## What merging would do

Merged, the opening interval becomes [2026-05-25 .. 2026-05-27].

- `cte-rwampara`: [2026-05-24 .. 2026-05-27] becomes [2026-05-25 .. 2026-05-27].
- `cte-cme`: [2026-05-25 .. 2026-05-27] becomes [2026-05-25 .. 2026-05-27].
- `cte-hgr-rwampara`: [2026-06-06 .. 2026-06-25] becomes [2026-05-25 .. 2026-05-27].
- `cte-cme-rwampara`: [none .. 2026-05-31] becomes [2026-05-25 .. 2026-05-27].
- `cte-istm-zs-rwampara`: [none .. 2026-06-27] becomes [2026-05-25 .. 2026-05-27].

## The quotes

### `cte-rwampara`

- SitRep 010, 2026-05-24, `under_construction`: Poursuite des travaux d’aménagement du CTE Rwampara
- SitRep 019, 2026-06-02, `opened`: | 2 | Capacité insuffisante en CTE normés malgré l'ouverture de Rwampara |
- SitRep 021, 2026-06-04, `opened`: Capacité insuffisante en CTE normés malgré l'ouverture de Rwampara
- SitRep 040, 2026-06-23, `under_construction`: Suivi des travaux d’extension du CTE Rwampara

### `cte-cme`

- SitRep 011, 2026-05-25, `under_construction`: Suivi des travaux au CME (compactage finalisé, circuit non mis en place, Balisage non fait) ;
- SitRep 028, 2026-06-11, `under_construction`: Suivi des travaux de construction des crèches et CTE (CME, ISTM Nyankunde, HGR Rwampara et Elykia).
- SitRep 013, 2026-05-27, `operating`: | CME (27 Lits : 08 Conf et 19 S ) |
- SitRep 015, 2026-05-29, `operating`: | ISSUES | HGR Bunia | HGR Rwampara | CME | HGR Mongbwalu | HGR Nyankunde | HGR Bambu | HGR Aru | Total |

### `cte-hgr-rwampara`

- SitRep 016, 2026-05-30, `under_construction`: Suivi des travaux de construction du CTE à l’HGR Bunia, au CME Bunia, au HGR Rwampara.
- SitRep 023, 2026-06-06, `under_construction`: CME BUNIA, HGR Rwampara (CTE).
- SitRep 042, 2026-06-25, `opened`: Opérationnalité des CTE HGR/Bunia, HGR/Nyankunde, ISTM/Nyankunde, HGR/Aru, HGR/Rwampara
- SitRep 042, 2026-06-25, `under_construction`: Poursuite des travaux d’aménagement aux CTE HGR/Bunia et HGR/Rwampara.

### `cte-cme-rwampara`

- SitRep 017, 2026-05-31, `opened`: Inauguration officielle du Centre de Traitement Ebola (CTE) normé de CME Rwampara, nouvellement réhabilité
- SitRep 018, 2026-06-01, `opened`: Remise officielle du CTE normé CME Rwampara à l'Incident Manager MVE
- SitRep 062, 2026-07-15, `strained`: et au CTE CME de Rwampara (157 %)

### `cte-istm-zs-rwampara`

- SitRep 044, 2026-06-27, `operating`: 1 au CTE Komanda et 1 au CTE ISTM/ZS Rwampara).

## Deciding

One facility: give every row of these names one `facility_id` in
`registry/facility_aliases.csv`, keeping the id already carrying the most
events, and set `reviewed = TRUE` on each. More than one: leave the ids
apart and set `reviewed = TRUE` anyway, so the flag stops being raised.
Put the reason in `note` either way.

Then rerun `R/02_resolve.R`, `R/03_checks.R` and `R/06_opening.R`.

Decision:

Reason:

