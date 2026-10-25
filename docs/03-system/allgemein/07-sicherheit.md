---
title: "Sicherheit"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Sicherheit

### 7.1 Authentifizierung

- **dbt → Azure SQL (CI):** SQL-Authentifizierung; Benutzer und Passwort kommen aus geschützten CI-Variablen, die `profiles.yml` wird im Job erzeugt und nicht versioniert.
- **dbt → Azure SQL (lokal):** SQL-Authentifizierung oder Azure CLI (`authentication: cli`), je nach Berechtigungsmodell des Mandanten.
- **External Tables → ADLS:** Managed Identity bzw. SAS-basierte Credentials der Datenbank.
- **Parquet-Exploration:** Die Macros `list_parquet_files` / `get_parquet_schema` / `get_parquet_data` nutzen ein SAS-Token aus der Umgebungsvariablen `STAGE_FS_SAS` (`var('stage_fs_sas')`) — nie im Repository ablegen.

### 7.2 Netzwerk

- SQL Server Firewall: Azure-Dienste und definierte IP-Bereiche (Runner, Arbeitsplätze)
- ADLS: Zugriff über den Storage-Endpunkt, optional Private Endpoint

### 7.3 Secrets

- Keine Passwörter im Repository und keine `profiles.yml` unter Versionskontrolle
- Lokale Profile liegen in `~/.dbt/`, CI-Profile werden zur Laufzeit generiert
- Tokens (SAS, Service Principal) über Umgebungs- bzw. CI-Variablen

### 7.4 Datenzugriffs-Security (OLS / RLS / CLS / CLE)

> Vollständige Referenz: **[03-system/security/](../security/00-security.md)**

Vier Schichten, Enforcement an der Mart-Grenze — Business-User erreichen ausschließlich `mart*`-Schemas:

| Schicht | Mechanismus | Verwaltung |
|---|---|---|
| **OLS** | Entra-Gruppen (`<gruppen-prefix>-<bereich>-ro`) + `GRANT SELECT` auf `mart*`-Views, gesetzt per `on-run-end`-Hook `grant_select_on_views()` aus `var('ols_view_grants')` | SSMS-Skripte in `security/ols/` + dbt-Hook |
| **RLS** | `sec.fn_check_rls` auf `dss_sec_value_key` (`'<mandant>'` bzw. `'<mandant>\|\|<kontext>'`) — in `_v`-Views via Macro `rls_filter`, auf physischen Fakt-Tabellen als Security Policy via Hook-Paar | dbt-Macros + `security/ddl/` |
| **CLS** | Spalten-Maskierung via Macro `cls_mask` + `sec.fn_check_cls` (z. B. Kontext `person_pii`) | dbt-Models |
| **CLE** | Tiering: Tier-1-Spalten (Sozialversicherungs-/Ausweisnummern, Badge-IDs) tauchen in keinem Mart auf; Baseline TDE + verschlüsselte Verbindungen | dbt-Test `assert_no_tier1_columns_in_mart` |

**Mandantentrennung:** DB pro Mandant und Umgebung (stärkste Isolation) **plus** Mandanten-Segment im `dss_sec_value_key`, abgeleitet pro dbt-Target über das Macro `tenant_key()`. Berechtigungen werden pro Entra-Gruppe (`sec.sec_group_privilege`, Standardweg) oder pro User-UPN (`sec.sec_user_privilege`, Ausnahmen/befristet) vergeben; `sec.sec_special_user_privilege` regelt Admin-/Service-User-Bypass (`no_sec` 1/2). Der dbt-Service-User benötigt zwingend `no_sec = 1`.

Das Security-Fundament (`sec`-Schema, Funktionen, Rechtetabellen) wird **nicht** über dbt deployed, sondern einmalig pro Datenbank über die Skripte in `security/`.

Details: [Deployment-Runbook](../../../security/DEPLOYMENT.md)
