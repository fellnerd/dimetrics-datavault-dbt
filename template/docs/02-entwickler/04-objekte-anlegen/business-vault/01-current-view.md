---
title: "Current View erstellen (sat_*_current_v)"
tags:
  - entwickler/business-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Business Vault](00-business-vault.md)

# Current View erstellen (sat_*_current_v)

📄 **Beispiel im Repository:** `models/raw_vault/<concept>/satellites/sat_<entity>__<quelle>_current_v.sql` · Generator-Macro: [macros/satellite_current_view.sql](../../../../macros/satellite_current_view.sql)

Für jeden Satellite wird eine Current View erstellt, die den aktuellen Stand bereitstellt. Mart-Modelle referenzieren diese Views statt der Satellites direkt.

📄 **Datei:** `models/raw_vault/_common/satellites/sat_<entity>_current_v.sql`

```sql
{{ config(materialized='view') }}
{{ satellite_current_view(
    satellite_model='sat_<entity>',
    hashkey_column='hk_<entity>'
) }}
```

**Zugriffsmuster:**
- **SCD1 (aktueller Stand):** `WHERE dss_is_current = 'Y'`
- **SCD2 (volle Historie):** Kein Filter, alle Records

**Datenfluss:**
```
Hub/Sat (vault.*) → Current View (sat_*_current_v) → Mart (mart_*.*)
```

---

[Übersicht](00-business-vault.md) · [PIT Table erstellen](02-pit-table.md) ▶
