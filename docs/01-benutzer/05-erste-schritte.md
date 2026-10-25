---
title: "Erste Schritte"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Erste Schritte

Von einem leeren Rechner bis zum ersten erfolgreichen `dbt debug`. Getestete Versionen: Python 3.11, dbt-core 1.11, dbt-sqlserver 1.9, automate_dv 0.11.4, dbt_external_tables 0.12.0.

## 1. Voraussetzungen

| Komponente | Wozu | Installation (macOS / Windows) |
|------------|------|--------------------------------|
| **Python 3.10–3.12** | Laufzeit für dbt | `brew install python@3.11` / [python.org](https://www.python.org/downloads/) (Haken „Add to PATH“) |
| **ODBC Driver 18 for SQL Server** | Verbindung zu Azure SQL | `brew tap microsoft/mssql-release && brew install msodbcsql18` / [Microsoft-Download](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server) |
| **Azure CLI** | Anmeldung mit Entra ID (`authentication: cli`) | `brew install azure-cli` / `winget install Microsoft.AzureCLI` |
| **Git** | Repository | `brew install git` / `winget install Git.Git` |
| **VS Code** (empfohlen) | Editor | Erweiterungen: *dbt Power User* (innoverio), *SQL Server (mssql)*, *YAML* |
| Netzwerk | Zugriff auf den SQL Server | Firewall-Freigabe der eigenen IP bzw. VPN — über den Betrieb beantragen |
| Berechtigung | Lesen/Schreiben in der Dev-Datenbank | Mitgliedschaft in der Entwickler-Gruppe (Entra ID) |

## 2. Projekt einrichten

```bash
git clone <repository-url> datavault-dbt
cd datavault-dbt

# Virtuelle Umgebung (einmalig) und aktivieren (bei jeder neuen Shell)
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate

# dbt und SQL-Server-Adapter
python -m pip install --upgrade pip
pip install -r requirements.txt          # gepinnte Versionen (dbt-core, dbt-sqlserver, pyodbc)

# dbt-Pakete aus packages.yml installieren (nach dbt_packages/)
dbt deps
```

`dbt deps` installiert die Pakete, auf denen das Projekt aufbaut:

| Paket | Version | Wofür |
|-------|---------|-------|
| `Datavault-UK/automate_dv` | 0.11.4 | Makros `stage()`, `hub()`, `sat()`, `link()`, `t_link()`, `eff_sat()`, `ma_sat()`, `pit()` — erzeugen das SQL der Vault-Objekte |
| `dbt-labs/dbt_external_tables` | 0.12.0 | `stage_external_sources`: legt die External Tables aus `sources.yml` an |

Die exakten Versionen sind in `packages.yml` bzw. `package-lock.yml` fixiert. Nach jeder Änderung an `packages.yml` erneut `dbt deps` ausführen.

## 3. Verbindung konfigurieren

dbt liest das Profil `datavault` aus `profiles.yml`. Die Datei enthält Zugangsdaten und wird **nie** eingecheckt (steht in `.gitignore`). Vorlage: `profiles.yml.example` im Repository.

```yaml
datavault:
  target: <mandant>-dev                  # Standard-Target
  outputs:
    <mandant>-dev:
      type: sqlserver
      driver: 'ODBC Driver 18 for SQL Server'
      server: <sql-server>.database.windows.net
      port: 1433
      database: <datenbank>-dev
      schema: stg
      authentication: cli                # Entra ID über az login; alternativ sql + user/password
      encrypt: true
      trust_cert: false
    <mandant>-test:   { … database: <datenbank>-test … }
    <mandant>:        { … database: <datenbank> … }
```

Ablageort: im Projektordner (dbt findet ihn dort automatisch) oder in `~/.dbt/`. Bei `authentication: cli` vorher anmelden:

```bash
az login
az account show          # richtige Subscription/Tenant?
```

## 4. Verfügbare Targets

| Target | Umgebung | Wer | Aufruf |
|--------|----------|-----|--------|
| `<mandant>-dev` (Standard) | Entwicklung, gemeinsame Dev-Datenbank | Entwickler | `dbt run` |
| `<mandant>-test` | Test / fachliche Abnahme | Pipeline, Entwickler im Ausnahmefall | `dbt run --target <mandant>-test` |
| `<mandant>` | Produktion | **nur die Pipeline** | — |

Konkrete Server- und Datenbanknamen: [Projektspezifische Dokumentation](../04-mandant-architektur/00-mandant-architektur.md). Test und Produktion werden über die Pipeline beliefert, siehe [Deployment Workflow](../02-entwickler/06-deployment-workflow.md).

## 5. Verbindung testen

```bash
dbt debug
```

Erwartet: `Connection test: [OK connection ok]` und `All checks passed!`. Schlägt es fehl: [Troubleshooting → Verbindung](11-troubleshooting.md).

## 6. Optional: Landing Zone erkunden

Die Macros zum Durchsuchen von Parquet-Dateien brauchen ein SAS-Token des Storage-Containers (Leserechte, zeitlich begrenzt) als Umgebungsvariable:

```bash
export STAGE_FS_SAS="se=...&sp=rl&sv=...&sig=..."
```

## 7. Erster Lauf

```bash
dbt ls --select staging | head      # Modelle sichtbar?
dbt compile --select <ein_modell>   # SQL erzeugen ohne Datenbankänderung
dbt run --select <ein_modell>       # gegen Dev bauen
```

Weiter mit den [dbt-Befehlen](06-dbt-befehle.md).

---

◀ [Namenskonventionen](04-namenskonventionen.md) · [Übersicht](00-benutzerhandbuch.md) · [dbt-Befehle](06-dbt-befehle.md) ▶
