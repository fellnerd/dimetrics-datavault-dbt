---
title: "Quick Reference"
tags:
  - entwickler
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Quick Reference

### Häufigste Befehle

```bash
# Umgebung aktivieren
cd <pfad>/datavault-dbt && source .venv/bin/activate

# Verbindung testen
dbt debug

# Models bauen
dbt run                                                  # Alle Models (ohne getaggte Domänen)
dbt run --select raw_vault.<concept>.hub_<entity>        # Einzelnes Model (empfohlen)
dbt run --select +raw_vault.<concept>.sat_<entity>+      # Model mit Abhängigkeiten
dbt run --select tag:<tag>                               # Getaggte Domäne (Massendaten)
dbt run --full-refresh                                   # Alles neu bauen

# External Tables erstellen / aktualisieren
# Namenskonvention: ext_<concept>_<entity>

## Option 1: ALLE External Tables (Standard, idempotent)
dbt run-operation stage_external_sources
# oder einzelne Tabelle (Format: staging.<table_name>)
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>'
# Full Refresh (DROP + CREATE, bei Schema-Änderungen)
dbt run-operation stage_external_sources --vars 'ext_full_refresh: true'
# Full Refresh für einzelne Tabelle
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>' --vars 'ext_full_refresh: true'

## Option 2: EINZELNE neue Tabelle (optimiert)
dbt run-operation create_external_table \
  --args 'table_name: ext_<concept>_<entity>'

## Option 3: Explorieren (ohne zu erstellen) — benötigt STAGE_FS_SAS
dbt run-operation get_parquet_schema --args '{"folder_path": "<concept>/<quelle>", "file_name": "<Datei>.parquet"}'
dbt run-operation get_parquet_data   --args '{"folder_path": "<concept>/<quelle>", "file_name": "<Datei>.parquet", "limit": 5}'

# Staging View bauen
dbt run --select <concept>_<entity>

# Tests
dbt test                                    # Alle Tests
dbt test --select hub_<entity>              # Tests für ein Model
dbt test --exclude tag:nightly              # ohne die langlaufenden Tests (wie in der CI)

# Seeds (Reference Data)
dbt seed

# Kompilieren (SQL anzeigen ohne Ausführung)
dbt compile --select <model>
cat target/compiled/datavault/models/path/to/model.sql

# Betrieb
dbt run-operation log_row_counts            # Row Counts je Objekt
dbt run-operation insert_ghost_records      # Ghost Records in Hubs
dbt run-operation run_sql --args '{"sql": "SELECT ..."}'   # Ad-hoc-Abfrage
```

### dbt Selektoren (Model Selection)

> **Wichtig:** Verwende den **vollständigen Pfad**, da Model-Namen in mehreren Concepts existieren können.

```bash
# ❌ Vermeiden - wählt gleichnamige Models in allen Concepts
dbt run --select hub_<entity>

# ✅ Empfohlen - spezifischer Pfad
dbt run --select raw_vault.<concept>.hub_<entity>

# ✅ Pfad-Pattern für einzelne Datei
dbt run --select path:models/raw_vault/<concept>/hubs/hub_<entity>.sql
```

**Selektor-Syntax:**

| Selektor | Beschreibung | Beispiel |
|----------|--------------|----------|
| `raw_vault.<concept>.hub_<entity>` | Pfad-basiert (Ordnerstruktur) | Empfohlen für einzelne Models |
| `raw_vault.<concept>` | Alle Models eines Concepts | Für Concept-Deployment |
| `staging.<concept>_*` | Wildcard-Pattern | Alle Staging Views einer Quelle |
| `+model_name` | Model inkl. Upstream-Dependencies | baut erst Staging |
| `model_name+` | Model inkl. Downstream-Dependents | baut auch Satellites/Marts |
| `+model_name+` | Beides | Vollständige Dependency-Chain |
| `tag:<tag>` | Nach Tag | Getaggte Domänen, `tag:nightly` für langsame Tests |

**Pfad-Mapping:**

