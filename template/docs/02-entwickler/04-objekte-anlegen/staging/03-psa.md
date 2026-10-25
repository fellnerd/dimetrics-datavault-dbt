---
title: "PSA (Persistent Staging Area) erstellen"
tags:
  - entwickler/staging
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Staging](00-staging.md)

# PSA (Persistent Staging Area) erstellen

> **Zweck:** PSA cached Daten aus External Tables (PolyBase/OPENROWSET) in einer inkrementellen SQL-Tabelle, um wiederholte teure Zugriffe auf ADLS zu vermeiden.

#### Wann PSA verwenden?

| Szenario | Empfehlung |
|----------|------------|
| Kleine Parquet-Dateien, schnelle Abfragen | ❌ Keine PSA nötig |
| Große Datenmengen, häufige dbt runs | ✅ PSA verwenden |
| Merge/Upsert-Logik erforderlich | ✅ PSA verwenden |
| Inkrementelle Verarbeitung | ✅ PSA verwenden |

#### Datenfluss mit PSA

```
ext_<concept>_<entity> (External Table - PolyBase)
    ↓
psa_<concept>_<entity> (PSA - Incremental dbt Table) ← NEUER LAYER
    ↓
<concept>_<entity> (Staging View - Hash-Berechnungen)
    ↓
Hub/Satellite/Link (Raw Vault)
```

**Wichtig:** Die Staging View muss angepasst werden, um die PSA statt der External Table zu referenzieren!

#### Schritt 1: PSA-Tabelle erstellen

📄 **Neue Datei:** `models/staging/psa_<concept>_<entity>.sql`

```sql
/*
 * Persistent Staging Area: psa_<concept>_<entity>
 * 
 * Source: ext_<concept>_<entity>
 * Strategy: merge
 * Unique Key: <business_key>
 * Incremental Column: dss_load_date
 * 
 * Purpose: Persists external table data to avoid repeated OPENROWSET calls.
 *          Staging views (hash calculation) should reference this PSA table.
 */

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='<business_key>',
    as_columnstore=false
) }}

SELECT
    <business_key>,
    <alle_spalten>,
    dss_record_source,
    dss_load_date,
    dss_run_id,
    dss_stage_timestamp,
    dss_source_file_name

FROM {{ source('staging', 'ext_<concept>_<entity>') }}

{% if is_incremental() %}
WHERE dss_load_date > (SELECT COALESCE(MAX(dss_load_date), '1900-01-01') FROM {{ this }})
{% endif %}
```

**Incremental Strategy Optionen:**

| Strategy | Beschreibung | Unique Key erforderlich? |
|----------|--------------|-------------------------|
| `merge` | Update bei Match, Insert bei neuem Record | ✅ Ja |
| `append` | Nur neue Records einfügen (kein Update) | ❌ Nein |

#### Schritt 2: sources.yml aktualisieren

📄 **Datei:** `models/staging/sources.yml`

Füge einen Eintrag für die PSA-Tabelle hinzu mit `meta.psa: true`:

```yaml
      # PSA für Entity
      - name: <concept>_<entity>    # Ohne ext_ Prefix
        description: Persistent Staging Area for ext_<concept>_<entity>
        meta:
          psa: true                 # Markiert als PSA für Tree View
          source_external_table: ext_<concept>_<entity>
        columns:
          - name: <business_key>
            data_type: BIGINT
          # ... weitere Spalten
```

#### Schritt 3: Staging View anpassen (KRITISCH!)

⚠️ **Die bestehende Staging View muss angepasst werden, um die PSA zu referenzieren!**

📄 **Datei:** `models/staging/<concept>_<entity>.sql`

```sql
-- VORHER:
WITH source AS (
    SELECT * FROM {{ source('staging', 'ext_<concept>_<entity>') }}
),

-- NACHHER:
WITH source AS (
    SELECT * FROM {{ ref('psa_<concept>_<entity>') }}
),
```

**Warum diese Änderung?**
- Die Hash-Berechnungen (hk_*, hd_*) erfolgen weiterhin in der Staging View
- Aber die Datenquelle ist jetzt die PSA-Tabelle statt der External Table
- Das reduziert teure OPENROWSET-Aufrufe bei jedem dbt run

#### Schritt 4: Schema YAML dokumentieren

📄 **Datei:** `models/staging/_staging__models.yml`

```yaml
  - name: psa_<concept>_<entity>
    description: "Persistent Staging Area for <entity>. Caches data from ext_<concept>_<entity>."
    columns:
      - name: <business_key>
        description: Business Key / Unique Identifier
        data_type: bigint
        tests:
          - not_null
      # ... weitere Spalten dokumentieren
```

#### Schritt 5: Deployment

```bash
# 1. PSA erstellen (lädt alle Daten)
dbt run --select psa_<concept>_<entity>

# 2. Staging View anpassen (s.o.)

# 3. Alle abhängigen Models neu bauen
dbt run --select +<concept>_<entity>+
```

#### VS Code Extension

Die VS Code Extension bietet den Befehl "Create PSA Table" im Kontextmenü der External Tables. Dieser erstellt automatisch:
- Die PSA SQL-Datei
- Den sources.yml Eintrag
- Die Schema YAML Dokumentation

⚠️ **Die Staging View muss manuell angepasst werden!** Die Extension ändert nur die PSA, nicht die referenzierende Staging View.

---

◀ [Staging View](02-staging-view.md) · [Übersicht](00-staging.md)
