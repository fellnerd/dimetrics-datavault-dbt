---
title: "Troubleshooting"
tags:
  - entwickler
  - typ/troubleshooting
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Troubleshooting

### Häufige Fehler

| Fehler | Ursache | Lösung |
|--------|---------|--------|
| `Column not found` | Spalte fehlt in External Table | `sources.yml` prüfen, `stage_external_sources` ausführen |
| `Columnstore not supported` | Service-Tier ohne Columnstore | `+as_columnstore: false` in Config |
| `Hash Diff changed unexpectedly` | Neue Spalte ohne Full Refresh | `dbt run --full-refresh` |
| `Duplicate key` | Unique-Constraint verletzt | Hash Key Berechnung prüfen |
| `Cross-database reference` | Hardcoded Database | `{{ target.database }}` verwenden |
| `Login timeout` | Token abgelaufen (Azure CLI) oder Firewall | `az login` bzw. Firewall-Freigabe prüfen |

### Debug-Befehle

```bash
# Generiertes SQL anzeigen
dbt compile --select <model>
cat target/compiled/datavault/models/path/to/model.sql

# Logs prüfen
less logs/dbt.log

# Letzte Query
cat target/run/datavault/models/path/to/model.sql

# Verbindung testen
dbt debug

# Ladeprotokoll und Row Counts
dbt run-operation log_row_counts
```

> Weitere Diagnosewege (Ladeprotokoll `vault.load_status_pending_v`, RLS-Overhead messen) stehen in der [Systemdokumentation, Kapitel 9](../03-system/allgemein/09-monitoring-troubleshooting.md).

---

◀ [Deployment Workflow](06-deployment-workflow.md) · [Übersicht](00-entwicklerhandbuch.md) · [Checklisten](08-checklisten.md) ▶
