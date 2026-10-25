---
name: dv-design-sync
description: Hält die Design-Dokumentation (Mermaid-ER-Diagramme, Staging-Datenfluss, Vault-Gesamtmodell im design/-Ordner) synchron zu den dbt-Modellen. Immer verwenden nach dem Anlegen/Ändern von Hubs, Satellites, Links oder Marts sowie bei "Design aktualisieren", "ER-Diagramm", "Diagramm pflegen", "Architektur visualisieren", "Mermaid" oder wenn der Design-Ordner vom Modellstand abweicht.
---

# Design-Dokumentation synchron halten (Model-First)

Dieses Projektschema arbeitet Model-First: Design in Mermaid → Review → Implementierung in dbt. Nach jeder Modell-Änderung müssen die Diagramme nachgezogen werden — ein ER-Diagramm, das nicht dem Code entspricht, ist schlimmer als keines, weil Reviews und Fachabstimmungen darauf vertrauen.

## Struktur

```
design/
├── staging/source_mapping.md        # Quelltabelle → Staging → Vault-Objekt Mapping
├── raw-vault/<concept>/
│   ├── overview.md                  # Hubs/Links/Sats mit BKs, offene Fragen
│   └── er-diagram.mmd               # Mermaid erDiagram des Konzepts
├── business-vault/                  # PITs, Bridges
└── data-flow/end_to_end.md          # Gesamtarchitektur (flowchart)
```

## Naming im Diagramm

- Entitätsnamen **lowercase**, exakt wie die dbt-Modelle: `hub_kunde`, `sat_kunde__erp`, `link_verkauf_kunde`
- Satellites immer mit `__<source>`-Suffix, Hubs/Links nie
- Relationslinien: `hub_kunde ||--o{ sat_kunde__erp : "has"`

## Mermaid-Muster

**ER-Diagramm** (Vault-Beziehungen, Datei `er-diagram.mmd`):

```mermaid
erDiagram
    hub_kunde {
        char64 hk_kunde PK
        string kundennr BK
    }
    sat_kunde__erp {
        char64 hk_kunde FK
        char64 hashdiff
        string name
    }
    hub_kunde ||--o{ sat_kunde__erp : "has"
    link_verkauf_kunde }o--|| hub_kunde : ""
```

**Datenfluss** (Staging, flowchart LR):

```mermaid
flowchart LR
    P[/quelle.parquet/] --> E[stg.ext_quelle] --> S[stg.stg_quelle]
    S -->|hk_kunde| HUB[hub_kunde]
    S -->|hd_kunde| SAT[sat_kunde__erp]
```

## Sync-Checkliste (nach jeder Modell-Änderung)

1. **Neues Vault-Objekt** → Entity-Block + Relationen in `er-diagram.mmd` des Konzepts ergänzen
2. **Jeder `sat_*`** hat eine Relation zu seinem Hub/Link; **jeder `link_*`** zu allen beteiligten Hubs
3. **Zähler/Übersicht** in `overview.md` aktualisieren (Objektlisten, offene Fragen abhaken)
4. **`source_mapping.md`**: neue Quelltabelle → Staging-View → Vault-Objekt Zeile eintragen
5. Konsistenz prüfen: Objekte in `models/raw_vault/**` ⇔ Einträge im Diagramm (beide Richtungen — der PostToolUse-Hook meldet Drift automatisch)
6. **Obsidian-Vault spiegeln** (nur wenn `design/vault-sync.json` existiert): `python3 scripts/sync_design_to_vault.py` ausführen — erzeugt je Eintrag eine `.md` im Vault: aus `.mmd` einen Mermaid-Block (Obsidian rendert keine `.mmd`), aus `.md`-Entwürfen den Inhalt mit umgerechneten Links. Ziel ist einheitlich `04-<mandant>-architektur/raw-vault/mart_<konzept>/`, `business-vault/` bzw. `information-mart/mart_<konzept>/` (Index je Ordner `00-<ordner>.md`, in `groups` als `index` eingetragen). Je Konzeptordner eine eigene Gruppe `{"title": "<Konzept>", "index": "00-mart-<konzept>.md"}` anlegen; Gruppen dürfen verschachtelt sein, der Breadcrumb zeigt dann Schicht und Konzept. Die Vault-Dateien nie von Hand ändern. Neues Diagramm → Eintrag in `design/vault-sync.json` ergänzen und im Index des Zielordners verlinken. `--check` meldet veraltete Kopien (für CI).
7. **Changelog** (Skill `dv-docs`): Zeile in `docs/changelog.md`.

## Obsidian-Vault einrichten (einmalig)

Liegt die Projektdoku als Obsidian-Vault vor, [`scripts/sync_design_to_vault.py`](scripts/sync_design_to_vault.py) nach `scripts/` im Projekt kopieren und `design/vault-sync.json` anlegen (Format im Kopf des Skripts: Vault-Pfad, Breadcrumb, Tags, Gruppen mit `title`/`tag`/`index`, Liste `source → target`). Gruppen-Tags: `architektur/raw-vault`, `architektur/business-vault`, `architektur/information-mart`. Struktur und Konventionen des Vaults: Skill `dv-docs`. `design/` bleibt die einzige Quelle; die Vault-Notizen tragen einen „generiert“-Kommentar und verweisen auf ihre Quelle.

## Diagramm-Validierung

Mermaid-Syntax vor dem Abschluss prüfen (fehlende Klammern, falsche Relationship-Syntax sind die häufigsten Fehler). Wenn ein Mermaid-Renderer-Tool verfügbar ist, Diagramm rendern; sonst mindestens auf Klammer-Balance und `||--o{`-Syntax achten.
