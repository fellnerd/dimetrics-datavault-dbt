# Staging-View Voll-Templates

## Pattern A: automate_dv.stage() (Standard)

Vollständig kommentiertes Muster. Header-Kommentar dokumentiert Quelle, BK, Hash Keys und Satellite-Splits — das ist die Referenz für den Vault-Architekten.

```sql
/*
 * Staging Model: <quelle>_<tabelle>
 *
 * Source: ext_<quelle>_<tabelle> (<Quellsystem-Notation>)
 * Business Key: <BK> (Normalisierung dokumentieren, z. B. DECIMAL → BIGINT-String)
 * Hash Key: hk_<entity>
 * Links: hk_link_<e1>_<e2> (<bk_e1>, <bk_e2>)
 * Hash Diffs: hd_<entity>__<source> (Payload), ggf. Splits: hd_<entity>_stamm__<source>, hd_<entity>_kontakt__<source>
 *
 * Uses automate_dv.stage() macro for standardized staging.
 */

{%- set yaml_metadata -%}
source_model:
  staging: "ext_<quelle>_<tabelle>"

derived_columns:
  # Pflicht-Metadaten
  dss_record_source: "!<quellsystem>"          # '!' = Literal-String
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"

  # BK-Normalisierung für Cross-Source-Kompatibilität:
  # HASH("44402") muss quellenübergreifend gleich sein — Typ vereinheitlichen!
  <bk_lower>: "CAST(CAST(<BK> AS BIGINT) AS NVARCHAR(MAX))"

  # Menschenlesbarer Business Key (Debugging/Audit) — fuer den PRIMAER-Hub, also die
  # Haupt-Entitaet dieses Stagings. Aufbau: '<mandant>||<collision>||<BK1>||<BK2>…'.
  # Die beiden 'default'-Segmente sind fuer Mandant und Collision-Code reserviert.
  # Mehrere BK-Spalten: je eine ISNULL(LTRIM(RTRIM(CAST(…))), '-1') mehr.
  # Dieselben BK-Spalten in derselben Reihenfolge wie in hashed_columns!
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<BK> AS NVARCHAR(MAX)))), '-1'))"

  # ACHTUNG: derived_columns koennen einander nicht referenzieren. Ist der BK selbst
  # abgeleitet (<x>_bk: "CONCAT_WS(...)"), denselben Ausdruck hier wiederholen und beide
  # Stellen gemeinsam pflegen. Segment 2 (Collision-Code) ist projektabhaengig, z. B.
  # das Quellsystem bei quelluebergreifenden Hubs mit hk = HASH(<x>_bk, quelle).

  # FK-Hubs, die aus DIESEM Staging geladen werden (Fremdschluessel-Spalten): KEINE
  # zweite Business-Key-Spalte hier. Jeder Hub hat genau eine Spalte dss_business_key
  # ohne Suffix — FK-Hubs bekommen dafuer eine eigene FK-Staging-View
  # <staging>__<entity> (siehe dv-patterns -> templates.md, Abschnitt Hub).

  # Reserved Keywords / Sonderzeichen-Spalten escapen (KEINE manuellen Aliase)
  _escape:
    source_column:
      - "PLAN"
      - "timestamp_landing-zone"
    escape: true

hashed_columns:
  hk_<entity>: "<bk_lower>"

  hk_link_<e1>_<e2>:
    - "<bk_e1>"
    - "<bk_e2>"

  hd_<entity>__<source>:
    is_hashdiff: true
    columns:            # exakt die Payload des späteren Satellites — nicht mehr, nicht weniger
      - "SPALTE_1"
      - "SPALTE_2"
{%- endset -%}

{% set metadata = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata['source_model'],
                     derived_columns=metadata['derived_columns'],
                     hashed_columns=metadata['hashed_columns']) }}
```

## Varianten

**Reference-Table-Quelle** (kein Hashing nötig) — schlanke View:

