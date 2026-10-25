---
title: "Erweiterung"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Erweiterung

### 8.1 Neuen Mandanten hinzufügen

1. **Datenbanken anlegen** — je eine für dev, test und prod:
   ```bash
   az sql db create \
     --resource-group <resource-group> \
     --server <sql-server> \
     --name <datenbank>
   ```

2. **Targets ergänzen** (`profiles.yml` lokal, Profil-Generierung in der CI):
   ```yaml
   <mandant>-dev:
     type: sqlserver
     driver: 'ODBC Driver 18 for SQL Server'
     server: <sql-server>.database.windows.net
     database: <datenbank>
     schema: dv
     # Authentifizierung wie bei den bestehenden Targets
   ```
   Das Macro `tenant_key()` leitet den Mandantenschlüssel aus dem Target-Namen ab — neue Mandanten dort ergänzen oder über `var('tenant_key')` setzen.

3. **Security-Fundament deployen:** Skripte aus `security/` (Schema `sec`, Funktionen, Rechtetabellen, Service-User-Exemption) einmalig pro Datenbank ausführen.

4. **Infrastruktur und Daten aufbauen:**
   ```bash
   dbt run-operation stage_external_sources --target <mandant>-dev
   dbt seed --target <mandant>-dev
   dbt run --target <mandant>-dev
   dbt test --target <mandant>-dev
   ```

### 8.2 Neue Entity hinzufügen

1. **External Table in `models/staging/sources.yml` definieren** (`ext_<concept>_<entity>`)
2. **Staging View erstellen:** `models/staging/<concept>_<entity>.sql`
3. **Hub erstellen:** `models/raw_vault/<_common|concept>/hubs/hub_<entity>.sql`
4. **Satellite erstellen:** `.../satellites/sat_<entity>__<quelle>.sql`
5. **Link erstellen (falls nötig):** `.../links/link_<entity1>_<entity2>.sql`
6. **Tests und YAML-Dokumentation ergänzen**

Ausführlich im [Entwicklerhandbuch](../../02-entwickler/04-objekte-anlegen/00-objekte-anlegen.md).
