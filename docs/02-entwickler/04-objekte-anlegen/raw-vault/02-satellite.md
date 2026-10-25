---
title: "Satellite erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Satellite erstellen

Ein Satellite hält die beschreibenden Attribute eines Hubs (oder Links) und historisiert sie: Ändert sich der Inhalt, entsteht eine neue Zeile.

Namenskonvention: `sat_<entity>__<quelle>` — der Quell-Suffix ist Pflicht, denn je Quelle gibt es einen eigenen Satellite.

## Template

```sql
{#
    Satellite: sat_<entity>__<quelle>
    Parent Hub: hub_<entity>
    Source: <staging_model>
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
  source_column: "hd_<entity>__<quelle>"
  alias: "hashdiff"
src_payload:
    - "<spalte_1>"
    - "<spalte_2>"
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

## Die Regeln, die man kennen muss

**Payload = Hashdiff-Spalten.** Die Spalten in `src_payload` müssen exakt denen entsprechen, aus denen im Staging `hd_<entity>__<quelle>` gebildet wird. Weichen sie ab, erkennt der Satellite bei jedem Lauf eine Änderung und schreibt Dauer-Deltas.

**`dss_create_datetime` in `src_extra_columns`, nie im Payload.** Im Payload wäre es Teil des Hashdiff — jede Zeile sähe dann bei jedem Lauf wie eine neue Version aus.

**Lineage-Spalten nie in den Payload** (`dss_source_file_name`, `dss_run_id`, `dss_stage_timestamp` …) — aus demselben Grund.

**`alias: "hashdiff"`** ist Pflicht, nicht der `hd_*`-Name.

**Beide Post-Hooks.** Ohne `update_satellite_current_flag` bleiben `dss_is_current` und `dss_end_date` leer, und die `_current_v`-Views liefern nichts Sinnvolles.

## Current View

Zu jedem Satellite gehört eine View mit nur der aktuellen Version je Schlüssel — siehe [Current View erstellen](../business-vault/01-current-view.md).

## Sondertypen

Für abweichende Grain-Anforderungen gibt es eigene Muster. `dss_create_datetime` gilt dort genauso: **Pflicht im Dependent-Child-Satellite**, **empfohlen** (und in den Vorlagen enthalten) im Multi-Active-, Effectivity- und Transaction-Satellite — immer über `src_extra_columns` bzw. als eigene Spalte, nie im Hashdiff:

| Typ | Wann | Anleitung |
|---|---|---|
| Effectivity Satellite | Gültigkeit einer Beziehung | [06](05-effectivity-satellite.md) |
| Dependent Child | mehrere Zeilen je Schlüssel, unterschieden durch ein Attribut | [07](06-dependent-child-satellite.md) |
| Multi-Active | mehrere gleichzeitig gültige Zeilen je Schlüssel | [08](07-multi-active-satellite.md) |

## Häufige Fehler

| Symptom | Ursache |
|---|---|
| Jeder Lauf erzeugt neue Versionen | Payload ≠ Hashdiff-Spalten, oder Lineage-/`dss_create_datetime` im Payload |
| `dss_is_current` überall NULL | `update_satellite_current_flag` fehlt im Post-Hook |
| Change Detection bricht | `alias: "hashdiff"` fehlt |

---

◀ [Hub erstellen](01-hub.md) · [Übersicht](00-raw-vault.md) · [Link erstellen](03-link.md) ▶
