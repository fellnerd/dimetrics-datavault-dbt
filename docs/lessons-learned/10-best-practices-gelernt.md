---
title: "Best Practices (gelernt)"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Best Practices (gelernt)

### dbt Projektstruktur
```
models/
  staging/           # Views mit Hash-Berechnung
  raw_vault/
    hubs/            # Business Key + Metadata
    satellites/      # Attribute + Hash Diff
    links/           # Beziehungen
  business_vault/    # PITs, Bridges (virtuell)
```

### Staging Pattern
1. External Table als Source (`stg.ext_<concept>_<entity>`)
2. Staging View berechnet alle Hash Keys (`stg.<concept>_<entity>`)
3. Hash Key = Business Key Hash
4. Hash Diff = Alle Attribute Hash (für Change Detection)

### Satellite Change Detection
```sql
LEFT JOIN ON hk AND NOT EXISTS (sat mit gleichem hd)
```
Statt: Timestamp-basierter Vergleich

### Data Vault 2.1 Compliance Checkliste

| Feature | Status | Implementierung |
|---------|--------|----------------|
| Hash Keys (SHA2_256) | ✅ | `HASHBYTES()` mit CHAR(64) |
| Hash Diff für Change Detection | ✅ | `hd_*` Spalten in Satellites |
| Hash Separator '^^' | ✅ | Composite Keys in jira_company |
| dss_load_date Metadata | ✅ | Alle Vault-Objekte |
| dss_record_source | ✅ | Quellsystem-Tracking |
| dss_is_current Flag | ✅ | Satellites mit Post-Hook |
| dss_end_date | ✅ | Validity Periods |
| Ghost Records | ✅ | Macro erstellt (manuell ausführen) |
| PIT Tables | ✅ | pit_company für History |
| Effectivity Satellites | ✅ | eff_sat_company_country |
| Zero Key (0x00...) | ✅ | Macro vorhanden |
| Error Key (0xFF...) | ✅ | Macro vorhanden |

### Wiederverwendbare Macros

| Macro | Datei | Zweck |
|-------|-------|-------|
| `generate_schema_name` | macros/generate_schema_name.sql | Schema ohne Prefix |
| `update_satellite_current_flag` | macros/satellite_current_flag.sql | dss_is_current Post-Hook |
| `update_effectivity_end_dates` | macros/satellite_current_flag.sql | Effectivity Sat End-Dating |
| `zero_key` | macros/ghost_records.sql | 64x '0' für NULL BKs |
| `error_key` | macros/ghost_records.sql | 64x 'F' für Fehler |
| `insert_ghost_records` | macros/ghost_records.sql | Ghost Records in Hubs |

---

◀ [Probleme & Lösungen](09-probleme-loesungen.md) · [Übersicht](00-lessons-learned.md) · [CI/CD Pipeline (GitHub Actions)](12-ci-cd-pipeline-github-actions.md) ▶
