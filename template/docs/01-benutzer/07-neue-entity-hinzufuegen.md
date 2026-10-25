---
title: "Neue Entity hinzufügen"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Neue Entity hinzufügen

Kurzablauf, um eine neue Quelltabelle bis in den Raw Vault zu bringen: External Table → Staging View → Hub → Satellite → Link. Jeder Schritt verweist auf die ausführliche Anleitung unter [Objekte anlegen](../02-entwickler/04-objekte-anlegen/00-objekte-anlegen.md). Beispiel: Quelle `crm`, Entität `auftrag` mit Fremdschlüssel auf `kunde`.

```
sources.yml ─► ext_crm_auftrag ─► crm_auftrag (Staging View, Hashes)
                                     ├─► hub_auftrag
                                     ├─► sat_auftrag__crm
                                     ├─► crm_auftrag__kunde ─► hub_kunde (FK-Hub)
                                     └─► link_auftrag_kunde
```

## 1. External Table — `models/staging/sources.yml`

```yaml
      - name: ext_crm_auftrag
        external:
          location: "crm/<pfad>/auftrag.parquet"
          file_format: ParquetFormat
          data_source: StageFileSystem
        columns:
          - name: AUFTRAGNR
            data_type: BIGINT
          - name: KUNDENNR
            data_type: BIGINT
          - name: STATUS
            data_type: NVARCHAR(50)
          - name: BETRAG
            data_type: DECIMAL(18,2)
```

Spalten nicht abtippen: `get_parquet_schema` erzeugt den Block ([External Table](../02-entwickler/04-objekte-anlegen/staging/01-external-table.md)).

## 2. Staging View — `models/staging/crm_auftrag.sql`

```sql
{%- set yaml_metadata -%}
source_model:
  staging: "ext_crm_auftrag"
derived_columns:
  dss_record_source: "!crm"
  dss_load_date: "GETDATE()"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(AUFTRAGNR AS NVARCHAR(MAX)))), '-1'))"
hashed_columns:
  hk_auftrag: "AUFTRAGNR"
  hk_kunde: "KUNDENNR"
  hk_link_auftrag_kunde: ["AUFTRAGNR", "KUNDENNR"]
  hd_auftrag__crm:
    is_hashdiff: true
    columns: ["BETRAG", "STATUS"]
{%- endset -%}
{% set m = fromyaml(yaml_metadata) %}
{{ automate_dv.stage(include_source_columns=true, source_model=m['source_model'],
                     derived_columns=m['derived_columns'], hashed_columns=m['hashed_columns']) }}
```

Ausführlich: [Staging View](../02-entwickler/04-objekte-anlegen/staging/02-staging-view.md).

## 3. Hub — `models/raw_vault/_common/hubs/hub_auftrag.sql`

```sql
{{ config(materialized='incremental', as_columnstore=false,
          post_hook=["{{ create_hash_index('hk_auftrag') }}"]) }}
{{ automate_dv.hub(src_pk="hk_auftrag", src_nk="AUFTRAGNR",
                   src_extra_columns=["dss_business_key", "dss_create_datetime"],
                   src_ldts="dss_load_date", src_source="dss_record_source",
                   source_model="crm_auftrag") }}
```

Für `hub_kunde` (Fremdschlüssel) liest der Hub aus einer eigenen FK-Staging-View `crm_auftrag__kunde`, damit sein `dss_business_key` die Kundennummer enthält — [Hub → Primär- oder FK-Hub](../02-entwickler/04-objekte-anlegen/raw-vault/01-hub.md).

## 4. Satellite — `models/raw_vault/_common/satellites/sat_auftrag__crm.sql`

```sql
{{ config(materialized='incremental', as_columnstore=false,
          post_hook=["{{ create_hash_index('hk_auftrag') }}",
                     "{{ update_satellite_current_flag(this, 'hk_auftrag') }}"]) }}
{{ automate_dv.sat(src_pk="hk_auftrag",
                   src_hashdiff={"source_column": "hd_auftrag__crm", "alias": "hashdiff"},
                   src_payload=["BETRAG", "STATUS"],
                   src_extra_columns=["dss_create_datetime"],
                   src_ldts="dss_load_date", src_source="dss_record_source",
                   source_model="crm_auftrag") }}
```

Payload = exakt die Hashdiff-Spalten. [Satellite](../02-entwickler/04-objekte-anlegen/raw-vault/02-satellite.md).

## 5. Link — `models/raw_vault/_common/links/link_auftrag_kunde.sql`

```sql
{{ config(materialized='incremental', as_columnstore=false,
          post_hook=["{{ create_hash_index('hk_link_auftrag_kunde') }}"]) }}
{{ automate_dv.link(src_pk="hk_link_auftrag_kunde",
                    src_fk=["hk_auftrag", "hk_kunde"],
                    src_ldts="dss_load_date", src_source="dss_record_source",
                    source_model="crm_auftrag") }}
```

Der Link-Hash besteht aus den Business Keys **beider** Hubs in der Reihenfolge von `src_fk`.
[Link](../02-entwickler/04-objekte-anlegen/raw-vault/03-link.md).

## 6. Dokumentieren, bauen, prüfen

1. Modelle mit Spalten und Tests in `_staging__models.yml` bzw. `_<ordner>__models.yml` eintragen (Hub: `unique` + `not_null` auf `hk_auftrag`, Satellite: `relationships` zum Hub).
2. Bauen und testen:

   ```bash
   dbt run-operation stage_external_sources --args 'select: staging.ext_crm_auftrag'
   dbt build --select +link_auftrag_kunde +sat_auftrag__crm
   ```

3. Ergebnis prüfen: [Daten prüfen](08-daten-pruefen.md) (Eindeutigkeit, Waisen, Zeilenzahlen).
4. Design-Diagramm unter `design/` und den [Changelog](../changelog.md) nachziehen, Merge Request stellen ([Deployment Workflow](../02-entwickler/06-deployment-workflow.md)).

---

◀ [dbt-Befehle](06-dbt-befehle.md) · [Übersicht](00-benutzerhandbuch.md) · [Daten prüfen](08-daten-pruefen.md) ▶
