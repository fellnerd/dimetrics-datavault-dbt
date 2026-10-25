---
title: "Probleme & Lösungen"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Probleme & Lösungen

### Problem 1: automate-dv Hash Macros inkompatibel
**Symptom:** Fehler bei Verwendung von automate-dv hash() Macro

**Ursache:** automate-dv optimiert für Snowflake/BigQuery, SQL Server anders

**Lösung:** Eigene Hash-Logik im Staging Model:
```sql
CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2) AS hk_entity
```

### Problem 2: Columnstore Index nicht verfügbar
**Symptom:** `CREATE TABLE failed because the following SET options have incorrect settings: 'ANSI_NULLS'`

**Ursache:** Azure SQL Basic Tier unterstützt keine Columnstore Indexes

**Lösung:** In dbt_project.yml und Model-Config:
```yaml
+as_columnstore: false
```

### Problem 3: Schema-Prefix unerwünscht
**Symptom:** Schemas wurden als `dv_stg` statt `stg` erstellt

**Ursache:** dbt-sqlserver fügt Target-Schema als Prefix hinzu

**Lösung:** Custom Macro in `macros/generate_schema_name.sql`:
```sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {{ custom_schema_name | trim }}
{% endmacro %}
```

### Problem 4: profiles.yml im Repo
**Symptom:** Sicherheitsrisiko durch Credentials im Git

**Lösung:** 
- profiles.yml in ~/.dbt/ (außerhalb Repo)
- .gitignore mit `profiles.yml`
- Azure CLI Authentication (keine Passwörter)

### Problem 5: ROW_NUMBER() Performance bei is_current
**Symptom:** Langsame Abfragen bei großen Satellites mit ROW_NUMBER() für Current-Ermittlung

**Lösung:** 
- Physisches `dss_is_current` Flag (CHAR(1): 'Y'/'N')
- Post-Hook Macro `update_satellite_current_flag()` setzt alte Records auf 'N'
- `dss_end_date` für historische Abfragen ohne Window Functions

### Problem 6: object_id nicht global unique
**Symptom:** Duplikate in `hub_company` wenn nur `object_id` als Business Key

**Ursache:** `object_id` ist nur innerhalb einer Quelltabelle unique, nicht systemübergreifend

**Lösung:** Composite Key aus `object_id + source_table`:
```sql
HASHBYTES('SHA2_256', CONCAT(object_id, '^^', source_table))
```

### Problem 7: Schema-Änderungen bei Incremental Models
**Symptom:** Neue Spalten im Model erscheinen nicht in der DB-Tabelle

**Ursache:** dbt fügt bei `incremental` Models standardmäßig **keine neuen Spalten** hinzu

**Lösung:** In `dbt_project.yml`:
```yaml
models:
  datavault:
    raw_vault:
      satellites:
        +on_schema_change: append_new_columns
```

**Wichtig:** 
- `append_new_columns` fügt neue Spalten hinzu (bestehende Zeilen haben NULL)
- `sync_all_columns` würde auch Spalten entfernen (gefährlich!)
- `fail` (default) bricht ab, wenn Schema abweicht
- **Nie** `--full-refresh` bei historisierten Data Vault Tabellen!

### Problem 8: Deploy-Dialog auf Commits-Seite fehlte
**Symptom:** "Deploy to Data Vault" Button auf Commits-Seite machte nur Seiten-Refresh, kein Dialog

**Ursache:** Zwei verschiedene Deploy-Implementierungen:
- `/deploy` Seite: Hatte korrekten Dialog mit SSE-Streaming
- `/commits` Seite: Direkter API-Call ohne Dialog

**Lösung:**
1. Dialog mit Modus-Auswahl zur Commits-Seite hinzugefügt
2. SSE-Streaming (EventSource) für Live-Logs implementiert
3. Deploy-Modi: "Load + Master" (full) und "Nur Load" (load)

### Problem 9: Doppelte mds_load Tabellen (load_product vs product)
**Symptom:** `mds_load.load_product` und `mds_load.product` existieren beide

**Ursache:** API-Route `ensureLoadTable()` erstellte Tabelle mit `load_` Prefix, aber dbt-Model nutzt nur Entity-Code als Alias

**Lösung:**
```typescript
// VORHER (falsch):
const tableName = `load_${entity.code.toLowerCase()}`

// NACHHER (korrekt):
const tableName = entity.code.toLowerCase()
```

**Wichtig:** dbt Models haben `alias='product'` (ohne Prefix), daher muss die API konsistent sein!

---

◀ [Entscheidungen & Begründungen](08-entscheidungen-begruendungen.md) · [Übersicht](00-lessons-learned.md) · [Best Practices (gelernt)](10-best-practices-gelernt.md) ▶
