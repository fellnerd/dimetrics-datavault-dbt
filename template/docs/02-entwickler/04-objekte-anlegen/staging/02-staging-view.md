---
title: "Staging View"
tags:
  - entwickler/staging
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Staging](00-staging.md)

# Staging View

Die Staging View liest die External Table (oder PSA) und ergänzt Hash Keys, Hash Diffs und Metadaten mit `automate_dv.stage()`. Aus ihr laden Hubs, Satellites und Links. Datei: `models/staging/<concept>_<entity>.sql`, Materialisierung `view`.

## Template

```sql
/*
 * Staging Model: <concept>_<entity>
 * Source:        ext_<concept>_<entity>
 * Business Key:  <BK>            → hk_<entity>
 * Fremdschlüssel: <FK_BK>        → hk_<fk_entity>
 * Payload:       <n> Spalten     → hd_<entity>__<quelle>
 * Version:       <YYYY-MM-DD> V1.0 Initialversion
 */

{%- set yaml_metadata -%}
source_model:
  staging: "ext_<concept>_<entity>"          # Source: {source_name: table}; Modell: "<modell>"

derived_columns:
  dss_record_source: "!<mandant>_<quelle>"   # "!" = Konstante
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<BK> AS NVARCHAR(MAX)))), '-1'))"
  _escape:                                   # reservierte Wörter / Sonderzeichen
    source_column: ["TYPE", "timestamp_landing-zone"]
    escape: true

hashed_columns:
  hk_<entity>: "<BK>"                        # zusammengesetzt: ["<BK_1>", "<BK_2>"]
  hk_<fk_entity>: "<FK_BK>"
  hk_link_<entity>_<fk_entity>: ["<BK>", "<FK_BK>"]
  hd_<entity>__<quelle>:
    is_hashdiff: true
    columns:                                 # nur fachliche Attribute, alphabetisch
      - "<ATTR_A>"
      - "<ATTR_B>"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata_dict['source_model'],
                     derived_columns=metadata_dict['derived_columns'],
                     hashed_columns=metadata_dict['hashed_columns']) }}
```

> **`derived_columns` können sich nicht gegenseitig referenzieren** — `automate_dv.stage()` berechnet sie alle aus den Quellspalten. Wird ein Business Key erst abgeleitet (z. B. `<x>_bk: "CONCAT_WS('||', a, b)"`), steht derselbe Ausdruck in `dss_business_key` noch einmal statt `<x>_bk`. Beide Stellen gemeinsam ändern (Kommentar setzen), sonst driften Hash und Klartext auseinander. Konstanten (z. B. das Quellsystem) als Literal einsetzen.

## Was die Konfiguration bewirkt

| Einstellung (`dbt_project.yml` → `vars`) | Wert | Wirkung |
|---|---|---|
| `hash` | `SHA` | SHA2-256, über `hash_override.sql` als `CHAR(64)` hex |
| `concat_string` | `\|\|` | Trenner zwischen Spalten eines zusammengesetzten Keys |
| `null_placeholder_string` | `-1` | NULL im Hash-Input |
| `hash_content_casing` | `DISABLED` | kein `UPPER()` — `abc` und `ABC` sind verschiedene Keys |

## Regeln

**Business Key**
- Vor der Modellierung auf Eindeutigkeit prüfen ([Daten prüfen](../../../01-benutzer/08-daten-pruefen.md)).
- Dieselbe Entität aus mehreren Quellen: Business Key **gleich benennen, gleich casten** (`CAST(x AS BIGINT)` bzw. `NVARCHAR`) — `HASH('4711.00') ≠ HASH('4711')`.
- Kollidieren Schlüssel verschiedener Quellen (beide nummerieren ab 1), einen Diskriminator (z. B. Quell-Literal) in den Business Key aufnehmen.

**`dss_business_key`**
- Genau eine Spalte, gebildet aus **denselben Spalten in derselben Reihenfolge** wie `hk_<entity>` — sie ist die Klartext-Form des Hashes der **Haupt-Entität**.
- Für jeden Fremdschlüssel-Hub eine eigene FK-Staging-View `<staging>__<fk_entity>`, die `dss_business_key` für diese Entität bildet ([Hub → FK-Hub](../raw-vault/01-hub.md)).

**Hash Diff**
- Enthält alle fachlichen Attribute des Satellites — genau die Spalten, die der Satellite als `src_payload` führt.
- **Nie** im Hash Diff: `dss_*`-Spalten, Lineage (Datei, Run-ID, Export-Zeitstempel), Perioden- oder Ladekennzeichen, die sich ohne fachliche Änderung bewegen.
- Soll ein Satellite in zwei Satellites geteilt werden (Änderungshäufigkeit, Vertraulichkeit), gibt es zwei Hash Diffs.

**`dss_load_date`**
- Ein Wert je Ladelauf (Batch). Liefert die Quelle einen Ladezeitstempel, diesen verwenden, sonst `GETDATE()`. Bei Multi-Active Satellites **muss** er für alle Zeilen eines Schlüssels im Lauf identisch sein ([Multi-Active Satellite](../raw-vault/07-multi-active-satellite.md)).

## Vorbereitungs-View (optional)

Braucht die Quelle vor dem Hashen eine Bereinigung — Dubletten („letzter Export gewinnt“), Filter auf gültige Zeilen, Entpacken von JSON —, kommt sie in eine eigene View `<concept>_<entity>_dedup`, die dann `source_model` der Staging View ist. So bleibt die Staging View reines `stage()`.

```sql
{{ config(materialized='view') }}
SELECT *
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY <BK> ORDER BY dss_export_datum DESC) AS rn
    FROM {{ source('staging', 'ext_<concept>_<entity>') }}
) x
WHERE rn = 1
```

## Prüfen

```bash
dbt run --select <concept>_<entity>
dbt show --inline "SELECT TOP 5 hk_<entity>, dss_business_key, hd_<entity>__<quelle> FROM stg.<concept>_<entity>"
```

## Häufige Fehler

| Symptom | Ursache |
|---------|---------|
| `Incorrect syntax near 'TYPE'` | reserviertes Wort nicht in `_escape` |
| Hub mit doppelten Business Keys unter verschiedenen Hashes | uneinheitlicher Cast/Format des BK |
| Satellite schreibt bei jedem Lauf neue Versionen | Lineage-/Lade-Spalte im Hash Diff, oder Payload ≠ Hash-Diff-Spalten |
| `dss_business_key` im FK-Hub falsch | FK-Hub liest die Haupt-Staging-View statt seiner FK-Staging-View |

---

◀ [External Table](01-external-table.md) · [Übersicht](00-staging.md) · [PSA (Persistent Staging Area) erstellen](03-psa.md) ▶
