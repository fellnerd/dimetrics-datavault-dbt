---
title: "PIT Table erstellen"
tags:
  - entwickler/business-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Business Vault](00-business-vault.md)

# PIT Table erstellen

📄 **Hinweis:** Im aktuellen Projekt ist noch keine PIT-Tabelle im Einsatz — das Muster gilt, sobald Satellite-Joins über mehrere Sats spürbar teuer werden.

PIT (Point-in-Time) Tabellen für effiziente historische Abfragen.

```sql
{{ config(
    materialized='table',
    as_columnstore=false
) }}

WITH snapshot_dates AS (
    SELECT DISTINCT CAST(dss_load_date AS DATE) AS snapshot_date
    FROM {{ ref('sat_<entity>') }}
),

<entities> AS (
    SELECT DISTINCT hk_<entity>
    FROM {{ ref('hub_<entity>') }}
),

pit_base AS (
    SELECT 
        e.hk_<entity>,
        sd.snapshot_date
    FROM <entities> e
    CROSS JOIN snapshot_dates sd
),

sat_lookup AS (
    SELECT 
        pb.hk_<entity>,
        pb.snapshot_date,
        (
            SELECT TOP 1 s.hk_<entity>
            FROM {{ ref('sat_<entity>') }} s
            WHERE s.hk_<entity> = pb.hk_<entity>
              AND CAST(s.dss_load_date AS DATE) <= pb.snapshot_date
            ORDER BY s.dss_load_date DESC
        ) AS sat_<entity>_hk,
        (
            SELECT TOP 1 s.dss_load_date
            FROM {{ ref('sat_<entity>') }} s
            WHERE s.hk_<entity> = pb.hk_<entity>
              AND CAST(s.dss_load_date AS DATE) <= pb.snapshot_date
            ORDER BY s.dss_load_date DESC
        ) AS sat_<entity>_ldts
    FROM pit_base pb
)

SELECT * FROM sat_lookup
WHERE sat_<entity>_hk IS NOT NULL
```

---

◀ [Current View erstellen (sat_*_current_v)](01-current-view.md) · [Übersicht](00-business-vault.md)
