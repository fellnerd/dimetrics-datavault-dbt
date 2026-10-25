---
title: "Hub erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Hub erstellen

Ein Hub hält die eindeutigen Business Keys einer Entität — einmal pro Schlüssel, nie aktualisiert.

## Template

```sql
{#
    Hub: hub_<entity>
    Source: <staging_model>
    Business Key: <business_key>
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
    - "dss_business_key"
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

## Pflichtspalten

| Spalte | Herkunft |
|---|---|
| `hk_<entity>` | `hashed_columns` im Staging |
| `<business_key>` | Quellspalte (`src_nk`) |
| `dss_business_key` | `derived_columns` im Staging — **genau eine**, ohne Suffix |
| `dss_create_datetime` | `derived_columns` im Staging |
| `dss_load_date`, `dss_record_source` | `derived_columns` im Staging |

> **`src_extra_columns` muss auch an `automate_dv.hub()` übergeben werden.** Steht es nur im YAML-Block, fehlen die Spalten in der Tabelle — ohne Fehlermeldung.

Aufbau des `dss_business_key`: [Datenmodell → dss_business_key im Detail](../../../03-system/allgemein/03-datenmodell.md#34-dss_business_key-im-detail).

## Primär-Hub oder FK-Hub?

Ein Staging-Model speist oft mehrere Hubs: den seiner Haupt-Entität und zusätzlich die seiner Fremdschlüssel.

| | Beispiel | `source_model` |
|---|---|---|
| **Primär-Hub** | `hub_bestellung` aus `stg_bestellung` (Haupt-Entität Bestellung, BK `bestell_nr`) | das Staging selbst |
| **FK-Hub** | `hub_kunde` aus `stg_bestellung` (Fremdschlüssel, BK `kunden_nr`) | eigene FK-Staging-View `stg_bestellung__kunde` |

**Der `dss_business_key` eines Stagings gehört seiner Haupt-Entität.** In einem FK-Hub landete sonst der falsche Schlüssel: in `hub_kunde` stünde sonst die Bestellnummer. Umbenennen im Hub geht nicht, `automate_dv.hub()` übernimmt Zusatzspalten nur unter ihrem Namen. Deshalb liest jeder FK-Hub aus einer schlanken View, die den Schlüssel *seiner* Entität bildet:

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

Im FK-Hub dann `source_model: "<staging>__<entity>"`. Die Deduplizierung je Hash-Key übernimmt `automate_dv.hub()`.

## Multi-Source-Hub

Wird eine Entität aus mehreren Quellen geladen, `source_model` als Liste:

```yaml
source_model:
  - "<staging_model_a>"
  - "<staging_model_b>"
```

Der Business Key muss in allen Staging-Views **gleich heißen und gleich normalisiert** sein. Typ-Cast beachten: `HASH("44402.00") ≠ HASH("44402")` — vor dem Hashen einheitlich nach `BIGINT` bzw. `NVARCHAR` casten.

## Häufige Fehler

| Symptom | Ursache |
|---|---|
| Hub ohne `dss_business_key` / `dss_create_datetime` | `src_extra_columns` fehlt oder wird nicht an `automate_dv.hub()` übergeben |
| `dss_business_key` passt nicht zum Hub | FK-Hub liest direkt aus dem Haupt-Staging statt aus seiner FK-Staging-View |
| Spalte `dss_business_key_<entity>` | Nicht zulässig — genau eine Spalte `dss_business_key` je Hub |
| Doppelte Keys aus zwei Quellen | Business Key unterschiedlich gecastet |

Der Lint-Hook des Plugins prüft die ersten drei Punkte automatisch.

---

[Übersicht](00-raw-vault.md) · [Satellite erstellen](02-satellite.md) ▶
