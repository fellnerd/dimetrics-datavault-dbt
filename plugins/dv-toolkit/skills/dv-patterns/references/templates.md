# DV 2.1 Voll-Templates (automate_dv auf SQL Server)

Platzhalter: `<entity>`, `<source>`, `<staging_model>`, `<business_key>` ersetzen. Header-Kommentar mit Zweck, Quelle, BK und Versionshistorie ist Pflicht — er ist die einzige Doku direkt am Modell.

> **Hash-Separator — vor dem ersten Objekt klären:** Kanonisch (Boilerplate ≥ v1.2) läuft alles Hashing über automate_dv mit den Projekt-Overrides in `hash_override.sql` (`sqlserver__cast_binary` → `CHAR(64)` hex, `sqlserver__type_string` → `NVARCHAR`) und den Vars `concat_string: '||'`, `null_placeholder_string: '-1'`. Ältere Projekte/Beispiele berechnen Hashes manuell mit `'^^'` — beide Wege erzeugen für dieselben Spalten **unterschiedliche Hashes**. Innerhalb einer Entity (Staging ↔ Vault ↔ Multi-Source) nie mischen; maßgeblich ist das bestehende Projektmuster.

Weiterführende Objekt-Leitlinien (Wann/Warum je Objekttyp, DC/MA/Eff-Sat/PSA/PIT im Detail, Checklisten): [developer-guide.md](developer-guide.md)

## Hub

```sql
{#
    Hub: hub_<entity>
    Source: <staging_model>
    Business Keys: <business_key>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_<entity>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_<entity>"
src_nk: "<business_key>"
src_extra_columns:
    - "dss_business_key"          # genau EINE Spalte je Hub, nie mit Suffix
    - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.hub(src_pk=metadata_dict["src_pk"],
                   src_nk=metadata_dict["src_nk"],
                   src_extra_columns=metadata_dict["src_extra_columns"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
```

**Pflichtspalten jedes Hubs:** `dss_business_key` und `dss_create_datetime` in
`src_extra_columns` — und `src_extra_columns` auch an `automate_dv.hub()` übergeben,
sonst landen sie nicht in der Tabelle. **Genau eine** Spalte `dss_business_key` je Hub,
immer unter diesem Namen, **ohne Suffix**.

**Primär-Hub vs. FK-Hub:** Ein Staging hat eine Haupt-Entität, speist aber oft zusätzlich
Hubs für seine Fremdschlüssel (z.B. Bestellungs-Staging `stg_bestellung` → `hub_kunde`). Sein
`dss_business_key` gehört der Haupt-Entität und darf **nie** in einen FK-Hub — dort stünde
sonst die Bestellnummer statt der Kundennummer.

Umbenennen im Hub geht nicht: `automate_dv.hub()` übernimmt Zusatzspalten nur unter ihrem
Namen. Deshalb bekommt jeder FK-Hub eine eigene, schlanke **FK-Staging-View**, die den
Schlüssel seiner Entität als `dss_business_key` bildet:

```sql
-- models/staging/<staging>__<entity>.sql   (View, reine Projektion)
SELECT
    hk_<entity>,
    <FK_BK>,
    CONCAT_WS('||', 'default', 'default',
              ISNULL(LTRIM(RTRIM(CAST(<FK_BK> AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM {{ ref('<staging>') }}
```

Der FK-Hub nutzt dann `source_model: "<staging>__<entity>"`. Die Deduplizierung je
Hash-Key übernimmt `automate_dv.hub()`.

**Nachträglich ergänzen** bei bestehenden Hubs: die Spalte kommt per
`on_schema_change: append_new_columns` leer an. Bestehende Zeilen einmalig aus der
`src_nk`-Spalte befüllen — der Schlüssel ist daraus deterministisch ableitbar:

```sql
UPDATE vault.hub_<entity>
SET dss_business_key = CONCAT_WS('||', 'default', 'default',
        ISNULL(LTRIM(RTRIM(CAST(<business_key> AS NVARCHAR(MAX)))), '-1'))
WHERE dss_business_key IS NULL;
```

**Multi-Source-Hub:** `source_model` als Liste; der Business Key muss in allen Staging-Views gleich heißen und gleich normalisiert sein (Typ-Cast! `DECIMAL → BIGINT → NVARCHAR` vor dem Hashen, sonst `HASH("44402.00") ≠ HASH("44402")`).

```yaml
source_model:
  - "<staging_model_a>"
  - "<staging_model_b>"
```

## Satellite

