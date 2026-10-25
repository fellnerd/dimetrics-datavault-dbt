---
title: "Effectivity Satellite erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Effectivity Satellite erstellen

Für Links die **Gültigkeitszeiträume** haben (z.B. "Firma war von 2020-2023 in Deutschland").

```sql
{{ config(
    materialized='incremental',
    unique_key=['hk_<hub>', 'dss_start_date'],
    as_columnstore=false,
    post_hook=[
        "{{ update_effectivity_end_dates() }}"
    ]
) }}

WITH source_data AS (
    SELECT
        hk_<hub>,
        hk_<related_hub>,
        hk_link_<entity1>_<entity2>,
        dss_load_date AS dss_start_date,
        dss_create_datetime,              -- empfohlen, wie in jedem Satellite
        dss_record_source
    FROM {{ ref('<concept>_<source>') }}
),

{% if is_incremental() %}
existing AS (
    SELECT hk_<hub>, dss_start_date FROM {{ this }}
),
{% endif %}

new_records AS (
    SELECT *
    FROM source_data src
    {% if is_incremental() %}
    WHERE NOT EXISTS (
        SELECT 1 FROM existing e
        WHERE e.hk_<hub> = src.hk_<hub>
          AND e.dss_start_date = src.dss_start_date
    )
    {% endif %}
)

SELECT 
    *,
    'Y' AS dss_is_active,
    CAST(NULL AS DATETIME2) AS dss_end_date
FROM new_records
```

---

◀ [Transaction Link](04-transaction-link.md) · [Übersicht](00-raw-vault.md) · [Dependent Child Satellite (DC Sat) erstellen](06-dependent-child-satellite.md) ▶
