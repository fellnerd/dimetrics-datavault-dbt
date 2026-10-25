---
title: "Komponenten"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Komponenten

### 2.1 Azure Ressourcen

Pro Mandant werden dieselben Bausteine verwendet; die Namen stehen in der Mandanten-Dokumentation.

| Ressource | Rolle |
|-----------|-------|
| Azure SQL Server | Hosting der Mandanten-Datenbanken |
| SQL Database (dev) | Entwicklung |
| SQL Database (test) | Integration/Abnahme, Ziel der ADF-getriggerten Läufe |
| SQL Database (prod) | Produktion |
| Storage Account (ADLS Gen2) | Landing Zone für Parquet-Dateien |
| Container | Staging-Bereich, Ordnerstruktur `<concept>/<quelle>/` |
| Azure Data Factory / Synapse | Beladung der Landing Zone, Trigger für dbt-Läufe |
| CI-Runner (VM oder Azure Container Apps) | Ausführung von dbt in der Pipeline |

### 2.2 Datenbank-Schemas

| Schema | Inhalt | Beschreibung |
|--------|--------|--------------|
| `stg` | `ext_<concept>_<entity>`, `<concept>_<entity>`, `psa_*` | External Tables, Staging Views, optionale PSA; hier entstehen Hash Keys und Hash Diffs |
| `vault` | `hub_*`, `sat_*`, `link_*`, `ref_*` | Quellübergreifende Raw-Vault-Objekte (`models/raw_vault/_common`) |
| `vault_<concept>` | `hub_*`, `sat_*`, `link_*` | Raw Vault je Quellsystem/Domäne (z. B. CRM, ERP, Sensordaten) |
| `dv` | Default-Schema der Verbindung | Wird als Default-Schema im Profil geführt; Modelle setzen ihr Schema explizit |
| `mart`, `mart_<domain>` | Dimensionen, Fakten, `_v`-Views | Publizierte Konsumenten-Schicht (einzige Schemas mit Business-Grants) |
| `sec` | `sec_user_privilege`, `sec_group_privilege`, `sec_special_user_privilege`, `fn_check_rls`, `fn_check_cls` | Security-Fundament für RLS/CLS (manuell via `security/`-Skripte deployed) |

Das Schema eines Modells kommt aus `dbt_project.yml` (Ordner → Schema) in Verbindung mit dem Macro `generate_schema_name`, das den dbt-Standard-Prefix unterdrückt.

### 2.3 dbt Packages

| Package | Version | Zweck |
|---------|---------|-------|
| `automate_dv` | 0.11.4 | Data-Vault-Macros (Staging, Hubs, Sats, Links, Eff-Sats, PIT) |
| `dbt_external_tables` | 0.12.0 | Deklarative External-Table-Verwaltung aus `sources.yml` |
| `dbt_utils` | 1.3.3 | Allgemeine Utility-Macros (transitive Abhängigkeit) |

Maßgeblich sind `packages.yml` und `package-lock.yml`. Eigene Macros haben Vorrang vor denen des Packages — geregelt über `dispatch` in `dbt_project.yml` (`search_order: ['datavault', 'automate_dv']`).