```sql
{#
    Satellite: sat_<entity>__<source>
    Parent Hub: hub_<entity>
    Source: <staging_model>
    Payload: <kurzbeschreibung>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_<entity>') }}",
        "{{ update_satellite_current_flag(this, 'hk_<entity>') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_<entity>"
src_hashdiff:
  source_column: "hd_<entity>__<source>"
  alias: "hashdiff"
src_payload:
  - SPALTE_1
  - SPALTE_2
src_extra_columns:
  - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(src_pk=metadata_dict["src_pk"],
                   src_hashdiff=metadata_dict["src_hashdiff"],
                   src_payload=metadata_dict["src_payload"],
                   src_extra_columns=metadata_dict["src_extra_columns"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
```

Stolperfallen: `dss_create_datetime` in `src_extra_columns` — **nicht** in `src_payload` (sonst Teil des Hashdiff und damit jede Zeile eine neue Version); `alias: "hashdiff"` ist Pflicht (nicht der `hd_*`-Name); beide post_hooks nötig; Payload-Spalten müssen exakt den Hashdiff-Spalten der Staging-View entsprechen (sonst Dauer-Delta bei jedem Load). Die Signatur des Current-Flag-Macros im Zielprojekt prüfen — im Boilerplate: `update_satellite_current_flag(satellite_table, hash_key_column)`, also `(this, 'hk_<entity>')`.

## Multi-Active Satellite

Wie Satellite, zusätzlich Child Dependent Key und `_ma`-Naming (`sat_<entity>_ma__<source>`, Hash Diff `hd_<entity>_ma__<source>`):

```yaml
src_cdk:
  - "<unterscheidende_spalte>"
src_extra_columns:          # empfohlen, wie bei jedem Satellite
  - "dss_create_datetime"
```

Post-Hooks wie beim Standard-Satellite (`create_hash_index` + `update_satellite_current_flag`). `dss_create_datetime` ist im Standard- und Dependent-Child-Satellite Pflicht, im MA-, Effectivity- und Transaction-Satellite empfohlen.

## Link

```sql
{#
    Link: link_<e1>_<e2>
    Source: <staging_model>
    Foreign Keys: hk_<e1>, hk_<e2>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_link_<e1>_<e2>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_link_<e1>_<e2>"
src_fk:
  - "hk_<e1>"
  - "hk_<e2>"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.link(src_pk=metadata_dict["src_pk"],
                    src_fk=metadata_dict["src_fk"],
                    src_ldts=metadata_dict["src_ldts"],
                    src_source=metadata_dict["src_source"],
                    source_model=metadata_dict["source_model"]) }}
```

Link-Hash-Key wird in der **Staging-View** berechnet (via `hashed_columns` im stage()-Block):

```yaml
hashed_columns:
  hk_link_<e1>_<e2>:
    - "<bk_e1>"
    - "<bk_e2>"
```

## Transaction Link (Non-Historized, `_tl`)

Für unveränderliche Events (Transaktionen, Messwerte, Logs). Unterschiede zum regulären Link:

| Merkmal | Regulärer Link | Transaction Link |
|---------|---------------|------------------|
| Naming | `link_<e1>_<e2>` | `link_<entity>_tl` |
| Hash Key | Hash(FKs) | Hash(**event_id**, FKs) |
| incremental_strategy | (Default) | `append` |
| Zugehöriger Sat | Eff-Sat / DC-Sat | Transaction Sat: **kein** Hash Diff, **kein** current_flag-Hook |

```sql
{{ config(
    materialized='incremental',
    as_columnstore=false,
    incremental_strategy='append',
    post_hook=["{{ create_hash_index('hk_link_<entity>_tl') }}"]
) }}
```
(Macro-Aufruf wie beim regulären Link.)

## Dependent Child Satellite

Entity ohne eigenen BK (z. B. Belegpositionen): Satellite am Link, Link hat nur einen FK (Parent-Hub), Hash Key = `Hash(FK, DCK1, DCK2)` (Separator gem. Projektmuster) — die Dependent Child Keys gehören in den Staging-`hashed_columns`-Block.

## Reference Table

Stabile Lookups (Status, Arten, Länder) — **kein Hub**. Als View materialisieren:

```sql
{{ config(materialized='view') }}

SELECT
    <key_spalte>,
    <bezeichnung>,
    dss_record_source,
    dss_load_date
FROM {{ ref('<staging_model>') }}
```

## Schema-YAML (je Vault-Ordner `_<ordner>__models.yml`)

```yaml
version: 2

models:
  - name: hub_<entity>
    description: "Hub for <entity>"
    columns:
      - name: hk_<entity>
        data_type: "CHAR(64)"
        description: "Hash Key"
        data_tests: [not_null, unique]
      - name: <business_key>
        description: "Business Key"
        data_tests: [not_null]
      - name: dss_load_date
        data_type: "DATETIME2(6)"
      - name: dss_record_source
        data_type: "VARCHAR(50)"
```

Satellites: `hk_*` und `hashdiff` mit `not_null` testen; `unique` gilt dort **nicht** (Historie!). Links: `hk_link_*` `not_null` + `unique`, FKs `not_null`.
