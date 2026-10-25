---
title: "Wiederverwendbare Macros"
tags:
  - system
  - typ/nachschlagen
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Wiederverwendbare Macros

Alle projekteigenen Macros unter `macros/`. Aufruf in Modellen als `{{ macro(...) }}`, im Betrieb als `dbt run-operation <macro> --args '{…}'`. Eigene Macros haben über `dispatch` (`search_order: ['datavault', 'automate_dv']`) Vorrang vor gleichnamigen automate_dv-Macros.

## Vault und Hashing

| Macro | Datei | Aufruf | Zweck |
|-------|-------|--------|-------|
| `sqlserver__cast_binary` | `hash_override.sql` | automatisch (dispatch) | Hash als lesbares `CHAR(64)` statt `BINARY(32)` |
| `sqlserver__type_string` | `hash_override.sql` | automatisch (dispatch) | Hash-Inputs als `NVARCHAR` (Unicode-sicher) |
| `generate_schema_name` | `generate_schema_name.sql` | automatisch | `+schema` ohne Target-Präfix |
| `update_satellite_current_flag(this, '<hk>')` | `satellite_current_flag.sql` | Post-Hook Satellite | setzt `dss_is_current` und `dss_end_date` |
| `update_effectivity_end_dates()` | `satellite_current_flag.sql` | Post-Hook Effectivity Satellite | End-Dating je Driving Key, `dss_is_active` |
| `satellite_current_view('<sat>', '<hk>')` | `satellite_current_view.sql` | Modell `sat_…_current_v` | aktuelle Version je Schlüssel inkl. `dss_version_rank` |
| `zero_key()`, `error_key()` | `ghost_records.sql` | in SQL | 64 × `0` bzw. 64 × `F` |
| `insert_ghost_records` | `ghost_records.sql` | `run-operation` | Ghost Records in alle Hubs |
| `surrogate_key('<spalte>')` | `surrogate_key.sql` | Mart | deterministischer BIGINT-Key (`ABS(CONVERT(BIGINT, HASHBYTES('MD5', …)))`) |

## Indizes und Performance

| Macro | Datei | Aufruf | Zweck |
|-------|-------|--------|-------|
| `create_hash_index('<spalte>', include_columns=[])` | `create_hash_index.sql` | Post-Hook | Non-Clustered Index, idempotent |
| `create_composite_index(['<a>','<b>'])` | `create_hash_index.sql` | Post-Hook | Index über mehrere Spalten |
| `create_clustered_index(['<spalte>'])` | `create_hash_index.sql` | Post-Hook | Heap → Clustered Index; Pflicht bei `delete+insert` |
| `drop_and_create_index('<spalte>')` | `create_hash_index.sql` | Post-Hook | Index neu anlegen |
| `measure_rls_overhead` | `measure_rls_overhead.sql` | `run-operation --args '{relation: <schema.view>, iterations: 3}'` | Laufzeit/Reads mit vs. ohne RLS vergleichen |

## Betrieb und Protokoll

| Macro | Datei | Aufruf | Zweck |
|-------|-------|--------|-------|
| `create_load_status_table` | `create_load_status_table.sql` | `run-operation` (einmalig je DB) | legt `vault.load_status` an |
| `log_load_status(results)` | `create_load_status_table.sql` | `on-run-end` | protokolliert vollständige `dbt run`/`build` (Status, Anzahl, Fehler) — Grundlage der ADF-Übergabe |
| `log_row_counts` | `log_row_counts.sql` | `run-operation` | Zeilen je Vault-Objekt |
| `run_sql` | `run_sql.sql` | `run-operation --args '{"sql": "…"}'` | Ad-hoc-SQL mit Ergebnisausgabe |
| `cleanup_old_objects` | `cleanup_old_objects.sql` | `run-operation` | entfernt abgelöste Objekte — Liste vor Gebrauch projektspezifisch anpassen |

## Quellen und External Tables

| Macro | Datei | Aufruf | Zweck |
|-------|-------|--------|-------|
| `create_external_table` | `stage_external_sources_selective.sql` | `run-operation --args '{"table_name": "ext_…"}'` | eine External Table aus `sources.yml` anlegen |
| `get_parquet_schema` | `get_parquet_schema.sql` | `run-operation --args '{"folder_path": "…", "file_name": "…"}'` | Spalten einer Parquet-Datei als YAML für `sources.yml` (optional `data_source`, `file_format`) |
| `get_parquet_data` | `get_parquet_data.sql` | wie oben + `"limit": 5` | Beispieldaten |
| `list_parquet_files` | `list_parquet_files.sql` | — | in Azure SQL Database **nicht ausführbar** (keine Ordner-Enumeration); nur Synapse Serverless |

Aus Paketen: `stage_external_sources` (dbt_external_tables); `stage`, `hub`, `sat`, `link`, `t_link`, `ma_sat`, `pit`, `bridge` (automate_dv).

## Security

| Macro | Datei | Aufruf | Zweck |
|-------|-------|--------|-------|
| `tenant_key()` | `security/tenant_key.sql` | in SQL | Mandantenschlüssel des Targets (Var `tenant_key`) |
| `sec_value_key('<ausdruck>')` | `security/tenant_key.sql` | Dimension | baut `dss_sec_value_key` = `<mandant>\|\|<wert>` |
| `rls_filter('<kontext>')` | `security/rls_filter.sql` | `WHERE` der `_v`-View | Zeilenfilter über `sec.fn_check_rls` |
| `cls_mask('<spalte>', '<kontext>')` | `security/cls_mask.sql` | SELECT der `_v`-View | Spaltenmaskierung über `sec.fn_check_cls` |
| `drop_security_policy()` / `apply_security_policy('<kontext>')` | `security/security_policy.sql` | Pre-/Post-Hook physischer Tabellen | native Security Policy |
| `grant_select_on_views()` | `security/grant_select_on_views.sql` | `on-run-end` | SELECT-Grants auf `mart*`-Views gemäß Var `ols_view_grants` |

Die Security-Macros setzen das Schema `sec` mit Funktionen und Rechtetabellen voraus (`security/ddl/`, Runbook `security/DEPLOYMENT.md`) — siehe [Security](../security/00-security.md).

## Projektspezifische Macros

Macros für eine einzelne Quelle (Batch-Loader, Zeitstempel-Parser aus Dateinamen) liegen ebenfalls in `macros/` und sind im Kopfkommentar sowie in der [projektspezifischen Dokumentation](../../04-mandant-architektur/00-mandant-architektur.md) beschrieben.