```sql
WITH source AS (
    SELECT * FROM {{ source('staging', 'ext_<quelle>_<tabelle>') }}
)
SELECT
    <key>                                                       AS <key_lower>,
    <bezeichnung>                                               AS bezeichnung,
    COALESCE(dss_record_source, '<quellsystem>')                AS dss_record_source,
    COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())   AS dss_load_date
FROM source
```

**JSON-Quelle** (OPENJSON via CROSS APPLY):

```sql
SELECT j.*, '<quellsystem>' AS dss_record_source, GETDATE() AS dss_load_date
FROM {{ source('staging', 'ext_<quelle>_json') }} AS r
CROSS APPLY OPENJSON(r.jsonline) WITH (
    FELD_1 NVARCHAR(100)  '$."Feld-1"',
    FELD_2 NVARCHAR(1000) '$.feld2'
) AS j
WHERE j.FELD_1 IS NOT NULL
```

## sources.yml-Eintrag (External Table, dbt_external_tables)

```yaml
- name: "ext_<quelle>_<tabelle>"
  description: "Auto-generated from <DATEI>.parquet"
  external:
    location: "<container-pfad>/<DATEI>.parquet"
    file_format: "ParquetFormat"
    data_source: "StageFileSystem"
  columns:
    - name: "<SPALTE>"
      data_type: "<TYP>"
```

Anlegen/Aktualisieren: `dbt run-operation stage_external_sources` (selektiv: `--args '{"select": "ext_<name>"}'` via `stage_external_sources_selective`).

## Pattern B: Manuelles Hashing (Legacy/Altbestand)

Erkennbar an direktem `HASHBYTES` im SQL — in Bestandsprojekten und älteren Beispielen (Separator dort typ. `'^^'`, im Projekt prüfen und konsequent beibehalten). Neuentwicklungen nutzen Pattern A.

```sql
/*
 * Staging Model: <quelle>_<entity>
 * Source: ext_<quelle>_<entity> | Business Key: <bk> | Hash Diff: hd_<entity>__<source>
 */

{%- set hashdiff_columns = ['SPALTE_1', 'SPALTE_2'] -%}

WITH source AS (
    SELECT * FROM {{ source('staging', 'ext_<quelle>_<entity>') }}
),

staged AS (
    SELECT
        -- HASH KEY
        CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            ISNULL(CAST(<bk> AS NVARCHAR(MAX)), '')
        ), 2) AS hk_<entity>,

        -- LINK HASH KEY (alle BKs, Separator konsistent!)
        CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            ISNULL(CAST(<bk_e1> AS NVARCHAR(MAX)), '') + '^^' +
            ISNULL(CAST(<bk_e2> AS NVARCHAR(MAX)), '')
        ), 2) AS hk_link_<e1>_<e2>,

        -- HASH DIFF (Change Detection)
        CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            CONCAT(
                {%- for col in hashdiff_columns %}
                ISNULL(CAST({{ col }} AS NVARCHAR(MAX)), ''){{ ",'^^'," if not loop.last }}
                {%- endfor %}
            )
        ), 2) AS hd_<entity>__<source>,

        <bk>,
        SPALTE_1,
        SPALTE_2,

        COALESCE(dss_record_source, '<quellsystem>')                AS dss_record_source,
        COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())   AS dss_load_date

    FROM source
)

SELECT * FROM staged
```

## PSA-Template (optionaler Cache-Layer)

```sql
/*
 * Persistent Staging Area: psa_<quelle>_<entity>
 * Source: ext_<quelle>_<entity> | Strategy: merge | Unique Key: <bk>
 * Zweck: cached External-Table-Daten, vermeidet wiederholte OPENROWSET/PolyBase-Zugriffe.
 */

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='<bk>',
    as_columnstore=false
) }}

SELECT *
FROM {{ source('staging', 'ext_<quelle>_<entity>') }}
{% if is_incremental() %}
WHERE dss_load_date > (SELECT COALESCE(MAX(dss_load_date), '1900-01-01') FROM {{ this }})
{% endif %}
```

Danach die Staging View auf `{{ ref('psa_<quelle>_<entity>') }}` umstellen — die Hash-Berechnung bleibt in der View. `merge` braucht einen unique_key; reine Append-Quellen können `append` nutzen.
