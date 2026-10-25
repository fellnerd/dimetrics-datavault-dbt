---
title: "Monitoring & Troubleshooting"
tags:
  - system
  - typ/troubleshooting
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Monitoring & Troubleshooting

### 9.1 Logs und Laufprotokolle

- dbt Logs: `logs/dbt.log`
- Target-Artefakte: `target/` (`run_results.json`, kompiliertes SQL)
- **Ladeprotokoll in der Datenbank:** der `on-run-end`-Hook `log_load_status()` schreibt je dbt-Lauf einen Statuseintrag (Tabelle via `create_load_status_table`); die View `vault.load_status_pending_v` zeigt an, ob seit dem letzten Lauf neue Quelldaten eingetroffen sind. Das Skript `scripts/check_load_pending.py` wertet sie aus und steuert den ADF-getriggerten CI-Job.
- **Row Counts:** `dbt run-operation log_row_counts`
- **RLS-Overhead messen:** `dbt run-operation measure_rls_overhead --args '{"relation": "<objekt>"}'`

### 9.2 Häufige Fehler

| Fehler | Ursache | Lösung |
|--------|---------|--------|
| `Cross-database reference not supported` | Hardcoded Datenbank | `{{ target.database }}` bzw. `ref()` verwenden |
| `Columnstore not supported` | Service-Tier ohne Columnstore | `+as_columnstore: false` |
| `External table error` / `location does not exist` | Parquet-Datei fehlt oder wird gerade geschrieben | Landing Zone prüfen, `stage_external_sources` erneut ausführen |
| `Invalid column name` nach Quelländerung | External Table veraltet | `stage_external_sources` mit `--vars 'ext_full_refresh: true'` |
| Hash Diff ändert sich unerwartet | Hash-Input geändert (Spalte, Typ, Casing) | betroffene Modelle mit `--full-refresh` neu bauen |