```
models/
├── staging/                    → staging.*
├── raw_vault/
│   ├── _common/                → raw_vault._common.*        (Schema vault)
│   │   ├── hubs/ satellites/ links/ refs/
│   └── <concept>/              → raw_vault.<concept>.*      (Schema vault_<concept>)
│       └── hubs/ satellites/ links/
├── business_vault/             → business_vault.*           (Schema mart_<domain>)
└── mart/
    ├── _common/                → mart._common.*             (Schema mart)
    └── <domain>/               → mart.<domain>.*            (Schema mart_<domain>)
```

**Kombinierte Selektoren:**

```bash
# Staging + Hub + Satellite für eine Entity (Upstream inklusive)
dbt run --select +raw_vault.<concept>.hub_<entity> +raw_vault.<concept>.sat_<entity>__<quelle>

# Alle Raw-Vault-Models eines Concepts
dbt run --select raw_vault.<concept>

# Nur Hubs eines Concepts
dbt run --select raw_vault.<concept>.hub_*
```

### Wichtige Dateien

| Datei | Zweck | Link |
|-------|-------|------|
| `dbt_project.yml` | Projektkonfiguration, Schemas, `vars`, Hooks | [öffnen](../../dbt_project.yml) |
| `models/staging/sources.yml` | External Tables (`ext_<concept>_<entity>`) | [öffnen](../../models/staging/sources.yml) |
| `models/staging/_staging__models.yml` | Dokumentation und Tests der Staging Views | [öffnen](../../models/staging/_staging__models.yml) |
| `macros/generate_schema_name.sql` | Schema-Naming ohne dbt-Prefix | [öffnen](../../macros/generate_schema_name.sql) |
| `macros/hash_override.sql` | Hash-Overrides (CHAR(64), NVARCHAR) | [öffnen](../../macros/hash_override.sql) |
| `macros/satellite_current_flag.sql` | `dss_is_current`, End-Dating | [öffnen](../../macros/satellite_current_flag.sql) |
| `macros/create_hash_index.sql` | Indizes auf Hash Keys | [öffnen](../../macros/create_hash_index.sql) |
| `macros/ghost_records.sql` | Ghost Records | [öffnen](../../macros/ghost_records.sql) |
| `macros/security/` | `tenant_key`, `rls_filter`, `cls_mask`, Security Policies, View-Grants | [öffnen](../../macros/security) |
| `security/DEPLOYMENT.md` | Runbook für das Security-Fundament | [öffnen](../../security/DEPLOYMENT.md) |

### Parquet-Exploration Macros

Für die Analyse von Parquet-Dateien in der Landing Zone (ADLS Gen2). Voraussetzung ist ein SAS-Token in der Umgebungsvariablen `STAGE_FS_SAS` (`export STAGE_FS_SAS="se=...&sp=rl&..."`).

| Macro | Zweck |
|-------|-------|
| `list_parquet_files` | Ordner auflisten — nur Synapse Serverless, in Azure SQL Database nicht ausführbar |
| `get_parquet_schema` | Schema einer Datei als YAML für `sources.yml` ausgeben |
| `get_parquet_data` | Beispieldaten einer Datei anzeigen |

### External Table Macros

| Macro | Zweck | Wann |
|-------|-------|------|
| `create_external_table` | Erstellt genau EINE Tabelle aus `sources.yml` | Neue Tabelle — schneller |
| `stage_external_sources` | Erstellt/aktualisiert ALLE Tabellen (idempotent) | Regelfall, auch in der CI |

**Typischer Workflow für eine neue Datenquelle:**
```bash
# 1. Verfügbare Dateien anzeigen (Azure Portal bzw. az storage fs file list)

# 2. Schema als YAML generieren (direkt in sources.yml kopierbar)
dbt run-operation get_parquet_schema --args '{"folder_path": "<concept>/<quelle>", "file_name": "<Datei>.parquet"}'

# 3. Optional: Beispieldaten prüfen
dbt run-operation get_parquet_data --args '{"folder_path": "<concept>/<quelle>", "file_name": "<Datei>.parquet", "limit": 3}'
```

**Voraussetzungen:**
- External Data Source (z. B. `StageFileSystem`) und File Format müssen in der Datenbank existieren
- Der ADLS-Gen2-Container muss über PolyBase/OPENROWSET erreichbar sein

---

◀ [Data Vault 2.1 Leitfaden](01-data-vault-leitfaden.md) · [Übersicht](00-entwicklerhandbuch.md) · [Projektstruktur](03-projektstruktur.md) ▶
