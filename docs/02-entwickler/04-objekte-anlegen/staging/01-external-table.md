---
title: "External Table"
tags:
  - entwickler/staging
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Staging](00-staging.md)

# External Table

Eine External Table macht eine Parquet-Datei der Landing Zone (ADLS Gen2) in Azure SQL als Tabelle lesbar. dbt legt sie mit dem Paket `dbt_external_tables` aus `models/staging/sources.yml` an; die Daten bleiben im Storage.

## Voraussetzungen (einmalig je Datenbank)

| Objekt | Zweck | Anlage |
|--------|-------|--------|
| Database Scoped Credential | Zugriff auf den Storage (Managed Identity oder SAS) | Setup-Skript unter `scripts/` |
| External Data Source `StageFileSystem` | Zeigt auf den Container der Landing Zone | Setup-Skript |
| External File Format `ParquetFormat` | Dateiformat | Setup-Skript |
| Schema `stg` | Zielschema | `scripts/setup_schemas.sql` bzw. erster dbt-Lauf |

## 1. Datei finden und Schema erzeugen

```bash
export STAGE_FS_SAS="se=...&sp=rl&..."        # Lese-SAS des Containers

# Schema als fertigen YAML-Block ausgeben
dbt run-operation get_parquet_schema --args '{"folder_path": "<concept>/<quelle>", "file_name": "<datei>.parquet"}'

# Beispieldaten ansehen
dbt run-operation get_parquet_data --args '{"folder_path": "<concept>/<quelle>", "file_name": "<datei>.parquet", "limit": 5}'
```

> [!NOTE]
> Azure SQL Database kann Ordner **nicht** auflisten (`list_parquet_files` funktioniert nur in Synapse Serverless). Dateinamen im Azure Portal (Storage Account → Container) oder mit `az storage fs file list --account-name <konto> -f <container> --path <ordner>` ermitteln.

## 2. In `sources.yml` eintragen

```yaml
sources:
  - name: "staging"
    database: "{{ target.database }}"
    schema: "stg"
    tables:
      - name: "ext_<concept>_<entity>"
        description: "<Quelle>: <Inhalt>, Datei <pfad>"
        external:
          location: "<concept>/<quelle>/<datei>.parquet"   # relativ zur Data Source; Ordner = alle Dateien darin
          file_format: "ParquetFormat"
          data_source: "StageFileSystem"
        columns:
          - name: "<BK_SPALTE>"
            data_type: "BIGINT"
          - name: "<TEXT_SPALTE>"
            data_type: "NVARCHAR(255)"
          - name: "dss_load_date"            # von ADF geliefert, falls vorhanden
            data_type: "DATETIME2"
```

**Regeln**

- Spaltennamen exakt wie in der Parquet-Datei (Groß-/Kleinschreibung), Reihenfolge egal.
- Typen passend zur Datei: Parquet-`string` → `NVARCHAR(n)`, `int64` → `BIGINT`, `double` → `FLOAT`, Dezimal → `DECIMAL(p,s)`, Zeitstempel → `DATETIME2`. Falsche Typen scheitern erst beim Lesen.
- `NVARCHAR` statt `VARCHAR` (Umlaute, und Hashes werden über NVARCHAR gebildet).
- Reservierte Wörter (`TYPE`, `LEVEL`, `PLAN` …) sind als Spaltennamen erlaubt; in der Staging View werden sie über `_escape` behandelt.

## 3. Anlegen

```bash
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>'
# nach Änderungen an Spalten/Typen: neu anlegen
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>' --vars 'ext_full_refresh: true'

dbt show --inline "SELECT TOP 5 * FROM stg.ext_<concept>_<entity>"
```

Die Pipeline führt `stage_external_sources` vor jedem Lauf aus — neue Einträge in `sources.yml` werden also in jeder Umgebung automatisch angelegt.

## Häufige Fehler

| Symptom | Ursache |
|---------|---------|
| `location does not exist` | Pfad relativ zur Data Source falsch oder Datei noch nicht geliefert |
| `Error converting data type` beim Lesen | `data_type` passt nicht zur Parquet-Spalte |
| Spalte bleibt NULL | Name weicht in Groß-/Kleinschreibung ab |
| Umlaute kaputt | `VARCHAR` statt `NVARCHAR` |

---

[Übersicht](00-staging.md) · [Staging View](02-staging-view.md) ▶
